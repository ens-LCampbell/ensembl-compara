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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DumpHomologyStats

=head1 DESCRIPTION

Dumps the homology statistics from a rapid homology database into a JSON file. Parses the output
file and flows it into the next step.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DumpHomologyStats;

use warnings;
use strict;
use File::Path;
use JSON qw(decode_json);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;
    my $filename = $self->param('species_name') . '-' . $self->param('assembly') . '-' . $self->param('geneset') . '-' . 'homology_stats' . '.json';
    $self->param('filename', $filename);
    my $filepath = $self->param_required('dump_dir') .'/homology_stats/'. $self->param('filename');
    $self->param('filepath', $filepath);
}

sub run {
    my $self = shift;
    my $out_dir = $self->param_required('dump_dir') .'/homology_stats';
    my $filepath = $self->param_required('filepath');
    mkpath($out_dir, 1, oct("755"));

    # Connect to per-species compara database:
    my $compara_dba   = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param_required('per_species_db') );
    my $meta          = $compara_dba->get_MetaContainer;
    # Get the reference collection info from the accumulator:
    my $refcoll_info = $self->param_required('refcoll_info')->{$self->param_required('genome_db_id')};
    # Set meta keys for reference database and collection:
    $meta->store_key_value('refdb_version', $refcoll_info->{'refdb_version'});
    $meta->store_key_value('ref_coll', $refcoll_info->{'ref_coll'});

    my $homology_stats_script = $self->param_required('homology_stats_script');
    my $db = $self->param_required('per_species_db');
    my $refdb = $self->param_required('ref_dbname');

    my $cmd = "python $homology_stats_script -i -x -d '$db' -r $refdb -o '$filepath'";
    my $run_cmd = $self->run_command($cmd, { 'die_on_failure' => 1});
}

sub write_output {
    my $self = shift;
    my $output_id = {
        filepath    => $self->param_required('filepath'),
        homology_stats => decode_json($self->_slurp( $self->param('filepath') )),
    };
    $self->dataflow_output_id( $output_id, 1 );
}
1;

