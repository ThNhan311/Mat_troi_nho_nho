# F-03A ? Face Service v? evaluation rehearsal (Windows)

[Contract/gi?i h?n](decisions/2026-11-24_F03A_FACE_SERVICE.md), [service OpenAPI](../../face/service_v2/openapi.json), [evidence](evidence/F03A_FACE_SERVICE.md). Base F02 `de82618`, branch `feature/face-service-integration`; source pin Face `fcabeba`. Kh?ng s?a checkout Face/model/cache g?c, kh?ng d? li?u biometric m?i, kh?ng DB chung.

## Runtime ri?ng v? model

T?i worktree t?ch h?p; ch?n private directory m?i d??i `$env:LOCALAPPDATA/Temp`, kh?ng trong Git. Python3.12/JDK21. V? d? bi?n `$private`, `$python`, `$jdk` do ng??i ch?y ??t; kh?ng ??i PATH h? th?ng.

```powershell
& $systemPython -m venv "$private/venv"
$python = "$private/venv/Scripts/python.exe"
& $python -m pip install -r face/service_v2/requirements-lock.txt
$env:PYTHONDONTWRITEBYTECODE='1'
$env:PYTHONUTF8='1'
& $python -m face.service_v2.artifacts --private-directory $private
& $python -m face.service_v2 --probe "$private/model-root"
& $python -m face.service_v2.smoke --model-root "$private/model-root" --output "$private/model-smoke.json"
```

Artifact bootstrap ch? official `buffalo_s` v0.7, pin archive/file SHA v? size; n?u kh?c ph?i review, kh?ng overwrite. Publisher digest ch?a c?ng b? ? API release khi ki?m tra; SHA l? m?c local t?i l?p. Kh?ng d?ng `buffalo_l` cache s?n l?m thay th?. Direct requirements gi? source versions; lock freeze transitive c?a isolated venv, ?p hai OpenCV packages c?ng4.11 ?? tr?nh namespace b? package transitive5.1 ghi ??. Kh?ng n?ng m?i tr??ng g?c.

Smoke th?c ch?y SCRFD tr?n3 uniform images v? ArcFace forward tr?n tensor112 t?ng h?p, r?i authenticated health/capture HTTP v?i model th?t. Kh?ng ng??i, kh?ng accuracy/enrollment/PAD/camera. Output t?o m?i, kh?ng ghi ??. Model gallery t?m mang UUID ri?ng ???c x?a ??ng file sau stop.

## Service th?t, kh?ng admission

T?o config **ri?ng ngo?i Git**, kh?a ng?u nhi?n ??c l?p do server c?p. Ch? ghi t?n tr??ng trong t?i li?u, kh?ng ghi gi? tr? credential: `guard=F03A_PRIVATE_REHEARSAL`, `port` tr?ng, `modelRoot` private, `controlToken`, `captureToken`, `signingKey`, `galleryKey` (Fernet), `threshold`, `margin`, `duplicateThreshold`. Threshold ph?i nh?p r?, ch?a ph?i production calibration. Kh?a kh?ng ??a v?o Dart/env web bundle/command line/log.

```powershell
& $python -m face.service_v2 --config "$private/service.json"
```

Bind127.0.0.1, kh?ng CORS/browser endpoint. Prepare/status/stage/finalize/abort ? private service; control authority ch? Backend, capture authority ch? trusted capture process. Stage5?15 frames encoded PNG/JPEG, >=3 usable vectors, 2MiB/frame/4096px, t?ng request12MiB. Kh?ng nh?n vectors/claimed match/member/score t? kiosk c?ng khai. Kh?ng l?u raw ?nh. PREPARED/STAGED ch?a recognition-visible; ACTIVE sau finalize m?i ???c d?ng. Recovery/revoke xem contract; kh?ng s?a SQLite/gallery b?ng tay ?? ?p state.

Backend v?n ch? cho protocol test host v?o mode V13 SIMULATED_TEST. Actual model provenance b?503 `ERR_FACE_REAL_ADMISSION_NOT_ENABLED`; kh?ng d?ng service model-smoke nh? credential ?? m? gate. NOT_PERFORMED lu?n kh?ng admission. Kh?ng gh?p profile ho?c thay default properties.

## Protocol + Backend/PostgreSQL tests

D?ng l?i private container/volume authority ?? x?c minh c?a [F02 runner](23_FACE_ENROLLMENT_QUICKSTART.md); t?o **authority directory m?i** cho F03, copy container identity v? app DPAPI sau khi ki?m tra quy?n s? h?u, danh s?ch `runs=[]` ri?ng; kh?ng ch?p registry/runs c? r?i cleanup. Re-inspect ID/image/label/volume/loopback15441 v? role tr??c start. Kh?ng in credentials. N?u thi?u authority, recover read-only inventory tr??c, kh?ng reset/provision ??.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/scripts/face-service-rehearsal.ps1 `
  -JavaHome $jdk -PrivateDirectory $private -ExpectedContainerId $verifiedContainerId -Python $python
```

