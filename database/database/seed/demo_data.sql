-- =====================================================================
-- Dữ liệu DEMO cho môi trường local/dev. KHÔNG dùng cho production.
-- Chạy SAU khi đã chạy migration V1..V7. Chạy lại được nhiều lần: các dòng demo Membership/Payment
-- được xóa và nạp lại (ngày tính theo hôm nay), các bảng khác dùng ON CONFLICT DO NOTHING.
-- Mật khẩu demo của mọi tài khoản: Demo@12345  (BCrypt, tạo bằng pgcrypto)
-- Không chứa dữ liệu thật, không có dữ liệu sinh trắc học thật.
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Hàm tạm: giờ Việt Nam của (hôm nay + d ngày) lúc h:m
CREATE OR REPLACE FUNCTION pg_temp.vn(d integer, h integer, m integer DEFAULT 0) RETURNS timestamptz AS $$
    SELECT (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh')
            + make_interval(days => d, hours => h, mins => m)) AT TIME ZONE 'Asia/Ho_Chi_Minh'
$$ LANGUAGE sql;

-- ---------- users ----------
INSERT INTO users (id, email, password_hash, role, status) VALUES
 ('00000000-0000-0000-0000-000000000001', 'admin@fitcenter.local',     crypt('Demo@12345', gen_salt('bf', 10)), 'ADMIN',  'ACTIVE'),
 ('00000000-0000-0000-0000-000000000011', 'pt.an@fitcenter.local',     crypt('Demo@12345', gen_salt('bf', 10)), 'PT',     'ACTIVE'),
 ('00000000-0000-0000-0000-000000000012', 'pt.binh@fitcenter.local',   crypt('Demo@12345', gen_salt('bf', 10)), 'PT',     'ACTIVE'),
 ('00000000-0000-0000-0000-000000000031', 'member1@fitcenter.local',   crypt('Demo@12345', gen_salt('bf', 10)), 'MEMBER', 'ACTIVE'),
 ('00000000-0000-0000-0000-000000000032', 'member2@fitcenter.local',   crypt('Demo@12345', gen_salt('bf', 10)), 'MEMBER', 'ACTIVE'),
 ('00000000-0000-0000-0000-000000000033', 'member3@fitcenter.local',   crypt('Demo@12345', gen_salt('bf', 10)), 'MEMBER', 'ACTIVE')
ON CONFLICT DO NOTHING;

INSERT INTO personal_trainers (id, user_id, full_name, bio, specialization, experience_summary) VALUES
 ('00000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000011', 'PT Demo An',   'Huấn luyện viên demo', 'Strength & Conditioning', '5 năm kinh nghiệm (dữ liệu demo)'),
 ('00000000-0000-0000-0000-000000000022', '00000000-0000-0000-0000-000000000012', 'PT Demo Bình', 'Huấn luyện viên demo', 'Giảm cân',               '3 năm kinh nghiệm (dữ liệu demo)')
ON CONFLICT DO NOTHING;

INSERT INTO members (id, user_id, full_name, dob, gender, phone) VALUES
 ('00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000031', 'Member Demo 1', '2000-01-15', 'MALE',   '0900000001'),
 ('00000000-0000-0000-0000-000000000042', '00000000-0000-0000-0000-000000000032', 'Member Demo 2', '1998-06-20', 'FEMALE', '0900000002'),
 ('00000000-0000-0000-0000-000000000043', '00000000-0000-0000-0000-000000000033', 'Member Demo 3', '2002-11-05', 'OTHER',  '0900000003')
ON CONFLICT DO NOTHING;

-- ---------- membership ----------
-- Xóa & nạp lại các dòng demo của Membership/Payment (ngày tháng tính theo hôm nay)
DELETE FROM membership_periods   WHERE membership_id IN ('00000000-0000-0000-0000-000000000061','00000000-0000-0000-0000-000000000062','00000000-0000-0000-0000-000000000063');
DELETE FROM payment_transactions WHERE id            IN ('00000000-0000-0000-0000-000000000071','00000000-0000-0000-0000-000000000072','00000000-0000-0000-0000-000000000073');
DELETE FROM memberships          WHERE id            IN ('00000000-0000-0000-0000-000000000061','00000000-0000-0000-0000-000000000062','00000000-0000-0000-0000-000000000063');

