=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Example::QfoProteinTrees_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::QfoProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

The QfO PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::QfoProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::Vertebrates::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the Vertebrates ones

        # custom pipeline name, in case you don't like the default one
        'pipeline_name'         => 'qfo_' . $ENV{QFO_RELEASE} . '_protein_trees_' . $self->o('rel_with_suffix'),
        # Tag attached to every single tree
        'division'              => 'qfo',

        # "Member" parameters:
        'allow_missing_coordinates' => 1,
        'allow_missing_cds_seqs'    => 0,

        # projection parameters
        'projection_source_species_names' => [],

        # blast parameters:

        # clustering parameters:
        # affects 'hcluster_dump_input_per_genome'
        'outgroups'                 => { },

        # species tree reconciliation
        'species_tree_input_file'   => undef,

        # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => [ ],

        # mapping parameters:
        'do_stable_id_mapping'      => 0,
        'do_treefam_xref'           => 0,
        'do_homology_id_mapping'    => 0,

        # homology dumps options
        'prev_homology_dumps_dir'   => undef,
        'homology_dumps_shared_dir' => undef,

        # executable locations:
        #'treebest_exe'              => '/homes/muffato/workspace/treebest/treebest.qfo',

        # connection parameters to various databases:

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db'     => "compara_master",
        'prev_rel_db'   => undef,
        'ncbi_db'       => "compara_master",
        'member_db'     => "compara_members",

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs'    => [ ],
        'curr_file_sources_locs'    => [ $ENV{ENSEMBL_ROOT_DIR} . '/ensembl-compara/conf/qfo/genome_mf.json' ],  # Can be a list of JSON files defining an additional set of species

        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ ],

        # Do we want to initialise the CAFE part now ?
        'do_cafe'  => 0,
        # gene order conservation ?
        'do_goc'   => 0,

    };
}


sub pipeline_wide_parameters {
    my ($self) = @_;
    return {
        %{$self->SUPER::pipeline_wide_parameters},

        'gene_tree_stats_shared_dir' => $self->o('work_dir') . '/' . 'gene_tree_stats',
    };
}


sub tweak_analyses {
    my $self = shift;
    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    $analyses_by_name->{'check_reusability'}->{'-parameters'}{'reuse_this'} = 0;

    foreach my $logic_name (qw(treebest treebest_short treebest_long_himem)) {
        #$analyses_by_name->{$logic_name}->{'-parameters'}{'cdna'} = 0;
        $analyses_by_name->{$logic_name}->{'-parameters'}{'store_intermediate_trees'} = 0;
        $analyses_by_name->{$logic_name}->{'-parameters'}{'store_filtered_align'} = 0;
        $analyses_by_name->{$logic_name}->{'-parameters'}{'store_tree_support'} = 0;
    }

    $analyses_by_name->{'backbone_fire_db_prepare'}->{'-parameters'} = { 'manual_ok' => 1 };
    $analyses_by_name->{'cluster_factory'}->{'-rc_name'} = '1Gb_24_hour_job';
    $analyses_by_name->{'load_mlss_id'}->{'-parameters'}->{'species_set_name'} = "qfo";
}

1;
