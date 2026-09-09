import logging;
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.datatypes { JSONResponse }
import from jaclang.server.serving.drain { DrainState }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }

glob logger: logging.Logger = logging.getLogger(__name__);


obj ReadinessCheck {
    has name: str,
        probe: Callable[[], bool];
}


def register_health_endpoints(
    app: ServingApp, drain: DrainState, checks: (list[ReadinessCheck] | None) = None
) {
    probes: list[ReadinessCheck] = list(checks or []);

    async def health_live -> JSONResponse {
        return JSONResponse(content={'status': 'alive'});
    }

    async def health_legacy -> JSONResponse {
        return JSONResponse(content={'status': 'ok'});
    }

    async def health_ready -> JSONResponse {
        if drain.draining {
            resp = JSONResponse(
                status_code=503, content={'status': 'draining', 'ready': False}
            );
            resp.headers.set('Retry-After', '1');
            return resp;
        }
        failing: list[str] = [];
        for check in probes {
            try {
                ok = bool(check.probe());
            } except Exception as e {
                logger.warning(f"readiness check {check.name} raised: {e}");
                ok = False;
            }
            if not ok {
                failing.append(check.name);
            }
        }
        if failing {
            return JSONResponse(
                status_code=503,
                content={'status': 'not_ready', 'ready': False, 'failing': failing}
            );
        }
        return JSONResponse(content={'status': 'ready', 'ready': True});
    }

    for (path, cb, summary, description) in [
        (
            '/healthz/live',
            health_live,
            'Liveness check',
            'Returns 200 while the server process is alive. Drives the '
            'Kubernetes livenessProbe.'
        ),
        (
            '/healthz/ready',
            health_ready,
            'Readiness check',
            'Returns 200 while this instance should receive traffic and 503 '
            'while it drains for shutdown or a readiness check fails. Drives '
            'the Kubernetes readinessProbe.'
        ),
        (
            '/healthz',
            health_legacy,
            'Liveness check (legacy)',
            'Back-compat alias of /healthz/live; answers {"status": "ok"}.'
        )
    ] {
        app.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path=path,
                callback=cb,
                parameters=[],
                tags=['Health'],
                summary=summary,
                description=description,
                forward_undeclared_query_params=False
            )
        );
    }
}