INSERT INTO membership_plans (id, name, description, duration_days, price, status) VALUES
 ('00000000-0000-0000-0000-000000000051', 'Gói 1 tháng',  'Gói demo 30 ngày',  30,   500000, 'ACTIVE'),
 ('00000000-0000-0000-0000-000000000052', 'Gói 3 tháng',  'Gói demo 90 ngày',  90,  1350000, 'ACTIVE'),
 ('00000000-0000-0000-0000-000000000053', 'Gói 12 tháng', 'Gói demo 365 ngày', 365, 4800000, 'INACTIVE')
ON CONFLICT DO NOTHING;

-- Member 1: kích hoạt tại quầy gói 1 tháng cách đây 20 ngày, đã gia hạn sớm gói 3 tháng (nối tiếp kỳ cũ)
--   => gói đang dùng = 1 tháng, gói kế tiếp = 3 tháng
-- Member 2: đã hết hạn;  Member 3: chờ kích hoạt
-- memberships.plan_id = gói của kỳ gần nhất đã mua; expiry_date = ngày kết thúc kỳ cuối đã trả tiền
INSERT INTO memberships (id, member_id, plan_id, start_date, expiry_date, status) VALUES
 ('00000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000052', app_today() - 20, app_today() + 99, 'ACTIVE'),
 ('00000000-0000-0000-0000-000000000062', '00000000-0000-0000-0000-000000000042', '00000000-0000-0000-0000-000000000051', app_today() - 60, app_today() - 31, 'EXPIRED'),
 ('00000000-0000-0000-0000-000000000063', '00000000-0000-0000-0000-000000000043', '00000000-0000-0000-0000-000000000051', NULL, NULL, 'PENDING_ACTIVATION')
ON CONFLICT DO NOTHING;

INSERT INTO payment_transactions (id, member_id, plan_id, membership_id, provider, provider_ref, amount, status, processed_at) VALUES
 ('00000000-0000-0000-0000-000000000071', '00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000052', '00000000-0000-0000-0000-000000000061', 'SIMULATOR', 'DEMO-TXN-0001', 1350000, 'SUCCESS', now() - interval '3 days'),
 ('00000000-0000-0000-0000-000000000072', '00000000-0000-0000-0000-000000000042', '00000000-0000-0000-0000-000000000051', NULL,                                   'SIMULATOR', 'DEMO-TXN-0002',  500000, 'FAILED',  now() - interval '2 days'),
 ('00000000-0000-0000-0000-000000000073', '00000000-0000-0000-0000-000000000042', '00000000-0000-0000-0000-000000000051', NULL,                                   'SIMULATOR', 'DEMO-TXN-0003',  500000, 'PENDING', NULL)
ON CONFLICT DO NOTHING;

INSERT INTO membership_periods (id, membership_id, plan_id, source, period_start, period_end, payment_transaction_id,
                                amount_collected, confirmed_by_user_id, confirmed_at, receipt_ref, note) VALUES
 -- Member 1: ACTIVATION (gói 1 tháng) tại quầy
 ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000051', 'ACTIVATION',
   app_today() - 20, app_today() + 9, NULL,
   500000, '00000000-0000-0000-0000-000000000001', pg_temp.vn(-20, 10), 'PT-DEMO-0001', 'Thu tiền mặt tại quầy (demo)'),
 -- Member 1: RENEWAL gói 3 tháng, nối tiếp kỳ trước
 ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000052', 'RENEWAL',
   app_today() + 10, app_today() + 99, '00000000-0000-0000-0000-000000000071',
   NULL, NULL, NULL, NULL, NULL),
 -- Member 2: ACTIVATION gói 1 tháng đã hết hạn
 ('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000062', '00000000-0000-0000-0000-000000000051', 'ACTIVATION',
   app_today() - 60, app_today() - 31, NULL,
   500000, '00000000-0000-0000-0000-000000000001', pg_temp.vn(-60, 10), 'PT-DEMO-0002', 'Thu tiền mặt tại quầy (demo)')
ON CONFLICT DO NOTHING;

-- ---------- check-in ----------
INSERT INTO facial_profiles (id, member_id, template_ref, status) VALUES
 ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-000000000041', 'face-store/demo/member-1', 'ACTIVE')
ON CONFLICT DO NOTHING;

INSERT INTO attendance_records (id, member_id, checked_in_at, source, kiosk_id, dedupe_key) VALUES
 ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000041', now() - interval '1 day',  'FACE', 'KIOSK-01', 'demo-m1-1'),
 ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000041', now() - interval '2 days', 'FACE', 'KIOSK-01', 'demo-m1-2')
ON CONFLICT DO NOTHING;

