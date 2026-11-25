# FitCenter Backend

Dùng **JDK21**, Maven Wrapper và PostgreSQL17.12 test riêng. Entrypoint cho người mới: [portable Core setup/demo](../docs/INTEGRATION_SETUP.md), [core-readiness.ps1](scripts/core-readiness.ps1).

Không cần container, ID hay credentials của máy bàn giao. Bootstrap tạo image-pinned container/volume riêng, app role không đặc quyền, secrets DPAPI mới trên máy đích và manifests ngoài Git. Không copy private authority từ worktree cũ.

- Default: canonical [V1–V6](../database/migrations/), `ddl-auto=validate`, activation/initial-membership/renewal/Face gates không bật như release.
- Guarded rehearsal hiện hành: frozen V1–V6,V8–V13, loopback15437/15441, SMTP sink chỉ example.invalid, simulator không tiền thật, Face test adapter không phải nhận diện thật. V7 vẫn quarantine, releaseReady=false.
- Các quickstart từng task là lịch sử và đã ghi commit pin. Dùng portable entrypoint cho checkout hiện hành; không lấy kết quả65/668/1106 tests trong tài liệu cũ làm lượt vừa chạy.
- Cấu hình mẫu: [.env.example](.env.example), chỉ tên biến/giá trị non-secret. Spring không tự load file này. Credentials do runner đưa vào process, không command line/log/Git.

```powershell
# Tại repo root; biến do người vận hành chọn theo máy hiện tại.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/core-readiness.ps1 `
  -Action Provision -JavaHome $jdk -PrivateDirectory $private
```

Các bước Build, Verify, focused/full, PrepareDemo, ServeBackend, Cleanup và Stop ở [hướng dẫn tích hợp](../docs/INTEGRATION_SETUP.md). Full dùng selected scopes rõ và authority baseline riêng, không hardcode ID máy cũ. Không gọi `mvn test` trống biến môi trường là full PostgreSQL regression; các suites opt-in sẽ bị skip.

API contracts: [API documentation](../docs/backend-handover/05_API_DOCUMENTATION.md), [OpenAPI](../docs/backend-handover/api/openapi.yaml). Error envelope, UUID profile khác User ID, UTC/Vietnam DATE semantics và auto-confirm Booking giữ nguyên. Không thêm API/đổi nghiệp vụ trong portable setup.
