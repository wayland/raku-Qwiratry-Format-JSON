use v6.e.PREVIEW;

use Qwiratry::DatabaseStorage::Location::Tree;
use X::Qwiratry;

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
C<:transformer> on C<useTable> (or the constructor) for nested tables.

=begin code

use Qwiratry::TaOP;
use Qwiratry::DatabaseStorage::Location::JSON;  # or rely on Database load-library

my $db = Database.new(
	storage-type => 'Location::JSON',
	location => './data',
);
my $t = $db.useTable(name => 'people', action => 'can-create');
$t.add-row({ name => 'Ada', age => 36 });
# → ./data/people.json

=end code

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

		# Default merge: replace document with the row array (today's
		# rows-to-document). Nested tables need an override transformer.
		unless self.transformer.defined {
			self.transformer = sub (Mu $document, @rows) {
				[@rows.map({ %($_) })]
			};
		}
	}
}
