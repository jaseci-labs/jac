"""Native <-> FastAPI cross-transport parity for the shared route surface.

The SAME app (`fixtures/http_surface_app.jac`) is served two ways and the
normalized outcomes are compared field-for-field:

  (a) the FastAPI / jac-scale stack, driven through `ScaleTestClient` (the same
      harness `jaclang/scale/tests/server/test_restspec.jac` uses); and
  (b) the desktop sv bridge, driven through
      `inprocess_dispatch.forward` (`inprocess_forward`).

Because Step 3 made the FastAPI adapter register its walker/function routes from
`http_surface.build_surface(...)` -- the exact route table the bridge already
consumes -- both front doors must resolve routes, bind fields (path / query /
body, incl. GET query int-coercion + undeclared-param drop), and shape their
success envelopes identically. This file asserts that they do.

What is NOT identical is documented, not hidden: on a *known path with the wrong
verb* FastAPI answers 405 (Method Not Allowed) while the lean bridge answers 404
(the matcher is verb-keyed and simply finds no route). Both still reject the
request as a non-executed 4xx; the differing code is asserted explicitly so a
future change is caught.

Both transports boot lazily, once, from the same fixture path (so they share the
loaded app module). The desktop side runs under the same hermetic global-state
swap `test_http_surface_bridge.jac` uses (Jac context + shared-root resolver +
the dispatch-module singletons are saved/restored around every call) so this
file never contaminates the sibling in-process-dispatch suites. It self-skips
when the stacks cannot be built (LLVM shim / scale deps absent)."""

import os;
import json;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.http_surface { build_surface }

glob _FIXTURE: str = str(
         Path(str(__file__)).parent / "fixtures" / "http_surface_app.jac"
     ),
     _CLIENT: any = None,
     _RT: any = None,
     _SURF: any = None,
     _MY_CTX: any = None,
     _MY_RES: any = None,
     _BUILD_FAILED: str = "";


