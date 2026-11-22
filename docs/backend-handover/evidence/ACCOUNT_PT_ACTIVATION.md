# Admin account / PT first activation — evidence22/11/2026

Worktree Mat_troi_nho_nho-booking-integration; branch **feature/admin-account-pt-activation**, HEAD1b1e323ff8ac0f947b3145b6544bac81339931ba. Source working tree, chưa stage/commit. [Checks máy đọc](ACCOUNT_PT_ACTIVATION_CHECKS.json), [SHA256 source](ACCOUNT_PT_ACTIVATION_HASHES.json), [contract/quyết định](../decisions/2026-11-22_ACCOUNT_PT_ACTIVATION.md), [status](../../PROJECT_STATUS.md). Không dùng evidence lịch sử như lượt vừa chạy.

## Khởi điểm và scope

Repo gốc feature/backend-service-eligibility089b5e2 có Face untracked, được giữ nguyên. Worktree tích hợp bắt đầu feature/admin-membership-plan-create1b1e323 với25file M-01 và4research chưa commit; tạo nhánh account từ đúngHEAD, không reset/stash/merge. Không có implementation account/OTP trước task. Fetch ref database thành công, origin/feature/database-schema vẫn558fb03fd5927ca9e04d17b54fd46e429fe62bb5; canonical V1–V6, V7 ở nhánh Duy chưa áp.

Admin GET/POST Members/PT mới, User+profile+audit transaction; nguyên statusDISABLED/BCryptplaceholder, UI AccountPage gốc dùng API thật. PT core OTP/grant/password, JDBC/lock/schema guard, test SMTP và UI đã chuẩn bị; activation defaultfalse/503 vì schema chưa thống nhất. Không schema/migration/resource production thay đổi. 11/12 executable hashes M-01 và4research khớp; Admin Home là file M-01 duy nhất đổi để route AccountsPage. Code/test/helper mới/đổi được liệt kê chính xác trong hashes; docs/shared API bổ sung không xóa báo cáo cũ. Không Membership/Payment/Face/Workout.

## Tests thực chạy (không cộng focused vào full)

| Nhóm | Passed | Failed/errors | Skipped | Bằng chứng/phạm vi |
|---|---:|---:|---:|---|
| Backend full regression | **762** | 0/0 | 0 | Surefire toàn suite, JDK21+PostgreSQL test guard |
| Backend focused | 475 | 0/0 | 0 | Tập con:433HTTP hiện có+16accountHTTP+23OTPunit+3SMTPunit |
| Admin Flutter full | **73** | 0 | 0 | 63retained+10account client/widget |
| PT Flutter full, sau sửa CORS | **55** | 0 | 0 | 48retained+7activation client/widget |
| Admin/PT focused | 10/7 | 0 | 0 | Đã nằm trong full, không cộng |

Backend full đã bao gồm16AccountHttpTest dùng HTTP thật và PostgreSQL: ADMIN Member/PT201, User/Profile khácUUID/DISABLED/audit/BCrypt và GET; noJWT login401;401/403/lockedAdmin; strictinput/massassignment/text; emailunique409case insensitive; rollback User/profile/audit; hai request chung barrier chỉ1success; OTPgate503 không query/tạo bảng. OTP23 unit kiểm digest/expiry300s/equality/attempt/resend limits/one-use/grant/password/legacy/role/Clock sau khóa; store mock nên không chứng minh transaction/race thật. SMTP3 unit gồm **1SMTP delivery thật vào sink loopback**, recipient tổng hợp, body/OTP chỉ memory;2tests chặn recipient thật và controlled mail failure. Không gửi email người thật.

JDKTemurin21.0.13+9; defaultprofile/UTC; guarded container e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0, labelbaseline-20261120, Dockerdesktop-linux localnamedpipe, volumefitcenter_baseline_20261120_data, loopback15437, DBfitcenter_baseline_20261120_test, rolefitcenter_baseline_app không quyền admin, history1–6. Guard xác minh trước Flyway, khôngalignment/V7/onboarding. Fullreport SHA256/summary trongCHECKS, raw logs/XML/manifest ngoài Git hoặc ignored.

Flutter3.50.1/Dart3.14.0: Admin/PT **Web JavaScript build exit0**, packageBackend exit0. AnalyzerAdmin44info/PT59info,0error/0warning với `--no-fatal-infos`; lần PT analyze mặc định exit1 vìinfo được ghi nhận, không gọi đó là pass. Không hạ SDK/constraints hoặc nâng hàng loạt dependency. Web build có Wasm dry-run warnings của source cũ; không nghiệm thu Wasm/native. Member không sửa/chạy lại trong task này (37 là lịch sử, không cộng).

## Chrome UI thật và DB

