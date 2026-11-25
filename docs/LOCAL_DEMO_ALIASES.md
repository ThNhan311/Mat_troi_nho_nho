# Alias dễ nhập cho fixture demo local

Chỉ đổi email của **năm tài khoản tổng hợp ACTIVE đã có** trong một scope Core demo riêng. Không tạo tài khoản, không thay password hash, UUID/profile, Membership, payment, slot hoặc booking. Đây là thao tác bảo trì fixture qua JDBC, không phải API quản lý tài khoản hoặc bằng chứng chạy lại activation.

| Nhãn trong manifest private | Email sau đổi |
|---|---|
| Admin | `admin@example.test` |
| Member A | `membera@example.test` |
| Member B | `memberb@example.test` |
| PT A | `pta@example.test` |
| PT B | `ptb@example.test` |

`@example` bị form login gốc từ chối vì thiếu dấu chấm; `@example.test` dùng được mà không sửa validation hoặc build lại Flutter. Mật khẩu demo do người vận hành chọn được giữ trong file bàn giao private, không hardcode vào source hoặc tài liệu. Helper này giữ nguyên BCrypt đã có.

## Chạy trên fixture đã xác minh

Hoàn thành [setup Core](INTEGRATION_SETUP.md) trước. Helper yêu cầu `manual-accounts.private.json` (array năm account gồm label/role/email/password và userId/profileId của Member/PT), `core-ui-registry.json` (run/created exact UUID), `demo-fixture.properties` của Admin seed, `current-run.json`, `account-resource.json` và `app.dpapi` đúng scope. Đây là registry private của phiên manual demo; helper không tự dựng manifest hoặc đoán tài khoản theo tên. Không chạy trên fixture historical đã cleanup/seal, DB chung hoặc production.

```powershell
# Các biến lấy từ authority/build của chính máy và phiên demo hiện tại.
# $demo / $handoff nằm ngoài mọi Git checkout, dưới LOCALAPPDATA/Temp.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/Set-LocalDemoAliases.ps1 `
  -DemoDirectory $demo -ExpectedContainerId $id -JavaHome $jdk `
  -BackendDirectory $builtBackend -ClasspathFile $classpath -HandoffFile $handoff
```

`$builtBackend` là thư mục Backend đã build bằng JDK21; `$classpath` là file dependency classpath do runner tạo. Helper có thể ở checkout mới trong khi các process demo vẫn dùng build main đã kiểm chứng. Không thay PATH/ExecutionPolicy hệ thống.

Guard kiểm context Docker, full container ID, image, named volume, scope, loopback15441, run/database, nonprivileged app role và exact history1–6,8–13 trước khi đổi. Không chạy Flyway/DDL. Preflight kiểm từng account với Admin seed và created UUID/profile/role; collision hoặc thay đổi identity/status bị từ chối. Transaction REPEATABLE_READ khóa User theo UUID tăng dần; snapshot toàn bộ bảng bảo đảm chỉ email/updated_at của user được đổi, giữ cả password hash. Các thao tác nghiệp vụ không được gọi trong transaction này.

Checkpoint private `alias-change-<random>/` chứa bản sao manifest/handoff trước SQL, request mapping và dấu `database-committed.txt`. DB commit không bao phủ filesystem: nếu bị ngắt sau commit, đối chiếu đúng UUID và checkpoint rồi hoàn tất cập nhật file private; không tạo account mới hoặc copy mù dữ liệu cũ ngược lên DB. Sau thành công, helper cập nhật account manifest, created ledger, Admin fixture và handoff; kiểm login HTTP cho đủ năm role. Intent emails ban đầu giữ nguyên; cleanup vẫn dựa trên created UUID/profile đã đăng ký. Handoff ngoài Git không được static web server phục vụ.

Đăng xuất/đăng nhập lại ở cả ba app sau đổi vì session cũ có claim email cũ. Reload sẽ xóa session memory. Dịch vụ demo được giữ chạy để người dùng thử.

**Giới hạn mail:** sink hiện chỉ nhận địa chỉ tổng hợp `@example.invalid`. Alias `@example.test` ở đây chỉ phục vụ login của account đã ACTIVE; không mở luồng OTP cho alias hoặc gửi mail thật. Account mới thử OTP vẫn dùng `@example.invalid`. Face admission tiếp tục tắt, simulator chỉ dev/test. Chưa xác minh nâng cấp DB cũ (`targetUpgradeVerified=false`).

[Evidence kiểm tra alias](backend-handover/evidence/LOCAL_DEMO_ALIASES.md).