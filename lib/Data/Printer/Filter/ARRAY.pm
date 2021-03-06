package Data::Printer::Filter::ARRAY;
use strict;
use warnings;
use Data::Printer::Filter;
use Data::Printer::Common;
use Scalar::Util ();

filter 'ARRAY' => sub {
    my ($array_ref, $ddp) = @_;

    return $ddp->maybe_colorize('[]', 'brackets') unless @$array_ref;
    return $ddp->maybe_colorize('[', 'brackets')
         . $ddp->maybe_colorize('...', 'array')
         . $ddp->maybe_colorize(']', 'brackets')
         if $ddp->max_depth && $ddp->current_depth >= $ddp->max_depth;

    #Scalar::Util::weaken($array_ref);
    my $string = $ddp->maybe_colorize('[', 'brackets');

    my @i = Data::Printer::Common::_fetch_indexes_for($array_ref, 'array', $ddp);

    # when showing array index, we must add the padding for newlines:
    my $has_index = $ddp->index;
    my $local_padding = 0;
    if ($has_index) {
        my $last_index;
        # Get the last index shown to add the proper padding.
        # If the array has 5000 elements but we're showing 4,
        # the padding must be 3 + length(1), not 3 + length(5000):
        for (my $idx = $#i; $idx >= 0; $idx--) {
            next if ref $i[$idx];
            $last_index = $i[$idx];
            last;
        }
        if (defined $last_index) {
            $local_padding = 3 + length($last_index);
            $ddp->{_array_padding} += $local_padding;
        }
    }

    $ddp->indent;
    foreach my $idx (@i) {
        $string .= $ddp->newline;

        # $idx is a message to display, not a real index
        if (ref $idx) {
            $string .= $$idx;
            next;
        }

        # if name was "var" it must become "var[0]", "var[1]", etc
        $ddp->current_name( $ddp->current_name . "[$idx]" );

        if ($has_index) {
            substr($string, -$local_padding) = ''; # get rid of local padding
            $string .= $ddp->maybe_colorize(
                sprintf("%-*s", $local_padding, "[$idx]"),
                'array'
            );
        }

        # scalar references should be re-referenced to gain
        # a '\' in front of them.
        my $ref = ref $array_ref->[$idx];

        if ( $ref && $ref eq 'SCALAR' ) {
            $string .= $ddp->parse(\\$array_ref->[$idx]);
        }
        elsif ( $ref && $ref ne 'REF' ) {
            $string .= $ddp->parse($array_ref->[$idx]);
        } else {
            $string .= $ddp->parse(\$array_ref->[$idx]);
        }

        $string .= $ddp->maybe_colorize($ddp->separator, 'separator')
            if $idx < $#{$array_ref} || $ddp->end_separator;

        # we're finished with "var[x]", turn it back to "var":
        my $size = 2 + length($idx); # [10], [100], etc
        my $name = $ddp->current_name;
        substr $name, -$size, $size, '';
        $ddp->current_name( $name );
    }
    $ddp->outdent;
    $ddp->{_array_padding} -= $local_padding if $has_index;
    $string .= $ddp->newline;
    $string .= $ddp->maybe_colorize(']', 'brackets');

    return $string;
};

#######################################
### Private auxiliary helpers below ###
#######################################

1;