"""Boot BOTH transports once, from the same fixture. Scale client first (its
context becomes ambient); then the desktop runtime, restoring the ambient
context/resolver so the scale side is left exactly as booted. Returns False
(tests self-skip) if either stack cannot be constructed."""
def _ensure -> bool {
    import from jaclang { JacRuntime as Jac }
    import jaclang.jac0core.runtime as _rtmod;
    import from jaclang.runtimelib.invocation { prepare_invocation_runtime }
    import from jaclang.scale.tests.scale_test_client { ScaleTestClient }

    if _RT is not None and _CLIENT is not None {
        return True;
    }
    if _BUILD_FAILED {
        return False;
    }
    try {
        scale_graph = tempfile.mkdtemp(prefix="parity_scale_");
        _CLIENT = ScaleTestClient.from_file(_FIXTURE, base_path=scale_graph);

        graph = tempfile.mkdtemp(prefix="parity_desk_");
        pre_ctx = Jac.exec_ctx;
        pre_res = list(_rtmod._shared_root_resolver);
        rt = prepare_invocation_runtime(_FIXTURE, os.path.join(graph, "graph"));
        _MY_CTX = Jac.exec_ctx;
        _MY_RES = list(_rtmod._shared_root_resolver);
        _SURF = build_surface(rt.introspector);
        # Restore the ambient (scale) context/resolver: building the desktop
        # runtime must leave the scale client untouched.
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


"""Drive inprocess_dispatch.forward() with the desktop runtime + surface swapped
in, restoring every perturbed global afterwards."""
def _desktop(method: str, path: str, body: any = None, token: str = "") -> dict {
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
        (status, text, _ctype) = ipd.forward(method, path, raw, token);
    } finally {
        Jac.set_context(s_ctx);
        _rtmod._shared_root_resolver[0] = s_res[0];
        _rtmod._shared_root_resolver[1] = s_res[1];
        ipd._runtime = s_rt;
        ipd._http_surface = s_hs;
        ipd._BOOT_ERROR = s_err;
    }
    j: any = {};
    try {
        j = json.loads(text);
    } except Exception { }
    ok = bool(isinstance(j, dict) and j.get("ok"));
    data = j.get("data") if isinstance(j, dict) else None;
    return {"status": status, "ok": ok, "data": data};
}


"""Drive the desktop sv bridge and return the raw (status, body, content_type)
tuple -- used for the streaming case where the body is an SSE stream, not JSON."""
def _desktop_raw(method: str, path: str, body: any = None, token: str = "") -> tuple {
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


"""Parse the JSON payloads of the `data:` frames of an SSE body, dropping the
terminal `event: end` frame (whose data is `{}`). Framing is identical across
transports (both use runtimelib/streaming.iter_sse_frames), so this normalizes
either transport's body to the list of streamed items."""
def _parse_sse_data(text: str) -> list {
    out: list = [];
    for block in text.split("\n\n") {
        if not block.strip() {
            continue;
        }
        is_event = False;
        payload: any = None;
        for line in block.split("\n") {
            if line.startswith("event:") {
                is_event = True;
            } elif line.startswith("data:") {
                payload = line[5:].strip();
            }
        }
        if is_event or payload is None {
            continue;
        }
        out.append(json.loads(payload));
    }
    return out;
}


"""Recursively drop `_jac_id` -- the per-instance walker/node UUID legitimately
differs between two independently-booted runtimes, so it is the one key that must
be ignored when asserting envelope parity. Everything else must match."""
def _strip_ids(val: any) -> any {
    if isinstance(val, dict) {
        return {
            k: _strip_ids(v)
            for (k, v) in val.items()
            if k != "_jac_id"
        };
    }
    if isinstance(val, list) {
        return [_strip_ids(v) for v in val];
    }
    return val;
}


"""Normalize a scale ScaleTestClient httpx response into the same shape."""
def _norm_scale(resp: any) -> dict {
    status = resp.status_code;
    j: any = {};
    try {
        j = resp.json();
    } except Exception { }
    ok = bool(isinstance(j, dict) and j.get("ok"));
    data = j.get("data") if isinstance(j, dict) else None;
    return {"status": status, "ok": ok, "data": data};
}


test "default walker + function envelopes match across transports" {
    if not _ensure() {
        testskip("transport stacks unavailable: " + _BUILD_FAILED);
    }
    # Default POST /walker/{name}
    a = _norm_scale(_CLIENT.post("/walker/greet", json={"name": "Ada"}));
    b = _desktop("POST", "/walker/greet", {"name": "Ada"});
    assert a["status"] == 200 and b["status"] == 200 , (a, b);
    assert a["ok"] and b["ok"];
    assert a["data"]["reports"][0] == {"greeting": "hello Ada"};
    # Full success payload is identical, not just the field we care about.
    assert _strip_ids(a["data"]) == _strip_ids(b["data"]) , (a["data"], b["data"]);

    # Default POST /function/{name}
    fa = _norm_scale(_CLIENT.post("/function/add", json={"a": 2, "b": 40}));
    fb = _desktop("POST", "/function/add", {"a": 2, "b": 40});
    assert fa["status"] == 200 and fb["status"] == 200 , (fa, fb);
    assert fa["data"]["result"] == 42 and fb["data"]["result"] == 42;
    assert _strip_ids(fa["data"]) == _strip_ids(fb["data"]) , (fa["data"], fb["data"]);
}


test "restspec custom path + verb resolves identically across transports" {
    if not _ensure() {
        testskip("transport stacks unavailable: " + _BUILD_FAILED);
    }
    # GET /custom/ping -- custom verb + custom path (default /walker/{name}
    # parsing would never reach this on either transport).
    a = _norm_scale(_CLIENT.get("/custom/ping"));
    b = _desktop("GET", "/custom/ping");
    assert a["status"] == 200 and b["status"] == 200 , (a, b);
    assert a["data"]["reports"][0] == {"pong": True, "path": "/custom/ping"};
    assert _strip_ids(a["data"]) == _strip_ids(b["data"]) , (a["data"], b["data"]);

    # POST /things/{thing_id}/update -- path param bound + JSON body field.
    pa = _norm_scale(_CLIENT.post("/things/widget-9/update", json={"label": "shiny"}));
    pb = _desktop("POST", "/things/widget-9/update", {"label": "shiny"});
    assert pa["status"] == 200 and pb["status"] == 200 , (pa, pb);
    rep_a = pa["data"]["reports"][0];
    assert rep_a["thing_id"] == "widget-9" and rep_a["label"] == "shiny";
    assert _strip_ids(pa["data"]) == _strip_ids(pb["data"]) , (pa["data"], pb["data"]);
}


test "GET query binding + int coercion match across transports" {
    if not _ensure() {
        testskip("transport stacks unavailable: " + _BUILD_FAILED);
    }
    # age arrives as the string "30"; both transports must coerce it to int and
    # drop the undeclared cache-buster `v` (never forwarded to the walker).
    a = _norm_scale(
        _CLIENT.get(
            "/walker/SearchWalker",
            params={"name": "Alice", "age": 30, "v": "1708012345"}
        )
    );
    b = _desktop("GET", "/walker/SearchWalker?name=Alice&age=30&v=1708012345");
    assert a["status"] == 200 and b["status"] == 200 , (a, b);
    rep_a = a["data"]["reports"][0];
    rep_b = b["data"]["reports"][0];
    assert rep_a["name"] == "Alice" and rep_a["age"] == 30;
    assert rep_a["age_type"] == "int" , rep_a;
    # Coercion + undeclared-drop produce the SAME report on both transports.
    assert rep_a == rep_b , (rep_a, rep_b);
    assert _strip_ids(a["data"]) == _strip_ids(b["data"]) , (a["data"], b["data"]);
}


test "unknown route is a matching 404 on both transports" {
    if not _ensure() {
        testskip("transport stacks unavailable: " + _BUILD_FAILED);
    }
    a = _norm_scale(_CLIENT.post("/walker/__no_such_walker__", json={}));
    b = _desktop("POST", "/walker/__no_such_walker__", {});
    # Same status AND same "not executed" outcome.
    assert a["status"] == 404 , a;
    assert b["status"] == 404 , b;
    assert not a["ok"] and not b["ok"];
}


test "streaming responses frame identically as SSE across transports" {
    if not _ensure() {
        testskip("transport stacks unavailable: " + _BUILD_FAILED);
    }
    # Step 6: a streaming function now drains as SSE on BOTH transports (the sv
    # bridge used to 500). Scale answers via StreamingResponse(sse_frame_stream);
    # the desktop bridge materializes the same runtimelib/streaming frames. The
    # streamed items must match field-for-field.
    a = _CLIENT.post("/function/stream_numbers", json={"n": 3});
    assert a.status_code == 200 , a.text;
    assert "text/event-stream" in a.headers.get("content-type", "") , a.headers;

    (dstatus, dtext, dctype) = _desktop_raw(
        "POST", "/function/stream_numbers", {"n": 3}
    );
    assert dstatus == 200 , dtext;
    assert "text/event-stream" in dctype , dctype;

    scale_items = _parse_sse_data(a.text);
    desk_items = _parse_sse_data(dtext);
    assert desk_items == [{"n": 0}, {"n": 1}, {"n": 2}] , desk_items;
    assert scale_items == desk_items , (scale_items, desk_items);
    # Both bodies terminate with the shared `event: end` sentinel.
    assert "event: end" in a.text and "event: end" in dtext;
}


test "wrong-verb rejection: both reject, documented 405 vs 404 divergence" {
    if not _ensure() {
        testskip("transport stacks unavailable: " + _BUILD_FAILED);
    }
    # `greet` is a default POST /walker/greet; hitting it with GET is not a valid
    # route on either transport. Shared invariant: rejected as a non-executed 4xx.
    a = _norm_scale(_CLIENT.get("/walker/greet"));
    b = _desktop("GET", "/walker/greet");
    assert 400 <= a["status"] < 500 and not a["ok"] , a;
    assert 400 <= b["status"] < 500 and not b["ok"] , b;
    # Documented, asserted divergence in the exact code (not a bug -- a transport
    # surface difference): FastAPI knows the path and answers 405 Method Not
    # Allowed; the lean verb-keyed bridge matcher finds no route and answers 404.
    assert a["status"] == 405 , f"expected FastAPI 405 for wrong verb, got {a[
        'status'
    ]}";
    assert b["status"] == 404 , f"expected bridge 404 for wrong verb, got {b[
        'status'
    ]}";
}
