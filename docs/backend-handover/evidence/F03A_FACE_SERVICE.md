# F-03A — Face Service integration/evaluation evidence (24/11/2026)

Branch `feature/face-service-integration`, base **de82618c21d2aaeb2c3b1d39df4382b3928d93e7 + working tree F03A**. Commit đóng tra Git history. [Kết quả/suites/model](F03A_RESULTS.json), [39 executable/helper/dependency hashes và source provenance](F03A_SOURCE_HASHES.json), [contract/recovery/gates](../decisions/2026-11-24_F03A_FACE_SERVICE.md), [chạy lại](../24_FACE_SERVICE_QUICKSTART.md), [service OpenAPI](../../../face/service_v2/openapi.json).

## Thực chạy — không cộng các tập con

| Phạm vi | Passed | Failed/errors/skipped | Giới hạn |
|---|---:|---|---|
| Backend selected full cuối | **1106** | **0/0/0** |43fresh XML suites, JDK21/UTC, PostgreSQL17.12 riêng |
| Focused cuối |63|0/0/0|Tập con full, không cộng thêm; 13PG/HTTP +17unit F03 và F02 regression |
| Python repo cuối |58|0/0/0|31service/evaluation synthetic +27F01addon |
| Python source pin state/auth |22|0/0/0|Command riêng/private export, không accuracy/camera |
| Actual model smoke |đạt|không tính là unit tests|SCRFD uniform inputs; ArcFace512 tensor; model HTTP health/capture NO_FACE |
| Cleanup |108checks /36DB|0failed|Exact UUID, outside-row comparison; lặp lại đạt; không cộng vào tests |

Full selector `*Test,!PtActivationPostgresTest,!ActivationSchemaRehearsalTest,!InitialMembershipPostgresTest`. Integrated replacements được chọn; ba profile PG legacy và application filename không khớp `*Test` không được chọn, không gọi là đã chạy tất cả profiles. Không Flutter/Dart thay đổi nên không chạy lại Admin/Member/PT analyze/widget/build/UI. F02 Admin133/UI và F01/F02 số test cũ **là lịch sử**, không dùng làm lượt F03A.

Full đầu1106 đã đạt; review tiếp phát hiện service JSON `status:null` có thể gây NPE, đã sửa thành controlled503 và thêm assertion HTTP. Focused63 rồi full1106 cuối chạy lại trên executable Java cuối. Chỉ báo lượt full cuối, không cộng hai full/focused. Source hashes raw working-tree và normalized-LF để phân biệt EOL Git; docs cập nhật sau tests không thay executable.

## Service integration đã chạy

[Backend HTTP suite](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/FaceServicePostgresTest.java) chạy Backend TCP, Python FastAPI/uvicorn TCP process và PostgreSQL thật trên cặp DB riêng. **Engine trả one-hot từ ảnh uniform, provenance SYNTHETIC_PROTOCOL**, không phải biometric recognition.

- Operation→Member/profile/reference/generation immutable, strict binding/auth, staged không nhận diện được; Complete commit DB rồi finalize ACK. UUID members.id khác users.id; actor/consent như F02.
- Sai binding/generation/auth/malformed null state trả sanitized503; retry cùng operation không thêm profile/audit. Timeout sau external stage giữ DB PENDING; timeout sau finalize có thể DB/service ACTIVE, retry reconcile chính operation.
- Trigger tổng hợp làm DB insert rollback: service chỉ STAGED, old profile vẫn hoạt động; bỏ fault rồi same-op recovery mới publish replacement generation2.
- Re-enroll cùng Member/predecessor không bị duplicate-self. Duplicate người khác bị chặn ở staging/reservation, old profiles giữ nguyên. SQLite race reserve không cho hai identity trùng vượt tới Backend commit.
- Concurrent completions cùng chờ Member lock thực trong `pg_stat_activity`, chỉ một mapping ACTIVE. Revoke khi finalize đang bị barrier chặn: DB REVOKED/service ABORTED, late finalize không resurrect. Abort pending, reference tombstone trước prepare, finalize/abort cạnh tranh, durable restart và encrypted payload được kiểm.
- Proof ký HMAC ràng buộc request/capture/profile/generation/model/provenance/TTL; sai signature/request, generation không khớp và stale revoked profile bị từ chối. **Proof hợp lệ NOT_PERFORMED vẫn không admission/Attendance.** Không client tự khai member/score.
- User/Membership/payment/receipt/period/activation/Booking snapshot không đổi bởi lifecycle. Empty/history migration giữ dữ liệu tổng hợp cũ, V1–V13 bytes/checksums không thay. Không thêm/apply migration mới; không V7/shared DB.

[Python service tests](../../../face/service_v2/tests/test_service.py) dùng real TCP HTTP, synthetic engine tách biệt production CLI; checks no-store/auth/stage/finalize/abort/one-in-flight, abort khi inference đang chờ, encrypted store/key mismatch, capture retry không gia hạn TTL. Heavy inference chạy threadpool để status/abort không bị ASGI event loop chặn. F01 SingleFlightWorker/state/auth giữ cooldown5s/VERIFYING/stale-result behavior, không gọi headless tests là webcam/kiosk GUI đã chạy.

