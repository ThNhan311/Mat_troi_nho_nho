# FitCenter Face Service — hợp đồng API (v1, bản nháp)

Trạng thái: **bản nháp cho giai đoạn thử nghiệm**. Frontend đã đồng ý dùng để kiosk gọi trực tiếp Face Service. Backend (Spring Boot) **chưa** xác nhận; khi backend vào giữa (đợt 3) thì kiosk gọi backend, backend gọi Face Service bằng chính hợp đồng này.

Face Service chỉ trả lời "khuôn mặt này giống thành viên nào". Nó **không** kiểm tra gói tập, không ghi `AttendanceRecord`, không chống ghi trùng 30 phút. Những việc đó thuộc backend. **Chưa có liveness**: ảnh hoặc video của người đã đăng ký có thể vượt qua, nên mọi phản hồi mang `"liveness": "NOT_PERFORMED"`.

## Quy ước chung

- Base URL mặc định `http://127.0.0.1:8750`. Service chỉ nghe địa chỉ loopback trừ khi cấu hình khác; HTTP trần, không dùng qua mạng không tin cậy.
- Ảnh gửi bằng `multipart/form-data`, trường `frames`, mỗi ảnh là JPEG hoặc PNG (≤ 2 MB). Flutter: `http.MultipartRequest`, ảnh từ `CameraController.takePicture()`.
- Xác thực bằng header, **mọi** endpoint (trừ `/v1/health`). Thiếu hoặc sai → `401`.

| Header | Dùng cho | Biến môi trường phía service |
|---|---|---|
| `X-Kiosk-Token` | `POST /v1/identify` | `FITCENTER_KIOSK_TOKEN` |
| `X-Admin-Token` | `POST /v1/enroll`, `DELETE /v1/members/{id}` | `FITCENTER_ADMIN_TOKEN` |

- Lỗi trả JSON `{"error": "<MÃ_LỖI>", "detail": "<mô tả ngắn>"}`. `detail` không chứa dữ liệu sinh trắc học.
- Service xử lý lần lượt từng yêu cầu nhận diện; quá tải trả `503 BUSY`. Client nên đặt timeout 8 giây.

## `GET /v1/health`

Không cần token. `200 {"status": "ok", "members": <số thành viên>, "model": "insightface-buffalo_s"}`.

## `POST /v1/identify`

Nhận diện 1:N. Gửi 1–5 frame của cùng một người (nên 3). Service lấy trung bình embedding các frame có mặt rồi so với toàn bộ gallery.

| Trường form | Bắt buộc | Ghi chú |
|---|---|---|
| `frames` | có | 1–5 file ảnh |
| `request_id` | không | Chuỗi ≤ 64 ký tự, được trả lại nguyên vẹn. Thiếu thì service tự sinh UUID. |

Phản hồi `200`:

```json
{
  "request_id": "b3f1c0e2-...",
  "outcome": "SUCCESS",
  "member_id": "M001",
  "score": 0.71,
  "liveness": "NOT_PERFORMED"
}
```

| `outcome` | Ý nghĩa | `member_id` |
|---|---|---|
| `SUCCESS` | Khớp một thành viên rõ ràng | có |
| `REJECTED` | Có mặt nhưng không khớp ai, hoặc khớp mơ hồ | `null` |
| `NO_FACE` | Không phát hiện mặt trong các frame | `null` |

`score` là cosine similarity tốt nhất (-1..1), chỉ để gỡ lỗi; **kiosk không nên hiển thị**. Ngưỡng và biên độ chưa hiệu chỉnh, xem README.

Lỗi: `400 INVALID_IMAGE`, `400 TOO_MANY_FRAMES`, `400 NO_FRAMES`, `413 IMAGE_TOO_LARGE`, `401 UNAUTHORIZED`, `503 BUSY`.

Ánh xạ gợi ý cho kiosk Flutter (`KioskState`): `SUCCESS` → hỏi backend về gói tập (`success` hoặc `membershipInvalid`), `REJECTED` hoặc `NO_FACE` → `noMatch`. Tên thành viên phải lấy từ backend theo `member_id`; Face Service không lưu tên.

## `POST /v1/enroll`  (Admin)

Chỉ Admin tại phòng gym, sau khi đã xác minh danh tính và ghi nhận đồng ý xử lý sinh trắc học (BR-FR-01). Service **không** kiểm tra đồng ý; việc đó thuộc quy trình của Admin và backend.

| Trường form | Bắt buộc | Ghi chú |
|---|---|---|
| `member_id` | có | 1–64 ký tự `A-Za-z0-9_-` |
| `frames` | có | 5–15 ảnh, nhiều góc nhẹ |

Mỗi thành viên chỉ một hồ sơ ACTIVE: đăng ký lại thay hồ sơ cũ (BR-FR-02/03). Từ chối nếu khuôn mặt giống thành viên **khác**.

`200 {"member_id": "M001", "samples_used": 8, "members": 12}`

Lỗi: `400 INVALID_MEMBER_ID`, `400 TOO_FEW_FRAMES`, `400 NO_FACE` (ít hơn 3 frame có mặt), `409 DUPLICATE_IDENTITY`, cùng các lỗi ảnh và xác thực như trên.

## `DELETE /v1/members/{member_id}`  (Admin)

Xóa hồ sơ khuôn mặt (quyền xóa dữ liệu). `200 {"member_id": "M001", "removed": true}`, hoặc `404 NOT_FOUND`.

## Chưa nằm trong hợp đồng này

Liveness, đo FAR/FRR, nhật ký audit, TLS, giới hạn tần suất, đồng bộ nhiều kiosk. Thêm ở các đợt sau; đổi hợp đồng phải tăng phiên bản (`/v2`).
