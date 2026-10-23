-- =====================================================================
-- V1: Nền tảng + tài khoản (users, members, personal_trainers)
-- Tham chiếu: hồ sơ mục 4.1 / 4.2, NFR-SEC-01/02, domain invariant 2.5
-- =====================================================================

-- btree_gist cần cho EXCLUDE constraint (chống trùng giờ) ở V4
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Hàm dùng chung: tự cập nhật updated_at
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- users: tài khoản đăng nhập của cả 3 role (MEMBER / PT / ADMIN)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,            -- BCrypt/Argon2, KHÔNG lưu plain text
    role          VARCHAR(10)  NOT NULL,
    status        VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_users_role         CHECK (role   IN ('MEMBER', 'PT', 'ADMIN')),
    CONSTRAINT ck_users_status       CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DISABLED')),
    CONSTRAINT ck_users_email_format CHECK (position('@' IN email) > 1),
    -- cần cho FK (user_id, role) ở members / personal_trainers
    CONSTRAINT uq_users_id_role      UNIQUE (id, role)
);
-- Email duy nhất, không phân biệt hoa/thường
CREATE UNIQUE INDEX uq_users_email        ON users (lower(email));
CREATE INDEX        idx_users_role_status ON users (role, status);

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- members: hồ sơ hội viên (1 user MEMBER <-> tối đa 1 member)
-- user_role + FK ghép đảm bảo chỉ user có role MEMBER mới có hồ sơ member
-- ---------------------------------------------------------------------
CREATE TABLE members (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL,
    user_role  VARCHAR(10)  NOT NULL DEFAULT 'MEMBER',  -- cột kỹ thuật, backend không cần map
    full_name  VARCHAR(150) NOT NULL,
    dob        DATE,
    gender     VARCHAR(20),
    phone      VARCHAR(20),
    avatar_url VARCHAR(500),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_members_user      UNIQUE (user_id),
    CONSTRAINT ck_members_user_role CHECK (user_role = 'MEMBER'),
    CONSTRAINT fk_members_user      FOREIGN KEY (user_id, user_role) REFERENCES users (id, role)
);
CREATE INDEX idx_members_phone ON members (phone);

CREATE TRIGGER trg_members_updated_at BEFORE UPDATE ON members
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- personal_trainers: hồ sơ huấn luyện viên (user có role PT)
-- ---------------------------------------------------------------------
CREATE TABLE personal_trainers (
    id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            UUID         NOT NULL,
    user_role          VARCHAR(10)  NOT NULL DEFAULT 'PT',
    full_name          VARCHAR(150) NOT NULL,
    bio                TEXT,
    specialization     VARCHAR(200),
    experience_summary TEXT,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_pt_user      UNIQUE (user_id),
    CONSTRAINT ck_pt_user_role CHECK (user_role = 'PT'),
    CONSTRAINT fk_pt_user      FOREIGN KEY (user_id, user_role) REFERENCES users (id, role)
);

CREATE TRIGGER trg_pt_updated_at BEFORE UPDATE ON personal_trainers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
