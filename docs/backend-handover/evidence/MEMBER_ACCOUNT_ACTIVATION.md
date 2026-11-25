# MEMBER account activation — thực nghiệm23/11/2026

Base M-03 **5399c5707288669997e898740daa36c57d04d632**, branch **feature/member-account-activation**, tested working tree trước commit. [Quyết định/contract](../decisions/2026-11-23_MEMBER_ACCOUNT_ACTIVATION.md), [quickstart](../19_MEMBER_ACCOUNT_ACTIVATION_QUICKSTART.md), [OpenAPI](../api/openapi.yaml).

## Kết quả thực chạy

| Tầng | Passed | Failed/errors/skipped | Ghi chú |
|---|---:|---|---|
| Backend scoped full/JDK21 |914|0/0/0|Maven hoàn tất2026-11-23T08:55:25Z |
| Focused Backend |159|0/0/0|Tập con full, không cộng |
| Member Flutter client/widget |60|0/0/0|Focused activation7 tập con |
| PT Flutter regression |55|0/0/0|PT Dart không đổi, tests thực sự rerun |
| Chrome UI checks |15|0/0/0|Admin→M03→Member OTP/password→login→M04/relogin |
| HTTP riêng trong UI harness |5|0/0/0|NoJWT trướcACTIVE, SMTP thật, role/grant isolation/replay |
| DB checks của UI |3|0/0/0|User state/audit và snapshot nghiệp vụ |
| Cleanup checks |18|0/0/0|6 DB own, repeat đạt; không cộng hai lượt |

Backend gồm Member unit23, PT unit23, Member guard7, **Member24/PT23 real HTTP+PG+SMTP**, integratedM0354, schema5, và baseline Booking/D01/account/auth/policy/plan. Ba lớp PG profile riêng cũ PtActivationPostgresTest/ActivationSchemaRehearsalTest/InitialMembershipPostgresTest **không được chọn**, thay bằng integrated contracts; không gọi chúng là pass hoặc cộng trùng với các lớp thay thế. [Fresh JUnit summary](MEMBER_ACCOUNT_TEST_RESULTS.json), không xuất raw logs/XML/system-out.

