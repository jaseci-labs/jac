"""Records each `on_drain` hook with the pid that ran it, in the file HOOK_MARK names."""

import asyncio;
import os;

def _mark(stage: str) {
    with open(os.environ["HOOK_MARK"], "a") as f {
        f.write(f"{stage} {os.getpid()}\n");
    }
}

@on_drain
def stop_background_work {
    _mark("decorated");
}

@on_drain
async def flush_async {
    await asyncio.sleep(0);
    _mark("async");
}

with entry {
    _mark("entry");
    on_drain(lambda { _mark("called"); });
}

walker:pub ping {
    can go with Root entry {
        report "pong";
    }
}
