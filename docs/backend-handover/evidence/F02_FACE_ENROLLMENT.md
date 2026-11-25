# F02 — Enrollment lifecycle evidence24/11/2026

Branch feature/face-enrollment; tested base **c3eb411cfbb6cfdfdfdc441d850d2eea456f7b46 + working tree**. [Source hashes](F02_SOURCE_HASHES.json), [structured results](F02_RESULTS.json), [contract/limits](../decisions/2026-11-24_F02_FACE_ENROLLMENT.md), [rerun](../23_FACE_ENROLLMENT_QUICKSTART.md). Không dùng F01 lịch sử như lượt vừa chạy.

| Thực chạy | Passed | Failed/errors | Skipped | Phạm vi |
|---|---:|---:|---:|---|
| Backend selected full |1076|0/0|0|41XML suites tươi, JDK21/UTC/PostgreSQL17.12|
| Focused cuối trước hai case bổ sung |30|0/0|0|Tập con full; full có25PG+8unit F02|
| Admin client/widget toàn app |133|0|0|23tests F02,110tests cũ; không cộng focused|
| Python selected F01 protocol |49|0|0|27addon+22source Face state/auth pin; không hardware/model|
| Real Admin Web |10checks|0|0|Chrome1024×768, timezone máy America/Los_Angeles, hiển thị VN|
| Direct HTTP orchestration |10checks|0|0|Ngoài các response UI quan sát; không phải tổng mọi network request|
| PostgreSQL E2E |6checks|0|0|Mapping/old rejection/consent/history/nonbusiness mutation|
| Cleanup/repeat |92checks/44DB|0|—|Cả hai chạy thành công trước stop, nonfixture rows giữ nguyên|

Flutter analyze exit0 với `--no-fatal-infos`,109info/0error/0warning; analyze mặc định ban đầu exit1 vì info, không che thành zero issues. Web JS build/package JAR thành công. Member/PT Dart không đổi, không chạy Flutter của chúng. Backend selector *Test trừ3PG profiles cũ, integrated replacements chạy; FitcenterApplicationTests không match selector. Tổng XML filesystem có4report cũ **không được tính**; chỉ41file tạo sau full start1076.

## Cases và failure đã sửa

[HTTP/PG tests](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/EnrollmentPostgresTest.java) chạy25cases: empty/history migration; Member UUID khác User; no-profile-before-ready; consent/strict input; RBAC/disabled account; actor bị khóa trong lúc request chờ Member lock; sai Member/operation/profile; duplicate pending/idempotency; prepare FAILED giữ oldACTIVE; adapter wrongMember binding FAILED/compensated; successful replacement; revoke+external remove fail/retry không đổi metadata; old capture và same-request replay bị chặn; parallel starts/samekey/complete; revoke khi external prepare đang chờ; DBrollback sau READY giữ PENDING/oldACTIVE và recovery sameoperation; pending revoke/tombstone chống late prepare; legacy reference collision không xóa gallery của Member khác.

Concurrency thực có barrier/latch/Member lock và chờ pg_stat_activity xác nhận request cùng tranh khóa, không chỉ gọi tuần tự. Trigger lỗi tổng hợp được tạo/gỡ trong DB riêng; không SQL/stack trace qua HTTP. [Unit](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/enrollment/EnrollmentUnitTest.java)8tests strict payload/default gate. F01 default/40HTTP/unit và Account/PT/Member activation/M03/M04/renewal/Booking/D01 được hồi quy trong selected full.

Failure thực trước cuối: Java test `var a,b` compile bị từ chối, tách declaration; một assertion disabled JWT nhầm403 trong khi convention401, sửa assertion và thêm service recheck403 sau wait; widget lazy ListView chưa dựng FAILED ở ngoài viewport, sửa test cuộn đến phần tử. Review cuối sửa thời điểm record đối chiếu khi revoke đã hoàn tất bằng key mới, không retcon profile/audit; thêm test và chạy lại full/UI cho Java cuối. Lượt cuối0failure. Không có test recognition/biometric duplicate/liveness thật; duplicate enrollment trong F02 là operation/race, không phải xác thực cùng người.

