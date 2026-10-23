# Ghi chú thiết kế Database — Topic 11 FitCenter

Nguồn: `Topic11_FITCENTER.docx`, Chương 4 (ERD & Database Design), mục 2.5 (invariant), 3.7, 5, 7.5.

## 1. Quy ước chung
- Khóa chính `UUID` (`gen_random_uuid()`, PostgreSQL 13+; khuyến nghị image `postgres:16`).
- Thời gian dùng `TIMESTAMPTZ` (lưu UTC, UI tự đổi sang giờ địa phương — mục 5.1).
- Enum lưu bằng `VARCHAR` + `CHECK` (không dùng `CREATE TYPE`), để JPA `@Enumerated(EnumType.STRING)` và Flyway dễ thay đổi sau này.
- `updated_at` được trigger `set_updated_at()` cập nhật tự động.
- Schema chỉ thay đổi bằng migration mới (`V7__...`). **Không sửa file V đã merge.**

## 2. Ràng buộc nghiệp vụ đã được DB đảm bảo

| Quy tắc (nguồn) | Cơ chế trong DB | File |
|---|---|---|
| AC-BKG-02 / BR-BKG-06: tối đa 1 booking CONFIRMED mỗi slot | `UNIQUE INDEX uq_booking_slot_confirmed ... WHERE status='CONFIRMED'` (+ exclusion constraint của PT) | V4 |
| AC-BKG-03: không chồng giờ (Member và PT) | `EXCLUDE USING gist` trên `bookings` cho `member_id` và `pt_id`, chỉ xét `CONFIRMED` | V4 |
| PT không có 2 slot chồng giờ | `EXCLUDE USING gist` trên `availability_slots` (bỏ qua `DISABLED`) | V4 |
| Booking khớp slot / PT / giờ | FK ghép `(slot_id, pt_id, start_at, end_at)` | V4 |
| Slot mở lại sau khi Member hủy (BR-BKG-07) | Không unique tuyệt đối theo `slot_id`; booking cũ giữ lại làm lịch sử | V4 |
| AC-BKG-06: PT hủy bắt buộc có lý do | `CHECK` (`cancelled_by='PT'` ⇒ `cancel_reason` không rỗng) | V4 |
| CANCELLED ⇔ có `cancelled_by` + `cancelled_at`; COMPLETED ⇔ có `completed_at` | `CHECK` | V4 |
| Chỉ 1 Booking Policy active | `UNIQUE INDEX ((active)) WHERE active` | V4 |
| AC-PAY-01: callback lặp không gia hạn lần hai | `UNIQUE (provider_ref)` (cộng kiểm tra trạng thái trong transaction ở backend) | V2 |
| Mỗi Member 1 membership hiện hành | `UNIQUE INDEX ... WHERE status <> 'CANCELLED'` | V2 |
| `duration_days > 0`, `price >= 0`, `expiry_date >= start_date` | `CHECK` | V2 |
| Mỗi Member 1 facial profile ACTIVE | `UNIQUE INDEX ... WHERE status='ACTIVE'` | V3 |
| AC-CHK-04: không tạo attendance trùng | `UNIQUE (dedupe_key)` (chốt chặn cuối) | V3 |
| Không lưu ảnh/vector khuôn mặt thô (NFR-PRIV-01) | Chỉ có cột `template_ref` | V3 |
| Email duy nhất, không phân biệt hoa/thường | `UNIQUE INDEX ON lower(email)` | V1 |
| Hồ sơ Member chỉ gắn với user role MEMBER; PT chỉ với role PT | FK ghép `(user_id, role)` | V1 |
| Không lưu mật khẩu thô / thẻ thanh toán | Cột `password_hash`; không có cột thẻ/ngân hàng | V1, V2 |

## 3. Những phần ghi thêm so với Data Dictionary 4.1 (cần team duyệt)
1. **`audit_logs` (V6)** — mục 3.7 yêu cầu audit nhưng 4.1 không có bảng. Bỏ file V6 nếu không dùng.
2. **`payment_transactions.period_start/period_end/provider`** — để biết giao dịch đã cộng khoảng thời hạn nào (phục vụ `GET /memberships/history`).
3. **`attendance_records.kiosk_id`, `source`** — theo API `/check-ins/face` (có `kioskId`).
4. **`availability_slots.version`** — optimistic locking.
5. **`members.user_role`, `personal_trainers.user_role`** — cột kỹ thuật cho FK ghép; backend không cần map.
6. **Exclusion constraint cho slot/booking** — mục 4.3 gọi là phương án mạnh hơn, đã bật sẵn.
7. **Mô hình membership "một dòng hiện hành, gia hạn = cập nhật `expiry_date`"** — hồ sơ chưa nêu rõ. Nếu team muốn mỗi lần mua là một dòng riêng thì bỏ index `uq_membership_one_current_per_member`.

## 4. Câu hỏi cần chốt với nhóm
- **Slot sau khi PT hủy**: hồ sơ chỉ nói "không tự reopen". Seed đang để `DISABLED`. Backend cần thống nhất trạng thái này.
- **Giá trị Booking Policy mặc định**: hồ sơ chưa nêu số. Seed dùng 14 ngày / 2 giờ / 24 giờ / 3 booking (chỉ là demo, Admin đổi được).
- **Vị trí file migration khi gộp vào repo chính**: nếu backend dùng Flyway thì chuyển `migrations/` sang `backend/src/main/resources/db/migration/`; tránh để 2 nơi cùng quản lý bảng `flyway_schema_history`.
- **Xóa slot đã từng có booking**: do FK, không `DELETE` được; backend nên chuyển `status='DISABLED'` thay vì xóa cứng.
- **Sửa giờ slot đã từng có booking (kể cả đã hủy)**: bị FK chặn, hãy tạo slot mới.
- **Giới hạn 90 phút/session**: hồ sơ nêu "Core session duration 90 phút", DB chỉ kiểm `end_at > start_at`; backend validate độ dài.

## 5. Quy tắc DB KHÔNG tự kiểm tra — thuộc Service (backend)
- Membership phải `ACTIVE` khi đặt lịch / check-in.
- Booking Policy: max advance, min notice, max future bookings, cancel deadline.
- Cửa sổ trùng check-in 30 phút (backend tính, ghi `dedupe_key`).
- Đồng bộ `availability_slots.status` với booking (BOOKED/AVAILABLE) trong cùng transaction.
- Member chỉ ghi completion cho plan được giao cho chính mình.
- Ánh xạ lỗi: `23505` (unique) và `23P01` (exclusion) ⇒ `ERR_SLOT_NO_LONGER_AVAILABLE` / HTTP 409.
