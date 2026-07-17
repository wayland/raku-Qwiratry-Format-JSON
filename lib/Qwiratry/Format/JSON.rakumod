=begin pod

=head1 Overview

JSON format backend for Qwiratry, powered by L<JSON::Fast>.

Defines C<Qwiratry::Format::JSON::Parse> and
C<Qwiratry::Format::JSON::Render> implementations loaded through
L<Qwiratry::Format.make>.

The parser lowers JSON objects to hashes, arrays to arrays, strings to C<Str>,
numbers to C<Int> or C<Num>, and JSON literals to Raku booleans or undefined
values.

The renderer keeps Qwiratry's current JSONdemo behavior where it matters:
compact output by default and C<:pretty> as an explicit opt-in. It also
supports C<:spacing> and C<:sorted-keys>.

=end pod
use JSON::Fast;
use Qwiratry::Format::Base;

class Qwiratry::Format::JSON::Parse is Qwiratry::Format::Base::Parse {

	=begin pod

	=head1 Methods

	=head2 C<parse(Str $input-string)>

	Parse JSON text into ordinary Raku data structures using L<JSON::Fast>.

	=end pod
	method parse(Str $input-string --> Mu) {
		from-json($input-string)
	}
}

class Qwiratry::Format::JSON::Render is Qwiratry::Format::Base::Render {

	=begin pod

	=head2 C<render(Mu $data, Associative :%options)>

	Render ordinary Raku data structures to JSON text using L<JSON::Fast>.

	C<%options<pretty>> defaults to false so this backend stays compact by
	default, matching Qwiratry's existing JSONdemo behavior. C<%options<spacing>>
	defaults to 2, and C<%options<sorted-keys>> defaults to true for deterministic
	output.

	=end pod
	method render(Mu $data, *%options --> Str) {
		my $pretty = %options<pretty> // False;
		my $spacing = %options<spacing> // 2;
		my $sorted-keys = %options<sorted-keys> // True;

		to-json(
			$data,
			:pretty($pretty),
			:spacing($spacing),
			:sorted-keys($sorted-keys),
		)
	}
}
