-- =====================================================================
-- Kiểm thử constraint ở tầng DB (Repository/DB integration - hồ sơ mục 7.5)
-- Yêu cầu: đã chạy migration V1..V7 và seed/demo_data.sql (nạp seed trong cùng ngày chạy test;
-- nếu seed đã cũ, chạy lại seed để ngày tháng demo được làm mới).
-- Toàn bộ chạy trong 1 transaction rồi ROLLBACK -> không làm bẩn dữ liệu.
-- Đọc kết quả ở các dòng NOTICE: "PASS | ..." / "FAIL | ...".
-- Nếu có test FAIL, script kết thúc bằng lỗi (psql -v ON_ERROR_STOP=1 sẽ trả exit code != 0).
-- Test đồng thời nhiều request (TC-BKG-02 thật sự) thuộc phần Backend (Testcontainers).
-- =====================================================================
BEGIN;

CREATE TEMP TABLE test_results (name text, ok boolean, detail text);

-- Mong đợi câu lệnh LỖI với một trong các SQLSTATE cho trước
CREATE OR REPLACE FUNCTION pg_temp.expect_fail(p_name text, p_sql text, p_states text[]) RETURNS void AS $$
BEGIN
    BEGIN
        EXECUTE p_sql;
        INSERT INTO test_results VALUES (p_name, false, 'câu lệnh chạy thành công nhưng đáng ra phải lỗi');
        RAISE NOTICE 'FAIL | % -> không bị chặn', p_name;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = ANY (p_states) THEN
            INSERT INTO test_results VALUES (p_name, true, SQLSTATE);
            RAISE NOTICE 'PASS | % (%)', p_name, SQLSTATE;
        ELSE
            INSERT INTO test_results VALUES (p_name, false, SQLSTATE || ' ' || SQLERRM);
            RAISE NOTICE 'FAIL | % -> lỗi khác dự kiến: % %', p_name, SQLSTATE, SQLERRM;
        END IF;
    END;
END;
$$ LANGUAGE plpgsql;

-- Mong đợi câu lệnh THÀNH CÔNG
CREATE OR REPLACE FUNCTION pg_temp.expect_ok(p_name text, p_sql text) RETURNS void AS $$
BEGIN
    BEGIN
        EXECUTE p_sql;
        INSERT INTO test_results VALUES (p_name, true, 'ok');
        RAISE NOTICE 'PASS | %', p_name;
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO test_results VALUES (p_name, false, SQLSTATE || ' ' || SQLERRM);
        RAISE NOTICE 'FAIL | % -> % %', p_name, SQLSTATE, SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- Mong đợi câu truy vấn trả về TRUE
CREATE OR REPLACE FUNCTION pg_temp.expect_true(p_name text, p_query text) RETURNS void AS $$
DECLARE
    v boolean;
BEGIN
    EXECUTE p_query INTO v;
    IF v IS TRUE THEN
        INSERT INTO test_results VALUES (p_name, true, 'ok');
        RAISE NOTICE 'PASS | %', p_name;
    ELSE
        INSERT INTO test_results VALUES (p_name, false, 'truy vấn trả về ' || COALESCE(v::text, 'NULL'));
        RAISE NOTICE 'FAIL | % -> truy vấn không trả về TRUE', p_name;
    END IF;
EXCEPTION WHEN OTHERS THEN
    INSERT INTO test_results VALUES (p_name, false, SQLSTATE || ' ' || SQLERRM);
    RAISE NOTICE 'FAIL | % -> % %', p_name, SQLSTATE, SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- ===================== MEMBERSHIP PERIODS (V7) =====================
-- Kiểm tra dữ liệu seed trước khi các test bên dưới thêm dòng mới
SELECT pg_temp.expect_true('V7 | payment_transactions không còn cột period_start/period_end',
$q$ SELECT NOT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_name = 'payment_transactions' AND column_name IN ('period_start', 'period_end')) $q$);

