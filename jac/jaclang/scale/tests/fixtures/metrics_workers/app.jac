"""Fixture for multi-worker metrics tests: a quick walker and one that holds its worker."""

import time;

walker:pub Ping {
    can go with Root entry {
        report "pong";
    }
}

walker:pub Hold {
    has seconds: float = 60.0;

    can go with Root entry {
        time.sleep(self.seconds);
        report "released";
    }
}
