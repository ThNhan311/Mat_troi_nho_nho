-- Integrated test-rehearsal V10. Default profile never applies it.
-- V7 membership periods is deliberately not applied. Synchronize version/order before merge/release.
CREATE TABLE member_account_activation (
 user_id UUID PRIMARY KEY,
 user_role VARCHAR(10) NOT NULL DEFAULT 'MEMBER' CHECK(user_role='MEMBER'),
 otp_digest VARCHAR(100),
 otp_expires_at TIMESTAMPTZ,
 attempts SMALLINT NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 5),
 send_window_started_at TIMESTAMPTZ NOT NULL,
 send_count SMALLINT NOT NULL CHECK(send_count BETWEEN 1 AND 5),
 last_sent_at TIMESTAMPTZ NOT NULL,
 grant_digest CHAR(64) UNIQUE,
 grant_expires_at TIMESTAMPTZ,
 completed_at TIMESTAMPTZ,
 CONSTRAINT fk_member_activation_role FOREIGN KEY(user_id,user_role) REFERENCES users(id,role),
 CONSTRAINT ck_otp_pair CHECK((otp_digest IS NULL)=(otp_expires_at IS NULL)),
 CONSTRAINT ck_grant_pair CHECK((grant_digest IS NULL)=(grant_expires_at IS NULL)),
 CONSTRAINT ck_activation_phase CHECK(otp_digest IS NULL OR grant_digest IS NULL),
 CONSTRAINT ck_activation_completed CHECK(completed_at IS NULL OR (otp_digest IS NULL AND grant_digest IS NULL))
);
