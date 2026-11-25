-- DB01 REHEARSAL CANDIDATE ONLY. V1-V13 unchanged; version14 requires shared inventory before publication.
-- Requires before-upgrade callback, V9 and V11. Maintenance mode, no application writers.
SET LOCAL lock_timeout = '5s';
LOCK TABLE members IN EXCLUSIVE MODE;
LOCK TABLE memberships, payment_transactions, membership_paid_periods IN EXCLUSIVE MODE;
CREATE TABLE db01_period_sources (
 source_table VARCHAR(40) NOT NULL, source_id UUID NOT NULL,
 source_row JSONB NOT NULL, canonical_period_id UUID REFERENCES membership_paid_periods(id),
 PRIMARY KEY(source_table,source_id)
);
CREATE TABLE db01_generated_aggregate_archive (
 id UUID PRIMARY KEY, source_row JSONB NOT NULL, reason TEXT NOT NULL
);
DO $db01$
DECLARE r record; target_id UUID; ms record;
BEGIN
 IF to_regclass('public.db01_payment_period_evidence') IS NULL THEN RAISE EXCEPTION 'DB01_COMPATIBILITY_STEP_REQUIRED'; END IF;
 IF to_regclass('public.membership_periods') IS NOT NULL THEN
  LOCK TABLE membership_periods IN EXCLUSIVE MODE;
  IF EXISTS(SELECT 1 FROM membership_periods p WHERE p.source='ACTIVATION' AND NOT EXISTS(
   SELECT 1 FROM db01_receipt_evidence e WHERE e.legacy_period_id=p.id AND e.membership_id=p.membership_id
    AND e.source_row=to_jsonb(p))) THEN RAISE EXCEPTION 'DB01_RECEIPT_COMPATIBILITY_STEP_REQUIRED'; END IF;
  INSERT INTO db01_period_sources(source_table,source_id,source_row)
   SELECT 'V7_MEMBERSHIP_PERIODS',id,to_jsonb(l) FROM membership_periods l;
 END IF;
 INSERT INTO db01_period_sources(source_table,source_id,source_row)
  SELECT 'V2_PAYMENT_EVIDENCE',payment_id,source_row||jsonb_build_object('period_start',period_start,'period_end',period_end)
  FROM db01_payment_period_evidence;
 -- Reject V7 dated membership without any period/payment evidence. Never synthesize a cash receipt or price.
 IF to_regclass('public.membership_periods') IS NOT NULL THEN
 IF EXISTS(
   SELECT 1 FROM memberships m WHERE m.start_date IS NOT NULL AND NOT EXISTS(
    SELECT 1 FROM membership_periods l WHERE l.membership_id=m.id)
    AND NOT EXISTS(SELECT 1 FROM payment_transactions p JOIN db01_payment_period_evidence e ON e.payment_id=p.id
     WHERE p.membership_id=m.id AND p.status='SUCCESS'))
 THEN RAISE EXCEPTION 'DB01_MEMBERSHIP_COVERAGE_PROVENANCE_MISSING'; END IF;
 END IF;
 -- V11 generates a coarse aggregate before this migration. Preserve its full row before replacing
 -- only aggregates for memberships with verified granular source. No original source row is removed.
 INSERT INTO db01_generated_aggregate_archive(id,source_row,reason)
 SELECT x.id,to_jsonb(x),'V11_DERIVED_AGGREGATE_REPLACED_BY_SOURCED_PERIODS' FROM membership_paid_periods x
 WHERE x.source='LEGACY_AGGREGATE' AND x.payment_transaction_id IS NULL AND EXISTS(
  SELECT 1 FROM db01_period_sources s WHERE (s.source_row->>'membership_id')::uuid=x.membership_id);
 DELETE FROM membership_paid_periods x USING db01_generated_aggregate_archive a WHERE x.id=a.id;
 -- Import V7 rows first; UUID/date/plan are retained. Unknown original quote/name/currency stays NULL.
 FOR r IN SELECT s.*,m.member_id FROM db01_period_sources s
  JOIN memberships m ON m.id=(s.source_row->>'membership_id')::uuid
  WHERE s.source_table='V7_MEMBERSHIP_PERIODS' ORDER BY s.source_id LOOP
  IF r.source_row->>'source'='RENEWAL' AND EXISTS(SELECT 1 FROM payment_transactions p
     WHERE p.id=(r.source_row->>'payment_transaction_id')::uuid AND p.status<>'SUCCESS')
  THEN RAISE EXCEPTION 'DB01_LEGACY_PAYMENT_NOT_SUCCESS'; END IF;
  SELECT id INTO target_id FROM membership_paid_periods WHERE membership_id=(r.source_row->>'membership_id')::uuid
   AND plan_id=(r.source_row->>'plan_id')::uuid AND start_date=(r.source_row->>'period_start')::date
   AND end_date=(r.source_row->>'period_end')::date AND (
    payment_transaction_id IS NOT DISTINCT FROM (r.source_row->>'payment_transaction_id')::uuid OR
    (r.source_row->>'source'='ACTIVATION' AND source='INITIAL_COUNTER' AND EXISTS(
     SELECT 1 FROM membership_initial_activations a WHERE a.membership_id=membership_paid_periods.membership_id
      AND a.receipt_ref=r.source_row->>'receipt_ref' AND a.confirmed_by_user_id=(r.source_row->>'confirmed_by_user_id')::uuid
      AND a.listed_price_snapshot=(r.source_row->>'amount_collected')::numeric)));
  IF target_id IS NULL THEN
   IF EXISTS(SELECT 1 FROM membership_paid_periods p WHERE p.id=r.source_id OR
     (p.membership_id=(r.source_row->>'membership_id')::uuid AND daterange(p.start_date,p.end_date,'[]') &&
       daterange((r.source_row->>'period_start')::date,(r.source_row->>'period_end')::date,'[]')) OR
     p.payment_transaction_id=(r.source_row->>'payment_transaction_id')::uuid)
   THEN RAISE EXCEPTION 'DB01_PERIOD_SOURCE_CONFLICT'; END IF;
   target_id=r.source_id;
   INSERT INTO membership_paid_periods(id,member_id,membership_id,plan_id,source,start_date,end_date,payment_transaction_id,created_at)
    VALUES(target_id,r.member_id,(r.source_row->>'membership_id')::uuid,(r.source_row->>'plan_id')::uuid,
      'LEGACY_AGGREGATE',(r.source_row->>'period_start')::date,(r.source_row->>'period_end')::date,
      (r.source_row->>'payment_transaction_id')::uuid,(r.source_row->>'created_at')::timestamptz);
  END IF;
  UPDATE db01_period_sources SET canonical_period_id=target_id WHERE source_table=r.source_table AND source_id=r.source_id;
 END LOOP;
 FOR r IN SELECT s.*,p.member_id,p.membership_id,p.plan_id,p.status FROM db01_period_sources s
  JOIN payment_transactions p ON p.id=s.source_id WHERE s.source_table='V2_PAYMENT_EVIDENCE' ORDER BY s.source_id LOOP
  IF r.status<>'SUCCESS' THEN CONTINUE; END IF;
  IF r.membership_id IS NULL THEN RAISE EXCEPTION 'DB01_PAYMENT_MEMBERSHIP_BINDING_MISSING'; END IF;
  SELECT id INTO target_id FROM membership_paid_periods WHERE payment_transaction_id=r.source_id
    AND membership_id=r.membership_id AND member_id=r.member_id AND plan_id=r.plan_id
    AND start_date=(r.source_row->>'period_start')::date AND end_date=(r.source_row->>'period_end')::date;
  IF target_id IS NULL THEN
   IF EXISTS(SELECT 1 FROM membership_paid_periods p WHERE p.payment_transaction_id=r.source_id OR
     (p.membership_id=r.membership_id AND daterange(p.start_date,p.end_date,'[]') &&
       daterange((r.source_row->>'period_start')::date,(r.source_row->>'period_end')::date,'[]')))
   THEN RAISE EXCEPTION 'DB01_PERIOD_SOURCE_CONFLICT'; END IF;
   target_id=gen_random_uuid();
   INSERT INTO membership_paid_periods(id,member_id,membership_id,plan_id,source,start_date,end_date,payment_transaction_id)
    VALUES(target_id,r.member_id,r.membership_id,r.plan_id,'LEGACY_AGGREGATE',
     (r.source_row->>'period_start')::date,(r.source_row->>'period_end')::date,r.source_id);
  END IF;
  UPDATE db01_period_sources SET canonical_period_id=target_id WHERE source_table=r.source_table AND source_id=r.source_id;
 END LOOP;
 IF to_regclass('public.membership_periods') IS NOT NULL THEN
  ALTER TABLE membership_periods RENAME TO db01_legacy_membership_periods;
 END IF;
