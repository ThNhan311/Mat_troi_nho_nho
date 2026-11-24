# F-01 — Core check-in evidence24/11/2026

Branch `feature/face-checkin-core`, tested HEAD/base **4af8bb8a51908cc46643fba009659c3903c1dba3 + F01 working tree**. [JSON/suites/migration/readback](F01_RESULTS.json), [28 executable/packaging hashes](F01_SOURCE_HASHES.json), [source Face survey](F01_FACE_SOURCE_SURVEY.md), [contract/decisions](../decisions/2026-11-24_F01_CHECKIN_CORE.md), [rerun](../22_CHECKIN_CORE_QUICKSTART.md).

## Kết quả thực chạy

| Phạm vi | Passed | Failed/errors | Skipped | Giới hạn |
|---|---:|---:|---:|---|
| Scoped full Backend | 1043 | 0/0 | 0 | 39XMLsuites tươi, JDK21/UTC/PostgreSQL17.12 |
| Focused cuối | 52 | 0/0 | 0 | 40CheckinPostgres +12unit, tập con full |
| Python selected | 49 | 0 | 0 | 27addon +22pinned Face state/auth tests, không cộng vào Backend |
| Adapter/Core E2E | 6checks | 0 | 0 | Actual CoreCheckinClient/SingleFlightWorker/HTTP, simulated identity |
| HTTP orchestration E2E | 14checks | 0 | 0 | Login, plan/M03, rejected claims, owner/history/read-back; tách6adapter requests |
| DB E2E | 7checks | 0 | 0 | UUID/state/dedupe/replay/owner/no external mutation |
| Cleanup | 44checks/20DB | 0 | — | Lặp lại đạt, exactUUID/nonfixture preservation |
| Package | đạt | 0 | — | JAR từ source full đã test, guard kiểm11SQL/scripts |

Full selector `*Test,!PtActivationPostgresTest,!ActivationSchemaRehearsalTest,!InitialMembershipPostgresTest`. Ba lớp PG profile cũ không chọn, integrated replacements vẫn chạy. Baseline15437 phục vụ Booking/default API; account/renewal/F01 ở3pairs khác nhau15441 đúng locations. Không gọi toàn bộ profiles đã chạy hoặc cộng focused52 vào1043. Focused đầu46đạt, sau bổ sung race/deny tests cuối52đạt. **989 của M05 là lịch sử, không dùng làm lượt mới.**

Python không chọn camera/detector/selector, embedding/gallery/enrollment/service suites hoặc biometric hardware. PYTHONDONTWRITEBYTECODE/cache off, nguồn Face export pinfcabeba vào private. Không Flutter/Dart thay đổi nên không chạy analyze/build/widget ba app. Không có UI/camera/recognition/liveness E2E trong F01; không gọi Core simulation là Face ID đã đạt.

## Traceability

| Yêu cầu | Bằng chứng |
|---|---|
| Default không có fake match | [default HTTP tests](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/CheckinDefaultHttpTest.java): POST self-claimed identity503, history anonymous401; unit gate không chạm DB |
| Kiosk/service trust, no public memberId | [security chain](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/checkin/CheckinSecurity.java), [strict request](../../../backend/src/main/java/vn/edu/tdtu/fitcenter/checkin/CheckinRequest.java), registered credentials/opaque reference test |
| ACTIVE User/profile/Membership + VN DATE/paid coverage | [HTTP/PG suite](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/CheckinPostgresTest.java): missing/inactive/future/expired/suspended/cancelled, inclusive leap-day expiry, renewal PENDING versus SUCCESS |
| 30phút rolling và recheck | before/exact/after30m; duplicate account/Membership/paid coverage đổi vẫn bị chặn, không sliding timestamp hoặc calendar bucket |
| Idempotency/owner | sameID replay giữ ledger gốc, khác capture/kiosk409, different-payload same-ID race, MemberID khác UserID |
| Concurrency | Giữ Member/request advisory lock ngoài transaction HTTP, đồng bộ tasks, chờ PostgreSQL xác nhận cả hai đang wait rồi nhả; hai kiosk chỉ một Attendance; same-ID chỉ một creation và một replay |
| Clock sau chờ | Request đến trước expiry nhưng lấy Member lock sau midnight VN bị từ chối theo Clock mới; profile revoke khi chờ cũng bị chặn |
| Rollback | Trigger tổng hợp làm ledger insert lỗi sau Attendance insert: cả hai rollback; retry cùng ID sau bỏ fault chỉ tạo1record, business rows không đổi |
| History | Principal members.id, array range inclusive/exclusive/UTC/no-store, role/account/empty/error, không lộ MemberB dù query memberIdB; SIMULATED_TEST versus UNVERIFIED_LEGACY |
| Kiosk protocol | [addon tests](../../../face/integration/tests/test_core_client.py): one in-flight, VERIFYING no extra request, cooldown5s/leave, uncooperative transport giữslot, cancel/late/drop, malformed200/denial/timeout không fake success |
| Upgrade | [fixture/schema test](../../../backend/src/test/java/vn/edu/tdtu/fitcenter/http/CheckinIntegrationDatabase.java): empty/history11migrations, CRC đúng manifest, V12 giữ nguyên tất cả rows hiện có và rerun0migrations |

