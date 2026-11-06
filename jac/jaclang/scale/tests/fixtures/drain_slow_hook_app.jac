"""A hook that outlasts the drain budget, and a walker that fits inside it."""

import time;

@on_drain
def slow_hook {
    time.sleep(3);
}

walker:pub slow {
    can go with Root entry {
        time.sleep(1.5);
        report "done";
    }
}
