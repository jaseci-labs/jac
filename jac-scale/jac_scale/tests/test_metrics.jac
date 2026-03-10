"""Tests for Prometheus metrics integration."""

import from jac_scale.abstractions.metrics { NoOpMetricsCollector }
import from jac_scale.factories.utility_factory { UtilityFactory }
import from jac_scale.utilities.metrics.prometheus_metrics { PrometheusMetricsCollector }

# --- NoOpMetricsCollector tests ---
test "noop is disabled" {
    collector = NoOpMetricsCollector();
    assert collector.is_enabled() is False;
}

test "noop methods do nothing" {
    collector = NoOpMetricsCollector();

    # These should not raise any exceptions
    collector.request_started();
    collector.request_finished();
    collector.record_request("GET", "/test", 200, 0.5);
    collector.record_walker("TestWalker", 0.1, True);
}

test "noop endpoint handler returns callable" {
    collector = NoOpMetricsCollector();
    handler = collector.get_endpoint_handler();
    assert callable(handler);
}

# --- PrometheusMetricsCollector tests ---
glob ENABLED_CONFIG: dict = {
         "enabled": True,
         "namespace": "test_app",
         "walker_metrics": True,
         "histogram_buckets": [0.01, 0.1, 1.0]
     },
     DISABLED_CONFIG: dict = {"enabled": False};

test "prometheus enabled when configured" {
    collector = PrometheusMetricsCollector(config=ENABLED_CONFIG);
    assert collector.is_enabled() is True;
}

test "prometheus disabled when configured" {
    collector = PrometheusMetricsCollector(config=DISABLED_CONFIG);
    assert collector.is_enabled() is False;
}

test "prometheus uses custom namespace" {
    collector = PrometheusMetricsCollector(config=ENABLED_CONFIG);
    assert collector._namespace == "test_app";
}

test "prometheus walker metrics enabled" {
    collector = PrometheusMetricsCollector(config=ENABLED_CONFIG);
    assert collector._include_walker_metrics is True;
    assert collector._walker_latency is not None;
}

test "prometheus walker metrics disabled by default" {
    config = {"enabled": True, "namespace": "test_no_walker"};
    collector = PrometheusMetricsCollector(config=config);
    assert collector._include_walker_metrics is False;
    assert collector._walker_latency is None;
}

test "prometheus record request does not raise" {
    collector = PrometheusMetricsCollector(config=ENABLED_CONFIG);
    collector.record_request("GET", "/api/test", 200, 0.05);
    collector.record_request("POST", "/api/create", 201, 0.1);
    collector.record_request("GET", "/api/error", 500, 0.02);
}

test "prometheus active requests tracking" {
    collector = PrometheusMetricsCollector(config=ENABLED_CONFIG);
    collector.request_started();
    collector.request_started();
    collector.request_finished();
    collector.request_finished();
}

test "prometheus walker recording" {
    collector = PrometheusMetricsCollector(config=ENABLED_CONFIG);
    collector.record_walker("MyWalker", 0.5, True);
    collector.record_walker("FailingWalker", 1.0, False);
}

test "prometheus endpoint handler returns response" {
    collector = PrometheusMetricsCollector(config=ENABLED_CONFIG);
    handler = collector.get_endpoint_handler();
    response = handler();

    assert response.status_code == 200;
    assert "text" in response.media_type or "openmetrics" in response.media_type;
}

# --- UtilityFactory metrics tests ---
test "factory returns noop when disabled" {
    config = {"enabled": False};
    collector = UtilityFactory.create_metrics("prometheus", config);
    assert isinstance(collector, NoOpMetricsCollector);
}

test "factory returns noop when no config" {
    collector = UtilityFactory.create_metrics("prometheus", None);
    assert isinstance(collector, NoOpMetricsCollector);
}

test "factory returns prometheus when enabled" {
    config = {"enabled": True, "namespace": "factory_test"};
    collector = UtilityFactory.create_metrics("prometheus", config);
    assert isinstance(collector, PrometheusMetricsCollector);
    assert collector.is_enabled() is True;
}

test "factory returns noop for none type" {
    config = {"enabled": True};
    collector = UtilityFactory.create_metrics("none", config);
    assert isinstance(collector, NoOpMetricsCollector);
}

test "factory raises for unsupported type" {
    config = {"enabled": True};
    raised = False;
    try {
        UtilityFactory.create_metrics("unsupported", config);
    } except ValueError as e {
        raised = True;
        assert "Unsupported metrics type" in str(e);
    }
    assert raised , "Expected ValueError for unsupported metrics type";
}

