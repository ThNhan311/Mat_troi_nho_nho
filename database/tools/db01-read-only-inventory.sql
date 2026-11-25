-- READ-ONLY INVENTORY ONLY. The DB owner chooses the target/readonly connection.
-- Do not run Flyway, DDL, clean/repair, migration or data repair from this script.
\set ON_ERROR_STOP on
\if :{?expected_database}
\else
 \echo 'DB01 expected_database required'
 DO $$BEGIN RAISE EXCEPTION 'DB01_REQUIRED_TARGET_IDENTITY_MISSING_OR_MISMATCH'; END$$;
\endif
\if :{?expected_role}
\else
 \echo 'DB01 expected_role required'
 DO $$BEGIN RAISE EXCEPTION 'DB01_REQUIRED_TARGET_IDENTITY_MISSING_OR_MISMATCH'; END$$;
\endif
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '10s';
SELECT current_database()=:'expected_database' AND current_user=:'expected_role' AS target_ok \gset
\if :target_ok
\else
 \echo 'DB01 target identity mismatch; inventory stopped'
 DO $$BEGIN RAISE EXCEPTION 'DB01_REQUIRED_TARGET_IDENTITY_MISSING_OR_MISMATCH'; END$$;
\endif
SELECT current_database() database_name,current_user role_name,inet_server_addr() server_addr,
       inet_server_port() server_port,current_setting('server_version') postgres_version,
       current_setting('transaction_read_only') transaction_read_only,
       current_setting('TimeZone') session_timezone;
SELECT to_regclass('public.flyway_schema_history') IS NOT NULL AS has_history \gset
\if :has_history
 SELECT installed_rank,version,description,script,checksum,type,success,installed_on
 FROM public.flyway_schema_history ORDER BY installed_rank;
\endif
SELECT table_name,column_name,data_type,is_nullable,character_maximum_length,numeric_precision,numeric_scale
 FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name,ordinal_position;
SELECT c.relname table_name,con.conname constraint_name,pg_get_constraintdef(con.oid) definition
 FROM pg_constraint con JOIN pg_class c ON c.oid=con.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' ORDER BY c.relname,con.conname;
SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname;
SELECT to_regclass('public.payment_transactions') IS NOT NULL AS has_payments \gset
\if :has_payments
 -- JSON lookup avoids referencing dropped V7 columns. Missing columns are NOT recovered here.
 SELECT count(*) payment_rows,
  count(*) FILTER(WHERE to_jsonb(p)?'period_start') rows_with_period_start_column,
  count(*) FILTER(WHERE to_jsonb(p)->>'period_start' IS NOT NULL) nonnull_period_start,
  count(*) FILTER(WHERE to_jsonb(p)->>'period_end' IS NOT NULL) nonnull_period_end
 FROM public.payment_transactions p;
 SELECT status,count(*) FROM public.payment_transactions GROUP BY status ORDER BY status;
\endif
SELECT to_regclass('public.membership_initial_activations') IS NOT NULL AS has_receipts \gset
\if :has_receipts
 SELECT count(*) counter_receipts,count(DISTINCT receipt_key) distinct_receipts,
 count(*) FILTER(WHERE response_snapshot IS NULL) missing_response_snapshots
 FROM public.membership_initial_activations;
\endif
SELECT to_regclass('public.membership_paid_periods') IS NOT NULL AS has_paid_periods \gset
\if :has_paid_periods
 SELECT source,count(*) periods,min(start_date) earliest_date,max(end_date) latest_date
 FROM public.membership_paid_periods GROUP BY source ORDER BY source;
\endif
SELECT to_regclass('public.pt_account_activation') IS NOT NULL AS has_pt_state,
 to_regclass('public.member_account_activation') IS NOT NULL AS has_member_state,
 to_regclass('public.membership_periods') IS NOT NULL AS has_v7_period_model,
 to_regclass('public.renewal_payment_quotes') IS NOT NULL AS has_renewal_quotes;
-- No email, password hash, OTP digest, grant, token, template or individual payment data emitted.
-- Both models and transaction bindings; aggregate-only, no receipt/email/biometric values.
SELECT c.relname,c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN('membership_periods','membership_paid_periods','db01_legacy_membership_periods','db01_period_sources');
SELECT to_regclass('public.membership_periods') IS NOT NULL AS has_v7_periods \gset
\if :has_v7_periods
 SELECT source,count(*),min(period_start),max(period_end),count(payment_transaction_id) linked_payments
 FROM membership_periods GROUP BY source ORDER BY source;
 SELECT count(*) bad_v7_payment_binding FROM membership_periods l JOIN payment_transactions p ON p.id=l.payment_transaction_id
 JOIN memberships m ON m.id=l.membership_id WHERE p.member_id<>m.member_id OR p.plan_id<>l.plan_id
 OR p.membership_id IS DISTINCT FROM l.membership_id;
\endif
SELECT viewname,definition FROM pg_views WHERE schemaname='public' AND viewname IN('membership_periods','v_membership_overview');
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal
 AND c.relname IN('membership_periods','membership_paid_periods','payment_transactions','db01_legacy_membership_periods');
SELECT to_regclass('public.renewal_payment_quotes') IS NOT NULL AS has_quotes \gset
\if :has_quotes
 SELECT fulfillment_status,count(*),count(*) FILTER(WHERE reconciliation_reason IS NOT NULL) reconciliation_rows
 FROM renewal_payment_quotes GROUP BY fulfillment_status ORDER BY fulfillment_status;
\endif
SELECT to_regclass('public.db01_payment_period_evidence') IS NOT NULL AS has_bridge \gset
\if :has_bridge
 SELECT origin,count(*) FROM db01_payment_period_evidence GROUP BY origin ORDER BY origin;
\endif
COMMIT;
