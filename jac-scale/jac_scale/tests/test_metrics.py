"""Tests for Prometheus metrics integration."""

from typing import Any

import pytest

try:
    from ..abstractions.metrics import NoOpMetricsCollector
    from ..factories.utility_factory import UtilityFactory
    from ..utilities.metrics.prometheus_metrics import PrometheusMetricsCollector
except ImportError:
    pytest.skip("Jac modules not compiled", allow_module_level=True)


class TestNoOpMetricsCollector:
    """Tests for NoOpMetricsCollector."""

    def test_noop_is_disabled(self) -> None:
        """NoOpMetricsCollector should always report disabled."""
        collector = NoOpMetricsCollector()
        assert collector.is_enabled() is False

    def test_noop_methods_do_nothing(self) -> None:
        """NoOpMetricsCollector methods should not raise errors."""
        collector = NoOpMetricsCollector()

        # These should not raise any exceptions
        collector.request_started()
        collector.request_finished()
        collector.record_request("GET", "/test", 200, 0.5)
        collector.record_walker("TestWalker", 0.1, True)

    def test_noop_endpoint_handler_returns_callable(self) -> None:
        """NoOpMetricsCollector should return a callable handler."""
        collector = NoOpMetricsCollector()
        handler = collector.get_endpoint_handler()
        assert callable(handler)


class TestPrometheusMetricsCollector:
    """Tests for PrometheusMetricsCollector."""

    @pytest.fixture
    def enabled_config(self) -> dict[str, Any]:
        """Return config with metrics enabled."""
        return {
            "enabled": True,
            "namespace": "test_app",
            "walker_metrics": True,
            "histogram_buckets": [0.01, 0.1, 1.0],
        }

    @pytest.fixture
    def disabled_config(self) -> dict[str, Any]:
        """Return config with metrics disabled."""
        return {"enabled": False}

    def test_prometheus_enabled_when_configured(
        self, enabled_config: dict[str, Any]
    ) -> None:
        """PrometheusMetricsCollector should be enabled with proper config."""
        collector = PrometheusMetricsCollector(config=enabled_config)
        assert collector.is_enabled() is True

    def test_prometheus_disabled_when_configured(
        self, disabled_config: dict[str, Any]
    ) -> None:
        """PrometheusMetricsCollector should respect enabled=False."""
        collector = PrometheusMetricsCollector(config=disabled_config)
        assert collector.is_enabled() is False

    def test_prometheus_uses_custom_namespace(
        self, enabled_config: dict[str, Any]
    ) -> None:
        """PrometheusMetricsCollector should use configured namespace."""
        collector = PrometheusMetricsCollector(config=enabled_config)
        assert collector._namespace == "test_app"

    def test_prometheus_walker_metrics_enabled(
        self, enabled_config: dict[str, Any]
    ) -> None:
        """PrometheusMetricsCollector should enable walker metrics when configured."""
        collector = PrometheusMetricsCollector(config=enabled_config)
        assert collector._include_walker_metrics is True
        assert collector._walker_latency is not None

    def test_prometheus_walker_metrics_disabled_by_default(self) -> None:
        """PrometheusMetricsCollector should disable walker metrics by default."""
        config = {"enabled": True, "namespace": "test_no_walker"}
        collector = PrometheusMetricsCollector(config=config)
        assert collector._include_walker_metrics is False
        assert collector._walker_latency is None

    def test_prometheus_record_request_does_not_raise(
        self, enabled_config: dict[str, Any]
    ) -> None:
        """Recording a request should not raise exceptions."""
        collector = PrometheusMetricsCollector(config=enabled_config)
        collector.record_request("GET", "/api/test", 200, 0.05)
        collector.record_request("POST", "/api/create", 201, 0.1)
        collector.record_request("GET", "/api/error", 500, 0.02)

    def test_prometheus_active_requests_tracking(
        self, enabled_config: dict[str, Any]
    ) -> None:
        """Active requests gauge should work without errors."""
        collector = PrometheusMetricsCollector(config=enabled_config)
        collector.request_started()
        collector.request_started()
        collector.request_finished()
        collector.request_finished()

    def test_prometheus_walker_recording(self, enabled_config: dict[str, Any]) -> None:
        """Walker execution recording should work when enabled."""
        collector = PrometheusMetricsCollector(config=enabled_config)
        collector.record_walker("MyWalker", 0.5, True)
        collector.record_walker("FailingWalker", 1.0, False)

    def test_prometheus_endpoint_handler_returns_response(
        self, enabled_config: dict[str, Any]
    ) -> None:
        """Metrics endpoint handler should return a Response with Prometheus format."""
        collector = PrometheusMetricsCollector(config=enabled_config)
        handler = collector.get_endpoint_handler()
        response = handler()

        assert response.status_code == 200
        # Should be text/plain or openmetrics format
        assert "text" in response.media_type or "openmetrics" in response.media_type


class TestUtilityFactoryMetrics:
    """Tests for UtilityFactory.create_metrics method."""

    def test_factory_returns_noop_when_disabled(self) -> None:
        """Factory should return NoOpMetricsCollector when disabled."""
        config = {"enabled": False}
        collector = UtilityFactory.create_metrics("prometheus", config)
        assert isinstance(collector, NoOpMetricsCollector)

    def test_factory_returns_noop_when_no_config(self) -> None:
        """Factory should return NoOpMetricsCollector with no config."""
        collector = UtilityFactory.create_metrics("prometheus", None)
        assert isinstance(collector, NoOpMetricsCollector)

    def test_factory_returns_prometheus_when_enabled(self) -> None:
        """Factory should return PrometheusMetricsCollector when enabled."""
        config = {"enabled": True, "namespace": "factory_test"}
        collector = UtilityFactory.create_metrics("prometheus", config)
        assert isinstance(collector, PrometheusMetricsCollector)
        assert collector.is_enabled() is True

    def test_factory_returns_noop_for_none_type(self) -> None:
        """Factory should return NoOpMetricsCollector for 'none' type."""
        config = {"enabled": True}
        collector = UtilityFactory.create_metrics("none", config)
        assert isinstance(collector, NoOpMetricsCollector)

    def test_factory_raises_for_unsupported_type(self) -> None:
        """Factory should raise ValueError for unsupported metrics type."""
        config = {"enabled": True}
        with pytest.raises(ValueError, match="Unsupported metrics type"):
            UtilityFactory.create_metrics("unsupported", config)


class TestMetricsInterface:
    """Tests to verify MetricsCollector interface compliance."""

    def test_noop_implements_interface(self) -> None:
        """NoOpMetricsCollector should implement all interface methods."""
        collector = NoOpMetricsCollector()
        assert hasattr(collector, "init")
        assert hasattr(collector, "record_request")
        assert hasattr(collector, "request_started")
        assert hasattr(collector, "request_finished")
        assert hasattr(collector, "record_walker")
        assert hasattr(collector, "get_endpoint_handler")
        assert hasattr(collector, "is_enabled")

    def test_prometheus_implements_interface(self) -> None:
        """PrometheusMetricsCollector should implement all interface methods."""
        collector = PrometheusMetricsCollector(
            config={"enabled": True, "namespace": "iface_test"}
        )
        assert hasattr(collector, "init")
        assert hasattr(collector, "record_request")
        assert hasattr(collector, "request_started")
        assert hasattr(collector, "request_finished")
        assert hasattr(collector, "record_walker")
        assert hasattr(collector, "get_endpoint_handler")
        assert hasattr(collector, "is_enabled")
