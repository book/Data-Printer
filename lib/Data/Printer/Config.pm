package Data::Printer::Config;
use strict;
use warnings;
use Data::Printer::Common;

sub load_rc_file {
    my ($filename) = @_;
    if (!$filename) {
        if (exists $ENV{DATAPRINTERRC}) {
            $filename = $ENV{DATAPRINTERRC};
        }
        else {
            require File::Spec;
            $filename = File::Spec->catfile(
                Data::Printer::Common::_my_home, '.dataprinter'
            );
        }
    }
    return unless $filename && -e $filename && !-d $filename;
    if (open my $fh, '<', $filename) {

        # slurp the file:
        my $rc_data;
        { local $/ = undef; $rc_data = <$fh> }
        close $fh;
        return _str2data($filename, $rc_data);
    }
    else {
        Data::Printer::Common::_warn("error opening '$filename': $!");
        return;
    }
}

sub _str2data {
    my ($filename, $content) = @_;
    my $config = { _ => {} };
    my $counter = 0;
    my $ns = '_';
    # based on Config::Tiny
    foreach ( split /(?:\015{1,2}\012|\015|\012)/, $content ) {
        $counter++;
        next if /^\s*(?:\#|\;|$)/; # skip comments and empty lines
        if ( /^\s*\[\s*(.+?)\s*\]\s*$/ ) {
            # Create the sub-hash if it doesn't exist.
            # Without this sections without keys will not
            # appear at all in the completed struct.
            $config->{$ns = $1} ||= {};
        }
        elsif ( /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ ) {
            # Handle properties:
            my ($path_str, $value) = ($1, $2);
            # turn a.b.c.d into {a}{b}{c}{d}
            my @subpath = split /\./, $path_str;
            my $current = $config->{$ns};
            while (my $subpath = shift @subpath) {
                if (@subpath > 0) {
                    $current->{$subpath} ||= {};
                    $current = $current->{$subpath};
                }
                else {
                    $current->{$subpath} = $value;
                }
            }
        }
        else {
            Data::Printer::Common::_warn("error reading rc file '$filename': syntax error at line $counter: $_");
            if ($counter == 1 && /\A\s*{/s) {
                Data::Printer::Common::_warn(
                    "RC file format changed in 1.00. Usually all it takes is:\n"
                  . "cp $filename $filename.old && perl -MData::Printer::Config -E 'Data::Printer::Config::convert(q($filename))' > $filename\n"
                  . "Please visit https://metacpan.org/pod/Data::Printer::Config for details."
                );
            }
            return {};
        }
    }
    return $config;
}

# converts the old format to the new one
sub convert {
    my ($filename) = @_;
    Data::Printer::Common::_die("please provide a .dataprinter file path")
        unless $filename;
    Data::Printer::Common::_die("file '$filename' not found")
        unless -e $filename && !-d $filename;
    open my $fh, '<', $filename
        or Data::Printer::Common::_die("error reading file '$filename': $!");

    my $rc_data;
    { local $/; $rc_data = <$fh> }
    close $fh;

    my $config = eval $rc_data;
    if ( $@ ) {
        Data::Printer::Common::_die("error loading file '$filename': $@");
    }
    elsif (!ref $config or ref $config ne 'HASH') {
        Data::Printer::Common::_die("error loading file '$filename': config file must return a hash reference");
    }
    else {
        return _convert('', $config);
    }
}

sub _convert {
    my ($key_str, $value) = @_;
    if (ref $value eq 'HASH') {
        my $str = '';
        foreach my $k (sort keys %$value) {
            $str .= _convert(($key_str ? "$key_str.$k" : $k), $value->{$k});
        }
        return $str;
    }
    elsif (ref $value) {
        Data::Printer::Common::_warn(
            " [*] path '$key_str': expected scalar, found " . ref($value)
          . ". Filters must be in their own class now, loaded with 'filter'\n"
        );
        return '';
    }
    else {
        return "$key_str = $value\n";
    }
}

1;
__END__

=head1 NAME

Data::Printer::Config - Load run-control (.dataprinter) files for Data::Printer

=head1 DESCRIPTION

This module is used internally to load C<.dataprinter> files.

=head1 THE RC FILE

    # line comments are ok, DO NOT USE inline comments at the end of a line!
    ; this is also a line comment
    multiline  = 0
    hash_max   = 5
    array_max  = 5
    string_max = 50
    class.show_methods = none
    class.internals    = 0
    filters = DB, Web

    # if you tag a class, those settings will override your basic ones
    # whenever you call p() inside that class.
    [MyApp::Some::Class]
    multiline = 1
    show_tainted: 1
    class.format_inheritance = lines
    filters = MyAwesomeDebugFilter

    [Other::Class]
    theme = Monokai

=head1 SEE ALSO

L<Data::Printer>
