#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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


use strict;
use warnings;

use File::Basename qw(dirname);
use Getopt::Long qw(:config pass_through);
use JSON qw(decode_json);

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::IO qw(:slurp);

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Registry;

my ($url, $reg_conf, $reg_type, $reg_alias);
my ($repair, $ensj_testrunner, $ensj_json_config);

GetOptions(
    'url=s'                         => \$url,
    'reg_conf|regfile|reg_file=s'   => \$reg_conf,
    'reg_type=s'                    => \$reg_type,
    'reg_alias|regname|reg_name=s'  => \$reg_alias,
    'ensj-testrunner=s'             => \$ensj_testrunner,
    'ensj-json-config=s'            => \$ensj_json_config,
    'repair'                        => \$repair,
);

unless ($url or ($reg_conf and $reg_alias)) {
    print "\nNeither --url nor --reg_conf and --reg_alias is not defined. The URL should be something like mysql://ensro\@compara1:3306/kb3_ensembl_compara_59\nEXIT 2\n\n";
    exit 2;
}

if ($reg_conf) {
    Bio::EnsEMBL::Registry->load_all($reg_conf);
}
my $dba = $reg_alias
    ? Bio::EnsEMBL::Registry->get_DBAdaptor( $reg_alias, $reg_type || 'compara' )
    : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $url );

my $division = $dba->get_division;

unless ($ensj_testrunner) {
    die "Need to give the --ensj-testrunner option or set the ENSEMBL_CVS_ROOT_DIR environment variable to use the default" unless $ENV{ENSEMBL_CVS_ROOT_DIR};
    $ensj_testrunner = $ENV{ENSEMBL_CVS_ROOT_DIR} . '/ensj-healthcheck/run-configurable-testrunner.sh';
}
die "'$ensj_testrunner' is not a valid executable" unless -x $ensj_testrunner;

unless ($ensj_json_config) {
    die "Need to give the --ensj-config option or set the ENSEMBL_CVS_ROOT_DIR environment variable to use the default" unless $ENV{ENSEMBL_CVS_ROOT_DIR};
    $ensj_json_config = $ENV{ENSEMBL_CVS_ROOT_DIR} . "/ensembl-compara/conf/$division/ensj-healthcheck.json";
}
die "'$ensj_json_config' is not a valid file" unless -e $ensj_json_config;
my $ensj_config = decode_json(slurp($ensj_json_config));


# Common parameters
my @params = (
    '--host'    => $dba->dbc->host,
    '--port'    => $dba->dbc->port,
    '--driver'  => 'org.gjt.mm.mysql.Driver',
    '--release' => $ENV{CURR_ENSEMBL_RELEASE} || software_version(),
    '--test_databases'  => $dba->dbc->dbname,
);

# RO or RW user depending on the --repair option
if ($repair) {
    push @params, (
        '--user'    =>  Bio::EnsEMBL::Compara::Utils::Registry::get_rw_user($dba->dbc->host),
        '--password'=>  Bio::EnsEMBL::Compara::Utils::Registry::get_rw_pass($dba->dbc->host),
        '--repair'  => 1,
    );
} else {
    push @params, (
        '--user'    =>  'ensro',
    );
}

# Division-specific configuration
foreach my $key (qw(host1 host2 host3 secondary.host)) {

    my $key_prefix = $key;
    my $key_suffix = $key;
    $key_prefix =~ s/host.*//;
    $key_suffix =~ s/.*host//;

    # Configure the host if it is set
    if (my $host = $ensj_config->{$key}) {
        my $port = Bio::EnsEMBL::Compara::Utils::Registry::get_port($host);
        push @params, (
            "--${key_prefix}host${key_suffix}"    => $host,
            "--${key_prefix}port${key_suffix}"    => $port,
            "--${key_prefix}user${key_suffix}"    => 'ensro',
            "--${key_prefix}driver${key_suffix}"  => 'org.gjt.mm.mysql.Driver',
        );
    } else {
        # Trick to tell the HC to ignore the default value that may be set in database.defaults.properties
        # We rely on the fact that the HC doesn't die if the host name is not valid
        push @params, (
            "--${key_prefix}host${key_suffix}"    => '""',
        );
    }
}

print "Executing: ", join(" ", $ensj_testrunner, @params, @ARGV), "\n\n";

# Need to change directory because database.default.properties is read from the current directory
chdir dirname($ensj_testrunner);
exec($ensj_testrunner, @params, @ARGV);

