-- =====================================================================
-- V2: Membership + Payment
-- Tham chiếu: UC-04/05/20/21, BR-MEM-04, AC-MEM-01, AC-PAY-01, FR-PAY-07
-- =====================================================================

CREATE TABLE membership_plans (
    id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(100)  NOT NULL,
    description   TEXT,
    duration_days INTEGER       NOT NULL,
    price         NUMERIC(12,2) NOT NULL,
    status        VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_plan_duration CHECK (duration_days > 0),
    CONSTRAINT ck_plan_price    CHECK (price >= 0),
    CONSTRAINT ck_plan_status   CHECK (status IN ('ACTIVE', 'INACTIVE'))
);
CREATE TRIGGER trg_plans_updated_at BEFORE UPDATE ON membership_plans
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- memberships: mỗi Member có tối đa 1 membership "hiện hành" (chưa CANCELLED).
-- Gia hạn = cập nhật expiry_date của dòng này (extendExactlyOnce).
-- start_date / expiry_date có thể NULL khi PENDING_ACTIVATION.
-- ---------------------------------------------------------------------
CREATE TABLE memberships (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id   UUID        NOT NULL REFERENCES members (id),
    plan_id     UUID        NOT NULL REFERENCES membership_plans (id),
    start_date  DATE,
    expiry_date DATE,
    status      VARCHAR(20) NOT NULL DEFAULT 'PENDING_ACTIVATION',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_membership_status CHECK (status IN
        ('PENDING_ACTIVATION', 'ACTIVE', 'SUSPENDED', 'EXPIRED', 'CANCELLED')),
    CONSTRAINT ck_membership_dates  CHECK (expiry_date >= start_date),
    CONSTRAINT ck_membership_dates_required CHECK (
        status = 'PENDING_ACTIVATION' OR (start_date IS NOT NULL AND expiry_date IS NOT NULL))
);
CREATE INDEX idx_memberships_member_status_expiry ON memberships (member_id, status, expiry_date);
CREATE INDEX idx_memberships_plan                 ON memberships (plan_id);
CREATE UNIQUE INDEX uq_membership_one_current_per_member
    ON memberships (member_id) WHERE status <> 'CANCELLED';

CREATE TRIGGER trg_memberships_updated_at BEFORE UPDATE ON memberships
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- payment_transactions: provider_ref UNIQUE => callback idempotent
-- membership_id nullable: giao dịch tạo trước khi membership được cập nhật
-- period_start/period_end: khoảng thời hạn mà giao dịch SUCCESS đã cộng thêm
-- (phục vụ GET /memberships/history, có thể bỏ nếu team không cần)
-- Không lưu thông tin thẻ / ngân hàng (NFR-SEC-04)
-- ---------------------------------------------------------------------
CREATE TABLE payment_transactions (
    id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id     UUID          NOT NULL REFERENCES members (id),
    plan_id       UUID          NOT NULL REFERENCES membership_plans (id),
    membership_id UUID          REFERENCES memberships (id),
    provider      VARCHAR(30)   NOT NULL DEFAULT 'SIMULATOR',
    provider_ref  VARCHAR(100)  NOT NULL,
    amount        NUMERIC(12,2) NOT NULL,
    status        VARCHAR(10)   NOT NULL DEFAULT 'PENDING',
    processed_at  TIMESTAMPTZ,
    period_start  DATE,
    period_end    DATE,
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_payment_provider_ref UNIQUE (provider_ref),
    CONSTRAINT ck_payment_amount CHECK (amount >= 0),
    CONSTRAINT ck_payment_status CHECK (status IN
        ('PENDING', 'SUCCESS', 'FAILED', 'CANCELLED', 'REFUNDED')),
    CONSTRAINT ck_payment_period CHECK (
        (period_start IS NULL) = (period_end IS NULL) AND period_end >= period_start)
);
CREATE INDEX idx_payment_member_created ON payment_transactions (member_id, created_at);
CREATE INDEX idx_payment_plan           ON payment_transactions (plan_id);
CREATE INDEX idx_payment_membership     ON payment_transactions (membership_id);

CREATE TRIGGER trg_payment_updated_at BEFORE UPDATE ON payment_transactions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
