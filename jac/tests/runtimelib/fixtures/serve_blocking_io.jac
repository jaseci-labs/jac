"""Fixture for testing that blocking sync walkers run concurrently."""

import from time { sleep, time }
import from threading { current_thread }

walker :pub slow_blocking {
    has duration: float = 1.0;

    can enter with Root entry {
        start = time();
        sleep(self.duration);
        report {
            "thread": current_thread().name,
            "duration": time() - start
        };
    }
}
