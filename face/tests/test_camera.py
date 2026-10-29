import pytest
from face.prototype.camera import CameraCapture


class FakeSource:
    def __init__(self, reads, opened=True):
        self.reads, self.opened, self.releases = iter(reads), opened, 0

    def isOpened(self):
        return self.opened

    def read(self):
        value = next(self.reads)
        if isinstance(value, Exception):
            raise value
        return value

    def release(self):
        self.releases += 1


@pytest.mark.parametrize("failure", [(False, None), OSError("unplugged")])
def test_T13_camera_disconnect_reconnect_release(failure):
    frame, recovered = object(), object()
    first = FakeSource([(True, frame), failure])
    second = FakeSource([(True, recovered)])
    sources = iter([first, second])
    camera = CameraCapture(factory=lambda _: next(sources))
    assert camera.read(0) is frame
    assert camera.read(.1) is None
    assert "disconnected" in camera.warning
    assert first.releases == 1
    assert camera.read(.5) is None  # No busy loop reconnects.
    assert camera.read(1.1) is recovered
    assert camera.warning == ""
    camera.close()
    camera.close()
    assert second.releases == 1
    assert camera.read(2) is None


def test_T13_camera_open_failure_releases():
    source = FakeSource([], opened=False)
    camera = CameraCapture(factory=lambda _: source)
    assert camera.read(0) is None
    assert source.releases == 1
    camera.close()


def test_T13_camera_factory_exception_no_crash():
    def factory(_):
        raise PermissionError("camera blocked")
    camera = CameraCapture(factory=factory)
    assert camera.read(0) is None
    assert camera.warning
    camera.close()


@pytest.mark.skip(reason="Manual Windows webcam preview/unplug check requires operator and physical device; mocks tested in T13")
def test_T13_physical_webcam_manual():
    pass
