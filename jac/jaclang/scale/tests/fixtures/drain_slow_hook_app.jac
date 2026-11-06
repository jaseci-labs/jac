"""A hook that outlasts the drain budget, and a walker that fits inside it and
touches the file WALKER_MARK names once it has started."""

import os;
import time;
import from pathlib { Path }

@on_drain
def slow_hook {
    time.sleep(3);
}

walker:pub slow {
    can go with Root entry {
        Path(os.environ["WALKER_MARK"]).touch();
        time.sleep(1.5);
        report "done";
    }
}
