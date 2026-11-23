-- Test-only M-03 rehearsal V9. Keep canonical V1-V6 and V8 rehearsal unchanged.
-- V7 is NOT applied; coordinate release version/order before merge.
-- Technical FK targets: id is already PK, these do not restrict old business rows further.
ALTER TABLE memberships
 ADD CONSTRAINT uq_m03_membership_identity UNIQUE (id, member_id);
ALTER TABLE payment_transactions
 ADD CONSTRAINT uq_m03_payment_identity UNIQUE (id, member_id, membership_id);

CREATE TABLE membership_initial_activations (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 member_id UUID NOT NULL REFERENCES members(id),
 membership_id UUID NOT NULL,
 payment_transaction_id UUID NOT NULL,
 idempotency_key UUID NOT NULL,
 request_fingerprint CHAR(64) NOT NULL,
 receipt_ref VARCHAR(100) NOT NULL,
 receipt_key VARCHAR(100) NOT NULL,
 confirmed_by_user_id UUID NOT NULL REFERENCES users(id),
 confirmed_at TIMESTAMPTZ NOT NULL,
 listed_price_snapshot NUMERIC(12,2) NOT NULL,
 duration_days_snapshot INTEGER NOT NULL,
 currency CHAR(3) NOT NULL, -- VND is proposed, not yet an approved rule.
 note VARCHAR(500),
 response_snapshot JSONB NOT NULL, -- Committed DTO only, never credentials.
 CONSTRAINT uq_m03_initial_member UNIQUE(member_id),
 CONSTRAINT uq_m03_initial_membership UNIQUE(membership_id),
 CONSTRAINT uq_m03_initial_payment UNIQUE(payment_transaction_id),
 CONSTRAINT uq_m03_idempotency UNIQUE(idempotency_key),
 -- Proposed gym-wide/case-sensitive identity after application strips outer whitespace.
 CONSTRAINT uq_m03_receipt_ref UNIQUE(receipt_key),
 CONSTRAINT ck_m03_receipt_ref CHECK(length(btrim(receipt_ref))>0),
 CONSTRAINT ck_m03_fingerprint CHECK(request_fingerprint ~ '^[0-9a-f]{64}$'),
 CONSTRAINT ck_m03_listed_price CHECK(listed_price_snapshot>=0),
 CONSTRAINT ck_m03_duration CHECK(duration_days_snapshot>0),
 CONSTRAINT ck_m03_currency CHECK(currency='VND'),
 CONSTRAINT ck_m03_response CHECK(jsonb_typeof(response_snapshot)='object'),
 CONSTRAINT fk_m03_membership_owner FOREIGN KEY(membership_id,member_id)
  REFERENCES memberships(id,member_id),
 CONSTRAINT fk_m03_payment_owner FOREIGN KEY(payment_transaction_id,member_id,membership_id)
  REFERENCES payment_transactions(id,member_id,membership_id)
);
CREATE INDEX idx_m03_confirming_admin ON membership_initial_activations(confirmed_by_user_id,confirmed_at);
-- ACTIVE ADMIN, matching plan/SUCCESS/counter source/dates/amount and response content remain
-- service invariants in the same Member-first transaction; FKs do not prove these.
-- No app UPDATE/DELETE endpoint. Later corrections/refunds need a separate design.
-- Period backfill must classify linked COUNTER tx as initial activation, not RENEWAL just
-- because status=SUCCESS, and preserve receipt-to-counter-payment linkage/provenance.
