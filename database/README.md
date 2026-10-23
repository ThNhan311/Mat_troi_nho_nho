# Database — Topic 11 FitCenter

PostgreSQL 16 + Flyway migration. Phụ trách: vai trò Database của nhóm.

```
database/
├── docker-compose.yml     # PostgreSQL + Flyway chạy local
├── .env.example           # mẫu biến môi trường (copy thành .env, KHÔNG commit .env)
├── migrations/            # V1..V6: schema (Flyway)
├── seed/demo_data.sql     # dữ liệu demo (không dùng cho production)
├── tests/constraints_test.sql  # kiểm thử constraint ở tầng DB
└── docs/                  # ERD.md (sơ đồ) + DESIGN_NOTES.md (ghi chú thiết kế)
```

## Cách 1 — Docker (khuyên dùng)
Cần cài Docker Desktop. Mở terminal trong thư mục `database/`:

```bash
cp .env.example .env                       # Windows CMD: copy .env.example .env
docker compose up -d                       # chạy PostgreSQL và tự áp dụng migration
docker compose logs flyway                 # xem "Successfully applied 6 migrations"

# nạp dữ liệu demo
docker compose exec -T db psql -U fitcenter -d fitcenter -f /seed/demo_data.sql

# chạy kiểm thử constraint (cuối phải thấy "N / N test PASS")
docker compose exec -T db psql -U fitcenter -d fitcenter -v ON_ERROR_STOP=1 -f /tests/constraints_test.sql

docker compose down -v                     # xóa sạch để làm lại từ đầu
```
Nếu bạn đổi `POSTGRES_USER` / `POSTGRES_DB` trong `.env` thì sửa lại hai tham số `-U` và `-d` cho khớp.

## Cách 2 — Không dùng Docker
Cài PostgreSQL 16 + pgAdmin, tạo database `fitcenter`, mở **Query Tool** và chạy lần lượt
`V1` → `V2` → `V3` → `V4` → `V5` → `V6`, sau đó `seed/demo_data.sql`, cuối cùng `tests/constraints_test.sql`
(kết quả PASS/FAIL nằm ở tab *Messages*).

## Kết nối từ backend (local)
`jdbc:postgresql://localhost:5432/fitcenter` — user/password lấy từ `.env`.
Tài khoản demo (sau khi nạp seed), mật khẩu `Demo@12345`: `admin@fitcenter.local`,
`pt.an@fitcenter.local`, `pt.binh@fitcenter.local`, `member1@fitcenter.local` … `member3@fitcenter.local`.

## Quy tắc làm việc
- Muốn đổi schema: **tạo file migration mới** (`V7__ten_thay_doi.sql`), không sửa file đã merge.
- Không commit `.env`, mật khẩu thật, dữ liệu khuôn mặt, ảnh người dùng.
- Xem `docs/DESIGN_NOTES.md` cho các điểm cần team chốt.