## Model inference thật đã chạy

13file source/dependency Face nhập nguyên bytes pin `fcabeba765d6e597cbc5fbed76fafc08f9604e03`; không merge prototype app/camera/mock entry point. Tái dùng embedder, Gallery normalize/search, Matcher và register; thêm lifecycle store/transport thay phần API cũ publish gallery trực tiếp. Cache máy có buffalo_l nhưng không dùng thay buffalo_s.

Weights lấy đúng official v0.7 `buffalo_s.zip`,127607557bytes; archive SHA `d85a87f503f691807cd8bb97128bdf7a0660326cd9cd02657127fa978bab8b5e`; API upstream không công bố digest, local SHA không phải publisher signature. Det500m SHA `5e4447f50245bbd7966bd6c0fa52938c61474a04ec7def48753668a9d8b4ea3a`; w600k_mbf SHA `9cc6e4a75f0e2bf0b1aed94578f144d15175f357bdc05e815e5c4a02b319eb4f`. Artifact bootstrap và preflight đã chạy, cache/venv riêng ngoài Git.

Runtime thực: Python3.12, InsightFace2.1, onnxruntime1.31.1, NumPy2.2.6, OpenCV4.11, CPUExecutionProvider; detector class SCRFD, recognition class ArcFaceONNX. Dependency freeze ở lock, không sửa venv gốc. Nạp model +3 direct uniform non-person images NO_FACE; forward ArcFace trên aligned112 tensor tổng hợp có shape1×512/finite/nonzero norm. Authenticated service HTTP với model thật health200/capture200 NO_FACE, provenance MODEL_INFERENCE_UNCALIBRATED, NOT_PERFORMED/admissionEnabled=false. Latency từng bước trong JSON, **không phải latency nhận diện kiosk thực tế/accuracy**; tensor output không được dùng như enrollment của người thật.

## Accuracy/liveness/camera chưa kiểm chứng

Không có bộ dữ liệu biometric được phép cung cấp: **không chạy calibration, genuine/impostor model dataset scores, FAR/FRR/FPIR/FNIR thực**, không bịa số và không duyệt threshold production. [Evaluator unit tests](../../../face/service_v2/tests/test_evaluate.py) chỉ kiểm công thức, split/hash leakage, validation bằng ảnh uniform/engine synthetic. Harness hỗ trợ known/unknown identities, separate calibration/evaluation subjects/hash, gallery/probe, version/model/preprocessing/threshold/gallery-size, identity-max scores, 1:N wrong/reject/ambiguity/FNIR/FPIR/rank1 và inference/identification latency.

Source không có PAD component; camera quality/ROI/state machine không phải liveness. NOT_PERFORMED không chuyển PASSED. Chưa camera capture/real-person embedding/enrollment/1:N accuracy/liveness/Backend admission thật. Cần dataset được phép, đại diện kiosk/unknown cohorts, session-separated labels và PAD attack/bona-fide data; chọn/đánh giá PAD và threshold là bước tiếp, chưa tự quyết trong task.

V13 chỉ SIMULATED_TEST. Backend remote nhận actual model provenance sẽ503, không ghi real inference dưới nhãn synthetic. Real model service đã nạp/chạy độc lập, nhưng **Backend real-model enrollment/admission còn đóng**. Shared migration inventory/V7 backfill/order V8–V13, model usage/license, retention/key rotation/legacy gallery mapping cần giải quyết trước release. **Không gọi F03 hoàn tất hoặc release-ready.**

## Failures, review và cleanup

Lỗi thực đã sửa: assertion unit so Long/Integer cùng giá trị; pytest cross-drive root collection chạm Windows junction (tách commands/rootdir); transitive OpenCV5.1 metadata xung đột namespace contrib4.11 (pin riêng cùng4.11). Review sửa staged duplicate reservation, inference event-loop blocking, TTL lấy hai Clock lần có thể lệch1s, malformed status null và early no-store. Các error/409/503/rollback500 được assert đúng contract, không coi expected denial là test failed. Final không failure mở.

39hashes gồm executable/test/helper/dependency mới/sửa, source pin và2F01files unchanged được regression. 13source imports khớp raw pin;26Face untracked/cache/model gốc khớp snapshot byte/size, không overwrite/move. Bốn research untracked giữ ngoài task. Không credentials/manifest/raw logs/model/SDK/cache/build hoặc biometric người thật trong commit.

Cleanup18pairs/36DB của authority F03,108checks và repeat đạt; exact registry UUID/FK order/outside-row hashes, schema/history giữ lại. Test Python processes/JVM và hai private DB containers đã dừng; volumes còn, không LAN/shared DB. CI/CD inventory08:30UTC:0workflow/run/deployment/webhook, **không phải CI passed**. Commit/push riêng sau review, không merge/force.
