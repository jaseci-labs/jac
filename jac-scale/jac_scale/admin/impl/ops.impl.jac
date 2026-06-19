"""Implementation of JacAPIServerOps - the signal self-check.

Two clearly separated layers:

  (a) PURE chain-evaluation helpers - `short_circuit_chain` plus the
      per-signal `_*_chain` builders. They take a flat dict of probe
      primitives and assemble `{status, chain[]}`, short-circuiting so the
      first failing rung is the diagnosis and every rung after it is marked
      `ok=None` ("skipped"). No I/O, no globals -> `test_ops_health.jac`
      exercises them with mocked probe dicts.

  (b) THIN probe functions - each does one outbound call (Tempo/Loki/
      Prometheus /ready, a Mongo/Redis ping, a recent-volume query) with a
      short timeout inside try/except, returning a primitive. They feed the
      pure builders. A dead/slow backend yields a red rung, never a 500.

Backend URLs reuse the existing resolvers `_tempo_base_url` (traces) and
`_loki_base_url` (logs); Prometheus gets a sibling resolver here.
"""
import os;
import asyncio;
import logging;
import time;
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}
import from jac_scale.config_loader { get_scale_config }
import from jac_scale.admin.traces { _tempo_base_url }
import from jac_scale.admin.logs { _loki_base_url, _app_namespace }
import from jac_scale._optdeps.prometheus { HAS_PROMETHEUS }
import from jac_scale._optdeps.opentelemetry { HAS_OTEL }
import from jac_scale.microservices.runtime.tracing { tracing_active }

glob logger = logging.getLogger(__name__),
     # Short, uniform probe budget: a dead backend must render a red row fast,
     # never hang the diagnostics endpoint.
     _PROBE_TIMEOUT_S: float = 2.0;


# =========================================================================
# (a) PURE chain-evaluation helpers - no I/O, unit-tested directly.
# =========================================================================
"""Short-circuit an ordered rung list into a `{status, chain}` result.

Each input rung is `{name, ok: bool, detail: str, gate?: bool}`. Walks in
order: every rung up to AND INCLUDING the first `ok==False` is emitted with
its real verdict; every rung after it is emitted with `ok=None` and
detail "skipped" (its probe was blocked by the earlier failure, so its
value is meaningless). The first failure IS the diagnosis.

status:
  - "ok"   : every rung passed.
  - "off"  : the first failing rung is a `gate` (a config on/off toggle,
             e.g. `tracing.enabled = false`) - amber, not an error.
  - "fail" : the first failing rung is a real check - red.
"""
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


"""Fallback signal result when a probe raises unexpectedly. Renders a
single red rung naming the error, so the endpoint never 500s."""
def _probe_error(name: str, err: any) -> dict {
    logger.warning(f"ops self-check probe '{name}' errored: {err}");
    return {
        "status": "fail",
        "chain": [{"name": "probe", "ok": False, "detail": f"self-check error: {err}"}]
    };
}


