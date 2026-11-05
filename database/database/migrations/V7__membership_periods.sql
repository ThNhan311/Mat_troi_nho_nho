-- =====================================================================
-- V7: Lịch sử kỳ membership (membership_periods) + view tổng hợp
-- Đã thống nhất với backend (Thùy):
--  * Gói đang dùng / gói kỳ kế tiếp được suy ra từ các kỳ (periods), KHÔNG dựa vào memberships.plan_id
--  * Gia hạn nhiều lần trước hạn: kỳ mới nối tiếp kỳ cuối cùng đã thanh toán, không chồng ngày
--  * Kích hoạt lần đầu tại quầy: Admin xác nhận + số tiền thực thu + mã phiếu thu -> kỳ ACTIVATION
--  * Mỗi giao dịch SUCCESS chỉ cộng đúng 1 kỳ (UNIQUE payment_transaction_id)
-- Giữ nguyên V1..V6 (không sửa migration đã áp dụng).
-- Phần "ACTIVATION + amount_collected + bằng chứng quầy" là bổ sung ngoài Data
-- Dictionary 4.1, cần nhóm/Nhân xác nhận (xem docs/DESIGN_NOTES.md).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Bỏ 2 cột period_start/period_end của payment_transactions
--    (backend chưa có Entity PaymentTransaction nên không ảnh hưởng)
-- ---------------------------------------------------------------------
ALTER TABLE payment_transactions DROP CONSTRAINT ck_payment_period;
ALTER TABLE payment_transactions DROP COLUMN period_start;
ALTER TABLE payment_transactions DROP COLUMN period_end;

-- đích của FK ghép (payment_transaction_id, plan_id) từ membership_periods
ALTER TABLE payment_transactions ADD CONSTRAINT uq_payment_id_plan UNIQUE (id, plan_id);

-- ---------------------------------------------------------------------
-- 2. Ngày nghiệp vụ hiện tại (giờ Việt Nam). Đổi múi giờ ở MỘT chỗ duy nhất nếu cần.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app_today() RETURNS date AS $$
    SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
$$ LANGUAGE sql STABLE;

-- ---------------------------------------------------------------------
-- 3. membership_periods
--    ACTIVATION: kích hoạt lần đầu tại quầy (không có payment_transaction)
--    RENEWAL   : gia hạn qua app, gắn đúng 1 payment_transaction SUCCESS;
--                số tiền lấy từ payment_transactions (không lưu trùng ở đây)
--    period_start / period_end đều tính cả ngày (đóng 2 đầu)
-- ---------------------------------------------------------------------
CREATE TABLE membership_periods (
    id                     UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    membership_id          UUID          NOT NULL REFERENCES memberships (id),
    plan_id                UUID          NOT NULL REFERENCES membership_plans (id),
    source                 VARCHAR(10)   NOT NULL,
    period_start           DATE          NOT NULL,
    period_end             DATE          NOT NULL,
    payment_transaction_id UUID,
    -- chỉ dùng cho ACTIVATION (bằng chứng thanh toán tại quầy)
    amount_collected       NUMERIC(12,2),
    confirmed_by_user_id   UUID          REFERENCES users (id),
    confirmed_at           TIMESTAMPTZ,
    receipt_ref            VARCHAR(100),
    note                   VARCHAR(500),
    created_at             TIMESTAMPTZ   NOT NULL DEFAULT now(),

    CONSTRAINT ck_period_source CHECK (source IN ('ACTIVATION', 'RENEWAL')),
    CONSTRAINT ck_period_dates  CHECK (period_end >= period_start),
    CONSTRAINT ck_period_amount CHECK (amount_collected >= 0),
    -- ACTIVATION: bắt buộc có Admin xác nhận, thời điểm, số tiền thực thu, mã phiếu thu; không gắn giao dịch online
    CONSTRAINT ck_period_activation CHECK (source <> 'ACTIVATION' OR (
        payment_transaction_id IS NULL
        AND confirmed_by_user_id IS NOT NULL
        AND confirmed_at IS NOT NULL
        AND amount_collected IS NOT NULL
        AND COALESCE(length(btrim(receipt_ref)), 0) > 0)),
    -- RENEWAL: bắt buộc gắn giao dịch; không có thông tin xác nhận tại quầy
    CONSTRAINT ck_period_renewal CHECK (source <> 'RENEWAL' OR (
        payment_transaction_id IS NOT NULL
        AND amount_collected IS NULL
        AND confirmed_by_user_id IS NULL
        AND confirmed_at IS NULL
        AND receipt_ref IS NULL)),

    -- mỗi giao dịch chỉ cộng đúng 1 kỳ (chống cộng trùng ở tầng DB)
    CONSTRAINT uq_period_payment UNIQUE (payment_transaction_id),
    -- plan của kỳ phải khớp plan của giao dịch
    CONSTRAINT fk_period_payment FOREIGN KEY (payment_transaction_id, plan_id)
        REFERENCES payment_transactions (id, plan_id),
    -- các kỳ của cùng 1 membership không được chồng ngày
    CONSTRAINT ex_period_no_overlap EXCLUDE USING gist
        (membership_id WITH =, daterange(period_start, period_end, '[]') WITH &&)
);
-- mỗi membership chỉ có 1 kỳ ACTIVATION
CREATE UNIQUE INDEX uq_period_one_activation ON membership_periods (membership_id) WHERE source = 'ACTIVATION';
CREATE INDEX idx_period_membership_start ON membership_periods (membership_id, period_start);
CREATE INDEX idx_period_plan             ON membership_periods (plan_id);

