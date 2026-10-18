CREATE TABLE membership_plans (
    id UUID PRIMARY KEY,

    name VARCHAR(100) NOT NULL,

    description VARCHAR(500),

    duration_days INTEGER NOT NULL,

    price NUMERIC(12, 2) NOT NULL,

    active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMP WITH TIME ZONE
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITH TIME ZONE
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_membership_plan_duration
        CHECK (duration_days > 0),

    CONSTRAINT chk_membership_plan_price
        CHECK (price >= 0)
);


CREATE TABLE memberships (
    id UUID PRIMARY KEY,

    member_id UUID NOT NULL,

    plan_id UUID NOT NULL,

    start_date DATE NOT NULL,

    end_date DATE NOT NULL,

    status VARCHAR(20) NOT NULL,

    created_at TIMESTAMP WITH TIME ZONE
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP WITH TIME ZONE
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_membership_member
        FOREIGN KEY (member_id)
        REFERENCES users(id),

    CONSTRAINT fk_membership_plan
        FOREIGN KEY (plan_id)
        REFERENCES membership_plans(id),

    CONSTRAINT chk_membership_dates
        CHECK (end_date >= start_date)
);


CREATE INDEX idx_memberships_member_id
    ON memberships(member_id);

CREATE INDEX idx_memberships_plan_id
    ON memberships(plan_id);

CREATE INDEX idx_memberships_status
    ON memberships(status);