V3 không đủ lưu request fingerprint/outcome cho no-match/denied/duplicate nên thêm V12 ledger/owner FK/unique creation index riêng, không sửa V3 hoặc V1–V11. Historical fixture có6payment legacy/status/period, M03receipt/audit/snapshots và activation states; V11 backfilled paid periods, synthetic V3facial/Attendance. Quote/event V11 tables còn trống ở migration fixture; luồng renewal thật sau schema12 được kiểm bằng HTTP PENDING→SUCCESS→Core coverage. Không tuyên bố đã có inventory dữ liệu DB đồng đội.

## E2E Core thật với simulated identity

[Harness](../../../backend/scripts/verify-checkin-core.py) dùng một backend127.0.0.1:18085/một DB riêng15441. [Fixture helper](../../../backend/scripts/CheckinDemo.java) migrate pair mới và chỉ seed Admin/2ACTIVE Member accounts + synthetic facial references, **không phải Account activation hoặc enrollment thật**. Plan/2Membership/payment quầy được tạo qua API M01/M03, không seed quyền chưa trả tiền. Không ảnh/vector/template thật.

1. Addon/SingleFlightWorker gửi opaque capture/request UUID, Backend map synthetic FacialProfile→members.id, ghi Attendance+request ledger nguyên tử; UUID khác users.id.
2. KioskB scan cùng Member trong30m: accessAllowed=true nhưng không thêm Attendance; same-request replay cũng không thêm hoặc sửa metadata ledger.
3. NO_MATCH/unknown → REJECTED, không Attendance. Anonymous/Member/Admin JWT không thể tự khai match; request ID cùng payload khác409.
4. MemberB check-in độc lập; historyA/B trả đúng một row thuộc mình, query memberIdB không đổi owner. Fresh loginA đọc lại cùng Attendance UUID/time/mode.
5. Snapshot toàn bộ User/profile/Membership/payment/receipt/activation/Booking và các business tables ngoài attendance/ledger giữ nguyên sau Core. Chỉ có2Attendance tổng hợp; readback trong JSON.

Không đổi Clock production/chờ30phút/giả complete tương lai. Boundary dùng controlled test Clock. Mode của response/ledger/history đều ghi SIMULATED_TEST; `attendance_records.source=FACE` là constraint V3, **không phải bằng chứng nhận diện thật**. Default/rows legacy không có provenance trả UNVERIFIED_LEGACY.

## Review, bảo toàn và tài nguyên

28hashes E2E khớp source cuối; Java application/test source không đổi từ full. Source pin Face được hash riêng;26file untracked cache/model liên quan ở checkout gốc giữ nguyên bytes. Không overwrite/move/reset/stash hoặc thu dữ liệu người thật. Bốn research untracked không thuộc commit. Private credentials/config/UUID registry/raw logs/export/build/SDK không vào Git.

Cleanup20DB/44checks đã hoàn tất và lặp lại đạt trước stop;8DB pair chưa dùng trong focused được kiểm0publictables. Không truncate/drop/clean/repair/reset hoặc sửa history; giữ schema/history/volume. Own JVM/wrapper và rehearsal DB dừng,18085/15441 đóng; baseline/account volumes còn. Không thay DB chung hoặc tài nguyên đồng đội. Remote fetch/pins không đổi, CI/CD inventory0workflow/run/deployment/webhook, không gọi CI pass.

Không có test failure còn mở. Review trước tests đã chặn việc replay một request từng bị deny tự trở thành admission mới không Attendance; test giữ REQUEST_PREVIOUSLY_DENIED và yêu cầu scan/request mới. Các denials/401/409/rollback500 được assert là tình huống mong đợi, không phải test failed. Docs/OpenAPI refs đã validate sau tests; không rerun full chỉ vì docs.

## Phần chưa đạt/decision trước Face thật

- Recognition source có nhưng F01 không chạy; threshold/model defaults chưa có calibration/FAR/FRR được duyệt, không chọn giá trị mới.
- Chưa liveness/PAD, không chấp nhận NOT_PERFORMED như passed. Cần chốt phương án liveness và capture/trust transport cho adapter thật.
- Chưa mapping/enrollment atomic giữa gallery aliases và Backend FacialProfile/Member UUID, consent/revoke audit; yêu cầu Admin tại gym/consent đã có Topic11, không hỏi lại.
- Kiosk source0307242 vẫn mock; README nói có bản mới nhưng chưa xác định ref tương ứng. Addon là seam được kiểm headless, chưa nối app.py/Flutter/camera GUI chính.
- **releaseReady=false**: V7 destructive chưa backfill, shared DB inventory unknown; cần đồng bộ V8–V12/artifact và dữ liệu trước merge/release. V12/test adapter đóng ở SIMULATED_TEST. Không gateway/Face production hoặc merge trong task.
