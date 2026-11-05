-- =====================================================================
-- V6 (đề xuất thêm - team duyệt): Audit log
-- Hồ sơ mục 3.7 yêu cầu audit cho: payment callback, Admin đổi policy,
-- lý do PT hủy, enrollment/revoke sinh trắc học; UC-23 "bản ghi vận hành".
-- Data Dictionary 4.1 chưa có bảng này. Nếu team không dùng, bỏ file V6.
-- Tuyệt đối KHÔNG ghi mật khẩu / token / template khuôn mặt vào details.
-- =====================================================================
CREATE TABLE audit_logs (
    id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id  UUID         REFERENCES users (id),      -- NULL nếu do kiosk/gateway
    actor_type     VARCHAR(10)  NOT NULL,
    action         VARCHAR(60)  NOT NULL,
    entity_type    VARCHAR(40)  NOT NULL,
    entity_id      UUID,
    details        JSONB,
    correlation_id VARCHAR(64),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_audit_actor_type CHECK (actor_type IN ('USER', 'KIOSK', 'GATEWAY', 'SYSTEM'))
);
CREATE INDEX idx_audit_entity  ON audit_logs (entity_type, entity_id);
CREATE INDEX idx_audit_actor   ON audit_logs (actor_user_id, created_at);
CREATE INDEX idx_audit_created ON audit_logs (created_at);
