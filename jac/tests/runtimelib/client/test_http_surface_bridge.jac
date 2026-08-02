"""Cross-transport tests for the http_surface route table + the sv-bridge
(`inprocess_dispatch.forward`) that now consumes it.

Three layers:

1. Lean-boot import guard (backend-free, subprocess): importing http_surface AND
   the native dispatch path must NOT pull FastAPI / starlette / pydantic or any
   `jaclang.scale.server` module -- these ride the lean desktop boot path.
2. Pure route-surface unit tests (backend-free): match + bind + specificity +
   GET-query coercion + path/node binding, driven by hand-built RouteSpecs.
3. End-to-end `forward()` round-trips (needs the in-process backend): default
   walker/function routes, a custom @restspec path+verb, GET+query type coercion,
   an unknown-path 404, a wrong-verb 404, and streaming draining as SSE frames
   (forward materializes them; forward_outcome tags a live generator for the
   broker to drain).

The backend layer boots one in-process runtime for the module and drives
`forward()` under a hermetic global-state swap (Jac context + shared-root resolver
+ the dispatch module singletons are saved/restored around every call) so this
file never contaminates the sibling `test_inprocess_dispatch` suite that shares
the same `inprocess_dispatch` module singleton. It self-skips when the in-process
backend cannot be built (e.g. LLVM shim / backend deps absent).
"""

import os;
import sys;
import json;
import tempfile;
import subprocess;
import from pathlib { Path }
import from jaclang.runtimelib.http_surface { HttpSurface, RouteSpec, build_surface }
import from jaclang.runtimelib.invocation { InvocationKind }


glob _FIXTURE: str = str(Path(str(__file__)).parent / "fixtures" / "http_surface_app.jac"),
     _RT: any = None,
     _SURF: any = None,
     _MY_CTX: any = None,
     _MY_RES: any = None,
     _BUILD_FAILED: str = "";


# ---------------------------------------------------------------------------
# 1. Lean-boot import guard (subprocess so sys.modules is pristine)
# ---------------------------------------------------------------------------
test "http_surface + native dispatch import without pulling FastAPI/starlette/pydantic" {
    code = (
        "import jaclang.runtimelib.http_surface;"
        "import jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch;"
        "import sys;"
        "heavy=[m for m in ('fastapi','starlette','pydantic') if m in sys.modules];"
        "assert not heavy, ('unexpected heavy import: '+repr(heavy));"
        "scale=[m for m in sys.modules if m.startswith('jaclang.scale.server')];"
        "assert not scale, ('scale.server leaked onto lean path: '+repr(scale));"
        "print('LEAN_OK')"
    );
    res = subprocess.run(
        [str(sys.executable), "-c", code],
        capture_output=True,
        text=True,
        env=dict(os.environ)
    );
    assert res.returncode == 0 , (
        f"lean import guard failed (rc={res.returncode}).\nSTDOUT:{res.stdout}\nSTDERR:{res.stderr}"
    );
    assert "LEAN_OK" in res.stdout , res.stdout;
}


# ---------------------------------------------------------------------------
# 2. Pure route-surface unit tests (no backend, no boot)
# ---------------------------------------------------------------------------
"""match() resolves verb + literal/param segments; specificity prefers literals."""
test "route surface matches verbs, path params, and prefers literal routes" {
    literal = RouteSpec(
        method="GET",
        path_template="/a/b",
        kind=InvocationKind.WALKER,
        name="Literal"
    );
    templated = RouteSpec(
        method="GET",
        path_template="/a/{x}",
        kind=InvocationKind.WALKER,
        name="Templated"
    );
    surface = HttpSurface(routes=[templated, literal]);
    surface.finalize();

    # Literal wins over the fully-templated route for the same segment count.
    hit = surface.match("GET", "/a/b");
    assert hit is not None;
    assert hit[0].name == "Literal" and hit[1] == {};

    # A non-literal path binds the param.
    hit2 = surface.match("GET", "/a/zzz");
    assert hit2 is not None;
    assert hit2[0].name == "Templated" and hit2[1] == {"x": "zzz"};

    # Verb mismatch -> no match (this is what yields the wrong-verb 404).
    assert surface.match("POST", "/a/b") is None;
    # Unknown path -> None.
    assert surface.match("GET", "/nope") is None;
    # Query string on the request path is ignored by the matcher.
    hit3 = surface.match("GET", "/a/b?z=1");
    assert hit3 is not None and hit3[0].name == "Literal";
}


