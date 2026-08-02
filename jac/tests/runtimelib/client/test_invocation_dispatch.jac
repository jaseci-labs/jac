"""InvocationDispatcher direct-path tests (lean CI lane).

Exercises the transport-neutral dispatcher without FastAPI/Starlette.
HTTP parity is covered separately via serve.endpoints routing.
"""

import json;
import os;
import tempfile;
import from pathlib { Path }


glob _FIXTURE: str = str(Path(__file__).parent / "fixtures" / "inprocess_app.jac"),
     _BLOCKED_BOOT_MODULES: tuple = ("fastapi", "starlette", "pydantic", "jwt");


"""A `sys.meta_path` finder that raises on any import of the serve-closure
modules, so the lean desktop boot fails loudly if it ever reaches for FastAPI,
Starlette, Pydantic, or JWT."""
obj _ImportBlocker {
    def find_spec(name: str, path: any = None, target: any = None) -> any {
        for b in _BLOCKED_BOOT_MODULES {
            if name == b or name.startswith(b + ".") {
                raise ImportError("lean-boot test blocked import of '" + name + "'");
            }
        }
        return None;
    }
}


def _boot_runtime -> any {
    import from jaclang.runtimelib.invocation { prepare_invocation_runtime }
    graph_root = tempfile.mkdtemp(prefix="jac_invoke_test_");
    return prepare_invocation_runtime(_FIXTURE, os.path.join(graph_root, "graph"));
}


def _invoke(
    runtime: any, kind: str, name: str, fields: dict = None, token: str = ""
) -> dict {
    import asyncio;
    import from jaclang.runtimelib.invocation { InvocationKind, InvocationRequest }
    req = InvocationRequest(
        kind=InvocationKind.WALKER if kind == "walker" else InvocationKind.FUNCTION,
        name=name,
        fields=fields or {},
        token=token
    );
    result = asyncio.run(runtime.dispatcher.invoke(req));
    return {
        "ok": result.ok,
        "status": result.http_status,
        "body": result.to_transport()
    };
}


test "dispatcher executes a public walker" {
    rt = _boot_runtime();
    try {
        out = _invoke(rt, "walker", "greet", {"name": "Ada"});
        assert out["status"] == 200;
        assert out["ok"] == True;
        assert out["body"].data["reports"][0]["greeting"] == "hello Ada";
    } finally {
        rt.close();
    }
}


test "dispatcher executes a public function" {
    rt = _boot_runtime();
    try {
        out = _invoke(rt, "function", "add", {"a": 2, "b": 40});
        assert out["status"] == 200;
        assert out["ok"] == True;
        assert out["body"].data["result"] == 42;
    } finally {
        rt.close();
    }
}


test "dispatcher returns NOT_FOUND for unknown targets" {
    rt = _boot_runtime();
    try {
        out = _invoke(rt, "walker", "missing_walker");
        assert out["status"] == 404;
        assert out["body"].error.code == "NOT_FOUND";
    } finally {
        rt.close();
    }
}


test "dispatcher rejects a missing required field" {
    rt = _boot_runtime();
    try {
        out = _invoke(rt, "function", "add", {"a": 2});
        assert out["status"] == 422;
        assert out["body"].error.code == "VALIDATION_ERROR";
    } finally {
        rt.close();
    }
}


test "dispatcher coerces numeric-string fields like HTTP" {
    rt = _boot_runtime();
    try {
        out = _invoke(rt, "function", "add", {"a": "2", "b": "40"});
        assert out["status"] == 200;
        assert out["body"].data["result"] == 42;
    } finally {
        rt.close();
    }
}


test "dispatcher rejects an uncoercible field type" {
    rt = _boot_runtime();
    try {
        out = _invoke(rt, "function", "add", {"a": "abc", "b": 1});
        assert out["status"] == 422;
        assert out["body"].error.code == "VALIDATION_ERROR";
    } finally {
        rt.close();
    }
}


