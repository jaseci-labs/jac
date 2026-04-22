"""Fixture for testing that blocking sync walkers run concurrently."""

import asyncio;
import from time { time }
import from threading { current_thread }

walker :pub slow_blocking {
    has duration: float = 1.0;

    can enter with Root entry {
        import from time { sleep }
        start = time();
        sleep(self.duration);
        report {
            "thread": current_thread().name,
            "duration": time() - start
        };
    }
}

async walker :pub slow_async {
    has duration: float = 1.0;

    async can enter with Root entry {
        start = time();
        await asyncio.sleep(self.duration);
        report {
            "thread": current_thread().name,
            "duration": time() - start
        };
    }
}

# Reports the caller's user_root id after yielding to the event loop.
# The sleep ensures multiple concurrent calls interleave at an await point
# between user_root resolution and the report statement — which is exactly
# the window where a shared ctx.user_root would get overwritten by another
# request.
async walker :pub whoami_async {
    has sleep_s: float = 0.1;

    async can enter with Root entry {
        import from jaclang.jac0core.runtime { JacRuntimeInterface as Jac }
        start_root_id = Jac.get_context().user_root.id.hex;
        await asyncio.sleep(self.sleep_s);
        end_root_id = Jac.get_context().user_root.id.hex;
        report {
            "start_root_id": start_root_id,
            "end_root_id": end_root_id
        };
    }
}

# Same probe as whoami_async, but the walker body is sync — to prove
# per-request isolation holds across the to_thread boundary too.
walker :pub whoami_sync {
    has sleep_s: float = 0.1;

    can enter with Root entry {
        import from time { sleep }
        import from jaclang.jac0core.runtime { JacRuntimeInterface as Jac }
        start_root_id = Jac.get_context().user_root.id.hex;
        sleep(self.sleep_s);
        end_root_id = Jac.get_context().user_root.id.hex;
        report {
            "start_root_id": start_root_id,
            "end_root_id": end_root_id
        };
    }
}
