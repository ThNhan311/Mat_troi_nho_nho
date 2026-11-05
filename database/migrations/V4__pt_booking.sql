-- =====================================================================
-- V4: PT Availability + Booking + Booking Policy
-- Tham chiếu: UC-09/10/11/13/15/16/22, BR-BKG-*, AC-BKG-01..09, NFR-REL-01
-- =====================================================================

-- ---------------------------------------------------------------------
-- availability_slots
-- ---------------------------------------------------------------------
CREATE TABLE availability_slots (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pt_id      UUID        NOT NULL REFERENCES personal_trainers (id),
    start_at   TIMESTAMPTZ NOT NULL,
    end_at     TIMESTAMPTZ NOT NULL,
    status     VARCHAR(10) NOT NULL DEFAULT 'AVAILABLE',
    version    BIGINT      NOT NULL DEFAULT 0,          -- optimistic locking (JPA @Version)
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_slot_time   CHECK (end_at > start_at),
    CONSTRAINT ck_slot_status CHECK (status IN ('AVAILABLE', 'BOOKED', 'DISABLED')),
    -- đích của FK ghép từ bookings
    CONSTRAINT uq_slot_identity UNIQUE (id, pt_id, start_at, end_at),
    -- 1 PT không công bố 2 slot chồng giờ (trừ slot đã DISABLED)
    CONSTRAINT ex_slot_pt_no_overlap EXCLUDE USING gist
        (pt_id WITH =, tstzrange(start_at, end_at) WITH &&) WHERE (status <> 'DISABLED')
);
CREATE INDEX idx_slot_pt_start_status ON availability_slots (pt_id, start_at, status);

CREATE TRIGGER trg_slot_updated_at BEFORE UPDATE ON availability_slots
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- bookings: 1 Booking = 1 PT Session
-- start_at/end_at là bản sao của slot; FK ghép ép chúng khớp với slot + PT.
-- ---------------------------------------------------------------------
CREATE TABLE bookings (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id     UUID         NOT NULL REFERENCES members (id),
    pt_id         UUID         NOT NULL REFERENCES personal_trainers (id),
    slot_id       UUID         NOT NULL,
    start_at      TIMESTAMPTZ  NOT NULL,
    end_at        TIMESTAMPTZ  NOT NULL,
    status        VARCHAR(10)  NOT NULL DEFAULT 'CONFIRMED',
    cancelled_by  VARCHAR(10),
    cancel_reason VARCHAR(500),
    cancelled_at  TIMESTAMPTZ,
    completed_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT fk_booking_slot FOREIGN KEY (slot_id, pt_id, start_at, end_at)
        REFERENCES availability_slots (id, pt_id, start_at, end_at),

    CONSTRAINT ck_booking_status       CHECK (status IN ('CONFIRMED', 'CANCELLED', 'COMPLETED')),
    CONSTRAINT ck_booking_time         CHECK (end_at > start_at),
    CONSTRAINT ck_booking_cancelled_by CHECK (cancelled_by IN ('MEMBER', 'PT')),
    -- trạng thái CANCELLED <=> có người hủy + thời điểm hủy
    CONSTRAINT ck_booking_cancel_by_status CHECK ((status = 'CANCELLED') = (cancelled_by IS NOT NULL)),
    CONSTRAINT ck_booking_cancel_at_status CHECK ((status = 'CANCELLED') = (cancelled_at IS NOT NULL)),
    -- AC-BKG-06: PT hủy bắt buộc có lý do không rỗng
    CONSTRAINT ck_booking_pt_reason CHECK (
        cancelled_by IS DISTINCT FROM 'PT' OR COALESCE(length(btrim(cancel_reason)), 0) > 0),
    CONSTRAINT ck_booking_completed CHECK ((status = 'COMPLETED') = (completed_at IS NOT NULL)),

    -- AC-BKG-03: không chồng giờ giữa các session CONFIRMED (PT và Member)
    CONSTRAINT ex_booking_pt_no_overlap EXCLUDE USING gist
        (pt_id WITH =, tstzrange(start_at, end_at) WITH &&) WHERE (status = 'CONFIRMED'),
    CONSTRAINT ex_booking_member_no_overlap EXCLUDE USING gist
        (member_id WITH =, tstzrange(start_at, end_at) WITH &&) WHERE (status = 'CONFIRMED')
);

-- AC-BKG-02: chốt chặn cuối - tối đa 1 booking CONFIRMED cho mỗi slot.
-- KHÔNG unique tuyệt đối theo slot_id vì slot có thể được đặt lại sau khi Member hủy.
CREATE UNIQUE INDEX uq_booking_slot_confirmed ON bookings (slot_id) WHERE status = 'CONFIRMED';
CREATE INDEX idx_booking_slot          ON bookings (slot_id);
CREATE INDEX idx_booking_member_start  ON bookings (member_id, start_at, status);
CREATE INDEX idx_booking_pt_start      ON bookings (pt_id, start_at, status);

CREATE TRIGGER trg_booking_updated_at BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- booking_policy: cấu hình toàn hệ thống, Admin quản lý, KHÔNG hard-code
-- Cùng lúc chỉ có đúng 1 policy active. Đổi policy: tắt dòng cũ rồi thêm dòng mới
-- (hoặc UPDATE tại chỗ).
-- ---------------------------------------------------------------------
CREATE TABLE booking_policy (
    id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    max_advance_days      INTEGER     NOT NULL,
    min_notice_hours      INTEGER     NOT NULL,
    cancel_deadline_hours INTEGER     NOT NULL,
    max_future_bookings   INTEGER     NOT NULL,
    effective_from        TIMESTAMPTZ NOT NULL DEFAULT now(),
    active                BOOLEAN     NOT NULL DEFAULT true,
    updated_by            UUID        REFERENCES users (id),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_policy_advance  CHECK (max_advance_days > 0),
    CONSTRAINT ck_policy_notice   CHECK (min_notice_hours >= 0),
    CONSTRAINT ck_policy_deadline CHECK (cancel_deadline_hours >= 0),
    CONSTRAINT ck_policy_future   CHECK (max_future_bookings > 0)
);
CREATE UNIQUE INDEX uq_booking_policy_single_active ON booking_policy ((active)) WHERE active;

CREATE TRIGGER trg_policy_updated_at BEFORE UPDATE ON booking_policy
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
