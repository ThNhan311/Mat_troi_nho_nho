# FitCenter — trạng thái tiếp tục

Cập nhật24/11/2026, worktree Mat_troi_nho_nho-booking-integration; branch **feature/membership-renewal-simulator**, HEAD/base trước commit đóng **d2774c9b860e7d263b26edac1003502da8781790**. Xác minh Git khi tiếp tục; commit task tra history, file không tự chứa SHA của chính nó.

## M-05/M-06 đã kiểm chứng trên test riêng

Backend renewal PENDING/idempotency/snapshot và ADMIN simulator default-off, period CURRENT/NEXT/HISTORY, RECONCILIATION_REQUIRED khi tiền SUCCESS chưa thể cấp quyền. Member và Admin dùng màn/theme/navigation gốc; no blind replay, session epoch, owner/role kiểm phía server. Không gateway/tiền thật/refund/Face/Workout. Không đổi current plan sang next plan bằng ghi đè FK; Booking/D01 kiểm paid coverage không bắc cầu qua gap. M03/activation giữ nguyên semantics.

Thực chạy23/11: scoped full **989 passed/0failed/0errors/0skipped**,36XMLsuites; focused71 là tập con. Flutter Member80/Admin110 passed, analyze0errors/0warnings (85infos mỗiapp),2Webbuilds đạt. PT Dart không đổi nên không chọn Flutter PT; Backend activation/PT/Booking/D01/M03/M04 có trong regression phù hợp. Ba PG profile cũ bị loại selector, integrated counterparts đã chạy; không gọi tất cả profiles đã test.

E2E **29UI/18HTTP/10DB checks**,0failed/skipped; một backend/DB/mail sink, chỉ seed Admin. Member activate qua SMTP/UI thật, kế đến Member tạo PENDING→Admin UI SUCCESS→reload/login cùng UUID/CURRENT/NEXT; FAILED/CANCELLED/replay không cộng kỳ. UI early renewal dùng thời gian thật, boundary/expired dùng test Clock. [Evidence/traceability/hashes/ảnh](backend-handover/evidence/M05_M06_RENEWAL_SIMULATOR.md), [JSON](backend-handover/evidence/M05_M06_RESULTS.json), [quickstart](backend-handover/21_RENEWAL_SIMULATOR_QUICKSTART.md), [quyết định/contract](backend-handover/decisions/2026-11-23_M05_M06_RENEWAL_SIMULATOR.md), [OpenAPI](backend-handover/api/openapi.yaml).

## Schema, Git và tài nguyên

V11 additive riêng; frozen candidate1–6,8–11, không sửa SQL đã áp/V7. Empty/history upgrade giữ payment periods, M03 receipt/snapshots và activation state. Default gates còn tắt; runner/profile renewal-integration-rehearsal guard loopback15441/role/namespace/locations. [Manifest ứng viên](../database/renewal-integration-candidate.json), [I01 release inventory](backend-handover/decisions/2026-11-23_I01_MIGRATION_CANDIDATE.md).

Thay đổi task đã review để commit/push feature riêng theo quyền; chưa merge/force. Bốn research22/11 untracked giữ ngoài commit; Face/survey tại checkout gốc089b5e2 nguyên vẹn. Không credential/private manifest/raw log/cache/SDK/build vào Git. Remote database ref558fb03; CI/CD inventory0workflow/run/deployment/webhook, không gọi CI pass.

Cleanup exactUUID22DB/54checks, lặp lại đạt; nonfixture rows/schema/history/volume giữ nguyên. Own backend/wrapper/2web/mail và DB đã dừng, task ports đóng, baseline/account volumes còn. Một lượt repeat từng bị stop sớm đã được mở lại và hoàn tất trước stop cuối. Không DB chung hoặc tài nguyên đồng đội bị đổi.

## Blocker release và bước tiếp theo

**releaseReady=false**: chưa có shared DB inventory/checksum; V7 có thể đã áp nơi khác, bản database558fb03 DROP payment periods chưa backfill nên không chạy nguyên bản. Cần đồng bộ Duy mapping/backfill/backup/thứ tự artifact V7–V11, xử lý legacy provenance không rõ. Không out-of-order/history edits/clean/repair/đổi số migration để lách. Simulator chỉ dev/test, chưa gateway/refund/production mail/manual reconciliation workflow.

Bước tiếp: review nhánh renewal, thu inventory chỉ đọc từ chủ DB và chốt canonical migration trước rollout; không mở module khác khi chưa giao. [Quyết định tổng hợp](DECISIONS.md), [quy tắc repository](../AGENTS.md). I01 d2774c9, MEMBER activation9503110, M03 5399c57, M04 92328e0 là mốc lịch sử; không cộng số cũ vào lượt M05/M06.
