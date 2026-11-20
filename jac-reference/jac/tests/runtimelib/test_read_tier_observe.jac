"""A read-tier retry is an operator-visible event.

Writer demotion is per-process: every replica re-learns which units write
by paying one `ReadOnlyRetry` per writing unit key per TTL window, and on a
rolling deploy every new replica does so at once against live traffic. The
conflict loop used to swallow that silently. It now reports each retry
through one seam - an info log naming the unit key, plus the metrics
collector the serving layer injects into the execution manager - so a
post-deploy latency blip can be correlated with re-learning.
"""

import inspect;
import logging;
import from jaclang.server.server { ExecutionManager, observe_read_tier_retry }


obj FakeMetrics {
    has seen: list[str] = [];

    def record_read_tier_retry(unit_key: str) {
        self.seen.append(unit_key);
    }
}


class _Capture(logging.Handler) {
    def init(self: _Capture) {
        super.__init__();
        self.records: list[any] = [];
    }

    def emit(self: _Capture, record: logging.LogRecord) {
        self.records.append(record);
    }
}


def _with_capture(fn: any) -> list[str] {
    cap = _Capture();
    log = logging.getLogger("jaclang.serve");
    old_level = log.level;
    log.addHandler(cap);
    log.setLevel(logging.INFO);
    try {
        fn();
    } finally {
        log.removeHandler(cap);
        log.setLevel(old_level);
    }
    return [
        r.getMessage()
        for r in cap.records
        if r.levelno == logging.INFO
    ];
}


test "read tier: a retry is logged at info with the unit key and counted" {
    metrics = FakeMetrics();
    msgs = _with_capture(
        lambda() { observe_read_tier_retry(metrics, "walker:app.place_order"); }
    );
    assert any(("walker:app.place_order" in m) for m in msgs) , (
        f"the retry must be logged with its unit key, got {msgs}"
    );
    assert metrics.seen == ["walker:app.place_order"];
}


test "read tier: a retry with no metrics collector still logs" {
    msgs = _with_capture(lambda() { observe_read_tier_retry(None, "fn:app.report"); });
    assert any(("fn:app.report" in m) for m in msgs);
}


test "read tier: the execution manager carries an injectable metrics collector" {
    params = inspect.signature(ExecutionManager).parameters;
    assert "metrics" in params , (
        "the serving layer injects its collector into ExecutionManager so the "
        "conflict loop can count retries without importing the scale package"
    );
    assert params["metrics"].`default is None;
}
