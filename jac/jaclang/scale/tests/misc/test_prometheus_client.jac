import sys;
import from unittest.mock { patch, MagicMock }
import from jaclang.scale.observability { prometheus_client }


test "prometheus_client does not eager-import requests and degrades without it" {
    # The serve admin/observability mixins pull this module into the serve
    # import chain. `requests` is outside the base serve closure, so importing
    # it at module level made microservice pods crash at serve (issue #7070).
    # It must not be bound at module scope; it is only touched lazily in a query.
    assert not hasattr(prometheus_client, "requests");

    # With a Prometheus URL resolved but `requests` unavailable at call time, a
    # query must return None gracefully instead of raising ImportError, and the
    # missing-requests warning must fire once, not on every call.
    prometheus_client._warned_once.clear();
    fake_logger = MagicMock();
    with patch.object(
        prometheus_client, "resolve_prometheus_url", lambda : "http://localhost:9090"
    ) {
        with patch.object(prometheus_client, "logger", fake_logger) {
            with patch.dict(sys.modules, {"requests": None}) {
                assert prometheus_client.query("up") is None;
                assert prometheus_client.query("up") is None;
                assert prometheus_client.query_range("up", 0.0, 1.0) is None;
            }
        }
    }
    assert fake_logger.warning.call_count == 1;
}
