# M-05/M-06 — evidence renewal và simulator

Kiểm thử thực chạy23/11/2026; review/đóng24/11. Branch `feature/membership-renewal-simulator`, tested base/HEAD `d2774c9b860e7d263b26edac1003502da8781790` + working tree task. Commit đóng tra Git history, không self-reference SHA trong file. Không dùng kết quả I01 làm kết quả lượt này.

[JSON kết quả/suites/read-back/migration](M05_M06_RESULTS.json), [40 hashes executable/packaging và build/JAR](M05_M06_SOURCE_HASHES.json), [contract/quyết định](../decisions/2026-11-23_M05_M06_RENEWAL_SIMULATOR.md), [chạy lại](../21_RENEWAL_SIMULATOR_QUICKSTART.md). Thành công E2E đã đối chiếu **236** source hashes với working tree cuối,0mismatch; Java source không đổi từ full regression. Hash là raw bytes tại test, Git có thể normalize EOL cho source ngoài SQL; V1–V11 SQL được pin EOL và manifest. Docs sau kiểm thử không thay executable.

## Kết quả được chọn

| Lượt | Passed | Failed/errors | Skipped | Phạm vi |
|---|---:|---:|---:|---|
| Scoped full Backend | 989 | 0/0 | 0 | 36XML suites tươi, JDK21/UTC, PostgreSQL17.12 |
| Focused cuối | 71 | 0/0 | 0 | RenewalDates10, RenewalRequest15, RenewalPostgres46; là tập con full |
| Flutter Member | 80 | 0 | 0 | Toàn bộ client/widget trong app, kể cả Booking/M04/activation |
| Flutter Admin | 110 | 0 | 0 | Toàn bộ client/widget trong app, M01/M03/account/policy/simulator |
| Flutter analyze | 2apps đạt | 0errors/0warnings mỗiapp | — | --no-fatal-infos; mỗiapp85infos, gồm style/braces và material.dart deprecated, không gọi zero-lint |
| Web build | 2apps đạt | 0 | — | Flutter3.50.1/Dart3.14, cùng API18084 |
| Chrome UI checks | 29 | 0 | 0 | UI thật ở dưới, không cộng vào unit tests |
| HTTP checks trong E2E | 18 | 0 | 0 | Cùng backend/DB/mail với UI; tách khỏi 989tests |
| DB checks trong E2E | 10 | 0 | 0 | UUID/state/period/receipt/read-back, không cộng tests |
| Cleanup | 54checks/22DB | 0 | — | ExactUUID, nonfixture preserved, lặp lại đạt |

Full selector `*Test,!PtActivationPostgresTest,!ActivationSchemaRehearsalTest,!InitialMembershipPostgresTest`. Ba lớp PG profile cũ **không chọn**, đã có integrated Account/PT/Member/M03 counterparts trong suite được chọn; không ghi các lớp bị loại là skipped0 đã chạy. Booking/D01 HTTP baseline15437, integrated account15441 pair riêng, renewal15441 pair riêng. UI chỉ một backend18084/một DB15441 và SMTP11035/control11036. PT Dart không đổi nên không chạy lại Flutter PT; Backend PT/activation regression vẫn chạy trong989. Không gọi đây là E2E toàn bộ FitCenter.

## Traceability

| Yêu cầu | Bằng chứng |
|---|---|
| Early/expired/inclusive/VN midnight/leap/year/date overflow | [RenewalDatesTest](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/renewal/RenewalDatesTest.java), HTTP expiry/retry/Clock-after-lock |
| Strict UUID/owner/role/account, unknown/null/type/decimal | [RenewalRequestTest](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/renewal/RenewalRequestTest.java), [RenewalPostgresTest](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/RenewalPostgresTest.java) |
| Snapshot giá/duration/name, inactive plan after quote, giá0 | HTTP quote/settle + UI zero-price; current plan không bị next plan ghi đè |
| Key same/different payload, owner/global-key isolation | HTTP, same-key contention và frontend retained-key/no-auto-replay tests |
| Hai independent SUCCESS và duplicate SUCCESS cạnh tranh | HTTP requests cùng blocked trên Member lock, chờ pg_stat_activity xác nhận rồi nhả; một payment/period mỗi yêu cầu |
| FAILED/CANCELLED, reordered/mismatched/reference/currency | HTTP trace + SUCCESS không downgrade; UI từng terminal |
| SUSPENDED/CANCELLED khi initiate hoặc sau thu tiền | HTTP RECONCILIATION_REQUIRED; status/coverage không được tự mở |
| Rollback | Trigger tổng hợp chặn event insert: payment về PENDING, không period/event/claim/audit hoặc đổi Membership |
| History preservation | [RenewalIntegrationDatabase](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/RenewalIntegrationDatabase.java): V1–V10 snapshots trước/sau V11 bằng nhau;6legacy payments/status/period, receipt và activation states giữ nguyên |
| M03/M04/Booking/D01 | Full selected regressions; renewal tests check gap không được nối bằng unpaid days, current/last-paid plan đúng; không thêm start marker |
| Frontend | [Member tests](../../../frontend/fitcenter_member/test/renewal_test.dart), [Admin tests](../../../frontend/fitcenter_ad/test/renewal_test.dart): malformed DTO, PENDING/SUCCESS/recon, loading/empty/error,409, network/no replay, retained keys, logout/stale response |

