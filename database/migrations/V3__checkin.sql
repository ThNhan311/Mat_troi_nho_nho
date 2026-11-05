-- =====================================================================
-- V3: Facial profile + Attendance
-- Tham chiếu: UC-06/07, BR-CHK-01..04, AC-CHK-01..04, NFR-SEC-05, NFR-PRIV-01/02
-- =====================================================================

-- ---------------------------------------------------------------------
-- facial_profiles: CHỈ lưu template_ref (tham chiếu), không lưu ảnh/vector
-- thô trong DB nghiệp vụ. Mỗi Member có tối đa 1 profile ACTIVE.
-- ---------------------------------------------------------------------
CREATE TABLE facial_profiles (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id    UUID         NOT NULL REFERENCES members (id),
    template_ref VARCHAR(255) NOT NULL,
    status       VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',
    enrolled_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    revoked_at   TIMESTAMPTZ,
    CONSTRAINT ck_facial_status  CHECK (status IN ('ACTIVE', 'REVOKED')),
    CONSTRAINT ck_facial_revoked CHECK ((status = 'REVOKED') = (revoked_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_facial_active_per_member ON facial_profiles (member_id) WHERE status = 'ACTIVE';
CREATE INDEX        idx_facial_member           ON facial_profiles (member_id);

-- ---------------------------------------------------------------------
-- attendance_records: chỉ tạo khi check-in thành công và không trùng cửa sổ 30 phút.
-- dedupe_key (vd: memberId + ':' + mốc thời gian) là chốt chặn cuối ở DB.
-- ---------------------------------------------------------------------
CREATE TABLE attendance_records (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id     UUID         NOT NULL REFERENCES members (id),
    checked_in_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    source        VARCHAR(20)  NOT NULL DEFAULT 'FACE',
    kiosk_id      VARCHAR(50),
    dedupe_key    VARCHAR(150),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_attendance_source CHECK (source IN ('FACE')),   -- QR không thuộc Core v4.1
    CONSTRAINT uq_attendance_dedupe UNIQUE (dedupe_key)
);
CREATE INDEX idx_attendance_member_time ON attendance_records (member_id, checked_in_at DESC);
