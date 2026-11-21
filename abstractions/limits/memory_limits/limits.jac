"""The standard limits: each actor's uses within its window, kept in
the program's memory. They are one program's own: two instances of an app
count apart."""

import threading;
import time;
import from common.contract { Host }
import from limits.contract { Limits }

"""The uses of one scope by one actor within its window."""
obj Uses {
    has seconds: int,
        times: list[float] = [];
}

obj MemoryLimits(Limits) {
    """How many actors' uses are kept before those whose window has passed
    are let go."""
    has sweep_at: int = 1024;

    has kept: dict[str, Uses] postinit;
    has turn: any postinit;
    has next_sweep: int postinit;

    def postinit {
        self.kept = {};
        self.turn = threading.Lock();
        self.next_sweep = self.sweep_at;
    }

    """Nothing to open: it keeps its counts in memory, and asks nothing of
    the program."""
    def open(host: dyn Host) {}

    """How many actors' uses are kept now."""
    def held -> int {
        return len(self.kept);
    }

    def consume(scope: str, actor: str, limit: int, seconds: int) -> int {
        key = scope + "|" + actor;
        now = time.time();
        with self.turn {
            if len(self.kept) >= self.next_sweep {
                for k in [
                    k
                    for (k, u) in self.kept.items()
                    if now - u.times[len(u.times) - 1] >= u.seconds
                ] {
                    del self.kept[k];
                }
                # Twice what is left: a sweep's cost is paid for by as many uses.
                self.next_sweep = max(self.sweep_at, 2 * len(self.kept));
            }
            was = self.kept.get(key, None);
            uses = [t for t in was.times if now - t < seconds] if was is not None else [];
            if len(uses) >= limit {
                self.kept[key] = Uses(seconds=seconds, times=uses);
                return int(seconds - (now - uses[0])) + 1;
            }
            uses.append(now);
            self.kept[key] = Uses(seconds=seconds, times=uses);
            return 0;
        }
    }
}
