-- REVIEW CANDIDATE ONLY. NOT a canonical/Flyway migration. DO NOT APPLY without schema/version agreement.
-- V1-V6 unchanged. V7 belongs to Duy's membership periods; no version reserved here.
-- No backfill of all DISABLED users: eligibility requires Admin creation audit proof.
CREATE TABLE pt_account_activation (
 user_id UUID PRIMARY KEY,
 user_role VARCHAR(10) NOT NULL DEFAULT 'PT' CHECK(user_role='PT'),
 otp_digest VARCHAR(100),
 otp_expires_at TIMESTAMPTZ,
 attempts SMALLINT NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 5),
 send_window_started_at TIMESTAMPTZ NOT NULL,
 send_count SMALLINT NOT NULL CHECK(send_count BETWEEN 1 AND 5),
 last_sent_at TIMESTAMPTZ NOT NULL,
 grant_digest CHAR(64) UNIQUE,
 grant_expires_at TIMESTAMPTZ,
 completed_at TIMESTAMPTZ,
 CONSTRAINT fk_pt_activation_role FOREIGN KEY(user_id,user_role) REFERENCES users(id,role),
 CONSTRAINT ck_otp_pair CHECK((otp_digest IS NULL)=(otp_expires_at IS NULL)),
 CONSTRAINT ck_grant_pair CHECK((grant_digest IS NULL)=(grant_expires_at IS NULL)),
 CONSTRAINT ck_activation_phase CHECK(otp_digest IS NULL OR grant_digest IS NULL),
 CONSTRAINT ck_activation_completed CHECK(completed_at IS NULL OR (otp_digest IS NULL AND grant_digest IS NULL))
);
-- Service serializes User -> this row. No OTP/plain grant/password in table/audit/logs.
-- UNIQUE grant digest prevents ambiguous grant lookup. Completed row retained to prevent first-activation reuse.
-- Rollout: Duy confirms applied versions/checksums + canonical location, chooses forward version, reviews SQL;
-- rehearse on a separate test DB only after agreement, then enable fitcenter.activation.enabled.
-- Existing DISABLED legacy rows without Admin audit proof are never automatically enrollable.