Final runner `verify-account-ui.mjs`: **16 UI checks passed,0failed/skipped**, **1 HTTP check riêng** cho DISABLED login401/noJWT. Chromeheadless1024×768, timezoneAmerica/Los_Angeles; Adminlocalhost3002/PT3001/Backend127.0.0.1:18081, CORS chỉ3000/3001/3002. Flow: loginAdmin thật→Home→Hội viên&PT→GETlist→PTsegmented→form gốc→1POST201→reload/logout/login→GET đúngUUID/profile/status/pending→logout; PTlogin gốc→activationemail→503ERR_ACTIVATION_NOT_READY→UI chưa sẵn sàng, khôngOTP/passwordform/fake success→vềlogin. Không OTP gửi thật từ API đang gate.

Account cuối do UI tạo: **User53a03cc9-0078-4e3a-a1e9-a3b706929958**, **PTprofilecd39ced7-9c9f-4447-905b-d66d166d72ce**, DISABLED, fullName tổng hợp. ADMIN/2MEMBER/2PT/baseplan/memberships do seed riêng, không tuyên bố tạo qua UI. **DBprepare2/audit3 assertions**, cùng UUID/body/role/BCryptpresence/auditAdmin; snapshot ngoài account không đổi (membership/payment/booking/slot/plan). Đây không phải số tests Maven và không cộng với UI/HTTP. Không có membership activation.

| Ảnh1024×768 đã xem | Nội dung |
|---|---|
| [List thật](account-pt-activation/admin-account-list.png) | Segmented/filter/card/theme gốc, dữ liệu tổng hợp từ DB |
| [Modal tạo](account-pt-activation/admin-create-account.png) | Chỉ họ tên/email/role, không password/membership |
| [Sau201](account-pt-activation/admin-created-inactive-account.png) | Chưa kích hoạt, UUID User/Profile thật |
| [Sau reload/login](account-pt-activation/admin-persisted-account.png) | Cùng account từ GET, không localmock |
| [PT gate503](account-pt-activation/pt-activation-schema-blocked.png) | Không giả đã gửi OTP/kích hoạt |

Ảnh không password/token/OTP/người thật/Face; có email tổng hợp@example.invalid vàUUID. Credentials/registry/raw logs riêng local ngoàiGit. Helper UI chỉ1createPOST; không retry write chưa rõ. Helper DB guard container/context/volume/role/history, registry đúngUUID/profile/auditID/actor, kiểm dữ liệu ngoài fixture; cleanup không theo tên/email, khôngtruncate/broaddelete.

## Failures đã sửa và giới hạn thực tế

- Unit helper ban đầu truyền Runnable thay JUnitExecutable; sửa action::run, compile/test cuối pass.
- SMTP sink timeout3giây quá ngắn cho cold setupJavaMail; dùngEHLOlocalhost và sink15giây, adapter connection/read/write2giây; SMTP3 cuối pass. Focused475 đầu có1SMTPerror, không dùng làm bằng chứng pass; lượt475 cuối và762full pass.
- Widget GET reconcile tap offscreen: ensureVisible, Admin73pass cuối.
- UI lượt đầu tạo account thành công nhưng PT requestOTP bị CORS do client gửi headerCache-Control không được phép. Audit/cleanup đúngUUID account đầu, lưu attempt lỗi private; bỏ requestheader không cần thiết, response no-store giữ nguyên; thêm test khôngheader, focused7/full55/buildPT chạy lại. UI lượt cuối16pass; không dùng lượt lỗi làm pass. Java không đổi sau762 nên không lặpBackend chỉ vì sửaDart.
- PT analyzer mặc định exit1 vì59infos (deprecated Flutter Material/style); explicit --no-fatal-infos exit0/0errors/0warnings, ghi đúng giới hạn, không sửa rộng code cũ.
- **Chưa chạy:** activation HTTP+PostgreSQL/mail flow và race verify/password/resend/rollback thực, empty/history schema rehearsal; schema chưa được phép. Maven skipped0 không có nghĩa các scenario bịblock này đã chạy. Không E2E toàn hệ thống/emailproduction/Memberactivation.

## Chạy lại và cleanup

[Testing guide](../06_TESTING_GUIDE.md) và [quickstart](../15_BOOKING_WEB_QUICKSTART.md) có runnerguard/Flutter/UI/DBcommands. JDK21, DB_PASSWORD secureprocess, fullcontainerID đãinspect; focused `-AccountFocused`, full `-FullSuite`, không kết hợp. Unit-only có thể Maven chỉ PtActivationServiceTest,TestSmtpActivationMailerTest, không cần apply candidate. Tuyệt đối không bật activation flag trước thống nhất schema.

Cả2accountUI attempts được audit/cleanup exactUUID. Final accountcleanup4checks, lần2no-op1check; BookingDemoCleanupfixture2lần, seeded=false. Dừng Java24040/wrapper22392/NodeAdmin31048/PT29040 đã đối chiếu commandline/parent; verifiedDBcontainer đãdừng, volume giữ nguyên, ports3001/3002/18081/15437 không cònlisten. Không dừng engine/tài nguyên chung.

Tiếp theo cần Duy thống nhất phiên bản/schema candidate, rồi migrationforward review và test riêng đầy đủ trước bậtPTactivation. [Candidate SQL](../proposals/account_activation_candidate.sql) không canonical/Flyway/apply. Task account vàM-01 vẫn chưa stage/commit; không push/merge.
