import pytest
from face.prototype.config import PrototypeConfig
from face.prototype.selector import EligibleFaceSelector
from face.prototype.types import Box, FaceCandidate


@pytest.fixture
def config():
    return PrototypeConfig()


@pytest.fixture
def front():
    return FaceCandidate(Box(230, 140, 180, 200), 150.0, 120.0)


@pytest.fixture
def selector(config):
    return EligibleFaceSelector(config)


@pytest.fixture
def single(selector, front):
    return selector.select(640, 480, [front])


@pytest.fixture
def empty(selector):
    return selector.select(640, 480, [])


def make_ready(machine, selection, start=0.0):
    # Realistic 8 Hz observations, not just two distant timestamps.
    for i in range(7):
        machine.observe(selection, start + i * 0.125)
    return start + 0.75
