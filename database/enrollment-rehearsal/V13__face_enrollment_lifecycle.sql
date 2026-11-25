-- F02 additive rehearsal only; V3 and published migrations are unchanged.
CREATE UNIQUE INDEX uq_facial_id_owner ON facial_profiles(id,member_id);
CREATE TABLE face_enrollments (
 id UUID PRIMARY KEY, member_id UUID NOT NULL REFERENCES members(id),
 proposed_profile_id UUID NOT NULL UNIQUE, previous_profile_id UUID REFERENCES facial_profiles(id),
 activated_profile_id UUID, template_ref VARCHAR(255) NOT NULL UNIQUE,
 idempotency_key UUID NOT NULL UNIQUE, request_fingerprint CHAR(64) NOT NULL,
 status VARCHAR(10) NOT NULL CHECK(status IN ('PENDING','ACTIVE','FAILED','REVOKED')),
 consent_version VARCHAR(64) NOT NULL, consent_at TIMESTAMPTZ NOT NULL,
 started_by UUID NOT NULL REFERENCES users(id), started_at TIMESTAMPTZ NOT NULL,
 finalized_by UUID REFERENCES users(id), finalized_at TIMESTAMPTZ,
 failure_code VARCHAR(64), identity_mode VARCHAR(24) NOT NULL CHECK(identity_mode='SIMULATED_TEST'),
 FOREIGN KEY(activated_profile_id,member_id) REFERENCES facial_profiles(id,member_id),
 CHECK(activated_profile_id IS NULL OR activated_profile_id=proposed_profile_id),
 CHECK(status<>'ACTIVE' OR activated_profile_id IS NOT NULL)
);
CREATE UNIQUE INDEX uq_face_pending_member ON face_enrollments(member_id) WHERE status='PENDING';
CREATE TABLE face_revocations (
 idempotency_key UUID PRIMARY KEY, member_id UUID NOT NULL REFERENCES members(id),
 profile_id UUID NOT NULL, revoked_by UUID NOT NULL REFERENCES users(id), revoked_at TIMESTAMPTZ NOT NULL,
 FOREIGN KEY(profile_id,member_id) REFERENCES facial_profiles(id,member_id)
);
CREATE TABLE face_gallery_cleanup (
 id UUID PRIMARY KEY, member_id UUID NOT NULL REFERENCES members(id), template_ref VARCHAR(255) NOT NULL UNIQUE,
 status VARCHAR(20) NOT NULL CHECK(status IN ('PENDING','DONE','MANUAL_REQUIRED')),
 created_at TIMESTAMPTZ NOT NULL, completed_at TIMESTAMPTZ
);
