-- DB01 candidate: execute only in maintenance mode with a reviewed target inventory.
-- Not a versioned migration and never edits flyway_schema_history.
-- Invoked BEFORE_MIGRATE and AFTER_EACH_MIGRATE(V7), before V9/V11.
SET LOCAL lock_timeout = '5s';
LOCK TABLE members IN EXCLUSIVE MODE;
LOCK TABLE memberships, payment_transactions IN EXCLUSIVE MODE;
CREATE TABLE IF NOT EXISTS db01_payment_period_evidence (
 payment_id UUID PRIMARY KEY REFERENCES payment_transactions(id),
 period_start DATE NOT NULL, period_end DATE NOT NULL CHECK(period_end>=period_start),
 origin VARCHAR(40) NOT NULL, source_row JSONB NOT NULL,
 recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS db01_receipt_evidence (
 receipt_key VARCHAR(100) PRIMARY KEY, legacy_period_id UUID NOT NULL UNIQUE,
 membership_id UUID NOT NULL REFERENCES memberships(id), source_row JSONB NOT NULL
);
DO $db01$
DECLARE had_columns boolean; has_legacy boolean;
BEGIN
 IF (SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='payment_transactions' AND column_name IN('period_start','period_end'))=1 THEN RAISE EXCEPTION 'DB01_PARTIAL_PERIOD_COLUMN_SCHEMA'; END IF;
 SELECT count(*)=2 INTO had_columns FROM information_schema.columns
 WHERE table_schema='public' AND table_name='payment_transactions' AND column_name IN('period_start','period_end');
 SELECT to_regclass('public.membership_periods') IS NOT NULL INTO has_legacy;
 IF had_columns THEN
  IF EXISTS(SELECT 1 FROM payment_transactions p JOIN db01_payment_period_evidence e ON e.payment_id=p.id
   WHERE p.period_start IS NOT NULL AND (p.period_start<>e.period_start OR p.period_end<>e.period_end))
  THEN RAISE EXCEPTION 'DB01_CONFLICTING_PERIOD_EVIDENCE'; END IF;
  INSERT INTO db01_payment_period_evidence(payment_id,period_start,period_end,origin,source_row)
   SELECT id,period_start,period_end,'V2_PAYMENT_COLUMNS',to_jsonb(p) FROM payment_transactions p
   WHERE period_start IS NOT NULL ON CONFLICT(payment_id) DO NOTHING;
 END IF;
 -- V7 source is accepted only if transaction/member/plan binding is exact.
 IF has_legacy AND EXISTS(SELECT 1 FROM pg_class WHERE oid=to_regclass('public.membership_periods') AND relkind='r') THEN
  IF EXISTS(SELECT 1 FROM membership_periods l JOIN payment_transactions p ON p.id=l.payment_transaction_id
   JOIN memberships m ON m.id=l.membership_id
   WHERE l.source='RENEWAL' AND (p.member_id<>m.member_id OR p.plan_id<>l.plan_id OR p.membership_id IS DISTINCT FROM l.membership_id))
  THEN RAISE EXCEPTION 'DB01_LEGACY_PAYMENT_BINDING_MISMATCH'; END IF;
  IF EXISTS(SELECT 1 FROM membership_periods l JOIN db01_payment_period_evidence e ON e.payment_id=l.payment_transaction_id
   WHERE l.period_start<>e.period_start OR l.period_end<>e.period_end)
  THEN RAISE EXCEPTION 'DB01_CONFLICTING_PERIOD_EVIDENCE'; END IF;
  INSERT INTO db01_payment_period_evidence(payment_id,period_start,period_end,origin,source_row)
   SELECT p.id,l.period_start,l.period_end,'V7_RENEWAL',to_jsonb(l) FROM membership_periods l
   JOIN payment_transactions p ON p.id=l.payment_transaction_id WHERE l.source='RENEWAL'
   ON CONFLICT(payment_id) DO NOTHING;
 END IF;
 IF to_regclass('public.membership_initial_activations') IS NOT NULL THEN
  IF EXISTS(SELECT 1 FROM membership_initial_activations a JOIN payment_transactions p ON p.id=a.payment_transaction_id
    WHERE p.provider<>'COUNTER' OR p.member_id<>a.member_id OR p.membership_id<>a.membership_id
      OR a.response_snapshot#>>'{membership,startDate}' IS NULL OR a.response_snapshot#>>'{membership,endDate}' IS NULL)
  THEN RAISE EXCEPTION 'DB01_COUNTER_SNAPSHOT_PROVENANCE_INVALID'; END IF;
  IF EXISTS(SELECT 1 FROM membership_initial_activations a JOIN db01_payment_period_evidence e ON e.payment_id=a.payment_transaction_id
    WHERE (a.response_snapshot#>>'{membership,startDate}')::date<>e.period_start OR (a.response_snapshot#>>'{membership,endDate}')::date<>e.period_end)
  THEN RAISE EXCEPTION 'DB01_CONFLICTING_PERIOD_EVIDENCE'; END IF;
  INSERT INTO db01_payment_period_evidence(payment_id,period_start,period_end,origin,source_row)
   SELECT payment_transaction_id,(response_snapshot#>>'{membership,startDate}')::date,
    (response_snapshot#>>'{membership,endDate}')::date,'M03_RESPONSE_SNAPSHOT',to_jsonb(a)
   FROM membership_initial_activations a ON CONFLICT(payment_id) DO NOTHING;
 END IF;
 IF NOT had_columns THEN
  -- ADD + restore occurs before pending migrations can reference these columns.
  ALTER TABLE payment_transactions ADD COLUMN period_start DATE;
  ALTER TABLE payment_transactions ADD COLUMN period_end DATE;
  -- Only V2 timestamp-maintenance trigger is suspended, not FK/CHECK/business triggers.
  ALTER TABLE payment_transactions DISABLE TRIGGER trg_payment_updated_at;
  UPDATE payment_transactions p SET period_start=e.period_start,period_end=e.period_end
   FROM db01_payment_period_evidence e WHERE p.id=e.payment_id;
  ALTER TABLE payment_transactions ENABLE TRIGGER trg_payment_updated_at;
  ALTER TABLE payment_transactions ADD CONSTRAINT ck_payment_period CHECK(
   (period_start IS NULL)=(period_end IS NULL) AND period_end>=period_start);
 END IF;
 IF EXISTS(SELECT 1 FROM payment_transactions p WHERE p.status='SUCCESS' AND p.period_start IS NULL
   AND NOT EXISTS(SELECT 1 FROM db01_payment_period_evidence e WHERE e.payment_id=p.id)) THEN
  -- SUCCESS without entitlement may be legitimate reconciliation; verify its quote explicitly.
  IF to_regclass('public.renewal_payment_quotes') IS NULL THEN
   RAISE EXCEPTION 'DB01_PAYMENT_PERIOD_PROVENANCE_MISSING';
  END IF;
  IF EXISTS(SELECT 1 FROM payment_transactions p WHERE p.status='SUCCESS' AND p.period_start IS NULL
    AND NOT EXISTS(SELECT 1 FROM renewal_payment_quotes q WHERE q.payment_id=p.id
       AND q.fulfillment_status='RECONCILIATION_REQUIRED' AND q.applied_period_id IS NULL))
  THEN RAISE EXCEPTION 'DB01_PAYMENT_PERIOD_PROVENANCE_MISSING'; END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM payment_transactions WHERE status='REFUNDED')
 THEN RAISE EXCEPTION 'DB01_REFUND_RECONCILIATION_REQUIRED'; END IF;
END $db01$;
