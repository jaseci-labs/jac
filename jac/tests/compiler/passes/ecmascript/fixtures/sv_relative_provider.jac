"""Analytics microservice reached by a sibling via a *relative* `sv import`.

Companion to `sv_relative_consumer.jac` — the consumer imports this with the
relative form `sv import from .sv_relative_provider { ... }`. Regression target
for #6507: a relative sv import must produce the same HTTP client stubs an
absolute one does.
"""

obj AnalyticsReport {
    has count: int = 0,
        label: str = "";
}

def:pub analyze(count: int) -> AnalyticsReport {
    return AnalyticsReport(count=count, label="analyzed");
}

walker:pub Analyze {
    has count: int;

    can run with Root entry {
        report AnalyticsReport(count=self.count, label="walker-analyzed");
    }
}
