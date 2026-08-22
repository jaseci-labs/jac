"""Health probes must fail soft when the database cannot serve reads (#8050).

`request_context_middleware` builds a `JScaleExecutionContext()` for every
request, and that constructor reads the root anchor. When the database ran out
of predicate-lock shared memory the read failed with 53200, so /healthz/live
failed too, Kubernetes restarted the pods, and the restarted pods hit the same
error immediately. Nine and eleven restarts, with the database up and healthy.

Kubernetes semantics: liveness answers "is this process wedged, restart it",
readiness answers "can this pod serve traffic, keep it in Endpoints". A
database outage is the second question, never the first. So liveness must not
touch the database at all, and readiness must report 503 rather than blowing up.
"""

import from jaclang.runtimelib.pgwire { PgWireError }
import from jaclang.scale.memory { context as scale_ctx_mod }
import from jaclang.scale.tests.scale_test_client { make_client }

glob PRED_LOCK_EXHAUSTION = {
         'S': 'ERROR',
         'C': '53200',
         'M': 'out of shared memory',
         'H': 'You might need to increase "max_pred_locks_per_transaction".',
         'F': 'predicate.c',
         'R': 'CreatePredicateLock'
     };


class _ExhaustedContext {
    def init(self: _ExhaustedContext) {
        raise PgWireError(PRED_LOCK_EXHAUSTION);
    }
}


test "health: liveness survives predicate-lock exhaustion in the store" {
    client = make_client("test_api.jac");
    original = scale_ctx_mod.JScaleExecutionContext;
    try {
        assert client.get("/healthz/live").status_code == 200 , (
            'liveness must be 200 before the fault is injected'
        );
        scale_ctx_mod.JScaleExecutionContext = _ExhaustedContext;
        resp = client.get("/healthz/live");
        assert resp.status_code == 200 , (
            f"/healthz/live returned {resp.status_code} while the store was "
            'refusing reads; a liveness probe that dies with the database turns '
            'database pressure into an unrecoverable pod restart loop'
        );
        assert resp.json()["status"] == "alive";
    } finally {
        scale_ctx_mod.JScaleExecutionContext = original;
        client.close();
    }
}


test "health: readiness reports 503 instead of raising when the store is down" {
    client = make_client("test_api.jac");
    original = scale_ctx_mod.JScaleExecutionContext;
    try {
        assert client.get("/healthz/ready").status_code == 200;
        scale_ctx_mod.JScaleExecutionContext = _ExhaustedContext;
        resp = client.get("/healthz/ready");
        assert resp.status_code == 503 , (
            f"/healthz/ready returned {resp.status_code}, expected 503 so "
            'kube-proxy removes the pod from Endpoints without restarting it'
        );
        assert resp.json()["ok"] is False;
    } finally {
        scale_ctx_mod.JScaleExecutionContext = original;
        client.close();
    }
}


test "health: the legacy /healthz alias is a liveness probe too" {
    client = make_client("test_api.jac");
    original = scale_ctx_mod.JScaleExecutionContext;
    try {
        scale_ctx_mod.JScaleExecutionContext = _ExhaustedContext;
        resp = client.get("/healthz");
        assert resp.status_code == 200 , (
            f"/healthz returned {resp.status_code}; it is documented as the "
            'legacy liveness alias and the local orchestrator polls it, so it '
            'must not depend on a database round trip either'
        );
    } finally {
        scale_ctx_mod.JScaleExecutionContext = original;
        client.close();
    }
}


test "health: an ordinary request reports 503 rather than a 500 traceback" {
    client = make_client("test_api.jac");
    original = scale_ctx_mod.JScaleExecutionContext;
    try {
        scale_ctx_mod.JScaleExecutionContext = _ExhaustedContext;
        resp = client.post("/walker/PublicInfo", json={});
        assert resp.status_code == 503 , (
            f"expected 503 for an unreachable database, got {resp.status_code}; "
            'a dependency failure is not an internal server error'
        );
    } finally {
        scale_ctx_mod.JScaleExecutionContext = original;
        client.close();
    }
}
