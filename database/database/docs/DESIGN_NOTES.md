# Ghi chú thiết kế Database — Topic 11 FitCenter

Nguồn: `Topic11_FITCENTER.docx`, Chương 4 (ERD & Database Design), mục 2.5 (invariant), 3.7, 5, 7.5.
Phần Membership/Payment đã được thống nhất giữa Database và Backend (xem mục 4).

## 1. Quy ước chung
- Khóa chính `UUID` (`gen_random_uuid()`, PostgreSQL 13+; khuyến nghị `postgres:16`).
- Thời gian dùng `TIMESTAMPTZ` (lưu UTC). Ngày nghiệp vụ (`DATE`) tính theo giờ Việt Nam qua hàm `app_today()` (V7).
- Enum lưu bằng `VARCHAR` + `CHECK` → JPA dùng `@Enumerated(EnumType.STRING)`.
- `updated_at` do trigger `set_updated_at()` cập nhật.
- **Quy tắc migration: không sửa file V đã áp dụng.** V1–V6 giữ nguyên; thay đổi mới nằm ở V7 trở đi.

## 2. Ràng buộc nghiệp vụ DB đã đảm bảo

| Quy tắc (nguồn) | Cơ chế trong DB | File |
|---|---|---|
| AC-BKG-02: tối đa 1 booking CONFIRMED mỗi slot | `UNIQUE INDEX ... WHERE status='CONFIRMED'` (+ exclusion của PT) | V4 |
| AC-BKG-03: không chồng giờ (Member, PT) | `EXCLUDE USING gist` trên `bookings` (chỉ `CONFIRMED`) | V4 |
| PT không có 2 slot chồng giờ | `EXCLUDE USING gist` trên `availability_slots` (bỏ `DISABLED`) | V4 |
| Booking khớp slot / PT / giờ | FK ghép `(slot_id, pt_id, start_at, end_at)` | V4 |
| BR-BKG-07: slot mở lại sau khi Member hủy | Không unique tuyệt đối theo `slot_id`; booking cũ giữ làm lịch sử | V4 |
| AC-BKG-06: PT hủy bắt buộc có lý do | `CHECK` | V4 |
| Chỉ 1 Booking Policy active | `UNIQUE INDEX ((active)) WHERE active` | V4 |
| AC-PAY-01: callback lặp không gia hạn lần hai | `UNIQUE (provider_ref)` + `UNIQUE (membership_periods.payment_transaction_id)` | V2, V7 |
| Mỗi giao dịch chỉ cộng khi `SUCCESS`, đúng Member | Trigger `fn_membership_period_validate` | V7 |
| Plan của kỳ gia hạn = plan của giao dịch | FK ghép `(payment_transaction_id, plan_id)` | V7 |
| Các kỳ của 1 membership không chồng ngày | `EXCLUDE USING gist` trên `daterange(period_start, period_end, '[]')` | V7 |
| Kích hoạt lần đầu có Admin xác nhận, tiền thực thu, mã phiếu thu | `CHECK` + trigger (role `ADMIN`) + `UNIQUE` 1 kỳ ACTIVATION/membership | V7 |
| Mỗi Member 1 membership hiện hành | `UNIQUE INDEX ... WHERE status <> 'CANCELLED'` | V2 |
| Mỗi Member 1 facial profile ACTIVE; không lưu ảnh/vector thô | `UNIQUE INDEX ... WHERE status='ACTIVE'`; chỉ cột `template_ref` | V3 |
| AC-CHK-04: không tạo attendance trùng | `UNIQUE (dedupe_key)` | V3 |
| Email duy nhất không phân biệt hoa/thường; hồ sơ Member/PT đúng role | `UNIQUE INDEX lower(email)`; FK ghép `(user_id, role)` | V1 |

## 3. Mô hình Membership (V7) — đã thống nhất với Backend
- `memberships`: mỗi Member **một dòng hiện hành**. Hết hạn rồi đăng ký lại / gia hạn = **UPDATE chính dòng đó** (`EXPIRED` → `ACTIVE`), không INSERT dòng mới. Chỉ INSERT khi Member chưa có dòng nào hoặc dòng cũ là `CANCELLED`.
- `membership_periods`: **nguồn dữ liệu chính** của gói đang dùng / gói kế tiếp và `GET /memberships/history`.
  - `ACTIVATION`: kích hoạt lần đầu tại quầy, không có `payment_transaction`; lưu `amount_collected`, `confirmed_by_user_id` (Admin), `confirmed_at`, `receipt_ref`, `note`.
  - `RENEWAL`: gắn đúng 1 giao dịch `SUCCESS`; số tiền lấy từ `payment_transactions`, không lưu trùng.
