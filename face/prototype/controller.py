from .auth_client import SingleFlightWorker
from .config import PrototypeConfig
from .state_machine import AuthStateMachine, State
from .types import AuthOutcome, AuthResult, Selection


class PrototypeController:
    def __init__(self, config: PrototypeConfig, worker: SingleFlightWorker):
        self.machine = AuthStateMachine(config)
        self.worker = worker
        self.requests_sent = 0

    def update(self, now: float, selection: Selection | None = None, observation_invalid: bool = False):
        self.machine.tick(now)
        if self.machine.closed:
            return
        if self.machine.state != State.VERIFYING and self.worker.busy:
            self.worker.cancel()
        for result in self.worker.drain():
            self.machine.receive(result, now)
        if observation_invalid:
            self.machine.invalidate_observation()
        elif selection is not None:
            self.machine.observe(selection, now)
            if self.machine.state == State.READY and not self.worker.busy:
                request = self.machine.start_request(now)
                if request is not None:
                    if self.worker.submit(request):
                        self.requests_sent += 1
                    else:
                        self.machine.receive(AuthResult(request.request_id, AuthOutcome.SERVICE_ERROR), now)

    def shutdown(self):
        self.machine.shutdown()
        self.worker.shutdown()