-- ---------- booking policy (giá trị demo, Admin có thể đổi) ----------
INSERT INTO booking_policy (id, max_advance_days, min_notice_hours, cancel_deadline_hours, max_future_bookings, active, updated_by) VALUES
 ('00000000-0000-0000-0000-000000000081', 14, 2, 24, 3, true, '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

-- ---------- slots + bookings (session 90 phút) ----------
INSERT INTO availability_slots (id, pt_id, start_at, end_at, status) VALUES
 ('00000000-0000-0000-0000-000000000091', '00000000-0000-0000-0000-000000000021', pg_temp.vn( 2, 18), pg_temp.vn( 2, 19, 30), 'BOOKED'),
 ('00000000-0000-0000-0000-000000000092', '00000000-0000-0000-0000-000000000021', pg_temp.vn( 3, 18), pg_temp.vn( 3, 19, 30), 'AVAILABLE'),  -- Member đã hủy đúng hạn -> mở lại
 ('00000000-0000-0000-0000-000000000093', '00000000-0000-0000-0000-000000000021', pg_temp.vn( 4, 18), pg_temp.vn( 4, 19, 30), 'DISABLED'),   -- PT hủy -> không tự mở lại
 ('00000000-0000-0000-0000-000000000094', '00000000-0000-0000-0000-000000000021', pg_temp.vn( 5, 18), pg_temp.vn( 5, 19, 30), 'AVAILABLE'),
 ('00000000-0000-0000-0000-000000000095', '00000000-0000-0000-0000-000000000022', pg_temp.vn( 2, 18), pg_temp.vn( 2, 19, 30), 'AVAILABLE'),  -- cùng giờ slot 91 nhưng PT khác
 ('00000000-0000-0000-0000-000000000096', '00000000-0000-0000-0000-000000000022', pg_temp.vn( 3,  9), pg_temp.vn( 3, 10, 30), 'AVAILABLE'),
 ('00000000-0000-0000-0000-000000000097', '00000000-0000-0000-0000-000000000021', pg_temp.vn(-1, 18), pg_temp.vn(-1, 19, 30), 'BOOKED')      -- session đã diễn ra
ON CONFLICT DO NOTHING;

INSERT INTO bookings (id, member_id, pt_id, slot_id, start_at, end_at, status, cancelled_by, cancel_reason, cancelled_at, completed_at) VALUES
 ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000091', pg_temp.vn( 2, 18), pg_temp.vn( 2, 19, 30), 'CONFIRMED', NULL,     NULL,                NULL,  NULL),
 ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000092', pg_temp.vn( 3, 18), pg_temp.vn( 3, 19, 30), 'CANCELLED', 'MEMBER', NULL,                now(), NULL),
 ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-000000000042', '00000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000093', pg_temp.vn( 4, 18), pg_temp.vn( 4, 19, 30), 'CANCELLED', 'PT',     'PT bận đột xuất',   now(), NULL),
 ('00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000097', pg_temp.vn(-1, 18), pg_temp.vn(-1, 19, 30), 'COMPLETED', NULL,     NULL,                NULL,  pg_temp.vn(-1, 19, 30))
ON CONFLICT DO NOTHING;

-- ---------- workout ----------
INSERT INTO workout_plans (id, pt_id, member_id, title, status) VALUES
 ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000041', 'Giáo án tuần 1 - Full body', 'ACTIVE')
ON CONFLICT DO NOTHING;

INSERT INTO workout_plan_items (id, workout_plan_id, exercise_name, instructions, sort_order) VALUES
 ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000c1', 'Squat',   'Giữ lưng thẳng, xuống chậm',   1),
 ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000c1', 'Push-up', 'Siết cơ bụng suốt động tác',   2),
 ('00000000-0000-0000-0000-0000000000c4', '00000000-0000-0000-0000-0000000000c1', 'Plank',   'Giữ tư thế theo hướng dẫn PT', 3)
ON CONFLICT DO NOTHING;

INSERT INTO workout_completions (id, item_id, member_id, status, completed_at) VALUES
 ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-000000000041', 'COMPLETED', now() - interval '1 day')
ON CONFLICT DO NOTHING;

INSERT INTO notifications (id, user_id, type, title, body) VALUES
 ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-000000000031', 'BOOKING_CONFIRMED', 'Đặt lịch thành công', 'Buổi tập PT của bạn đã được xác nhận.'),
 ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-000000000031', 'WORKOUT_ASSIGNED',  'Giáo án mới',         'PT vừa giao giáo án mới cho bạn.')
ON CONFLICT DO NOTHING;
