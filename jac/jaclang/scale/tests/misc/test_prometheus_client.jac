import sys;
import from unittest.mock { patch }
import from jaclang.scale.observability { prometheus_client }


test "prometheus_client does not eager-import requests and degrades without it" {
    # The serve admin/observability mixins pull this module into the serve
    # import chain. `requests` is outside the base serve closure, so importing
    # it at module level made microservice pods crash at serve (issue #7070).
    # It must not be bound at module scope; it is only touched lazily in a query.
    assert not hasattr(prometheus_client, "requests");

    # With a Prometheus URL resolved but `requests` unavailable at call time, a
    # query must return None gracefully instead of raising ImportError.
    with patch.object(
        prometheus_client, "resolve_prometheus_url", lambda : "http://localhost:9090"
    ) {
        with patch.dict(sys.modules, {"requests": None}) {
            assert prometheus_client.query("up") is None;
            assert prometheus_client.query_range("up", 0.0, 1.0) is None;
        }
    }
}