-- ---------------------------------------------------------------------
-- 4. Trigger kiểm tra các điều kiện liên bảng mà CHECK không làm được
--    * RENEWAL: giao dịch phải SUCCESS và thuộc cùng Member với membership
--    * ACTIVATION: người xác nhận phải có role ADMIN
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_membership_period_validate() RETURNS trigger AS $$
DECLARE
    v_tx_status VARCHAR(10);
    v_tx_member UUID;
    v_ms_member UUID;
    v_role      VARCHAR(10);
BEGIN
    IF NEW.source = 'RENEWAL' THEN
        SELECT status, member_id INTO v_tx_status, v_tx_member
          FROM payment_transactions WHERE id = NEW.payment_transaction_id;
        SELECT member_id INTO v_ms_member FROM memberships WHERE id = NEW.membership_id;
        IF v_tx_status IS DISTINCT FROM 'SUCCESS' THEN
            RAISE EXCEPTION 'Giao dich % chua SUCCESS, khong duoc cong ky gia han', NEW.payment_transaction_id
                USING ERRCODE = 'check_violation';
        END IF;
        IF v_tx_member IS DISTINCT FROM v_ms_member THEN
            RAISE EXCEPTION 'Giao dich % khong thuoc Member cua membership %', NEW.payment_transaction_id, NEW.membership_id
                USING ERRCODE = 'check_violation';
        END IF;
    ELSIF NEW.source = 'ACTIVATION' THEN
        SELECT role INTO v_role FROM users WHERE id = NEW.confirmed_by_user_id;
        IF v_role IS DISTINCT FROM 'ADMIN' THEN
            RAISE EXCEPTION 'Nguoi xac nhan kich hoat phai la ADMIN'
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_membership_period_validate BEFORE INSERT ON membership_periods
    FOR EACH ROW EXECUTE FUNCTION fn_membership_period_validate();

-- ---------------------------------------------------------------------
-- 5. View cho backend đọc: gói đang dùng / gói kỳ kế tiếp / ngày hết hạn đã trả tiền
-- ---------------------------------------------------------------------
CREATE VIEW v_membership_overview AS
SELECT
    m.id            AS membership_id,
    m.member_id,
    m.status,
    m.start_date,
    m.expiry_date,
    cur.plan_id       AS current_plan_id,
    cur.period_start  AS current_period_start,
    cur.period_end    AS current_period_end,
    nxt.plan_id       AS next_plan_id,
    nxt.period_start  AS next_period_start,
    nxt.period_end    AS next_period_end,
    lst.last_paid_end
FROM memberships m
LEFT JOIN LATERAL (
    SELECT p.plan_id, p.period_start, p.period_end
      FROM membership_periods p
     WHERE p.membership_id = m.id
       AND p.period_start <= app_today() AND p.period_end >= app_today()
     ORDER BY p.period_start DESC
     LIMIT 1
) cur ON true
LEFT JOIN LATERAL (
    SELECT p.plan_id, p.period_start, p.period_end
      FROM membership_periods p
     WHERE p.membership_id = m.id
       AND p.period_start > app_today()
     ORDER BY p.period_start ASC
     LIMIT 1
) nxt ON true
LEFT JOIN LATERAL (
    SELECT max(p.period_end) AS last_paid_end
      FROM membership_periods p
     WHERE p.membership_id = m.id
) lst ON true;

COMMENT ON COLUMN memberships.plan_id IS
    'Gói của kỳ gần nhất đã mua. KHÔNG dùng để hiển thị gói đang sử dụng - dùng v_membership_overview.current_plan_id.';
COMMENT ON COLUMN memberships.expiry_date IS
    'Luôn bằng period_end của kỳ cuối cùng đã thanh toán (v_membership_overview.last_paid_end). Service cập nhật trong cùng transaction khi thêm kỳ.';
COMMENT ON TABLE membership_periods IS
    'Lịch sử các kỳ membership; nguồn dữ liệu chính cho gói đang dùng/gói kế tiếp và GET /memberships/history.';
