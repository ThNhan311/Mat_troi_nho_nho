# FitCenter — trạng thái tiếp tục

Cập nhật24/11/2026, worktree Mat_troi_nho_nho-booking-integration; branch **feature/face-checkin-core**, HEAD/base trước commit đóng **4af8bb8a51908cc46643fba009659c3903c1dba3**. Git là thực tế; commit F01 tra history, file không tự chứa SHA của chính nó.

## F-01 Core đã kiểm chứng, Face thật chưa hoàn thành

Service-only check-in, opaque captureRef, Core tự resolve FacialProfile→members.id. Default gate tắt503; simulated adapter chỉ guarded face-checkin-rehearsal/private fixture/loopback. Kiểm ACTIVE account/profile/Membership/VN DATE/paid coverage; rolling30m, request idempotency/fingerprint, recheck deny/replay, concurrent kiosk và rollback. Owner history GET attendance/me dùng Member principal, không query owner từ client. Không đổi Membership/payment/Booking trong Core.

Thực chạy **1043 passed/0failed/0errors/0skipped**,39XMLsuites scoped full JDK21/PG17.12; focused52 là tập con. Python49selected=27addon+22pinned Face state/auth tests. Không chọn3PGprofiles cũ (integrated counterparts chạy), không chọn Face detector/model/service/hardware suites, không đổi Dart nên không chạy Flutter. Core E2E **6adapter/14HTTP/7DB checks**,0failed/skipped: actual addon/worker/HTTP/PG nhưng **SIMULATED_TEST**, không UI/camera/recognition/liveness thật.

[Evidence/traceability](backend-handover/evidence/F01_CHECKIN_CORE.md), [JSON](backend-handover/evidence/F01_RESULTS.json), [hashes](backend-handover/evidence/F01_SOURCE_HASHES.json), [source Face thực tế](backend-handover/evidence/F01_FACE_SOURCE_SURVEY.md), [contract/khóa](backend-handover/decisions/2026-11-24_F01_CHECKIN_CORE.md), [quickstart](backend-handover/22_CHECKIN_CORE_QUICKSTART.md), [OpenAPI](backend-handover/api/openapi.yaml).

## Source và schema

Face sourcefcabeba tại origin/feature/face-1n-identification có detection/quality/state/embedding/1N/enrollment/service, chưa liveness/calibration. Kiosk origin/frontend0307242 còn mock; không coi README claim là source/runtime đã tích hợp. Addon hẹp kiểm protocol với export source pin private, không thay prototype hay mang toàn Face branch.26untracked cache/model files liên quan checkout gốc nguyên bytes; venv không pip update, bytecode/cache off.

V12 additive request ledger location riêng, tận dụng Attendance V3; không sửa V1–V11 hoặc áp V7. Candidate1–6,8–12/11scripts, empty/history migration giữ old rows/CRC; default gates vẫn tắt. ReleaseReady=false; shared DB inventory chưa biết, V7 có thể đã áp nơi khác và bản558fb03 còn DROP periods chưa backfill. Cần đồng bộ mapping/backfill/backup/thứ tự V8–V12 trước canonical release, không out-of-order/history edit/clean/repair/renumber.

## Git/tài nguyên và bước tiếp

Review để commit/push riêng theo quyền, không merge/force. Bốn research22/11 untracked giữ ngoài commit; checkout gốc/Face không reset/overwrite. Không credential/private manifest/raw log/build/SDK/export vào Git. Remote chỉorigin, CI/CD inventory0workflow/run/deployment/webhook; không gọi CI passed.

Cleanup exactUUID20DB/44checks, lặp đạt xong mới stop; nonfixture rows/schema/history/volume giữ nguyên. Own backend/wrapper/DB dừng,18085/15441 đóng, volumes baseline/account còn, không DB chung hoặc tài nguyên đồng đội bị đổi.

Core simulated đã đạt. Trước Face thật cần bằng chứng model/threshold/FAR-FRR, phương án liveness/PAD và capture/trust deployment; binding/enrollment/revoke atomic và đúng kiosk source. Chưa thu biometric người thật, chưa gallery sync/real camera UI. Không phát triển gateway/Workout hoặc module khác khi chưa giao. [Quyết định tổng hợp](DECISIONS.md), [AGENTS](../AGENTS.md).

Mốc lịch sử: M05/M06 renewal4af8bb8 ([evidence](backend-handover/evidence/M05_M06_RENEWAL_SIMULATOR.md)), I01d2774c9, MEMBER activation9503110, M035399c57, M0492328e0. Không cộng989/80/110 hoặc UI của M05 vào F01.
