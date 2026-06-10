"""Implementation of JacAPIServerAnalyst - the A-07 Performance Analyst
admin endpoints.

v1 (this commit) exposes one read-only, admin-gated endpoint:

  GET /admin/analyst/digest  - the deterministic IncidentDigest (metric
                               symptoms + slow-trace exemplars + error
                               signatures), built by analyst_assemble. No
                               model is called; this is the funnel up to but
                               not including the REASON stage.

The reason / localize / github stages (A-07.b+) layer additional endpoints
onto this mixin later. Pattern mirrors JacAPIServerTraces / JacAPIServerLogs.
"""
import logging;
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }
import from jac_scale.admin.analyst_assemble { build_digest }

glob logger = logging.getLogger(__name__);


impl JacAPIServerAnalyst.register_analyst_endpoints -> None {
    # GET /admin/analyst/digest - deterministic incident digest. Query param:
    # baseline (PromQL offset for the comparison window, default 1h).
    async def digest_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get("http_status", 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
        }
        qp = request.query_params;
        baseline = (qp.get("baseline") or "1h").strip();
        try {
            digest = await build_digest(
                baseline_offset=baseline, trigger_kind="on_demand"
            );
        } except Exception as e {
            logger.warning(f"analyst: digest build failed: {e}");
            return JSONResponse(
                status_code=500,
                content={
                    "ok": False,
                    "error": {"message": "Digest build failed", "detail": str(e)}
                }
            );
        }
        return JSONResponse(content={"ok": True, "data": digest.to_dict()});
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/analyst/digest",
            callback=digest_handler,
            parameters=[],
            response_model=None,
            tags=["Analyst"],
            summary="Performance incident digest",
            description=(
                "Deterministic, pre-aggregated A-07 digest (metric symptoms, "
                "slow-trace exemplars, error signatures) from the in-cluster "
                "Prometheus / Tempo / Loki. Query param: baseline (default 1h). "
                "No model is invoked - this is the reduce-before-the-model "
                "funnel output."
            )
        )
    );
}