Focused g?m `FaceServicePostgresTest,FaceServiceUnitTest,EnrollmentPostgresTest,EnrollmentUnitTest`. Hai DB pair m?i, ri?ng F03 v? F02. JUnit t?o Python process ri?ng c? private synthetic config, registry PID/start-time, loopback port tr?ng; kh?ng public fake API ? production CLI. Fixtures ch? synthetic, model accuracy kh?ng ???c ?o ? c?c tests n?y. AfterAll abort ??ng managed references v? stop child; shutdown hook x? l? JVM exit.

Full: c?ng command th?m `-FullSuite`, truy?n baseline DB password ?? guard qua **process env ri?ng** l?y t? DPAPI, x?a env trong finally. Kh?ng vi?t literal password v?o command/log. Runner g?i full selector `*Test,!PtActivationPostgresTest,!ActivationSchemaRehearsalTest,!InitialMembershipPostgresTest`; integrated replacements v?n ch?y. Test application filename kh?ng thu?c `*Test` kh?ng ???c ch?n. F03 ri?ng1pair + F02/account/renewal/F01 ri?ng4pairs15441; Booking/default suite15437. Kh?ng g?i ??y l? m?i profile E2E ho?c c?ng focused v?o full.

```powershell
& $python -m pytest face/service_v2/tests face/integration/tests --rootdir=. -p no:cacheprovider -q
```

?? ki?m pinned state/auth, export ??ng tests/conftest t? Face pin ra private v? ch?y command ri?ng t?i private test directory v?i PYTHONPATH worktree; kh?ng g?p ???ng d?n C: v? D: l?m pytest scan root Windows. C?c module dependency ?? import nguy?n pin trong worktree. Kh?ng ch?y camera/detector UI khi ch?a ???c ph?p d? li?u.

## Evaluation ? ch? khi c? dataset ???c ph?p

Ch?a c? dataset biometric ???c cung c?p n?n c?c command b?n d??i l? h??ng d?n, **ch?a ch?y accuracy**. Manifest JSON private: `authorizedForEvaluation:true`, `datasetVersion`, `samples:[{id,role,subject,path,sha256}]`. role=`gallery|probe`; m?i subject l? pseudonymous ID (unknown c?ng c? ID ri?ng, kh?ng c? trong gallery). Kh?ng PII/?nh/vector trong Git; file relative n?m trong manifest directory; hash/ID kh?ng tr?ng. Calibration v? evaluation kh?ng tr?ng ng??i/hash; trong m?i split gallery v? probe c?ng ng??i nh?ng ?nh kh?c. Chu?n b? nhi?u session/?i?u ki?n/unknown cohort ph? h?p kiosk; quy?n s? d?ng/consent ph?i c? ngu?n th?t, flag kh?ng t? t?o consent.

```powershell
& $python -m face.service_v2.evaluate --phase calibration --manifest "$private/calibration/manifest.json" `
  --model-root "$private/model-root" --threshold $candidateThreshold --margin $candidateMargin --output "$private/calibration-result.json"
& $python -m face.service_v2.evaluate --phase evaluation --manifest "$private/evaluation/manifest.json" `
  --calibration-manifest "$private/calibration/manifest.json" --model-root "$private/model-root" `
  --threshold $chosenThreshold --margin $chosenMargin --output "$private/evaluation-result.json"
```

Operator ch?n candidate tr?n calibration, gi? evaluation ??c l?p; harness kh?ng t? duy?t threshold. B?o genuine/impostor identity-max scores, score FA/FR, 1:N FNIR/FPIR/rank1/wrong/ambiguous/unknown rejection v? latency. Kh?ng thay identification metrics b?ng pair accuracy; PAD v?n NOT_PERFORMED.

## Cleanup

Ch? registry UUID c?a c?c runs trong authority F03. D?ng [exact cleanup](../../backend/scripts/cleanup-enrollment-integration.mjs), secret app password process-only cho PGPASSWORD; ch?y l?p ?? ki?m idempotent v? outside-row hashes. Kh?ng truncate/drop/broad delete/clean/repair/out-of-order. Sau cleanup stop ??ng DB b?ng F02 runner `-Action Stop` c?ng container ID, gi? volume/schema/history. Baseline ch? d?ng n?u ch?nh task ?? kh?i ??ng; ki?m PID/start/command tr??c d?ng process ri?ng. Private keys/logs/SQLite/model cache kh?ng stage v?o Git. [Status](../PROJECT_STATUS.md).