SELECT pg_temp.expect_true('V7 | memberships.expiry_date = period_end của kỳ cuối đã trả tiền',
$q$ SELECT NOT EXISTS (
        SELECT 1 FROM memberships m
        JOIN (SELECT membership_id, max(period_end) AS last_end FROM membership_periods GROUP BY membership_id) x
          ON x.membership_id = m.id
        WHERE m.expiry_date <> x.last_end) $q$);

SELECT pg_temp.expect_true('V7 | view: gói đang dùng (1 tháng) khác gói kỳ kế tiếp (3 tháng)',
$q$ SELECT EXISTS (
        SELECT 1 FROM v_membership_overview
        WHERE membership_id = '00000000-0000-0000-0000-000000000061'
          AND current_plan_id = '00000000-0000-0000-0000-000000000051'
          AND next_plan_id    = '00000000-0000-0000-0000-000000000052'
          AND last_paid_end   = app_today() + 99) $q$);

-- Giao dịch mới SUCCESS của Member 1 (gói 1 tháng) để thử các kịch bản gia hạn
SELECT pg_temp.expect_ok('V7 | tạo giao dịch SUCCESS để gia hạn',
$q$ INSERT INTO payment_transactions (member_id, plan_id, membership_id, provider_ref, amount, status, processed_at)
    VALUES ('00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000051',
            '00000000-0000-0000-0000-000000000061', 'T-NEW-1', 500000, 'SUCCESS', now()) $q$);

SELECT pg_temp.expect_fail('V7 | cùng 1 giao dịch không cộng 2 kỳ (UNIQUE payment_transaction_id)',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end, payment_transaction_id)
    VALUES ('00000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000052', 'RENEWAL',
            app_today() + 300, app_today() + 389, '00000000-0000-0000-0000-000000000071') $q$,
ARRAY['23505']);

SELECT pg_temp.expect_fail('V7 | các kỳ của 1 membership không chồng ngày',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end, payment_transaction_id)
    SELECT '00000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000051', 'RENEWAL',
           app_today() + 50, app_today() + 79, id FROM payment_transactions WHERE provider_ref = 'T-NEW-1' $q$,
ARRAY['23P01']);

SELECT pg_temp.expect_fail('V7 | plan của kỳ phải khớp plan của giao dịch',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end, payment_transaction_id)
    SELECT '00000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000052', 'RENEWAL',
           app_today() + 100, app_today() + 189, id FROM payment_transactions WHERE provider_ref = 'T-NEW-1' $q$,
ARRAY['23503']);

SELECT pg_temp.expect_ok('V7 | gia hạn nhiều lần: kỳ mới nối tiếp kỳ cuối đã trả tiền',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end, payment_transaction_id)
    SELECT '00000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000051', 'RENEWAL',
           app_today() + 100, app_today() + 129, id FROM payment_transactions WHERE provider_ref = 'T-NEW-1' $q$);

SELECT pg_temp.expect_fail('V7 | giao dịch chưa SUCCESS không được cộng kỳ',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end, payment_transaction_id)
    VALUES ('00000000-0000-0000-0000-000000000062', '00000000-0000-0000-0000-000000000051', 'RENEWAL',
            app_today(), app_today() + 29, '00000000-0000-0000-0000-000000000073') $q$,
ARRAY['23514']);

SELECT pg_temp.expect_fail('V7 | giao dịch của Member khác không được cộng vào membership này',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end, payment_transaction_id)
    VALUES ('00000000-0000-0000-0000-000000000062', '00000000-0000-0000-0000-000000000052', 'RENEWAL',
            app_today(), app_today() + 89, '00000000-0000-0000-0000-000000000071') $q$,
ARRAY['23514']);

SELECT pg_temp.expect_fail('V7 | kỳ RENEWAL bắt buộc có payment_transaction_id',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end)
    VALUES ('00000000-0000-0000-0000-000000000062', '00000000-0000-0000-0000-000000000051', 'RENEWAL',
            app_today(), app_today() + 29) $q$,
ARRAY['23514']);

