"""Fixture for multi-worker metrics tests.

The app defines a counter of its own, so prometheus_client is imported while
the application loads: an entry point that opens the shared metrics directory
any later than that fixes every metric in this process to memory. One walker
names the worker that served it, another holds its worker until the request is
abandoned.
"""

import os;
import time;
import from prometheus_client { Counter }

glob APP_PINGS: any = Counter(
         "app_pings_total", "Pings counted by the app itself"
     );

walker:pub Ping {
    can go with Root entry {
        APP_PINGS.inc();
        report os.getpid();
    }
}

walker:pub Hold {
    has seconds: float = 60.0;

    can go with Root entry {
        time.sleep(self.seconds);
        report "released";
    }
}