"""bind() combines path params + declared query params (coerced) + JSON body,
and maps the walker `{nd}` segment onto node_id."""
test "route surface binds query (coerced), path params, node, and body" {
    surface = HttpSurface(routes=[]);

    # GET-shaped: declared query fields only, with scalar coercion.
    get_spec = RouteSpec(
        method="GET",
        path_template="/walker/Search",
        kind=InvocationKind.WALKER,
        name="Search",
        field_types={"name": "str", "age": "int"},
        query_fields=["name", "age"]
    );
    req = surface.bind(
        get_spec,
        {},
        {"name": ["Alice"], "age": ["30"], "v": ["cachebust"]},
        None
    );
    assert req.kind == InvocationKind.WALKER and req.name == "Search";
    assert req.node_id is None;
    # age coerced str->int; undeclared `v` dropped (not a declared query field).
    assert req.fields == {"name": "Alice", "age": 30};
    assert isinstance(req.fields["age"], int);

    # POST-shaped with a path param + a body field + the node segment.
    post_spec = RouteSpec(
        method="POST",
        path_template="/things/{thing_id}/update/{nd}",
        kind=InvocationKind.WALKER,
        name="UpdateThing",
        path_params=["thing_id", "nd"],
        node_param="nd",
        field_types={"thing_id": "str", "label": "str"}
    );
    req2 = surface.bind(
        post_spec,
        {"thing_id": "t-7", "nd": "node-42"},
        {},
        {"label": "hello", "extra": 1},
        "tok-abc"
    );
    assert req2.name == "UpdateThing" and req2.token == "tok-abc";
    # `{nd}` -> node_id (not a field); thing_id from path; body carried through.
    assert req2.node_id == "node-42";
    assert req2.fields["thing_id"] == "t-7" and req2.fields["label"] == "hello";
    assert "nd" not in req2.fields;
}


# ---------------------------------------------------------------------------
# 3. End-to-end forward() round-trips (needs the in-process backend)
# ---------------------------------------------------------------------------
"""Build one in-process runtime for the module + a route surface off its
introspector. Returns False (test self-skips) if the backend cannot be built."""
def _ensure_runtime -> bool {
    import from jaclang { JacRuntime as Jac }
    import jaclang.jac0core.runtime as _rtmod;
    import from jaclang.runtimelib.invocation { prepare_invocation_runtime }

    if _RT is not None {
        return True;
    }
    if _BUILD_FAILED {
        return False;
    }
    try {
        graph = tempfile.mkdtemp(prefix="jac_hs_test_");
        pre_ctx = Jac.exec_ctx;
        pre_res = list(_rtmod._shared_root_resolver);
        rt = prepare_invocation_runtime(_FIXTURE, os.path.join(graph, "graph"));
        # Capture our context + resolver, then restore the globals we perturbed so
        # building the runtime leaves no side effect on other suites.
        _MY_CTX = Jac.exec_ctx;
        _MY_RES = list(_rtmod._shared_root_resolver);
        _SURF = build_surface(rt.introspector);
        Jac.set_context(pre_ctx);
        _rtmod._shared_root_resolver[0] = pre_res[0];
        _rtmod._shared_root_resolver[1] = pre_res[1];
        _RT = rt;
        return True;
    } except Exception as e {
        _BUILD_FAILED = str(e);
        return False;
    }
}