SELECT pg_temp.expect_fail('V7 | ACTIVATION bắt buộc có Admin xác nhận + tiền + phiếu thu',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end)
    VALUES ('00000000-0000-0000-0000-000000000063', '00000000-0000-0000-0000-000000000051', 'ACTIVATION',
            app_today(), app_today() + 29) $q$,
ARRAY['23514']);

SELECT pg_temp.expect_fail('V7 | người xác nhận ACTIVATION phải là ADMIN',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end,
                                    amount_collected, confirmed_by_user_id, confirmed_at, receipt_ref)
    VALUES ('00000000-0000-0000-0000-000000000063', '00000000-0000-0000-0000-000000000051', 'ACTIVATION',
            app_today(), app_today() + 29, 500000, '00000000-0000-0000-0000-000000000031', now(), 'PT-TEST-0') $q$,
ARRAY['23514']);

SELECT pg_temp.expect_ok('V7 | kích hoạt lần đầu hợp lệ (Admin xác nhận, có tiền + phiếu thu)',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end,
                                    amount_collected, confirmed_by_user_id, confirmed_at, receipt_ref)
    VALUES ('00000000-0000-0000-0000-000000000063', '00000000-0000-0000-0000-000000000051', 'ACTIVATION',
            app_today(), app_today() + 29, 500000, '00000000-0000-0000-0000-000000000001', now(), 'PT-TEST-1') $q$);

SELECT pg_temp.expect_fail('V7 | mỗi membership chỉ có 1 kỳ ACTIVATION',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end,
                                    amount_collected, confirmed_by_user_id, confirmed_at, receipt_ref)
    VALUES ('00000000-0000-0000-0000-000000000063', '00000000-0000-0000-0000-000000000051', 'ACTIVATION',
            app_today() + 100, app_today() + 129, 500000, '00000000-0000-0000-0000-000000000001', now(), 'PT-TEST-2') $q$,
ARRAY['23505']);

SELECT pg_temp.expect_fail('V7 | period_end phải >= period_start',
$q$ INSERT INTO membership_periods (membership_id, plan_id, source, period_start, period_end,
                                    amount_collected, confirmed_by_user_id, confirmed_at, receipt_ref)
    VALUES ('00000000-0000-0000-0000-000000000062', '00000000-0000-0000-0000-000000000051', 'ACTIVATION',
            app_today() + 10, app_today() + 9, 500000, '00000000-0000-0000-0000-000000000001', now(), 'PT-TEST-3') $q$,
ARRAY['23514']);

-- ===================== BOOKING =====================
-- TC-BKG-02 (mức DB): slot 91 đã có booking CONFIRMED của Member 1 -> Member 2 không đặt thêm được
-- (23505 unique_violation hoặc 23P01 exclusion_violation; backend map cả hai thành HTTP 409)
SELECT pg_temp.expect_fail('TC-BKG-02 | 2 booking CONFIRMED cùng 1 slot bị chặn',
$q$ INSERT INTO bookings (member_id, pt_id, slot_id, start_at, end_at, status)
    SELECT '00000000-0000-0000-0000-000000000042', s.pt_id, s.id, s.start_at, s.end_at, 'CONFIRMED'
    FROM availability_slots s WHERE s.id = '00000000-0000-0000-0000-000000000091' $q$,
ARRAY['23505','23P01']);

-- AC-BKG-03: Member 1 đã có session lúc đó (slot 91), slot 95 của PT khác cùng giờ -> bị chặn
SELECT pg_temp.expect_fail('AC-BKG-03 | Member không đặt 2 session chồng giờ',
$q$ INSERT INTO bookings (member_id, pt_id, slot_id, start_at, end_at, status)
    SELECT '00000000-0000-0000-0000-000000000041', s.pt_id, s.id, s.start_at, s.end_at, 'CONFIRMED'
    FROM availability_slots s WHERE s.id = '00000000-0000-0000-0000-000000000095' $q$,
ARRAY['23P01']);

