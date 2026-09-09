import os;
import asyncio;
import logging;
import time;
import from jaclang.server.serving.datatypes { Request }
import from jaclang.server.serving.datatypes { JSONResponse }
import from jaclang.server.serving.endpoint {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.admin.service_urls { service_base_url }
import from jaclang.scale.admin.traces { _tempo_base_url }
import from jaclang.scale.admin.logs { _loki_base_url, _app_namespace }
import from jaclang.scale._optdeps.prometheus { HAS_PROMETHEUS }
import from jaclang.scale._optdeps.opentelemetry { HAS_OTEL }
import from jaclang.scale.runtime.context.tracing { tracing_active }

glob logger = logging.getLogger(__name__),
     _PROBE_TIMEOUT_S: float = 2.0;


def short_circuit_chain(rungs: list[dict]) -> dict {
    chain: list[dict] = [];
    status: str = "ok";
    failed: bool = False;
    for r in rungs {
        if failed {
            chain.append({"name": r["name"], "ok": None, "detail": "skipped"});
            continue;
        }
        ok = bool(r["ok"]);
        chain.append({"name": r["name"], "ok": ok, "detail": str(r.get("detail", ""))});
        if not ok {
            failed = True;
            status = "off" if r.get("gate", False) else "fail";
        }
    }
    return {"status": status, "chain": chain};
}


def _probe_error(name: str, err: any) -> dict {
    logger.warning(f"ops self-check probe '{name}' errored: {err}");
    return {
        "status": "fail",
        "chain": [{"name": "probe", "ok": False, "detail": f"self-check error: {err}"}]
    };
}


def _traces_chain(p: dict) -> dict {
    endpoint = str(p.get("endpoint", "") or "");
    count = int(p.get("recent_count", 0) or 0);
    return short_circuit_chain(
        [
            {
                "name": "'tracing' capability importable (HAS_OTEL)",
                "ok": p.get("has_otel", False),
                "detail": "opentelemetry SDK present"
                    if p.get("has_otel", False)
                    else "tracing NOT installed (image lacks the 'tracing' capability)"
            },
            {
                "name": "config tracing.enabled",
                "ok": p.get("cfg_enabled", False),
                "gate": True,
                "detail": "[scale.gateway.tracing].enabled"
                    + (
                        " = true"
                            if p.get("cfg_enabled", False)
                            else " = false (tracing off)"
                    )
            },
            {
                "name": "install_tracing() active",
                "ok": p.get("active", False),
                "detail": "tracing_active() == True"
                    if p.get("active", False)
                    else "install_tracing() ran but did not activate"
            },
            {
                "name": "OTEL_EXPORTER_OTLP_ENDPOINT set",
                "ok": bool(endpoint),
                "detail": endpoint or "env var unset"
            },
            {
                "name": "Tempo /ready reachable",
                "ok": p.get("tempo_ready", False),
                "detail": "Tempo responded to /ready"
                    if p.get("tempo_ready", False)
                    else "Tempo unreachable at the resolved service URL"
            },
            {
                "name": "traces in last 5m (count > 0)",
                "ok": count > 0,
                "detail": f"count = {count}"
            }
        ]
    );
}


def _logs_chain(p: dict) -> dict {
    count = int(p.get("recent_count", 0) or 0);
    return short_circuit_chain(
        [
            {
                "name": "config logs.enabled",
                "ok": p.get("cfg_enabled", False),
                "gate": True,
                "detail": "[scale.gateway.logs].enabled"
                    + (
                        " = true"
                            if p.get("cfg_enabled", False)
                            else " = false (logs off)"
                    )
            },
            {
                "name": "Loki /ready reachable",
                "ok": p.get("loki_ready", False),
                "detail": "Loki responded to /ready"
                    if p.get("loki_ready", False)
                    else "Loki unreachable at the resolved service URL"
            },
            {
                "name": "recent log lines (last 5m)",
                "ok": count > 0,
                "detail": f"count = {count}"
            }
        ]
    );
}


def _metrics_chain(p: dict) -> dict {
    return short_circuit_chain(
        [
            {
                "name": "prometheus_client importable",
                "ok": p.get("has_client", False),
                "detail": "prometheus_client present"
                    if p.get("has_client", False)
                    else "prometheus_client NOT installed (image lacks the 'monitoring' capability)"
            },
            {
                "name": "Prometheus reachable",
                "ok": p.get("prom_ready", False),
                "detail": "Prometheus responded to /-/ready"
                    if p.get("prom_ready", False)
                    else "Prometheus unreachable at the resolved service URL"
            }
        ]
    );
}


def _postgres_chain(p: dict) -> dict {
    return short_circuit_chain(
        [
            {
                "name": "Postgres reachable",
                "ok": p.get("ping", False),
                "detail": str(p.get("detail", ""))
            }
        ]
    );
}


def _admin_api_chain(registered: bool) -> dict {
    return short_circuit_chain(
        [
            {
                "name": "admin API registered (self.server set)",
                "ok": registered,
                "detail": "self.server is set - /admin/* routes are live"
                    if registered
                    else "self.server is None - _install_admin_api() failed "
                        + "(database unreachable?); /admin/* falls to the SPA catchall"
            }
        ]
    );
}


def _prometheus_base_url -> str {
    return service_base_url("PROMETHEUS_URL", "prometheus-service", 9090);
}


def _ms_section_enabled(section: str) -> bool {
    try {
        gw = get_scale_config().get_gateway_config();
        return bool(gw.get(section, {}).get("enabled", False));
    } except Exception {
        return False;
    }
}


def _mask_uri(uri: str) -> str {
    if not uri {
        return "";
    }
    try {
        if "@" in uri and "://" in uri {
            scheme = uri.split("://", 1)[0];
            after = uri.split("://", 1)[1];

            host_part = after.rsplit("@", 1)[1];
            return f"{scheme}://***@{host_part}";
        }
    } except Exception {
        return "configured";
    }
    return uri;
}


async def _http_ready(base: str, path: str) -> bool {
    import from jaclang.server.serving.client { arequest }
    url = base.rstrip("/") + path;
    try {
        resp = await arequest("GET", url, timeout=_PROBE_TIMEOUT_S);
        return resp.status_code < 500;
    } except Exception as e {
        logger.debug(f"ready probe {url} failed: {e}");
        return False;
    }
}


async def _tempo_recent_count -> int {
    import from jaclang.server.serving.client { arequest }
    base = _tempo_base_url();
    now_s = int(time.time());
    params = {"q": "{ }", "limit": "1", "start": str(now_s - 300), "end": str(now_s)};
    try {
        resp = await arequest(
            "GET",
            base.rstrip("/") + "/api/search",
            params=params,
            timeout=_PROBE_TIMEOUT_S
        );
        if not resp.ok() {
            raise ConnectionError(f"tempo returned {resp.status_code}");
        }
        return len(resp.json().get("traces", []) or []);
    } except Exception as e {
        logger.debug(f"tempo recent-count probe failed: {e}");
        return 0;
    }
}


async def _loki_recent_count -> int {
    import from jaclang.server.serving.client { arequest }
    base = _loki_base_url();
    ns = _app_namespace();
    selector = f'{{namespace="{ns}"}}' if ns else '{namespace=~".+"}';
    now_ns = int(time.time() * 1_000_000_000);
    params = {
        "query": selector,
        "limit": "1",
        "start": str(now_ns - 300 * 1_000_000_000),
        "end": str(now_ns),
        "direction": "backward"
    };
    try {
        resp = await arequest(
            "GET",
            base.rstrip("/") + "/loki/api/v1/query_range",
            params=params,
            timeout=_PROBE_TIMEOUT_S
        );
        if not resp.ok() {
            raise ConnectionError(f"loki returned {resp.status_code}");
        }
        data = resp.json().get("data", {}) or {};
        total = 0;
        for stream in (data.get("result", []) or []) {
            total += len(stream.get("values", []) or []);
        }
        return total;
    } except Exception as e {
        logger.debug(f"loki recent-count probe failed: {e}");
        return 0;
    }
}


def _postgres_ping_blocking -> tuple[bool, str] {
    try {
        import from jaclang.server.shared_store {
            NO_DATABASE_RESOLVED,
            shared_store,
            shared_store_failure
        }
        store = shared_store();
        if store is None {
            return (False, shared_store_failure() or NO_DATABASE_RESOLVED);
        }
        ok = store.is_available();
        return (
            ok,
            "SELECT 1 succeeded" if ok else "SELECT 1 failed at the resolved database"
        );
    } except Exception as e {
        return (False, f"probe failed: {e}");
    }
}


async def _probe_traces -> dict {
    has_otel = bool(HAS_OTEL);
    cfg_enabled = _ms_section_enabled("tracing");
    active = False;
    try {
        active = bool(tracing_active());
    } except Exception {
        active = False;
    }
    endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "").strip();
    gates_ok = has_otel and cfg_enabled and active and bool(endpoint);
    tempo_ready = await _http_ready(_tempo_base_url(), "/ready") if gates_ok else False;
    count = await _tempo_recent_count() if (gates_ok and tempo_ready) else 0;
    return _traces_chain(
        {
            "has_otel": has_otel,
            "cfg_enabled": cfg_enabled,
            "active": active,
            "endpoint": endpoint,
            "tempo_ready": tempo_ready,
            "recent_count": count
        }
    );
}


