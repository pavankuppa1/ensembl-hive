
=pod

=head1 NAME

Bio::EnsEMBL::Hive::Utils

=head1 SYNOPSIS

        # Example of an import:
    use Bio::EnsEMBL::Hive::Utils 'stringify';
    my $input_id_string = stringify($input_id_hash);

        # Example of inheritance:
    use base ('Bio::EnsEMBL::Hive::Utils', ...);
    my $input_id_string = $self->stringify($input_id_hash);

        # Example of a direct call:
    use Bio::EnsEMBL::Hive::Utils;
    my $input_id_string = Bio::EnsEMBL::Hive::Utils::stringify($input_id_hash);

=head1 DESCRIPTION

This module provides general utility functions that can be used in different contexts through three different calling mechanisms:

    * import:  another module/script can selectively import methods from this module into its namespace

    * inheritance:  another module can inherit from this one and so implicitly acquire the methods into its namespace
    
    * direct call to a module's method:  another module/script can directly call a method from this module prefixed with this module's name

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.
  
=cut


package Bio::EnsEMBL::Hive::Utils;

use strict;
use warnings;
use Data::Dumper;

use Exporter 'import';
our @EXPORT_OK = qw( stringify destringify dir_revhash parse_cmdline_options load_file_or_module script_usage);


=head2 stringify

    Description: This function takes in a Perl data structure and stringifies it using specific configuration
                 that allows us to store/recreate this data structure according to our specific storage/communication requirements.

    Callers    : Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor      # stringification of input_id() hash
                 Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf   # stringification of parameters() hash

=cut

sub stringify {
    my $structure = pop @_;

    local $Data::Dumper::Indent    = 0;  # we want everything on one line
    local $Data::Dumper::Terse     = 1;  # and we want it without dummy variable names
    local $Data::Dumper::Sortkeys  = 1;  # make stringification more deterministic
    local $Data::Dumper::Quotekeys = 1;  # conserve some space
    local $Data::Dumper::Useqq     = 1;  # escape the \n and \t correctly

    return Dumper($structure);
}

=head2 destringify

    Description: This function takes in a string that may or may not contain a stingified Perl structure.
                 If it seems to contain a hash/array/quoted_string, the contents is evaluated, otherwise it is returned "as is".
                 This function is mainly used to read values from 'meta' table that may represent Perl structures, but generally don't have to.

    Callers    : Bio::EnsEMBL::Hive::DBSQL::MetaContainer           # destringification of general 'meta' params
                 beekeeper.pl script                                # destringification of the 'pipeline_name' meta param

=cut

sub destringify {
    my $value = pop @_;

    if($value) {
        if($value=~/^'.*'$/
        or $value=~/^".*"$/
        or $value=~/^{.*}$/
        or $value=~/^[.*]$/) {

            $value = eval($value);
        }
    }

    return $value;
}

=head2 dir_revhash

    Description: This function takes in a string (which is usually a numeric id) and turns its reverse into a multilevel directory hash.
                 Please note that no directory is created at this step - it is purely a string conversion function.

    Callers    : Bio::EnsEMBL::Hive::Worker                 # hashing of the worker output directories
                 Bio::EnsEMBL::Hive::RunnableDB::JobFactory # hashing of an arbitrary id

=cut

sub dir_revhash {
    my $id = pop @_;

    my @dirs = reverse(split(//, $id));
    pop @dirs;  # do not use the first digit for hashing

    return join('/', @dirs);
}


=head2 parse_cmdline_options

    Description: This function reads all options from command line into a key-value hash
                (keys must be prefixed with a single or double dash, the following term becomes the value).
                The rest of the terms go into the list.
                Command line options are not removed from @ARGV, so the same or another parser can be run again if needed.

    Callers    : scripts

=cut

sub parse_cmdline_options {
    my %pairs = ();
    my @list  = ();

    my $temp_key;

    foreach my $arg (@ARGV) {
        if($temp_key) {
            $pairs{$temp_key} = $arg;
            $temp_key = '';
        } elsif($arg=~/^--?(\w+)=(.+)$/) {
            $pairs{$1} = $2;
        } elsif($arg=~/^--?(\w+)$/) {
            $temp_key = $1;
        } else {
            push @list, $arg;
        }
    }
    return (\%pairs, \@list);
}


=head2 load_file_or_module

    Description: This function takes one argument, tries to determine whether it is a module name ('::'-separated)
                or a path to the module ('/'-separated), finds the module_name and dynamically loads it.

    Callers    : scripts

=cut

sub load_file_or_module {
    my $file_or_module = pop @_;

    my $module_name;

    if( $file_or_module=~/^(\w|::)+$/ ) {

        $module_name = $file_or_module;

    } elsif(-r $file_or_module) {

        if(my $package_line = `grep ^package $file_or_module`) {
            if($package_line=~/^\s*package\s+((?:\w|::)+)\s*;/) {

                $module_name = $1;

            } else {
                warn "Package line format unrecognized:\n$package_line\n";
                script_usage(1);
            }
        } else {
            warn "Could not find the package definition line in '$file_or_module'\n";
            script_usage(1);
        }

    } else {
        warn "The parameter '$file_or_module' neither seems to be a valid module nor a valid readable file\n";
        script_usage(1);
    }

    eval "require $module_name;";
    die $@ if ($@);

    return $module_name;
}


=head2 script_usage

    Description: This function takes one argument (return value).
                It attempts to run perldoc on the current script, and if perldoc is not present, emulates its behaviour.
                Then it exits with the return value given.

    Callers    : scripts

=cut

sub script_usage {
    my $retvalue = pop @_;

    if(`which perldoc`) {
        system('perldoc', $0);
    } else {
        foreach my $line (<main::DATA>) {
            if($line!~s/\=\w+\s?//) {
                $line = "\t$line";
            }
            print $line;
        }
        <main::DATA>;   # this is just to stop the 'used once' warnings
    }
    exit($retvalue);
}


1;

