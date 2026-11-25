"""Records each `on_drain` hook and the walker with the pid that ran it, in the
file HOOK_MARK names. The last hook outlasts the drain budget the test sets."""

import os;
import time;
import from jaclang.server.serving.drain { on_drain }

def _mark(stage: str) {
    with open(os.environ["HOOK_MARK"], "a") as f {
        f.write(f"{stage} {os.getpid()}\n");
    }
}

@on_drain
def stop_background_work {
    _mark("decorated");
}

with entry {
    _mark("entry");
    on_drain(lambda { _mark("called"); });
    on_drain(lambda { time.sleep(3); });
}

walker:pub slow {
    can go with Root entry {
        _mark("walker");
        time.sleep(1.5);
        report "done";
    }
}