async def _probe_logs -> dict {
    cfg_enabled = _ms_section_enabled("logs");
    loki_ready = await _http_ready(_loki_base_url(), "/ready")
        if cfg_enabled
        else False;
    count = await _loki_recent_count() if (cfg_enabled and loki_ready) else 0;
    return _logs_chain(
        {"cfg_enabled": cfg_enabled, "loki_ready": loki_ready, "recent_count": count}
    );
}


async def _probe_metrics -> dict {
    has_client = bool(HAS_PROMETHEUS);
    prom_ready = await _http_ready(_prometheus_base_url(), "/-/ready")
        if has_client
        else False;
    return _metrics_chain({"has_client": has_client, "prom_ready": prom_ready});
}


async def _probe_postgres -> dict {
    (ping, detail) = await asyncio.to_thread(_postgres_ping_blocking);
    return _postgres_chain({"ping": ping, "detail": detail});
}


impl JacAPIServerOps.register_ops_endpoints -> None {
    async def health_handler(request: Request) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }

        signals: dict = {};

        registered = self?.server is not None;
        signals["admin_api"] = _admin_api_chain(registered);

        probe_names = ["traces", "logs", "metrics", "postgres"];
        results = await asyncio.gather(
            _probe_traces(),
            _probe_logs(),
            _probe_metrics(),
            _probe_postgres(),
            return_exceptions=True
        );
        for (idx, r) in enumerate(results) {
            name = probe_names[idx];
            if isinstance(r, Exception) {
                signals[name] = _probe_error(name, r);
            } else {
                signals[name] = r;
            }
        }

        return JSONResponse(content={"ok": True, "data": {"signals": signals}});
    }
    server = self.server;
    if server is None {
        return;
    }
    server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/ops/health",
            callback=health_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Signal self-check (traces/logs/metrics/postgres/admin)",
            description=(
                "Per signal a {status, chain[]} where each chain step is "
                "{name, ok, detail}, evaluated short-circuit so the first "
                "ok:false is the diagnosis. In-process reads (HAS_OTEL, "
                "config, self.server) + best-effort ~2s backend probes; a "
                "dead backend renders a red row, never a 500. No K8s API, "
                "no RBAC."
            )
        )
    );

    logger.info("Ops self-check endpoint registered: /admin/ops/health");
}
