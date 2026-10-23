use v6.e.PREVIEW;

use Qwiratry::DatabaseStorage::Location::Tree;
use Qwiratry::Mold::Slang;
use Qwiratry::Transformer;
use X::Qwiratry;

# §8 default merge Transformer (plan Q18 / §16.4.5): rebuild document from
# $*CONTEXT<rows>. Nested tables override :transformer on useTable.
transformer LocationJSONDefaultMerge {
	mold TOP
		when { True }
		do {
			# Push (not .Array on a Seq of Hashes): Hash is Iterable, so
			# `$seq.Array` / `[ $seq ]` flatten or nest wrongly.
			my @out;
			@out.push(%($_)) for @($*CONTEXT<rows> // []);
			@out
		}
}

=begin pod

=NAME Qwiratry *::DatabaseStorage::Location::JSON — JSON document ↔ rows

=TITLE Qwiratry *::DatabaseStorage::Location::JSON

=SUBTITLE Location-backed tables whose documents are JSON arrays of objects

=AUTHOR Tim Nelson - https://github.com/wayland

Ships with the C<Qwiratry::Format::JSON> distribution (not core). Thin
subclass of core C<Qwiratry::DatabaseStorage::Location::Tree> that defaults
C<:format('JSON')> and advertises today's root/identity/object-key projection
as §8 Format defaults (plan DatabaseStorage-Location-Tree §8 / Q4 / Q14).

Document shape (omit-args defaults):
=item Parse: JSON array of objects → one row per object; a single object →
one-row table (table root = document parse root).
=item Render/flush: rows → a JSON array of objects (empty table → C<[]>).

Override C<:table-selector> / C<:row-selector> / C<:field-projection> /
C<:transformer> / C<:path-transformer> on C<useTable> (or the constructor)
for nested tables. Default C<:path-transformer> is core
C<associative-path-transformer> (plan §10.3 / §16.4.3).

=begin code

use Qwiratry::TaOP;
use Qwiratry::Mold::Slang;
use Qwiratry::DatabaseStorage::Location::JSON;  # or rely on Database load-library

my $db = Database.new(
	storage-type => 'Location::JSON',
	location => './data',
);
my $t = $db.useTable(name => 'people', action => 'can-create');
$t.add-row({ name => 'Ada', age => 36 });
$t.storage-object.flush;  # Tree sync is explicit (plan Q20)
# → ./data/people.json

# Nested table under a key (override §8 defaults; keep sibling structure).
# Merge mold sees $*CONTEXT<rows> (plan Q18); topic is the document.
clear-collected-molds();
transformer MergePeople {
	mold TOP
		when { True }
		do {
			my %out = $_ ~~ Associative ?? %($_) !! %();
			%out<people> = [@($*CONTEXT<rows> // []).map({ %($_) })];
			%out
		}
}
# my $roster = $db.useTable(
#	name => 'roster',
#	action => 'use',
#	row-selector => sub (Mu $doc) { slip(($doc<people> // []).list) },
#	transformer => MergePeople.new,
# );

=end code

See also C<t/03-location-json.rakutest> and the core Qwiratry plan
C<docs/rakudoc/Developing/DatabaseStorage-Location-Tree.md>.

=end pod

class Qwiratry::DatabaseStorage::Location::JSON
	is Qwiratry::DatabaseStorage::Location::Tree
{
	# Parent Location defaults C<format> to C<JSONdemo>; this Format dist
	# wants C<JSON>. Keep a thin C<new> so an omitted C<:format> becomes
	# C<JSON> without treating an explicit C<JSONdemo> as "unset".
	method new(:$format = 'JSON', *%rest) {
		callwith(|%rest, :$format);
	}

	# §8 defaults when the caller/constructor did not supply a stage.
	# Callables: multi-node results use C<slip>; a bare Array/Hash is one node.
	# Parent attrs are private to Tree — set via C<is rw> accessors.
	submethod TWEAK() {
		unless self.table-selector.defined {
			self.table-selector = sub (Mu $document) { $document };
		}

		# Anonymous C<sub> (not C<< -> >>) so C<return> / C<slip> work.
		unless self.row-selector.defined {
			self.row-selector = sub (Mu $table-root) {
				without $table-root {
					return slip();
				}
				if $table-root ~~ Positional
					&& $table-root !~~ Str
					&& $table-root !~~ Associative
				{
					return slip($table-root.list);
				}
				if $table-root ~~ Associative {
					return $table-root;
				}
				X::Qwiratry::DatabaseStorage::UnexpectedShape.new(
					message => 'JSON default row-selector expected array or object table root',
					stage => 'row-selector',
					got => $table-root,
				).throw;
			};
		}

		unless self.field-projection.defined {
			self.field-projection = sub (Mu $row-node) {
				$row-node ~~ Associative
					?? %($row-node)
					!! X::Qwiratry::DatabaseStorage::UnexpectedShape.new(
						message => 'JSON default field-projection expected object row',
						stage => 'field-projection',
						got => $row-node,
					).throw;
			};
		}

		# Default merge: slang Transformer above (plan Q18 / §16.4.5).
		# Nested tables override :transformer (Callable still accepted).
		unless self.transformer.defined {
			self.transformer = LocationJSONDefaultMerge.new;
		}

		# §10.3: EMPTY mold — ancestors {}, table-site / row-collection [].
		unless self.path-transformer.defined {
			self.path-transformer = self.associative-path-transformer;
		}
	}
}