## UI + HTTP + PostgreSQL thật

[Harness](../../../frontend/verify-renewal-integration.mjs), Chrome1024×768, browser timezoneAmerica/Los_Angeles. Admin seed duy nhất bằng BCrypt; plans, DISABLED Member và M03 counter Membership/payment được tạo bằng HTTP thật. Member activate email→SMTP→OTP→password→ACTIVE qua UI gốc; không seed ACTIVE Member để giả activation. Initial plan2ngày/123456.78VND và renewal3ngày/0VND là dữ liệu tổng hợp riêng.

1. Member login→Membership gốc→Gia hạn/kỳ sử dụng→POST201 PENDING/NOT_APPLIED, DB expiry và số kỳ chưa đổi. [Ảnh PENDING](renewal-integration/member-pending.png).
2. Admin login/Home gốc→Thanh toán mô phỏng→xác nhận SUCCESS; response200/APPLIED. [Ảnh Admin](renewal-integration/admin-success.png). DB cùng Membership UUID, payment SUCCESS, đúng một period mới, memberships.plan_id vẫn initial.
3. Member reload/login→đọc server CURRENT(initial23–24/11) và NEXT(renewal25–27/11), cùng UUID/giá0/ngày VN. [Ảnh current/next](renewal-integration/member-current-next.png).
4. Hai thao tác mới rõ ràng tạo hai quote riêng; Admin UI FAILED/CANCELLED, Member login lại đọc đúng trạng thái server; DB dates và2paidperiods không đổi.
5. HTTP replay đúng event không thêm period hoặc audit; late FAILED409 không downgrade SUCCESS. Member khác không đọc payment/period, Member không được gọi Admin result.
6. M03 payment/receipt JSON trước/sau giữ nguyên, Booking không mutation. [Ảnh login lại](renewal-integration/member-reloaded-history.png), [activation thật](renewal-integration/member-activation-active.png).

Raw credentials/OTP/grant/token/private manifests/logs/build/SDK ở ngoài Git; evidence chỉ synthetic UUID/value/sanitized summaries. Ảnh đã xem trực tiếp, không có field credential/OTP. UI dùng dates thật, không Clock override/đổi DB để giả completion tương lai. Các current/next/history boundary và expired được test Clock/HTTP; UI thật này là **early renewal**, không tuyên bố đã chờ ngày kết thúc kỳ.

## Lỗi phát hiện và đã sửa

Focused đầu61 có2failed do so thứ tự JSON keys và mong403 thay vì JWT filter401 cho account khóa; sửa kỳ vọng, sau đó67và cuối71/989đạt. New Flutter fixture generator từng thay nhầm APPLIED khi thay tên package; sửa fixture, cuối80/110đạt. Hai UI attempts đầu fail selector Dropdown (option/text thay vì menuitem của Flutter); chưa gửi renewal quote, đã cleanup/archive riêng và chạy lại toàn bộ pair mới đạt29/18/10, không lấy ảnh attempt cũ làm evidence cuối.

Cleanup Windows ENAMETOOLONG được sửa bằng SQL stdin. Lượt repeat từng bị dừng DB quá sớm; đã mở lại đúng container, chạy repeat54checks xong rồi stop. Không failure còn mở hoặc dữ liệu ngoài fixture bị đổi. OpenAPI được parse/resolve internal refs sau cập nhật; không lặp full chỉ vì docs.

## Cleanup, Git và release

Cleanup22DB thuộc11pairs trong task manifest,54checks, lặp lại đạt; các pair account chưa migrate trong focused được xác minh0publictables. Seal UUID trước DELETE; rows ngoài ledger giữ nguyên, không truncate/drop/reset/clean. Dừng own JVM/wrapper/Member/Admin/mail và exact rehearsal DB; baseline15437 đã dừng, volumes còn. Ports18084/3000/3002/11035/11036/15441 đóng khi bàn giao. Không DB chung/Face/Docker Desktop/tài nguyên đồng đội bị thay.

Remote fetch database ref vẫn558fb03. REST raw JSON xác nhận0workflows/0runs/0deployments/0hooks; không gọi CI passed. Commit/push feature riêng sau review; không merge/force. Bốn research untracked giữ ngoài phạm vi, Face và survey tại checkout gốc nguyên vẹn.

**releaseReady=false**. V11 rehearsal additive đã chạy empty/history; V7 destructive chưa áp, chưa có shared DB history/inventory và mapping/backfill thống nhất V7–V11 với Duy. LEGACY_AGGREGATE ghi unknown snapshot rõ, không bịa lịch sử tiền/gói. Cần đối soát dữ liệu thiếu provenance trước rollout; chưa gateway/refund/manual reconciliation UI/production mail. Simulator default-off, chỉ test/dev được guard.