-- PT không công bố 2 slot chồng giờ
SELECT pg_temp.expect_fail('Slot | PT không có 2 slot chồng giờ',
$q$ INSERT INTO availability_slots (pt_id, start_at, end_at)
    SELECT pt_id, start_at + interval '30 minutes', end_at + interval '30 minutes'
    FROM availability_slots WHERE id = '00000000-0000-0000-0000-000000000094' $q$,
ARRAY['23P01']);

SELECT pg_temp.expect_fail('Slot | end_at phải sau start_at',
$q$ INSERT INTO availability_slots (pt_id, start_at, end_at)
    VALUES ('00000000-0000-0000-0000-000000000022', now() + interval '30 days', now() + interval '30 days') $q$,
ARRAY['23514']);

-- FK ghép: booking phải khớp slot + PT + giờ
SELECT pg_temp.expect_fail('Booking | giờ phải khớp với slot',
$q$ INSERT INTO bookings (member_id, pt_id, slot_id, start_at, end_at, status)
    SELECT '00000000-0000-0000-0000-000000000042', s.pt_id, s.id, s.start_at, s.end_at + interval '1 minute', 'CONFIRMED'
    FROM availability_slots s WHERE s.id = '00000000-0000-0000-0000-000000000094' $q$,
ARRAY['23503']);

-- AC-BKG-06 / TC-BKG-05: PT hủy phải có lý do
SELECT pg_temp.expect_fail('AC-BKG-06 | PT hủy với lý do rỗng bị chặn',
$q$ UPDATE bookings SET status = 'CANCELLED', cancelled_by = 'PT', cancelled_at = now(), cancel_reason = '   '
    WHERE id = '00000000-0000-0000-0000-0000000000b1' $q$,
ARRAY['23514']);

SELECT pg_temp.expect_fail('Booking | CANCELLED phải có cancelled_by',
$q$ UPDATE bookings SET status = 'CANCELLED' WHERE id = '00000000-0000-0000-0000-0000000000b1' $q$,
ARRAY['23514']);

SELECT pg_temp.expect_ok('AC-BKG-09 | PT hủy với lý do hợp lệ',
$q$ UPDATE bookings SET status = 'CANCELLED', cancelled_by = 'PT', cancelled_at = now(), cancel_reason = 'PT bận'
    WHERE id = '00000000-0000-0000-0000-0000000000b1' $q$);

-- AC-BKG-08: slot 92 từng có booking bị Member hủy -> Member khác đặt lại được
SELECT pg_temp.expect_ok('AC-BKG-08 | Đặt lại slot sau khi Member hủy',
$q$ INSERT INTO bookings (member_id, pt_id, slot_id, start_at, end_at, status)
    SELECT '00000000-0000-0000-0000-000000000042', s.pt_id, s.id, s.start_at, s.end_at, 'CONFIRMED'
    FROM availability_slots s WHERE s.id = '00000000-0000-0000-0000-000000000092' $q$);

-- ===================== PAYMENT / MEMBERSHIP =====================
-- AC-PAY-01 / TC-PAY-01: provider_ref trùng bị chặn (nền tảng của idempotent callback)
SELECT pg_temp.expect_fail('AC-PAY-01 | provider_ref trùng bị chặn',
$q$ INSERT INTO payment_transactions (member_id, plan_id, provider_ref, amount, status)
    VALUES ('00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000052', 'DEMO-TXN-0001', 1350000, 'PENDING') $q$,
ARRAY['23505']);

SELECT pg_temp.expect_fail('Payment | amount không âm',
$q$ INSERT INTO payment_transactions (member_id, plan_id, provider_ref, amount)
    VALUES ('00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000052', 'T-NEG', -1) $q$,
ARRAY['23514']);

SELECT pg_temp.expect_fail('Plan | duration_days phải > 0',
$q$ INSERT INTO membership_plans (name, duration_days, price) VALUES ('x', 0, 0) $q$,
ARRAY['23514']);

