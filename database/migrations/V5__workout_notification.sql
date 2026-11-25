-- =====================================================================
-- V5: Workout Plan + Notification
-- Tham chiếu: UC-17/18, BR-WRK-01, AC-WRK-01; Notification (SHOULD)
-- =====================================================================

CREATE TABLE workout_plans (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    pt_id      UUID         NOT NULL REFERENCES personal_trainers (id),
    member_id  UUID         NOT NULL REFERENCES members (id),
    title      VARCHAR(200) NOT NULL,
    status     VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_workout_plan_status CHECK (status IN ('ACTIVE', 'ARCHIVED'))
);
CREATE INDEX idx_workout_plans_member_status ON workout_plans (member_id, status);
CREATE INDEX idx_workout_plans_pt_created    ON workout_plans (pt_id, created_at);
CREATE TRIGGER trg_workout_plans_updated_at BEFORE UPDATE ON workout_plans
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Core chỉ cần tên bài tập + hướng dẫn; Set/Rep/Weight chi tiết KHÔNG thuộc Core
CREATE TABLE workout_plan_items (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_plan_id UUID         NOT NULL REFERENCES workout_plans (id) ON DELETE CASCADE,
    exercise_name   VARCHAR(200) NOT NULL,
    instructions    TEXT,
    sort_order      INTEGER      NOT NULL DEFAULT 0
);
CREATE INDEX idx_workout_items_plan_sort ON workout_plan_items (workout_plan_id, sort_order);

-- Member chỉ ghi completion, không sửa nội dung plan.
-- UQ(item_id, member_id): lưu trạng thái hiện tại (nếu cần lịch sử -> đổi thiết kế).
CREATE TABLE workout_completions (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id      UUID        NOT NULL REFERENCES workout_plan_items (id) ON DELETE CASCADE,
    member_id    UUID        NOT NULL REFERENCES members (id),
    status       VARCHAR(15) NOT NULL,
    completed_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_completion_status CHECK (status IN ('COMPLETED', 'NOT_COMPLETED')),
    CONSTRAINT ck_completion_time   CHECK ((status = 'COMPLETED') = (completed_at IS NOT NULL)),
    CONSTRAINT uq_completion_item_member UNIQUE (item_id, member_id)
);
CREATE INDEX idx_completion_member ON workout_completions (member_id);
CREATE TRIGGER trg_completions_updated_at BEFORE UPDATE ON workout_completions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE notifications (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type       VARCHAR(50)  NOT NULL,
    title      VARCHAR(200) NOT NULL,
    body       TEXT,
    read_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_user_read_created ON notifications (user_id, read_at, created_at);
