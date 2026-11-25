-- F01 additive rehearsal only. No changes to V3 or published V1-V11 SQL.
CREATE UNIQUE INDEX uq_attendance_id_owner ON attendance_records(id,member_id);
CREATE TABLE checkin_requests (
    request_id UUID PRIMARY KEY,
    kiosk_id VARCHAR(50) NOT NULL,
    request_fingerprint CHAR(64) NOT NULL CHECK(request_fingerprint ~ '^[0-9a-f]{64}$'),
    member_id UUID REFERENCES members(id),
    facial_profile_id UUID REFERENCES facial_profiles(id),
    attendance_id UUID,
    attendance_created BOOLEAN NOT NULL,
    identity_mode VARCHAR(24) NOT NULL CHECK(identity_mode='SIMULATED_TEST'),
    decision VARCHAR(40) NOT NULL,
    checked_at TIMESTAMPTZ NOT NULL,
    response_snapshot JSONB NOT NULL CHECK(jsonb_typeof(response_snapshot)='object'),
    FOREIGN KEY(attendance_id,member_id) REFERENCES attendance_records(id,member_id),
    CHECK(NOT attendance_created OR attendance_id IS NOT NULL),
    CHECK(attendance_id IS NULL OR member_id IS NOT NULL),
    CHECK(facial_profile_id IS NULL OR member_id IS NOT NULL)
);
CREATE UNIQUE INDEX uq_checkin_created_attendance ON checkin_requests(attendance_id) WHERE attendance_created;
CREATE INDEX idx_checkin_member_time ON checkin_requests(member_id,checked_at);
