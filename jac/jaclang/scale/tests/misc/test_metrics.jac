import from jaclang.scale.observability.metrics { NoOpMetricsCollector }
import from jaclang.scale.observability.factory { UtilityFactory }
import from jaclang.scale.observability.prometheus_metrics {
    PrometheusMetricsCollector
}

test "noop is disabled" {
    collector = NoOpMetricsCollector();
    assert collector.is_enabled() is False;
}

test "noop endpoint handler returns callable" {
    collector = NoOpMetricsCollector();
    handler = collector.get_endpoint_handler();
    assert callable(handler);
}

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

test "prometheus endpoint handler returns response" {
    collector = PrometheusMetricsCollector(config=ENABLED_CONFIG);
    handler = collector.get_endpoint_handler();
    response = handler();

    assert response.status_code == 200;
    assert "text" in response.media_type or "openmetrics" in response.media_type;
}

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

test "parse prometheus text and calculate summary" {
    import from jaclang.scale.admin.admin_portal {
        _parse_prometheus_text,
        _calculate_metrics_summary
    }

    raw = (
        "# HELP http_requests_total Total HTTP requests\n"
        "# TYPE http_requests_total counter\n"
        "http_requests_total{method=\"GET\",path=\"/walker/Hello\",status_code=\"200\"} 100\n"
        "http_requests_total{method=\"POST\",path=\"/walker/Hello\",status_code=\"500\"} 5\n"
        "http_requests_total{method=\"POST\",path=\"/walker/Hello\",status_code=\"404\"} 7\n"
        "http_requests_total{method=\"GET\",path=\"/admin/metrics\",status_code=\"200\"} 40\n"
        "http_requests_total{method=\"GET\",path=\"/healthz\",status_code=\"200\"} 30\n"
        "http_requests_total{method=\"GET\",path=\"/metrics\",status_code=\"200\"} 20\n"
        "# HELP requests_in_progress Active requests\n"
        "# TYPE requests_in_progress gauge\n"
        "requests_in_progress 3\n"
        "# HELP request_duration_seconds Request latency\n"
        "# TYPE request_duration_seconds histogram\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/walker/Hello\",le=\"0.1\"} 80\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/walker/Hello\",le=\"0.5\"} 100\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/walker/Hello\",le=\"+Inf\"} 100\n"
        "request_duration_seconds_bucket{method=\"POST\",path=\"/walker/Hello\",le=\"0.1\"} 0\n"
        "request_duration_seconds_bucket{method=\"POST\",path=\"/walker/Hello\",le=\"0.5\"} 2\n"
        "request_duration_seconds_bucket{method=\"POST\",path=\"/walker/Hello\",le=\"+Inf\"} 12\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/admin/metrics\",le=\"0.1\"} 40\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/admin/metrics\",le=\"0.5\"} 40\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/admin/metrics\",le=\"+Inf\"} 40\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/healthz\",le=\"0.1\"} 30\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/healthz\",le=\"0.5\"} 30\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/healthz\",le=\"+Inf\"} 30\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/metrics\",le=\"0.1\"} 20\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/metrics\",le=\"0.5\"} 20\n"
        "request_duration_seconds_bucket{method=\"GET\",path=\"/metrics\",le=\"+Inf\"} 20\n"
        "request_duration_seconds_sum 12.5\n"
        "request_duration_seconds_count 202\n"
    );

    metrics = _parse_prometheus_text(raw);

    assert len(metrics) == 3;
    assert metrics[0]['name'] == 'http_requests_total';
    assert metrics[0]['type'] == 'counter';
    assert len(metrics[0]['values']) == 6;
    assert metrics[0]['values'][0]['labels']['method'] == 'GET';
    assert metrics[0]['values'][0]['value'] == 100.0;

    summary = _calculate_metrics_summary(metrics);
    assert summary['active_requests'] == 3;

    scopes = summary['scopes'];
    assert scopes['all']['requests'] == 202;
    assert scopes['all']['server_errors'] == 5;
    assert scopes['all']['client_errors'] == 7;
    assert scopes['app']['requests'] == 112;
    assert scopes['app']['server_errors'] == 5;
    assert scopes['app']['client_errors'] == 7;
    assert scopes['other']['requests'] == 90;
    assert scopes['other']['server_errors'] == 0;
    assert scopes['other']['client_errors'] == 0;

    app_p50 = scopes['app']['p50'];
    assert app_p50['known'] and not app_p50['over'];
    assert abs(app_p50['value'] - 0.07) < 1e-9;
    assert scopes['app']['p95']['over'];
    assert scopes['app']['p95']['value'] == 0.5;
    assert scopes['app']['p99']['over'];

    labels = [g['label'] for g in scopes['app']['distribution']];
    counts = [g['count'] for g in scopes['app']['distribution']];
    assert labels
        == ['under 25ms', '25 - 100ms', '100 - 500ms', '500ms - 2.5s', 'over 2.5s'];
    assert counts == [0, 80, 22, 0, 10];

    endpoints = summary['endpoints'];
    assert [(e['method'], e['path']) for e in endpoints]
        == [
            ('POST', '/walker/Hello'),
            ('GET', '/walker/Hello'),
            ('GET', '/admin/metrics'),
            ('GET', '/healthz'),
            ('GET', '/metrics')
        ];
    post_hello = endpoints[0];
    assert post_hello['kind'] == 'app';
    assert post_hello['count'] == 12;
    assert post_hello['failed'] == 12;
    assert post_hello['p95']['over'] and post_hello['p95']['value'] == 0.5;
    get_hello = endpoints[1];
    assert get_hello['count'] == 100 and get_hello['failed'] == 0;
    assert abs(get_hello['p50']['value'] - 0.0625) < 1e-9;
    assert abs(get_hello['p95']['value'] - 0.4) < 1e-9;
    assert [e['kind'] for e in endpoints[2:]] == ['admin', 'health', 'system'];
}

