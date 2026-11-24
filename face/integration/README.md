# F01 Core addon — simulated identity only

Không phải model/Face Service mới; không thay prototype. Cần source Face pin fcabeba (origin/feature/face-1n-identification). Backend test guard F01 dùng opaque captureRef→synthetic FacialProfile; không ảnh/vector/người thật. Default flag tắt. Không đưa service key vào Web/Flutter build hoặc Git.

Khi addon ở cùng checkout có source Face, wiring hẹp cho existing controller:

```python
from face.integration.core_client import CoreCheckinClient
from face.prototype.auth_client import SingleFlightWorker
from face.prototype.controller import PrototypeController
from face.prototype.config import PrototypeConfig
# FITCENTER_CORE_CHECKIN_TEST_ADAPTER_ENABLED=true, credentials/capture từ private fixture.
client = CoreCheckinClient(base_url, registered_kiosk_id, private_token, opaque_capture_ref)
worker = SingleFlightWorker(client)
controller = PrototypeController(PrototypeConfig(kiosk_id=registered_kiosk_id), worker)
# Existing app giữ update/selection/shutdown; không đổi detector/model/threshold.
```

Branch Core hiện không import toàn Face prototype. Test runner export source pin riêng, PYTHONPATH trỏ export; tests/harness load addon từ file để không ghi đè checkout Face. `app.py` gốc chỉ có mock/local auth; đây là wiring point đã kiểm protocol, **chưa tự nối GUI/camera thật**. Frontend kiosk tìm thấy ở0307242 còn mock, chưa sửa vì chưa có source mới tương ứng với README Face.

Một authenticate gửi đúng một JSON requestId/captureRef qua loopback HTTP, không owner/status/biometric. HTTP200 phải có accessAllowed/recognized hợp lệ và mode SIMULATED_TEST; account/membership denial không thành success. Không retry khi timeout/mất mạng; cooperative cancellation bỏ response trễ, uncooperative transport giữ slot tới khi kết thúc. Prototype tiếp tục VERIFYING/cooldown5s/leave gate; Backend rolling30min là quy tắc độc lập.

[Contract/quyết định](../../docs/backend-handover/decisions/2026-11-24_F01_CHECKIN_CORE.md), [quickstart](../../docs/backend-handover/22_CHECKIN_CORE_QUICKSTART.md), [evidence](../../docs/backend-handover/evidence/F01_CHECKIN_CORE.md).