# --- MetricsCollector interface compliance tests ---
test "noop implements interface" {
    collector = NoOpMetricsCollector();
    assert hasattr(collector, "init");
    assert hasattr(collector, "record_request");
    assert hasattr(collector, "request_started");
    assert hasattr(collector, "request_finished");
    assert hasattr(collector, "record_walker");
    assert hasattr(collector, "get_endpoint_handler");
    assert hasattr(collector, "is_enabled");
}

test "prometheus implements interface" {
    collector = PrometheusMetricsCollector(
        config={"enabled": True, "namespace": "iface_test"}
    );
    assert hasattr(collector, "init");
    assert hasattr(collector, "record_request");
    assert hasattr(collector, "request_started");
    assert hasattr(collector, "request_finished");
    assert hasattr(collector, "record_walker");
    assert hasattr(collector, "get_endpoint_handler");
    assert hasattr(collector, "is_enabled");
}

# --- Prometheus text parsing and summary tests ---
test "parse prometheus text and calculate summary" {
    import from jac_scale.admin.admin_portal {
        _parse_prometheus_text,
        _calculate_metrics_summary
    }

    raw = (
        "# HELP http_requests_total Total HTTP requests\n"
        "# TYPE http_requests_total counter\n"
        "http_requests_total{method=\"GET\",status_code=\"200\"} 100\n"
        "http_requests_total{method=\"POST\",status_code=\"500\"} 5\n"
        "# HELP requests_in_progress Active requests\n"
        "# TYPE requests_in_progress gauge\n"
        "requests_in_progress 3\n"
        "# HELP request_duration_seconds Request latency\n"
        "# TYPE request_duration_seconds histogram\n"
        "request_duration_seconds_sum 2.5\n"
        "request_duration_seconds_count 50\n"
    );

    metrics = _parse_prometheus_text(raw);

    # Should parse 3 metric families
    assert len(metrics) == 3;
    assert metrics[0]['name'] == 'http_requests_total';
    assert metrics[0]['type'] == 'counter';
    assert len(metrics[0]['values']) == 2;
    assert metrics[0]['values'][0]['labels']['method'] == 'GET';
    assert metrics[0]['values'][0]['value'] == 100.0;

    summary = _calculate_metrics_summary(metrics);

    assert summary['total_requests'] == 105;
    assert summary['error_count'] == 5;
    assert summary['active_requests'] == 3;
    assert summary['avg_latency_ms'] == 50.0;
}

# --- Admin metrics endpoint integration tests ---
import shutil;
import tempfile;
import from pathlib { Path }
import from jac_scale.tests.scale_test_client { ScaleTestClient }

glob FIXTURES_DIR: str = str(Path(__file__).parent / "fixtures");

test "admin metrics endpoint returns valid response" {
    tmp = tempfile.mkdtemp();
    try {
        # Copy fixture files to temp dir for isolation
        import glob as glob_mod;
        for f in glob_mod.glob(str(Path(FIXTURES_DIR) / "*")) {
            dest = Path(tmp) / Path(f).name;
            if Path(f).is_file() {
                shutil.copy2(f, dest);
            }
        }
        client = ScaleTestClient.from_file(
            str(Path(FIXTURES_DIR) / "test_api.jac"), base_path=tmp
        );
        try {
            token = client.admin_login();
            response = client.get(
                "/admin/metrics", headers={"Authorization": f"Bearer {token}"}
            );
            assert response.status_code == 200;
            data = response.json();
            assert data["ok"] is True;
            assert "enabled" in data["data"];
            assert "metrics" in data["data"];
        } finally {
            client.close();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "admin metrics endpoint requires authentication" {
    tmp = tempfile.mkdtemp();
    try {
        import glob as glob_mod;
        for f in glob_mod.glob(str(Path(FIXTURES_DIR) / "*")) {
            dest = Path(tmp) / Path(f).name;
            if Path(f).is_file() {
                shutil.copy2(f, dest);
            }
        }
        client = ScaleTestClient.from_file(
            str(Path(FIXTURES_DIR) / "test_api.jac"), base_path=tmp
        );
        try {
            response = client.get("/admin/metrics");
            assert response.status_code == 403;
            data = response.json();
            assert data["ok"] is False;
        } finally {
            client.close();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