test "dispatcher drops unknown walker fields (FastAPI extra-ignore parity)" {
    rt = _boot_runtime();
    try {
        out = _invoke(rt, "walker", "greet", {"name": "Ada", "bogus": 1});
        assert out["status"] == 200;
        assert out["body"].data["reports"][0]["greeting"] == "hello Ada";
    } finally {
        rt.close();
    }
}


test "dispatcher honors a prevalidated-but-rejected token (401, no re-decode)" {
    import asyncio;
    import from jaclang.runtimelib.invocation { InvocationKind, InvocationRequest }
    rt = _boot_runtime();
    try {
        # A transport already saw a Bearer token but resolved no user; the
        # dispatcher must trust that (401) without validating the token itself,
        # even for a public walker.
        result = asyncio.run(
            rt.dispatcher.invoke(
                InvocationRequest(
                    kind=InvocationKind.WALKER,
                    name="greet",
                    fields={"name": "Ada"},
                    token="bad-token",
                    resolved_user=None,
                    identity_prevalidated=True
                )
            )
        );
        assert result.http_status == 401;
        assert result.error.code == "UNAUTHORIZED";
    } finally {
        rt.close();
    }
}


# Boot isolation gate: the whole justification for the direct dispatcher is that
# a minimal desktop app boots and serves public walkers/functions WITHOUT pulling
# in the serve closure. Prove it by actively blocking those imports during boot
# and dispatch.
test "runtime boots and dispatches with the serve closure imports blocked" {
    import sys;
    import asyncio;
    import os;
    import tempfile;
    import from jaclang.runtimelib.invocation {
        InvocationKind,
        InvocationRequest,
        prepare_invocation_runtime
    }

    blocker = _ImportBlocker();
    # Force the blocked names to re-resolve through the finder (a cached module
    # would import from sys.modules and dodge the block).
    saved_mods: dict = {};
    for name in list(sys.modules.keys()) {
        for b in _BLOCKED_BOOT_MODULES {
            if name == b or name.startswith(b + ".") {
                saved_mods[name] = sys.modules[name];
                del sys.modules[name];
            }
        }
    }
    sys.meta_path.insert(0, blocker);
    graph_root = tempfile.mkdtemp(prefix="jac_leanboot_test_");
    rt = None;
    try {
        rt = prepare_invocation_runtime(_FIXTURE, os.path.join(graph_root, "graph"));
        walk = asyncio.run(
            rt.dispatcher.invoke(
                InvocationRequest(
                    kind=InvocationKind.WALKER, name="greet", fields={"name": "Lean"}
                )
            )
        );
        assert walk.http_status == 200;
        assert walk.to_transport().data["reports"][0]["greeting"] == "hello Lean";

        fn = asyncio.run(
            rt.dispatcher.invoke(
                InvocationRequest(
                    kind=InvocationKind.FUNCTION, name="add", fields={"a": 1, "b": 2}
                )
            )
        );
        assert fn.http_status == 200;
        assert fn.to_transport().data["result"] == 3;

        # None of the blocked modules were imported during boot/dispatch.
        for b in _BLOCKED_BOOT_MODULES {
            assert b not in sys.modules , ("lean boot must not import '" + b + "'");
        }
    } finally {
        if rt is not None {
            rt.close();
        }
        if blocker in sys.meta_path {
            sys.meta_path.remove(blocker);
        }
        for (name, mod) in saved_mods.items() {
            sys.modules[name] = mod;
        }
    }
}


test "dispatcher marks generator functions as streams" {
    import asyncio;
    import from jaclang.runtimelib.invocation { InvocationKind, InvocationRequest }
    rt = _boot_runtime();
    try {
        result = asyncio.run(
            rt.dispatcher.invoke(
                InvocationRequest(
                    kind=InvocationKind.FUNCTION, name="stream_numbers", fields={"n": 3}
                )
            )
        );
        assert result.ok == True;
        assert result.is_stream == True;
        assert result.stream is not None;
        frames = list(result.stream);
        assert frames == [{"n": 0}, {"n": 1}, {"n": 2}];
    } finally {
        rt.close();
    }
}