"""Drive inprocess_dispatch.forward() with our runtime + surface swapped in, then
restore every global so the shared module singleton is left untouched."""
def _forward(method: str, path: str, body: any = None, token: str = "") -> tuple {
    import from jaclang { JacRuntime as Jac }
    import jaclang.jac0core.runtime as _rtmod;
    import jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch as ipd;

    s_ctx = Jac.exec_ctx;
    s_res = list(_rtmod._shared_root_resolver);
    s_rt = ipd._runtime;
    s_hs = ipd._http_surface;
    s_err = ipd._BOOT_ERROR;
    Jac.set_context(_MY_CTX);
    _rtmod._shared_root_resolver[0] = _MY_RES[0];
    _rtmod._shared_root_resolver[1] = _MY_RES[1];
    ipd._runtime = _RT;
    ipd._http_surface = _SURF;
    ipd._BOOT_ERROR = "";
    try {
        raw = b"" if body is None else json.dumps(body).encode("utf-8");
        return ipd.forward(method, path, raw, token);
    } finally {
        Jac.set_context(s_ctx);
        _rtmod._shared_root_resolver[0] = s_res[0];
        _rtmod._shared_root_resolver[1] = s_res[1];
        ipd._runtime = s_rt;
        ipd._http_surface = s_hs;
        ipd._BOOT_ERROR = s_err;
    }
}


"""Drive inprocess_dispatch.forward_outcome() (the streaming-aware broker bridge)
under the same hermetic global swap, returning its outcome dict."""
def _forward_outcome(method: str, path: str, body: any = None, token: str = "") -> dict {
    import from jaclang { JacRuntime as Jac }
    import jaclang.jac0core.runtime as _rtmod;
    import jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch as ipd;

    s_ctx = Jac.exec_ctx;
    s_res = list(_rtmod._shared_root_resolver);
    s_rt = ipd._runtime;
    s_hs = ipd._http_surface;
    s_err = ipd._BOOT_ERROR;
    Jac.set_context(_MY_CTX);
    _rtmod._shared_root_resolver[0] = _MY_RES[0];
    _rtmod._shared_root_resolver[1] = _MY_RES[1];
    ipd._runtime = _RT;
    ipd._http_surface = _SURF;
    ipd._BOOT_ERROR = "";
    try {
        raw = b"" if body is None else json.dumps(body).encode("utf-8");
        return ipd.forward_outcome(method, path, raw, token);
    } finally {
        Jac.set_context(s_ctx);
        _rtmod._shared_root_resolver[0] = s_res[0];
        _rtmod._shared_root_resolver[1] = s_res[1];
        ipd._runtime = s_rt;
        ipd._http_surface = s_hs;
        ipd._BOOT_ERROR = s_err;
    }
}


"""route_exists() (the CEF broker's front-door predicate) under the same swap."""
def _route_exists(method: str, path: str) -> bool {
    import jaclang.runtimelib.client.targets.desktop.native.inprocess_dispatch as ipd;
    s_rt = ipd._runtime;
    s_hs = ipd._http_surface;
    ipd._runtime = _RT;
    ipd._http_surface = _SURF;
    try {
        return ipd.route_exists(method, path);
    } finally {
        ipd._runtime = s_rt;
        ipd._http_surface = s_hs;
    }
}


test "default walker + function routes still work through inprocess_forward" {
    if not _ensure_runtime() {
        import pytest;
        pytest.skip("in-process backend unavailable: " + _BUILD_FAILED);
    }
    (status, text, ctype) = _forward("POST", "/walker/greet", {"name": "Ada"});
    assert status == 200 , text;
    assert ctype == "application/json";
    body = json.loads(text);
    assert body["ok"] == True;
    assert body["data"]["reports"][0]["greeting"] == "hello Ada";

    (fstatus, ftext, _fc) = _forward("POST", "/function/add", {"a": 2, "b": 40});
    assert fstatus == 200 , ftext;
    fbody = json.loads(ftext);
    assert fbody["ok"] == True and fbody["data"]["result"] == 42;
}


