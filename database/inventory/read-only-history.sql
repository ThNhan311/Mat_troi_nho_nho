-- Read-only inventory for the DATABASE OWNER to run on an authorized environment.
-- I-01 did not execute this against shared/production databases. Never include credentials.
BEGIN TRANSACTION READ ONLY;
SELECT current_database() AS database_name, current_user AS inspected_by,
       current_setting('server_version') AS postgres_version;
SELECT installed_rank,version,description,type,script,checksum,success
FROM flyway_schema_history ORDER BY installed_rank;
SELECT table_name,column_name,data_type,is_nullable
FROM information_schema.columns
WHERE table_schema='public' AND table_name IN
 ('payment_transactions','membership_periods','membership_initial_activations',
  'pt_account_activation','member_account_activation')
ORDER BY table_name,ordinal_position;
SELECT conrelid::regclass AS table_name,conname,pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE connamespace='public'::regnamespace
ORDER BY conrelid::regclass::text,conname;
COMMIT;