Member analyze --no-fatal-infos exit0,0error/0warning/**58info** Material/style, không strict lint clean. Member và Admin JS Web build thành công với API_BASE_URL localhost18084, không dependency/SDK constraint upgrade. Admin Dart không đổi nên không rerun Admin tests; build chỉ đổi target demo. PT55 là actual Flutter rerun trong task này, không lấy số cũ. JDK21.0.13+9; không đổi production Clock.

## HTTP/PG/SMTP và concurrency

- Admin-created marker + role/profile/status kiểm bên trong User→role-state locks; Member không cần Membership. Unknown/other-role/legacy email generic202 không mail; suspended/completed không tái kích hoạt; Admin activationPending không quảng bá reactivation sau completed rồi disabled.
- OTP300s,299/300/301 boundaries;5wrong attempts commit qua nhiều HTTP transactions,6th đúng cũng429; resend59/60 và5sends/window1h, grant cũ bị revoke, OTP/grant một lần và grantexpiry300. Password8codepoints/72UTF8bytes; không normalJWT trướcACTIVE, hoàn tất không tự login.
- MEMBER challenge/grant dùng PT endpoints và ngược lại bị400, challenge đúng còn dùng được ở role gốc. DB compositeFK/check không nhận rolePT ở bảngMember; counter/phase/grant unique constraints enforced.
- SMTP actual socket loopback/addresses tổng hợp, digest BCrypt/SHA256, không clear OTP/grant/password persisted/logged. SMTP failure rollback challenge; fault triggers verify/password rollback User/grant/audit. Repeat completion không đổi completedAt/audit.
- Races dùng user lock ngoài transaction, barrier/latch và pg_stat_activity xác nhận lock waits trước unlock: verify/verify, password/password, first-send/send, wrong-attempt counters, password/resend; request đến trước nhưng lấy lock sau expiry bị từ chối. Member activation và M03 cấp Membership tranh đồng thời: cả hai commit một lần, không deadlock, không sửa Booking/plan.
- Migration empty và history1–6,8,9→10: snapshot legacyPT activation state +6payments nhiều trạng thái/NULL link +M03 service-written receipt và payment periods giữ nguyên. V10 chỉ tạo bảngMember. V7 resolver/order validation bị từ chối khi đến muộn, không chạy SQLV7; nooutOfOrder/history edit/clean/repair.

Container **597f29e3297204351b3c81f1ac63eed4ccd8e37e267ee66cbe4bf4ba37cf2cbe**, volume **fitcenter_account_20261123_data**, role **fitcenter_account_app** không admin, loopback**15441**. Full nonce**5f7e8316c64b**, DB fitcenter_account_5f7e8316c64b_(empty|history)_test, history**1,2,3,4,5,6,8,9,10**. Guard container/volume/port/role/tênDB trước Flyway, profile riêng đúng4locations. Không compose/tắt guard cũ để ép chạy chung. History này chưa là release canonical.

## E2E thật đạt đủ5 bước người dùng giao

Chrome installed headless, viewport1024×768, timezoneAmerica/Los_Angeles. Chỉ **Admin + plan30ngày/100000** được seed với BCrypt; Member không seed ACTIVE, không seed Member/Membership. Admin tạo Member thật bằng UI/POST201 DISABLED có audit source; tiếp tục cấp Membership bằng M03 UI/POST201, User vẫn DISABLED. Member vào entry activation trên Login gốc, OTP từ protected SMTP sink11035/control11036 trong memory, verify→password→ACTIVE200 không JWT. Login password thật→M04→reload/login lại cùng UUID.

User UUID **7b9af45f-1a76-492c-addb-e86b32cae9cc**, Member profile UUID **fe3174ea-dd38-4f3b-8aca-a0a0377fb466**, khác nhau. Membership UUID **64326091-4bf5-40b7-9911-672bb1883ed2**, payment UUID **1ff70193-d9ae-4532-8b11-933c5aa0e54f**, COUNTER SUCCESS amount**100000**, dates**2026-11-23→2026-12-22**. Đây là dữ liệu tổng hợp đã cleanup, không credential.

Snapshot toàn bộ public rows trước activation (loại targetUser) so sau activation (chỉ loại thêm target state và đúng1audit mới) bằng nhau: **Membership/payment/receipt/Booking/plan/PT cũ không đổi**. User ACTIVE, completed_at có, OTP/grant digest null. Chỉ sau đó login nhận roleMEMBER và M04 đọc đúng Membership/date, reload mất memorysession và login lại thành công.

[Structured UI/HTTP/DB result + exact hashes tại UI](MEMBER_ACCOUNT_UI_RESULTS.json). [Final37 source/test/helper hashes](MEMBER_ACCOUNT_SOURCE_HASHES.json). Chỉ cleanup helper bổ sung đọc manifestdemo riêng sau khi UI đã bắt đầu; helper này không đổi UI/app, được execute và repeat riêng. Java/Dart application/test source không đổi sau lượt914/60; không lặp full chỉ để commit/docs.

Ảnh cùng viewport, đã review không email/OTP/password/token:

- [Admin cấp Membership trước account activation](member-account-activation/admin-membership-before-account-activation.png).
- [Member form email trống](member-account-activation/member-activation-email-empty.png).
- [OTP prompt trống](member-account-activation/member-otp-prompt-empty.png).
- [Password form sau verify, fields trống](member-account-activation/member-password-form-empty.png).
- [Account ACTIVE từ server](member-account-activation/member-account-active.png).
- [M04 sau OTP](member-account-activation/member-m04-after-otp.png).
- [M04 sau reload/login](member-account-activation/member-m04-relogin.png).

## Failures và recovery đã xử lý

Focused đầu153 có18failed do copied-test expectation đổi nhầm ERR_ACTIVATION/ERR_MEMBERSHIP/audit literal khi rename environment prefix, không đổi contract để làm test pass. Sửa expectations và thêm schema/race; focused159/full914 cuối đạt. Member Flutter test import ban đầu dùng sai tên package (Member gốc tênfitcenter), đã sửa,60tests/analyze/build đạt.

Sau môi trường phiên đổi, private directory sandbox cũ biến mất; source/build/JUnit reports còn. Xác minh đúngfullID/label/image/volume/port, role/zero app sessions và synthetic namespaces; phục hồi sealed UUIDregistry trước seed mới, rotate chỉ credential app test, không sửa rows/history. Không reset DB hoặc đổi guard. Playwright phục hồi offline ngoàiGit; sửa BOM JSON/Java helper và dùng npm.cmd doExecutionPolicy. Các bước tool lỗi trước UI mutation không coi là pass.

UI helper đã sửa selector AppBar y<40, tênHome là accessible label chứa subtitle, dropdown aria-label thay vì hasText, checkbox label có subtitle. Các account đã tạo ở lượt lỗi đều cleanup exactUUID/audit trước lượt mới, không replay POST mù hoặc seed ACTIVE để né OTP. Lượt cuối15/5/3 source-bound đạt. Không đưa ảnh debug/raw logs/credentials vàoGit.

## Cleanup / Git / giới hạn

[Cleanup+stop](MEMBER_ACCOUNT_CLEANUP_RESULTS.json):6DB own/18checks, repeat idempotent. Chỉ DELETE từng UUID từ base/test/demo/recovered registries, no broad delete/TRUNCATE/DROP; snapshot nonfixture rows giữ nguyên. Dừng ownbackend/web/mail/DB, ports3000/3002/18084/11035/11036/15441 đóng, giữ volume. Không đụng notification_service_app/food_booking_db hoặcDBchung.

Default Member/PT/M03 gates vẫn false/503, không mail người thật/production rollout. Cần Duy đồng bộ V7/V8/V9/V10 và backfill giữ periods trước release; không coi historyrehearsal là release. Không renewal/gateway/Face/Workout hoặc reset password. Bốn researchuntracked22/11 vàFace giữ riêng; stage chính xác task, review secret/hash rồicommit/push nhánh riêng, không merge/force. SHA commit cuối đối chiếu local/remote trong bàn giao.

Remote review23/11: database558fb03 không đổi, target feature/member-account-activation chưa có trước publish, GitHub0workflow/0run/0deployment/0webhook, không có CI pass để suy diễn.