END $db01$;
CREATE FUNCTION db01_read_only_source() RETURNS trigger LANGUAGE plpgsql AS $$
 BEGIN RAISE EXCEPTION 'DB01_LEGACY_PERIOD_WRITES_DISABLED' USING ERRCODE='55000'; END $$;
DO $$ BEGIN IF to_regclass('public.db01_legacy_membership_periods') IS NOT NULL THEN
 CREATE TRIGGER db01_legacy_read_only BEFORE INSERT OR UPDATE OR DELETE ON db01_legacy_membership_periods
 FOR EACH ROW EXECUTE FUNCTION db01_read_only_source(); END IF; END $$;
-- Compatibility readers see the canonical rows, never a separately maintained period table.
CREATE VIEW membership_periods AS SELECT p.id,p.membership_id,p.plan_id,
 CASE WHEN p.source='INITIAL_COUNTER' THEN 'ACTIVATION' WHEN p.source='RENEWAL' THEN 'RENEWAL'
   ELSE COALESCE(s.source_row->>'source','LEGACY') END::varchar(24) source,
 p.start_date period_start,p.end_date period_end,p.payment_transaction_id,
 COALESCE(a.listed_price_snapshot,(s.source_row->>'amount_collected')::numeric) amount_collected,
 COALESCE(a.confirmed_by_user_id,(s.source_row->>'confirmed_by_user_id')::uuid) confirmed_by_user_id,
 COALESCE(a.confirmed_at,(s.source_row->>'confirmed_at')::timestamptz) confirmed_at,
 COALESCE(a.receipt_ref,s.source_row->>'receipt_ref') receipt_ref,COALESCE(a.note,s.source_row->>'note') note,p.created_at
 FROM membership_paid_periods p LEFT JOIN membership_initial_activations a ON a.payment_transaction_id=p.payment_transaction_id
 LEFT JOIN db01_period_sources s ON s.canonical_period_id=p.id AND s.source_table='V7_MEMBERSHIP_PERIODS';