test "metrics summary over a real collector exposition" {
    import from jaclang.scale.admin.admin_portal {
        _parse_prometheus_text,
        _calculate_metrics_summary
    }

    collector = PrometheusMetricsCollector(config=ENABLED_CONFIG);
    collector.record_request("GET", "/walker/Hello", 200, 0.02);
    collector.record_request("GET", "/walker/Hello", 200, 0.3);
    collector.record_request("POST", "/walker/Hello", 500, 1.2);
    collector.record_request("GET", "/healthz", 200, 0.001);
    collector.record_request("GET", "/metrics", 200, 0.005);
    collector.request_started();

    summary = _calculate_metrics_summary(
        _parse_prometheus_text(collector.expose().decode("utf-8"))
    );

    assert summary["active_requests"] == 1;
    assert summary["scopes"]["app"]["requests"] == 3;
    assert summary["scopes"]["app"]["server_errors"] == 1;
    assert summary["scopes"]["app"]["client_errors"] == 0;
    assert summary["scopes"]["other"]["requests"] == 2;
    assert summary["scopes"]["all"]["requests"] == 5;

    endpoints = summary["endpoints"];
    assert endpoints[0]["method"] == "POST" and endpoints[0]["path"] == "/walker/Hello";
    assert endpoints[0]["p95"]["over"] and endpoints[0]["p95"]["value"] == 1.0;
    kinds = {e["path"]: e["kind"] for e in endpoints};
    assert kinds
        == {"/walker/Hello": "app", "/healthz": "health", "/metrics": "system"};
    assert sum([g["count"] for g in summary["scopes"]["app"]["distribution"]]) == 3;
}

test "metrics summary percentiles from bucket edges" {
    import from jaclang.scale.admin.admin_portal { _percentile_from_buckets }

    assert _percentile_from_buckets([], 0.5)
        == {'value': 0.0, 'over': False, 'known': False};

    inf = float('inf');
    empty = [{'le': 0.1, 'count': 0.0}, {'le': inf, 'count': 0.0}];
    assert _percentile_from_buckets(empty, 0.5)['known'] is False;

    buckets = [
        {'le': 0.1, 'count': 10.0},
        {'le': 0.5, 'count': 20.0},
        {'le': inf, 'count': 20.0}
    ];
    assert _percentile_from_buckets(buckets, 0.5)
        == {'value': 0.1, 'over': False, 'known': True};
    assert _percentile_from_buckets(buckets, 0.95)
        == {'value': 0.46, 'over': False, 'known': True};

    tail = [{'le': 0.1, 'count': 1.0}, {'le': inf, 'count': 10.0}];
    assert _percentile_from_buckets(tail, 0.5)
        == {'value': 0.1, 'over': True, 'known': True};
}

test "metrics summary classifies platform paths out of the app scope" {
    import from jaclang.scale.admin.admin_portal { _classify_path }

    assert _classify_path('/walker/Hello') == 'app';
    assert _classify_path('/') == 'app';
    assert _classify_path('/cl/main.js') == 'app';
    assert _classify_path('/healthcheck') == 'app';
    assert _classify_path('/health') == 'health';
    assert _classify_path('/healthz') == 'health';
    assert _classify_path('/admin/metrics') == 'admin';
    assert _classify_path('/metrics') == 'system';
    assert _classify_path('/docs') == 'system';
    assert _classify_path('/openapi.json') == 'system';
}

import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.tests.scale_test_client { ScaleTestClient }

glob FIXTURES_DIR: str = str(Path(__file__).parent.parent / "fixtures");

test "admin metrics endpoint returns valid response" {
    tmp = tempfile.mkdtemp();
    try {
        import glob as glob_mod;
        for f in glob_mod.`glob(str(Path(FIXTURES_DIR) / "*")) {
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
        for f in glob_mod.`glob(str(Path(FIXTURES_DIR) / "*")) {
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


test "prometheus counts read-tier retries per unit" {
    collector = PrometheusMetricsCollector(config=ENABLED_CONFIG);
    collector.record_read_tier_retry("walker:app.place_order");
    collector.record_read_tier_retry("walker:app.place_order");
    body = collector.expose().decode("utf-8");
    assert 'test_app_read_tier_retries_total{unit="walker:app.place_order"} 2.0'
        in body , (f"read-tier retries must be exposed per unit key, got:\n{body}");
}


test "noop read-tier retry is a no-op" {
    collector = NoOpMetricsCollector();
    collector.record_read_tier_retry("walker:app.place_order");
    assert collector.expose() == b"";
}
