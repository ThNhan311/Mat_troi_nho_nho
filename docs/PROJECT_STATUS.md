# FitCenter — trạng thái tiếp tục

Cập nhật24/11/2026, worktree Mat_troi_nho_nho-booking-integration; branch **feature/face-enrollment**, HEAD/base trước commit đóng **c3eb411cfbb6cfdfdfdc441d850d2eea456f7b46**. Git là thực tế; commit F02 tra history (file không tự chứa SHA của chính nó).

## F02 đã kiểm chứng ở chế độ simulated, Face thật chưa hoàn thành

Admin ACTIVE: enrollment start/complete/status/re-enroll/pending revoke/profile revoke; consent/at-gym/member verification attestation, actor/time server; server mints template/profile→members.id. Một ACTIVE/member; chỉ READY finalize, failure giữ old; external journal/outbox/recovery tách DB transaction. Old profile/capture/request không check-in sau revoke/replacement. No User/Membership/payment/Booking mutation; default503, profile riêng có guard.

Thực chạy **1076Backend selected full/0failed/errors/skipped**,41freshsuites, JDK21/PG17.12; focused30 là subset. **Admin133tests**,23F02; analyze109info/0error/0warning với --no-fatal-infos, web build đạt. **Python49selected** protocol F01, không detector/model/camera. **UI10/directHTTP10/DB6checks** đạt; identity SIMULATED_TEST. Không Flutter Member/PT thay đổi. [Evidence/traceability](backend-handover/evidence/F02_FACE_ENROLLMENT.md), [JSON](backend-handover/evidence/F02_RESULTS.json), [hashes](backend-handover/evidence/F02_SOURCE_HASHES.json), [quyết định/khóa/contract](backend-handover/decisions/2026-11-24_F02_FACE_ENROLLMENT.md), [quickstart](backend-handover/23_FACE_ENROLLMENT_QUICKSTART.md), [OpenAPI](backend-handover/api/openapi.yaml).

## Source/schema/release

Face source fcabeba đã có service/gallery/enroll, nhưng chưa staging/idempotent operation/generation/predecessor-aware duplicate phối hợpDB; không nối camera thật chỉ vì API enroll đã tồn tại. F02 adapter test external journal/default-off, không ảnh/vector/liveness/threshold mới;26untracked Face nguyên hash. [Khảo sát nguồn](backend-handover/evidence/F01_FACE_SOURCE_SURVEY.md).

V13 additive rehearsal riêng, frozen1–6,8–13/12scripts. V1–V12 giữ nguyên; không applyV7. Empty/history preservation đạt. Shared DB inventory chưa biết, V7 Duy558fb03 còn DROP periods chưa backfill; cần đồng bộ/backfill/backup/thứ tự V8–V13 trước release. Không renumber/out-of-order/history edits/clean/repair; **releaseReady=false**, production gates giữ nguyên.

## Git/tài nguyên/tiếp theo

Review để commit/push riêng theo quyền, không merge/force; CI/CD inventory04:04UTC0workflow/run/deployment/webhook, không gọi CI passed. Bốn research22/11 untracked giữ ngoài commit, không reset/stash/ghi đè Face hoặc source ngoài task. Credential/config/raw logs/SDK/build/private journal/manifest ngoài Git. Cleanup44DB/92checks +repeat đạt, ngoài fixture không đổi; own6process/hai lượt demo và DB đã dừng, giữ schema/history/volume.

F03: thống nhất service prepare/status/finalize/abort/remove có idempotency và generation, logical Member/predecessor mapping/duplicate; capture attestation/trust transport/kiosk source, calibration/model/license/FAR-FRR, liveness/PAD, production consent/version/retention/revoke audit. Không tuyên bố Face ID hoặc biometric E2E đã hoàn thành. [Quyết định tổng hợp](DECISIONS.md), [AGENTS](../AGENTS.md).

Mốc lịch sử: F01[c3eb411](backend-handover/evidence/F01_CHECKIN_CORE.md), renewal4af8bb8, I01d2774c9, MEMBER activation9503110, M035399c57, M0492328e0. Không dùng số test/UI lịch sử làm kết quả F02.