- `memberships.plan_id`: gói của kỳ gần nhất đã mua — **không dùng để hiển thị gói đang sử dụng**.
- `memberships.expiry_date`: luôn bằng `period_end` của kỳ cuối đã thanh toán (= `last_paid_end` của view).
- View `v_membership_overview`: `current_plan_id`, `current_period_*` (kỳ chứa hôm nay), `next_plan_id`, `next_period_*` (kỳ bắt đầu sau hôm nay), `last_paid_end`.

### Quy tắc cho Service khi xử lý giao dịch SUCCESS (trong 1 transaction)
1. Khóa dòng payment (`FOR UPDATE`), bỏ qua nếu đã xử lý (idempotent).
2. Khóa dòng membership (`SELECT ... FOR UPDATE`) **trước khi tính ngày**, để 2 callback đồng thời không tính ra cùng một ngày.
3. Tính kỳ mới (ngày kết thúc tính cả ngày đó):
   - `last_paid_end >= hôm nay`: `start = last_paid_end + 1`.
   - Ngược lại (đã hết hạn): `start = app_today()`.
   - `end = start + duration_days - 1`.
4. `INSERT membership_periods` (RENEWAL) → `UPDATE memberships` (`expiry_date = end`, `plan_id` = gói của kỳ, `status = ACTIVE` nếu đang `EXPIRED`).
5. Lỗi `23505` / `23P01` khi cộng kỳ ⇒ coi là xử lý trùng / chồng ngày, rollback và trả lại kết quả đã có.

## 4. Các phần bổ sung ngoài Data Dictionary 4.1 (cần Nhân/nhóm xác nhận)
1. **`membership_periods` kèm bằng chứng thanh toán tại quầy (`amount_collected`, `receipt_ref`, người xác nhận)** — UC-20 có "offline payment evidence" ở Input nhưng 4.1 chưa có chỗ lưu.
2. **`audit_logs` (V6)** — mục 3.7 yêu cầu audit nhưng 4.1 không có bảng.
3. **`attendance_records.kiosk_id`, `source`; `availability_slots.version`; `payment_transactions.provider`; `members/personal_trainers.user_role`** (cột kỹ thuật cho FK ghép).
4. **Exclusion constraint cho slot/booking/period** — mục 4.3 gọi là phương án mạnh hơn.
5. **Hàm `app_today()` cố định múi giờ `Asia/Ho_Chi_Minh`**.

## 5. Câu hỏi còn mở
- **Slot sau khi PT hủy**: SRS chỉ nói "không tự reopen". Seed đang để `DISABLED`; backend cần thống nhất.
- **`PENDING_ACTIVATION`**: có trong enum nhưng UC-20 cho `ACTIVE` ngay; cần chốt khi nào mới dùng.
- **Gia hạn khi `SUSPENDED` / `CANCELLED`**: SRS không nói; đề xuất từ chối.
- **Trả trước nhiều kỳ**: hiện không giới hạn số kỳ trả trước.
- **Giá trị Booking Policy mặc định** (seed: 14 ngày / 2 giờ / 24 giờ / 3 booking) chỉ là demo.
- **Vị trí file migration khi gộp repo chính**: chuyển `migrations/` sang `backend/src/main/resources/db/migration/` để chỉ một nơi quản lý Flyway.
- **Giới hạn 90 phút/session**: DB chỉ kiểm `end_at > start_at`; backend validate độ dài.
- **Xóa / sửa giờ slot đã từng có booking**: bị FK chặn; chuyển `DISABLED` rồi tạo slot mới.

## 6. Quy tắc DB KHÔNG tự kiểm tra — thuộc Service
- Membership phải `ACTIVE` khi đặt lịch / check-in.
- Booking Policy: max advance, min notice, max future bookings, cancel deadline.
- Cửa sổ trùng check-in 30 phút (backend tính và ghi `dedupe_key`).
- Đồng bộ `availability_slots.status` với booking trong cùng transaction.
- Member chỉ ghi completion cho plan được giao cho chính mình.
- Đồng bộ `memberships.expiry_date` với kỳ cuối khi thêm kỳ (mục 3).
- Ánh xạ lỗi: `23505` và `23P01` ⇒ HTTP 409 (`ERR_SLOT_NO_LONGER_AVAILABLE` với booking).
