"""
Tests for request_context_middleware async user-root resolution.

PR #5942 switched ctx.set_user_root() (blocks event loop) to
await ctx.aset_user_root() inside the async middleware. These tests verify:

1. aset_user_root is called on the top-level context (no _parent) for
   authenticated requests — this is the middleware's call site.
2. aset_user_root is NOT called on the top-level context when user_id
   is absent (unauthenticated request).

Context: there are two call sites for aset_user_root:
  a. request_context_middleware (PR #5942): called on the top-level
     JScaleExecutionContext created by create_j_context — _parent is None.
  b. _begin_request_context (spawn_walker path): called on a per-request
     fork — _parent is set. This fires for every walker call regardless
     of auth status and is intentionally excluded from these assertions.
"""

import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.scale.tests.scale_test_client {
    ScaleTestClient,
    make_client,
    extract_data
}

test "middleware calls aset_user_root on top-level context for authenticated requests" {
    # Patch aset_user_root to track calls made on top-level contexts
    # (_parent is None). These are the middleware calls. Calls with _parent
    # set come from _begin_request_context (spawn_walker path) and are
    # excluded so the assertion is specific to the middleware fix.
    client = make_client("test_api.jac");
    middleware_calls: list[str] = [];
    original_aset = ExecutionContext.aset_user_root;

    async def tracking_aset(self: any, root_id: str) {
        if self._parent is None {
            middleware_calls.append(root_id);
        }
        await original_aset(self, root_id);
    }

    ExecutionContext.aset_user_root = tracking_aset;
    try {
        r = client.post(
            "/user/register",
            json={
                "identities": [{"type": "username", "value": "mw_async_user_5942"}],
                "credential": {"type": "password", "password": "Pass!5942"}
            }
        );
        assert r.status_code == 201 , f"register failed: {r.text}";

        r = client.post(
            "/user/login",
            json={
                "identity": {"type": "username", "value": "mw_async_user_5942"},
                "credential": {"type": "password", "password": "Pass!5942"}
            }
        );
        assert r.status_code == 200 , f"login failed: {r.text}";
        token = extract_data(r.json())["token"];

        r = client.post(
            "/walker/PublicInfo", json={}, headers={"Authorization": f"Bearer {token}"}
        );
        assert r.status_code == 200 , f"walker request failed: {r.status_code} {r.text}";
    } finally {
        ExecutionContext.aset_user_root = original_aset;
        client.close();
    }

    assert len(middleware_calls) >= 1 , (
        "aset_user_root was never called on the top-level context for an "
        "authenticated request — middleware may still use the blocking "
        "set_user_root path (regression from PR #5942)"
    );
}

test "middleware skips aset_user_root on top-level context for unauthenticated requests" {
    # When no Authorization header is present user_id is None and the
    # middleware's `if user_id:` branch is not taken — aset_user_root must
    # not be called on the top-level context (_parent is None).
    client = make_client("test_api.jac");
    middleware_calls: list[str] = [];
    original_aset = ExecutionContext.aset_user_root;

    async def tracking_aset(self: any, root_id: str) {
        if self._parent is None {
            middleware_calls.append(root_id);
        }
        await original_aset(self, root_id);
    }

    ExecutionContext.aset_user_root = tracking_aset;
    try {
        r = client.post("/walker/PublicInfo", json={});
        assert r.status_code == 200 , f"public walker failed without auth: {r.status_code} {r.text}";
    } finally {
        ExecutionContext.aset_user_root = original_aset;
        client.close();
    }

    assert len(middleware_calls) == 0 , (
        f"aset_user_root was called {len(middleware_calls)} time(s) on the "
        "top-level context for an unauthenticated request — middleware should "
        "only call it when user_id is present"
    );
}
