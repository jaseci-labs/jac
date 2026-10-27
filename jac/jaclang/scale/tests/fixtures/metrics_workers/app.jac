"""Fixture for multi-worker metrics tests.

The app defines a counter of its own, so prometheus_client is imported while
the application loads: an entry point that opens the shared metrics directory
any later than that fixes every metric in this process to memory. One walker
names the worker that served it, another holds its worker until the request is
abandoned. A scheduled function counts its own runs per worker pid, so a test
that makes every worker win a tick can tell the merged run counter covers them
all.
"""

import os;
import time;
import from prometheus_client { Counter }

glob APP_PINGS: any = Counter(
         "app_pings_total", "Pings counted by the app itself"
     ),
     APP_BEATS: any = Counter(
         "app_beats_total", "Scheduled beats counted by the app itself", ["pid"]
     );

walker:pub Ping {
    can go with Root entry {
        APP_PINGS.inc();
        report os.getpid();
    }
}

@schedule(interval=0.5)
def beat {
    APP_BEATS.labels(pid=str(os.getpid())).inc();
}

walker:pub Hold {
    has seconds: float = 60.0;

    can go with Root entry {
        time.sleep(self.seconds);
        report "released";
    }
}