"""Traces signal chain (the `count:0` incident). Probe keys:
has_otel, cfg_enabled, active, endpoint, tempo_ready, recent_count."""
def _traces_chain(p: dict) -> dict {
    endpoint = str(p.get("endpoint", "") or "");
    count = int(p.get("recent_count", 0) or 0);
    return short_circuit_chain(
        [
            {
                "name": "jac-scale[tracing] importable (HAS_OTEL)",
                "ok": p.get("has_otel", False),
                "detail": "opentelemetry SDK present"
                    if p.get("has_otel", False)
                    else "tracing extra NOT installed (image lacks jac-scale[...,tracing])"
            },
            {
                "name": "config tracing.enabled",
                "ok": p.get("cfg_enabled", False),
                "gate": True,
                "detail": "[plugins.scale.microservices.tracing].enabled" + (
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


"""Logs signal chain. Probe keys: cfg_enabled, loki_ready, recent_count."""
def _logs_chain(p: dict) -> dict {
    count = int(p.get("recent_count", 0) or 0);
    return short_circuit_chain(
        [
            {
                "name": "config logs.enabled",
                "ok": p.get("cfg_enabled", False),
                "gate": True,
                "detail": "[plugins.scale.microservices.logs].enabled" + (
                    " = true" if p.get("cfg_enabled", False) else " = false (logs off)"
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


"""Metrics signal chain. Probe keys: has_client, prom_ready."""
def _metrics_chain(p: dict) -> dict {
    return short_circuit_chain(
        [
            {
                "name": "prometheus_client importable",
                "ok": p.get("has_client", False),
                "detail": "prometheus_client present"
                    if p.get("has_client", False)
                    else "prometheus_client NOT installed (image lacks jac-scale[...,monitoring])"
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


"""Mongo signal chain (covers the admin-login-HTML incident). Probe keys:
configured, detail, ping."""
def _mongo_chain(p: dict) -> dict {
    return short_circuit_chain(
        [
            {
                "name": "Mongo client configured",
                "ok": p.get("configured", False),
                "detail": str(p.get("detail", ""))
            },
            {
                "name": "Mongo ping reachable",
                "ok": p.get("ping", False),
                "detail": "admin.command('ping') succeeded"
                    if p.get("ping", False)
                    else "ping failed - admin API cannot bootstrap (UserManager)"
            }
        ]
    );
}


"""Redis signal chain. Probe keys: configured, detail, ping."""
def _redis_chain(p: dict) -> dict {
    return short_circuit_chain(
        [
            {
                "name": "Redis client configured",
                "ok": p.get("configured", False),
                "detail": str(p.get("detail", ""))
            },
            {
                "name": "Redis ping reachable",
                "ok": p.get("ping", False),
                "detail": "PING succeeded"
                    if p.get("ping", False)
                    else "ping failed at the resolved redis_url"
            }
        ]
    );
}


"""Admin-API signal chain. Single rung: is the JSON API registered?
A False here is the exact `_install_admin_api()` failure mode that makes
every /admin/* fall through to the SPA catchall (the HTML-not-JSON bug)."""
def _admin_api_chain(registered: bool) -> dict {
    return short_circuit_chain(
        [
            {
                "name": "admin API registered (self.server set)",
                "ok": registered,
                "detail": "self.server is set - /admin/* routes are live"
                    if registered
                    else "self.server is None - _install_admin_api() failed " + "(Mongo unreachable?); /admin/* falls to the SPA catchall"
            }
        ]
    );
}


# =========================================================================
# Config / URL resolvers (in-process reads, no I/O).
# =========================================================================
"""Prometheus base URL: PROMETHEUS_URL env -> K8s DNS -> localhost.

Mirrors `_tempo_base_url` / `_loki_base_url`. The deploy names the service
`<app>-prometheus-service:9090` (see targets/kubernetes/monitoring.jac)."""
def _prometheus_base_url -> str {
    env = os.getenv("PROMETHEUS_URL", "").strip();
    if env {
        return env.rstrip("/");
    }
    app_name = os.getenv("K8S_APP_NAME", "").strip();
    if not app_name {
        try {
            k8s_cfg = get_scale_config().get_kubernetes_config();
            raw = str(k8s_cfg.get("app_name", "") or "").strip();
            expanded = os.path.expandvars(raw);
            if expanded and "${" not in expanded {
                app_name = expanded;
            }
        } except Exception {
            app_name = "";
        }
    }
    if not app_name {
        return "http://localhost:9090";
    }
    return f"http://{app_name}-prometheus-service:9090";
}


"""Read `[plugins.scale.microservices.<section>].enabled`; False on any
lookup failure. Used for the tracing/logs config gates."""
def _ms_section_enabled(section: str) -> bool {
    try {
        ms = get_scale_config().get_microservices_config();
        return bool(ms.get(section, {}).get("enabled", False));
    } except Exception {
        return False;
    }
}


"""Mask a connection URI's credentials for safe display in the UI.

`mongodb://user:pass@host:27017/db` -> `mongodb://***@host:27017/db`.
Returns '' for a falsy uri."""
def _mask_uri(uri: str) -> str {
    if not uri {
        return "";
    }
    try {
        if "@" in uri and "://" in uri {
            scheme = uri.split("://", 1)[0];
            after = uri.split("://", 1)[1];
            # rsplit on the last '@' so a password containing '@' is masked.
            host_part = after.rsplit("@", 1)[1];
            return f"{scheme}://***@{host_part}";
        }
    } except Exception {
        return "configured";
    }
    return uri;
}


# =========================================================================
# (b) THIN probe functions - one short, guarded outbound call each.
# =========================================================================
"""GET `base + path` with a ~2s timeout. True iff status < 500.

`/ready`-style endpoints answer 200 when healthy; we treat any non-5xx as
"reachable". Any transport error / timeout -> False (a red rung)."""
async def _http_ready(base: str, path: str) -> bool {
    import httpx;
    url = base.rstrip("/") + path;
    try {
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(_PROBE_TIMEOUT_S, connect=_PROBE_TIMEOUT_S)
        ) as cl {
            resp = await cl.get(url);
            return resp.status_code < 500;
        }
    } except Exception as e {
        logger.debug(f"ready probe {url} failed: {e}");
        return False;
    }
}


"""Count traces in the last 5m via Tempo's search API (limit 1 is enough
to answer count > 0). Returns 0 on any failure."""
async def _tempo_recent_count -> int {
    import httpx;
    base = _tempo_base_url();
    now_s = int(time.time());
    params = {"q": "{ }", "limit": "1", "start": str(now_s - 300), "end": str(now_s)};
    try {
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(_PROBE_TIMEOUT_S, connect=_PROBE_TIMEOUT_S)
        ) as cl {
            resp = await cl.get(base.rstrip("/") + "/api/search", params=params);
            resp.raise_for_status();
            return len(resp.json().get("traces", []) or []);
        }
    } except Exception as e {
        logger.debug(f"tempo recent-count probe failed: {e}");
        return 0;
    }
}


"""Count log lines in the last 5m via Loki query_range (limit 1). Returns 0
on any failure. Namespace-scoped when known, else all-streams."""
async def _loki_recent_count -> int {
    import httpx;
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
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(_PROBE_TIMEOUT_S, connect=_PROBE_TIMEOUT_S)
        ) as cl {
            resp = await cl.get(
                base.rstrip("/") + "/loki/api/v1/query_range", params=params
            );
            resp.raise_for_status();
            data = resp.json().get("data", {}) or {};
            total = 0;
            for stream in (data.get("result", []) or []) {
                total += len(stream.get("values", []) or []);
            }
            return total;
        }
    } except Exception as e {
        logger.debug(f"loki recent-count probe failed: {e}");
        return 0;
    }
}


"""Blocking Mongo ping (run off the event loop via asyncio.to_thread).
True iff `admin.command('ping')` succeeds within the timeout."""
def _mongo_ping_blocking(uri: str) -> bool {
    client: any = None;
    try {
        import from pymongo { MongoClient }
        client = MongoClient(
            uri,
            serverSelectionTimeoutMS=int(_PROBE_TIMEOUT_S * 1000),
            connectTimeoutMS=int(_PROBE_TIMEOUT_S * 1000)
        );
        client.admin.command("ping");
        return True;
    } except Exception as e {
        logger.debug(f"mongo ping failed: {e}");
        return False;
    } finally {
        if client is not None {
            try {
                client.close();
            } except Exception {
                logger.debug("mongo client close failed");
            }
        }
    }
}


"""Blocking Redis ping (run off the event loop via asyncio.to_thread)."""
def _redis_ping_blocking(url: str) -> bool {
    client: any = None;
    try {
        import redis;
        client = redis.from_url(
            url,
            socket_connect_timeout=_PROBE_TIMEOUT_S,
            socket_timeout=_PROBE_TIMEOUT_S
        );
        client.ping();
        return True;
    } except Exception as e {
        logger.debug(f"redis ping failed: {e}");
        return False;
    } finally {
        if client is not None {
            try {
                client.close();
            } except Exception {
                logger.debug("redis client close failed");
            }
        }
    }
}


# =========================================================================
# Per-signal probe assemblers - gather primitives (short-circuiting the
# network calls when an in-process gate already failed) then call the pure
# builder. Wrapped in try/except by the handler so they never 500.
# =========================================================================
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


async def _probe_mongo -> dict {
    try {
        uri = str(
            get_scale_config().get_database_config().get("mongodb_uri", "") or ""
        );
    } except Exception {
        uri = "";
    }
    configured = bool(uri);
    ping = await asyncio.to_thread(_mongo_ping_blocking, uri) if configured else False;
    return _mongo_chain(
        {
            "configured": configured,
            "detail": _mask_uri(uri)
                if configured
                else "no MONGODB_URI / database.mongodb_uri",
            "ping": ping
        }
    );
}


async def _probe_redis -> dict {
    try {
        url = str(get_scale_config().get_database_config().get("redis_url", "") or "");
    } except Exception {
        url = "";
    }
    configured = bool(url);
    ping = await asyncio.to_thread(_redis_ping_blocking, url) if configured else False;
    return _redis_chain(
        {
            "configured": configured,
            "detail": _mask_uri(url)
                if configured
                else "no REDIS_URL / database.redis_url",
            "ping": ping
        }
    );
}


# =========================================================================
# Endpoint registration.
# =========================================================================
impl JacAPIServerOps.register_ops_endpoints -> None {
    # GET /admin/ops/health - the self-check. Per signal a
    # {status, chain[]} with short-circuit diagnosis. Every probe is
    # best-effort; a dead backend renders a red row, never a 500.
    async def health_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get("http_status", 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }

        signals: dict = {};

        # admin API: pure in-process read, can't fail. self.server is None
        # exactly when _install_admin_api() threw at boot.
        registered = self?.server is not None;
        signals["admin_api"] = _admin_api_chain(registered);

        # Run the probes concurrently so worst-case latency is ~one timeout,
        # not the sum. return_exceptions maps a stray failure to a red row.
        probe_names = ["traces", "logs", "metrics", "mongo", "redis"];
        results = await asyncio.gather(
            _probe_traces(),
            _probe_logs(),
            _probe_metrics(),
            _probe_mongo(),
            _probe_redis(),
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
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/ops/health",
            callback=health_handler,
            parameters=[],
            response_model=None,
            tags=["Operations"],
            summary="Signal self-check (traces/logs/metrics/mongo/redis/admin)",
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