## UI/DB thật, adapter mô phỏng

[UI harness](../../../frontend/verify-face-enrollment.mjs) dùng synthetic Admin/2ACTIVE Member accounts seed riêng, không seed FacialProfile. Plan/Membership quầy cấp qua API để có paid coverage, không chứng minh activation account hoặc enrollment camera. Admin UI gốc login/Home/menu → chọn Member → xác minh/at-gym/consent → start PENDING → complete ACTIVE chỉ sau server READY. Journal ngoài DB chỉ synthetic UUID, không ảnh/embedding.

[ACTIVE](f02-enrollment/admin-active.png), [FAILED giữ ACTIVE cũ](f02-enrollment/admin-failed-keeps-active.png), [REVOKED](f02-enrollment/admin-revoked.png), cùng viewport1024×768. Đã xem ảnh, không credential/ảnh người thật. Theme/navigation gốc giữ nguyên; không dashboard thay thế. UI hiển thị rõ chế độ kiểm thử/mẫu mô phỏng.

E2E tạo3operations: firstACTIVE, re-enrollFAILED, replacementACTIVE; hai profile cuốiREVOKED. Core identity mapping từ capture private tới reference→FacialProfile→members.id, paid eligibility đúng. Old capture/request không cấp quyền sau replacement/revoke. Reload yêu cầu login rồi đọc lại cùng UUID/status từ DB. Member JWT không đọc Admin API. Snapshot User/Member/Membership/paid periods/payment/receipt/activation/Booking/slot giữ nguyên qua enrollment; audit mới FACIAL_PROFILE. [Readback](F02_RESULTS.json) chứa UUID tổng hợp và actor/consent/mode, không secret.

## Schema, preservation và cleanup

V13 additive riêng đã áp DB empty và lịch sử tổng hợp trên15441. Candidate1–6,8–13/12scripts đúng SHA/CRC; V1–V12 nguyên bytes. V13 thêm lifecycle/idempotency/consent/mapping/cleanup tables và owner index, không backfill/drop legacy hoặc applyV7. Preexisting snapshot mọi row trước/sau V13 bằng nhau; history có legacy payments/periods, M03receipt/audit/snapshots, activation state và V3facial/Attendance. V12 request ledger ở upgrade fixture còn trống; các ledger/replay F01 mới được kiểm sau schema13, không giả là đã migrate một shared DB có ledger lịch sử.

28runtime/source/test/helper hashes cuối được đối chiếu. Java/Dart executable/test source không đổi từ full/build; cleanup helper sửa PK projection trước khi thực chạy92checks +repeat. Face ref fcabeba và database558fb03 không đổi sau fetch;26untracked Face caches/model nguyên hash, venv chỉ đọc/cache off. Bốn research22/11 giữ ngoài commit.

44DB do task đăng ký,20DB chưa dùng được xác nhận0publictables;24DB có schema được cleanup exactUUID (3checks mỗiDB), tổng62. Cleanup lặp đạt trước stop; schema/history/volume giữ lại. Own Backend JVM/wrapper/Adminweb (hai lượt,6process) và DB container dừng;18086/3002/15441 đóng. Không thay DB chung/production/default gates, không raw logs/config/credential/SDK/build/journal private vào Git.

## Giới hạn / F03

**Core enrollment lifecycle đạt trên simulated adapter; enrollment Face thật chưa đạt.** Chưa camera/recognition/liveness/threshold calibration, không thu biometric người thật. Chưa production consent notice/retention/deletion SLA hoặc gallery orphan operator/worker; external cleanup có thể PENDING/MANUAL_REQUIRED. Service hiện có cần operation/generation/staging/status/finalize/abort và predecessor-aware duplicate contract; mapping/enrollment/attestation phải server-authenticated. Không coi NOT_PERFORMED là liveness passed.

releaseReady=false: shared history inventory chưa biết, V7 destructive chưa backfill; đồng bộ V8–V13 trước merge/release, không out-of-order/history edits/clean/repair/renumber. Không merge hoặc mở default trong F02.

Remote review04:04UTC:0workflows/runs/deployments/webhooks; không gọi CI passed. Nhánh publish riêng sau review, không merge/force.