SELECT pg_temp.expect_fail('Membership | expiry_date >= start_date',
$q$ INSERT INTO memberships (member_id, plan_id, start_date, expiry_date, status)
    VALUES ('00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000051', CURRENT_DATE, CURRENT_DATE - 1, 'ACTIVE') $q$,
ARRAY['23514']);

SELECT pg_temp.expect_fail('Membership | mỗi Member chỉ 1 membership hiện hành',
$q$ INSERT INTO memberships (member_id, plan_id, start_date, expiry_date, status)
    VALUES ('00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000051', CURRENT_DATE, CURRENT_DATE + 30, 'ACTIVE') $q$,
ARRAY['23505']);

-- ===================== CHECK-IN =====================
SELECT pg_temp.expect_fail('AC-CHK-04 | dedupe_key trùng không tạo attendance thứ hai',
$q$ INSERT INTO attendance_records (member_id, dedupe_key) VALUES ('00000000-0000-0000-0000-000000000041', 'demo-m1-1') $q$,
ARRAY['23505']);

SELECT pg_temp.expect_fail('Facial | tối đa 1 profile ACTIVE mỗi Member',
$q$ INSERT INTO facial_profiles (member_id, template_ref, status)
    VALUES ('00000000-0000-0000-0000-000000000041', 'face-store/other', 'ACTIVE') $q$,
ARRAY['23505']);

SELECT pg_temp.expect_fail('Facial | REVOKED phải có revoked_at',
$q$ INSERT INTO facial_profiles (member_id, template_ref, status)
    VALUES ('00000000-0000-0000-0000-000000000042', 'face-store/x', 'REVOKED') $q$,
ARRAY['23514']);

SELECT pg_temp.expect_ok('Facial | thu hồi profile cũ',
$q$ UPDATE facial_profiles SET status = 'REVOKED', revoked_at = now()
    WHERE member_id = '00000000-0000-0000-0000-000000000041' AND status = 'ACTIVE' $q$);
SELECT pg_temp.expect_ok('Facial | enroll lại sau khi thu hồi',
$q$ INSERT INTO facial_profiles (member_id, template_ref, status)
    VALUES ('00000000-0000-0000-0000-000000000041', 'face-store/demo/member-1-v2', 'ACTIVE') $q$);

-- ===================== POLICY / USER / WORKOUT =====================
SELECT pg_temp.expect_fail('Policy | chỉ 1 policy active',
$q$ INSERT INTO booking_policy (max_advance_days, min_notice_hours, cancel_deadline_hours, max_future_bookings, active)
    VALUES (7, 1, 12, 2, true) $q$,
ARRAY['23505']);

SELECT pg_temp.expect_fail('User | email trùng (không phân biệt hoa/thường)',
$q$ INSERT INTO users (email, password_hash, role) VALUES ('ADMIN@FitCenter.local', 'x', 'ADMIN') $q$,
ARRAY['23505']);

SELECT pg_temp.expect_fail('Member | user role PT không thể có hồ sơ Member',
$q$ INSERT INTO members (user_id, full_name) VALUES ('00000000-0000-0000-0000-000000000011', 'Sai role') $q$,
ARRAY['23503']);

SELECT pg_temp.expect_fail('AC-WRK-01 | completion trùng (item, member)',
$q$ INSERT INTO workout_completions (item_id, member_id, status, completed_at)
    VALUES ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-000000000041', 'COMPLETED', now()) $q$,
ARRAY['23505']);

-- ===================== TỔNG KẾT =====================
DO $$
DECLARE
    v_total int; v_pass int; v_fail int;
BEGIN
    SELECT count(*), count(*) FILTER (WHERE ok), count(*) FILTER (WHERE NOT ok)
      INTO v_total, v_pass, v_fail FROM test_results;
    RAISE NOTICE '===== % / % test PASS =====', v_pass, v_total;
    IF v_fail > 0 THEN
        RAISE EXCEPTION '% test FAIL - xem các dòng FAIL ở trên', v_fail;
    END IF;
END;
$$;

ROLLBACK;
