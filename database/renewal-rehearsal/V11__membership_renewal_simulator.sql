-- Opt-in M-05/M-06 rehearsal only. V7 is quarantined; V1-V6,V8-V10 unchanged.
-- Refuse ambiguous M03 coverage rather than inventing a paid history.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM membership_initial_activations a
 JOIN memberships m ON m.id=a.membership_id
 JOIN payment_transactions p ON p.id=a.payment_transaction_id
 WHERE m.start_date IS DISTINCT FROM p.period_start OR m.expiry_date IS DISTINCT FROM p.period_end)
 THEN RAISE EXCEPTION 'M03 dates differ from recorded initial payment; reconcile legacy coverage before V11'; END IF;
END $$;
CREATE TABLE membership_paid_periods (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 member_id UUID NOT NULL REFERENCES members(id),
 membership_id UUID NOT NULL,
 plan_id UUID NOT NULL REFERENCES membership_plans(id),
 plan_name_snapshot VARCHAR(100),
 source VARCHAR(24) NOT NULL CHECK(source IN ('LEGACY_AGGREGATE','INITIAL_COUNTER','RENEWAL')),
 start_date DATE NOT NULL, end_date DATE NOT NULL CHECK(end_date>=start_date),
 amount_snapshot NUMERIC(12,2) CHECK(amount_snapshot>=0),
 duration_days_snapshot INTEGER CHECK(duration_days_snapshot>0), currency CHAR(3) CHECK(currency='VND'),
 payment_transaction_id UUID UNIQUE REFERENCES payment_transactions(id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 FOREIGN KEY(membership_id,member_id) REFERENCES memberships(id,member_id),
 CHECK(source='LEGACY_AGGREGATE' OR (payment_transaction_id IS NOT NULL AND plan_name_snapshot IS NOT NULL
   AND amount_snapshot IS NOT NULL AND duration_days_snapshot IS NOT NULL AND currency IS NOT NULL
   AND end_date-start_date=duration_days_snapshot-1)),
 EXCLUDE USING gist(membership_id WITH =,daterange(start_date,end_date,'[]') WITH &&)
);
CREATE INDEX idx_paid_periods_owner ON membership_paid_periods(member_id,membership_id,start_date);
INSERT INTO membership_paid_periods(member_id,membership_id,plan_id,plan_name_snapshot,source,start_date,end_date,amount_snapshot,duration_days_snapshot,currency,payment_transaction_id)
 SELECT a.member_id,a.membership_id,p.plan_id,a.response_snapshot#>>'{planSnapshot,name}','INITIAL_COUNTER',p.period_start,p.period_end,a.listed_price_snapshot,a.duration_days_snapshot,a.currency,p.id
 FROM membership_initial_activations a JOIN payment_transactions p ON p.id=a.payment_transaction_id;
-- Unknown legacy provenance is explicit; never infer prices/history from today's plan.
INSERT INTO membership_paid_periods(member_id,membership_id,plan_id,source,start_date,end_date)
 SELECT m.member_id,m.id,m.plan_id,'LEGACY_AGGREGATE',m.start_date,m.expiry_date FROM memberships m
 WHERE m.start_date IS NOT NULL AND m.expiry_date IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM membership_initial_activations a WHERE a.membership_id=m.id);
CREATE TABLE renewal_payment_quotes (
 payment_id UUID PRIMARY KEY REFERENCES payment_transactions(id),
 member_id UUID NOT NULL REFERENCES members(id), membership_id UUID NOT NULL,
 plan_id UUID NOT NULL REFERENCES membership_plans(id), idempotency_key UUID NOT NULL UNIQUE,
 request_fingerprint CHAR(64) NOT NULL CHECK(request_fingerprint ~ '^[0-9a-f]{64}$'),
 plan_name_snapshot VARCHAR(100) NOT NULL, amount_snapshot NUMERIC(12,2) NOT NULL CHECK(amount_snapshot>=0),
 duration_days_snapshot INTEGER NOT NULL CHECK(duration_days_snapshot>0), currency CHAR(3) NOT NULL CHECK(currency='VND'),
 fulfillment_status VARCHAR(32) NOT NULL DEFAULT 'NOT_APPLIED' CHECK(fulfillment_status IN ('NOT_APPLIED','APPLIED','RECONCILIATION_REQUIRED')),
 reconciliation_reason VARCHAR(64), applied_period_id UUID UNIQUE REFERENCES membership_paid_periods(id),
 created_at TIMESTAMPTZ NOT NULL,
 FOREIGN KEY(membership_id,member_id) REFERENCES memberships(id,member_id),
 FOREIGN KEY(payment_id,member_id,membership_id) REFERENCES payment_transactions(id,member_id,membership_id),
 CHECK((fulfillment_status='APPLIED')=(applied_period_id IS NOT NULL)),
 CHECK((fulfillment_status='RECONCILIATION_REQUIRED')=(reconciliation_reason IS NOT NULL))
);
CREATE INDEX idx_renewal_quote_owner ON renewal_payment_quotes(member_id,created_at,payment_id);
CREATE TABLE renewal_result_keys (
 event_key UUID PRIMARY KEY, payment_id UUID NOT NULL REFERENCES renewal_payment_quotes(payment_id),
 first_fingerprint CHAR(64) NOT NULL CHECK(first_fingerprint ~ '^[0-9a-f]{64}$'), created_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE renewal_payment_events (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), event_key UUID NOT NULL REFERENCES renewal_result_keys(event_key),
 payment_id UUID NOT NULL REFERENCES renewal_payment_quotes(payment_id),
 request_fingerprint CHAR(64) NOT NULL CHECK(request_fingerprint ~ '^[0-9a-f]{64}$'),
 reported_status VARCHAR(10) NOT NULL CHECK(reported_status IN ('SUCCESS','FAILED','CANCELLED')),
 supplied_provider_ref VARCHAR(100) NOT NULL, supplied_amount NUMERIC(12,2) NOT NULL CHECK(supplied_amount>=0), supplied_currency CHAR(3) NOT NULL,
 outcome VARCHAR(40) NOT NULL, error_code VARCHAR(64), http_status INTEGER NOT NULL CHECK(http_status IN(200,409)),
 actor_user_id UUID NOT NULL REFERENCES users(id), checked_at TIMESTAMPTZ NOT NULL,
 response_snapshot JSONB NOT NULL CHECK(jsonb_typeof(response_snapshot)='object'),
 UNIQUE(event_key,request_fingerprint)
);
CREATE INDEX idx_renewal_events_payment ON renewal_payment_events(payment_id,checked_at,id);
