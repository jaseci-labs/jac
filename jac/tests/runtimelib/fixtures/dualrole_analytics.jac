"""Standalone analytics microservice consumed by `dualrole_guestbook` (#6507).

Reached only via a server->server `sv import`; spawned lazily on first call.
"""

obj AnalyticsReport {
    has count: int = 0,
        label: str = "";
}

walker:pub Analyze {
    has count: int;

    can run with `root entry {
        report AnalyticsReport(count=self.count, label="analyzed");
    }
}