CREATE TRIGGER db01_compat_read_only INSTEAD OF INSERT OR UPDATE OR DELETE ON membership_periods
 FOR EACH ROW EXECUTE FUNCTION db01_read_only_source();
CREATE OR REPLACE VIEW v_membership_overview AS
 SELECT m.id membership_id,m.member_id,m.status,m.start_date,m.expiry_date,
 cur.plan_id current_plan_id,cur.start_date current_period_start,cur.end_date current_period_end,
 nxt.plan_id next_plan_id,nxt.start_date next_period_start,nxt.end_date next_period_end,
 lst.last_paid_end FROM memberships m
 LEFT JOIN LATERAL(SELECT p.plan_id,p.start_date,p.end_date FROM membership_paid_periods p
  WHERE p.membership_id=m.id AND p.start_date<=(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
   AND p.end_date>=(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date ORDER BY p.start_date DESC LIMIT 1) cur ON true
 LEFT JOIN LATERAL(SELECT p.plan_id,p.start_date,p.end_date FROM membership_paid_periods p
  WHERE p.membership_id=m.id AND p.start_date>(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date ORDER BY p.start_date LIMIT 1) nxt ON true
 LEFT JOIN LATERAL(SELECT max(p.end_date) last_paid_end FROM membership_paid_periods p WHERE p.membership_id=m.id) lst ON true;
-- Compatibility columns are retained because M03/renewal still write them atomically.
-- No independent V7 writer remains. Refund/reconciliation workflows are not invented here.

-- Reserve original V7 receipt identities without inventing a COUNTER payment or M03 response.
-- receipt_key was computed by the existing Java normalizer in the compatibility callback.
CREATE FUNCTION db01_legacy_receipt_conflict() RETURNS trigger LANGUAGE plpgsql AS $$
 BEGIN IF EXISTS(SELECT 1 FROM db01_receipt_evidence WHERE receipt_key=NEW.receipt_key)
 THEN RAISE EXCEPTION 'DB01_LEGACY_RECEIPT_ALREADY_RESERVED' USING ERRCODE='23505'; END IF; RETURN NEW; END $$;
CREATE TRIGGER db01_legacy_receipt_reservation BEFORE INSERT ON membership_initial_activations
 FOR EACH ROW EXECUTE FUNCTION db01_legacy_receipt_conflict();
