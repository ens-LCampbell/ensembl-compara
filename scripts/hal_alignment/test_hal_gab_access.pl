#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use warnings;
use strict;

=head1 NAME

test_hal_gab_access.pl

=head1 DESCRIPTION

This script tests access to genomic align blocks from an MLSS backed by a HAL file.
Both access via a slices and pairwise access via dnafrags is tested.

=head1 SYNOPSIS

    test_hal_gab_access.pl --regions regions.tsv --mlss 312167 --out output.json

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the L<--compara> option must be a URL or the COMPARA_REG_PATH
environmental variable must be set.

=item B<[--compara compara_db_name_or_alias]>

The compara database to use. You can use either the original name or any of the
aliases given in the registry_configuration_file. DEFAULT VALUE: compara_curr
(assumes the registry information is given).

=item B<--mlss method_link_species_set_id>

A MethodLinkSpeciesSet identifier.

=item B<--regions regions_tsv>

A TSV containing the test regions. It can be generated by the B<sample_genomic_regions.pl> script.

=item B<[--hal_dir hal_directory]>

The path to the directory containing the HAL files. Can also be specified through the B<COMPARA_HAL_DIR>
environmental variable.

=item B<[--out output_json]>

Name of the output JSON file.

=back

=cut

use Getopt::Long;
use Text::CSV qw(csv);
use Proc::ProcessTable;
use JSON;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $help;
my $reg_conf;
my $compara = 'compara_curr';
my $mlss_id;
my $regions_tsv;
my $outfile = "test_hal_gab_access.json";
my $hal_dir;

GetOptions(
    'help'          => \$help,
    'reg_conf=s'    => \$reg_conf,
    'compara=s'     => \$compara,
    'mlss=i'        => \$mlss_id,
    'regions=s'     => \$regions_tsv,
    'hal_dir=s'     => \$hal_dir,
    'out=s'         => \$outfile,
);

# Print Help and exit if help is requested
if ($help) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

# Process command line parameters:
die("The MLSS ID must be specified!") if !$mlss_id;
die("The regions TSV file must be specified!") if !$regions_tsv;

if ($hal_dir && $ENV{COMPARA_HAL_DIR}) {
    die("Cannot set HAL dir as the COMPARA_HAL_DIR envirnomental variable is already set!");
} elsif ($hal_dir) {
    $ENV{COMPARA_HAL_DIR} = $hal_dir;
}

$reg_conf = $ENV{COMPARA_REG_PATH} if !$reg_conf;

# Load all test regions from TSV file:
sub load_regions {
    my $infile = shift;
    my $aoh = csv (in => $infile, headers => "auto", sep_char => "\t");
    for my $r (@$aoh) {
        $r->{Region} = "$r->{Species}:$r->{CoordSys}:$r->{DnaFrag}:$r->{Start}:$r->{End}";
    }
    return $aoh;
}

#################################################
## Get the adaptors from the Registry

our $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, 'throw_if_missing') if $reg_conf;

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, 'compara');
}
if (!$compara_dba) {
  die "Cannot connect to compara database <$compara>.";
}

our $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();
our $gab_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor();
our $gdb_adaptor = $compara_dba->get_GenomeDBAdaptor();
our $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();

# Get MLSS obejct by ID:
our $cactus_mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);

# Load test regions:
my $test_regions =  load_regions($regions_tsv);

my $res = {};

# Test access via a slice:
sub test_slice_access {
    my $reg = shift;
    my $res = shift;

    my $sliceAdaptor = $registry->get_adaptor($reg->{Species}, 'Core', 'Slice');
    my $slice = $sliceAdaptor->fetch_by_region($reg->{CoordSys}, $reg->{DnaFrag}, $reg->{Start}, $reg->{End});

    my @slice_gabs = @{$gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cactus_mlss, $slice)};

    my $slice_gab_count = scalar(@slice_gabs);
    print "In region $reg->{Region} found $slice_gab_count GABs\n";
    $res->{SliceSummary}->{GabCount}->{$slice_gab_count}++;

    foreach my $i (0 .. $#slice_gabs) {
        my $gab = $slice_gabs[$i];
        $res->{SliceSummary}->{GabLength}->{$gab->length}++;
    }
}

# Test pairwise access via dnafrags:
sub test_dnafrag_access {
    my $reg = shift;
    my $res = shift;

    my $min_gab_len_cutoff = int(abs($reg->{End} - $reg->{Start}) / 1000);
    my $min_ga_len_cutoff  = $min_gab_len_cutoff / 4;

    print "Testing pairwise access on region $reg->{Region}\n";

    my $genome_db1 = $gdb_adaptor->fetch_by_name_assembly($reg->{Species});
    my $dnafrag1 = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($genome_db1, $reg->{DnaFrag});
    my @dnafrag_gabs = @{$gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($cactus_mlss, $dnafrag1, $reg->{Start}, $reg->{End})};
    my $dnafrag2;
    my $greatest_ga_dnafrag_length = 0;
    foreach my $i (0 .. $#dnafrag_gabs) {
        my $gab = $dnafrag_gabs[$i];
        if ($gab->length >= $min_gab_len_cutoff) {
            foreach my $ga (@{$gab->get_all_non_reference_genomic_aligns}) {
                my $ga_dnafrag_length = $ga->dnafrag_end - $ga->dnafrag_start + 1;
                if ($ga_dnafrag_length >= $min_ga_len_cutoff && $ga_dnafrag_length > $greatest_ga_dnafrag_length) {
                    $greatest_ga_dnafrag_length = $ga_dnafrag_length;
                    $dnafrag2 = $ga->dnafrag;
                }
            }
        }
    }

    if (defined $dnafrag2) {

        my $genome_db2 = $gdb_adaptor->fetch_by_name_assembly($dnafrag2->genome_db->name);
        $dnafrag2 = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($genome_db2, $dnafrag2->name);

        my @dnafrag2_gabs = @{$gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag($cactus_mlss, $dnafrag1, $reg->{Start}, $reg->{End}, $dnafrag2)};

        my $dnafrag2_gab_count = scalar(@dnafrag2_gabs);
        $res->{PairwiseSummary}->{GabCount}->{$dnafrag2_gab_count}++;

        foreach my $i (0 .. $#dnafrag2_gabs) {
            my $gab = $dnafrag2_gabs[$i];
            $res->{PairwiseSummary}->{GabLength}->{$gab->length}++;
        }
	}
 

}

# Run tests on all regions:
for my $reg (@$test_regions) {
    test_slice_access($reg, $res);
    test_dnafrag_access($reg, $res);
}

# Get process memory usage:
my $t = Proc::ProcessTable->new();
my $memsize = 0;
foreach my $p (@{$t->table}) {
    if($p->pid() == $$) {
        $memsize = $p->size();
        last;
    }
}
$memsize = $memsize / (1024 ** 3);
$res->{MemoryUsage} = $memsize;

# Encode results in JSON and dump to
# output file:
my $json = JSON->new->utf8;
my $encoded = $json->pretty->encode($res);

open my $outfh, ">", $outfile  or die "Can't open $outfile: $!\n";
print $outfh $encoded;
close $outfh;
