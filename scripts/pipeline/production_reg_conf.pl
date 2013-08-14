
# Release Coordinator, please update this file before starting every release
# and check the changes back into CVS for everyone's benefit.

# Things that normally need updating are:
#
# 1. Release number
# 2. Check the name prefix of all databases
# 3. Possibly add entries for core databases that are still on genebuilders' servers

use strict;
use Bio::EnsEMBL::Utils::ConfigRegistry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


# ------------------------- CORE DATABASES: --------------------------------------

# The majority of core databases live on two staging servers:
Bio::EnsEMBL::Registry->load_registry_from_url(
  'mysql://ensro@ens-staging1/73');

Bio::EnsEMBL::Registry->load_registry_from_url(
  'mysql://ensro@ens-staging2/73');

# Extra core databases that live on genebuilders' servers:

#Bio::EnsEMBL::DBSQL::DBAdaptor->new(
#    -host => 'genebuild1',
#    -user => 'ensro',
#    -port => 3306,
#    -species => 'gorilla_gorilla',
#    -group => 'core',
#    -dbname => 'ba1_gorilla31_new',
#);


# ------------------------- COMPARA DATABASES: -----------------------------------

# Individual pipeline database for ProteinTrees:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_ptrees',
    -dbname => 'mm14_compara_homology_73',
);

# Individual pipeline database for ncRNAtrees:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara3',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_nctrees',
    -dbname => 'mp12_compara_nctrees_73',
);

# Individual pipeline database for Families:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara2',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_families',
    -dbname => 'lg4_compara_families_73',
);


# Compara Master database:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara1',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_master',
    -dbname => 'sf5_ensembl_compara_master',
);

# previous release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara3',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_prev',
    -dbname => 'kb3_ensembl_compara_72',
);

# current release database on one of Compara servers:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host => 'compara2',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_curr',
    -dbname => 'lg4_ensembl_compara_73',
);


# final compara on staging:
Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( ## HAS TO BE CREATED (FINAL DB)
    -host => 'ens-staging',
    -user => 'ensadmin',
    -pass => $ENV{'ENSADMIN_PSW'},
    -port => 3306,
    -species => 'compara_staging',
    -dbname => 'ensembl_compara_73',
);

1;