test "a restspec custom path + verb routes correctly over the bridge" {
    if not _ensure_runtime() {
        import pytest;
        pytest.skip("in-process backend unavailable: " + _BUILD_FAILED);
    }
    # GET /custom/ping (custom verb + custom path) -- default POST /walker/{name}
    # parsing would never have reached this.
    (status, text, _c) = _forward("GET", "/custom/ping");
    assert status == 200 , text;
    body = json.loads(text);
    assert body["ok"] == True;
    assert body["data"]["reports"][0]["pong"] == True;
    assert body["data"]["reports"][0]["path"] == "/custom/ping";

    # route_exists agrees this is a known route (and rejects unknown ones).
    assert _route_exists("GET", "/custom/ping") == True;
    assert _route_exists("GET", "/definitely/not/a/route") == False;

    # A restspec POST with a path parameter + JSON body.
    (pstatus, ptext, _pc) = _forward(
        "POST", "/things/widget-9/update", {"label": "shiny"}
    );
    assert pstatus == 200 , ptext;
    pbody = json.loads(ptext);
    rep = pbody["data"]["reports"][0];
    assert rep["thing_id"] == "widget-9" and rep["label"] == "shiny";
}


test "GET with query params binds and coerces types over the bridge" {
    if not _ensure_runtime() {
        import pytest;
        pytest.skip("in-process backend unavailable: " + _BUILD_FAILED);
    }
    # age arrives as the string "30" in the query -- it must coerce to int, and the
    # undeclared cache-buster `v` must be dropped, not forwarded to the walker.
    (status, text, _c) = _forward(
        "GET", "/walker/SearchWalker?name=Alice&age=30&v=1708012345"
    );
    assert status == 200 , text;
    body = json.loads(text);
    rep = body["data"]["reports"][0];
    assert rep["name"] == "Alice";
    assert rep["age"] == 30;
    assert rep["age_type"] == "int" , (
        f"query int coercion failed: age_type={rep['age_type']}"
    );
}


test "unknown path returns a 404-shaped error over the bridge" {
    if not _ensure_runtime() {
        import pytest;
        pytest.skip("in-process backend unavailable: " + _BUILD_FAILED);
    }
    (status, text, _c) = _forward("POST", "/walker/__no_such_walker__", {});
    assert status == 404 , text;
    body = json.loads(text);
    assert body["ok"] == False;
    assert "unknown route" in str(body["error"]["message"]);

    # A default-POST walker hit with the wrong verb is also an unknown route (404),
    # never a silent success.
    (wstatus, wtext, _wc) = _forward("GET", "/walker/greet");
    assert wstatus == 404 , wtext;
    assert json.loads(wtext)["ok"] == False;
}


test "streaming responses drain as SSE frames through forward()" {
    if not _ensure_runtime() {
        import pytest;
        pytest.skip("in-process backend unavailable: " + _BUILD_FAILED);
    }
    # Step 6: the sv bridge no longer 500s on a streaming result. A direct
    # forward() caller materializes the shared runtimelib/streaming SSE frames
    # (data: per item, event: end) into the body as text/event-stream.
    (status, text, ctype) = _forward("POST", "/function/stream_numbers", {"n": 3});
    assert status == 200 , text;
    assert "text/event-stream" in ctype , ctype;
    assert 'data: {"n": 0}' in text , text;
    assert 'data: {"n": 1}' in text , text;
    assert 'data: {"n": 2}' in text , text;
    assert "event: end" in text , text;
}


test "forward_outcome tags a streaming result for the broker to drain" {
    if not _ensure_runtime() {
        import pytest;
        pytest.skip("in-process backend unavailable: " + _BUILD_FAILED);
    }
    # The broker-facing bridge hands back a live generator tagged mode "sse" so
    # the broker can drain it incrementally instead of buffering the whole body.
    outcome = _forward_outcome("POST", "/function/stream_numbers", {"n": 3});
    assert outcome["mode"] == "sse" , outcome;
    assert int(outcome["status"]) == 200;
    assert outcome["stream"] is not None;
    # Draining the carried generator yields the raw items (the broker frames them
    # via drain_sse); it is exhaustible exactly once.
    items = list(outcome["stream"]);
    assert items == [{"n": 0}, {"n": 1}, {"n": 2}] , items;

    # A non-streaming call comes back as a json outcome the broker echoes verbatim.
    ojson = _forward_outcome("POST", "/walker/greet", {"name": "Ada"});
    assert ojson["mode"] == "json" , ojson;
    assert int(ojson["status"]) == 200;
    jbody = json.loads(ojson["body"]);
    assert jbody["ok"] == True;
    assert jbody["data"]["reports"][0]["greeting"] == "hello Ada";
}
