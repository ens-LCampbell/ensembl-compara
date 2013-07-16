# patch_72_73_a.sql
#
# Title: Update schema version.
#
# Description:
#   Update schema_version in meta table to 73.

DELETE FROM meta WHERE meta_key='schema_version';
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL, 'schema_version', '73');

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_72_73_a.sql|schema_version');
