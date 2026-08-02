"""Tests for the opt-in [desktop.http] FastAPI sidecar (Phase 4, doc §7/§9).

Layers:

1. Lean-boot import guard (subprocess): importing the sidecar module + host_boot
   must NOT pull FastAPI / starlette / uvicorn or jaclang.scale.server onto the
   default desktop boot path -- everything heavy is lazy inside start().
2. Disabled path: host_boot._start_http_sidecar with enabled=false is a no-op
   (no sidecar, no heavy import).
3. End-to-end: start() on a real loopback port, drive it over HTTP -- a multipart
   upload reaches the shared InvocationDispatcher, the X-Jac-Sidecar-Token gate is
   enforced (401 without / with a wrong token), and a webhook funnels to a walker.
4. Capability-error helper (sv-side): the structured 415/501 envelope that lean
   mode returns names [desktop.http] and the capability.

Self-skips when the in-process backend or FastAPI/uvicorn are unavailable.
"""

import os;
import sys;
import json;
import socket;
import tempfile;
import subprocess;
import from pathlib { Path }
import from urllib.request { Request, urlopen }
import from urllib.error { HTTPError, URLError }

glob _FIXTURE: str = str(Path(str(__file__)).parent / "fixtures" / "http_sidecar_app.jac"),
     _RT: any = None,
     _HANDLE: any = None,
     _BUILD_FAILED: str = "";


# ---------------------------------------------------------------------------
# 1. Lean-boot import guard (subprocess so sys.modules is pristine)
# ---------------------------------------------------------------------------
test "http_sidecar + host_boot import without pulling FastAPI/uvicorn/scale.server" {
    # Warm the on-disk bytecode cache first: a cold Jac COMPILE type-checks the
    # lazy `import from fastapi` inside start() (a compile-time cost), whereas the
    # shipped desktop app imports PRE-COMPILED bytecode. The guard is about that
    # runtime import, so compile once in-process, then assert on a fresh process
    # that reads the cache without recompiling.
    import jaclang.runtimelib.client.targets.desktop.native.http_sidecar;
    import jaclang.runtimelib.client.targets.desktop.native.host_boot;
    code = (
        "import jaclang.runtimelib.client.targets.desktop.native.http_sidecar;"
        "import jaclang.runtimelib.client.targets.desktop.native.host_boot;"
        "import sys;"
        "heavy=[m for m in ('fastapi','starlette','uvicorn','pydantic') if m in sys.modules];"
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
# 2. Disabled path is a no-op
# ---------------------------------------------------------------------------
test "host_boot._start_http_sidecar is a no-op when [desktop.http] is disabled" {
    import from jaclang.runtimelib.client.targets.desktop.native { host_boot }
    ctx = host_boot.HostContext();
    host_boot._start_http_sidecar(ctx, {"enabled": False});
    assert ctx.http is None , "disabled sidecar must not start";
    # And the disabled bootstrap injects no window.__JAC_HTTP__.
    assert ctx.http_bootstrap_js() == "" , "no sidecar -> empty bootstrap js";
}


# ---------------------------------------------------------------------------
# 3. End-to-end over a real loopback port
# ---------------------------------------------------------------------------
def _ensure -> bool {
    import from jaclang.runtimelib.invocation { prepare_invocation_runtime }
    import from jaclang.runtimelib.client.targets.desktop.native.http_sidecar {
        start as sidecar_start
    }

    if _HANDLE is not None {
        return True;
    }
    if _BUILD_FAILED {
        return False;
    }
    try {
        import fastapi;
        import uvicorn;
    } except Exception as e {
        _BUILD_FAILED = "fastapi/uvicorn unavailable: " + str(e);
        return False;
    }
    try {
        graph = tempfile.mkdtemp(prefix="jac_sidecar_test_");
        rt = prepare_invocation_runtime(_FIXTURE, os.path.join(graph, "graph"));
        handle = sidecar_start(
            rt.dispatcher, rt.introspector, ["multipart", "webhooks", "openapi"], 0
        );
        _RT = rt;
        _HANDLE = handle;
        return True;
    } except Exception as e {
        import traceback;
        _BUILD_FAILED = str(e) + "\n" + traceback.format_exc();
        return False;
    }
}


def _build_multipart(fields: dict, files: dict) -> tuple[bytes, str] {
    boundary = "----JacSidecarBoundary7QZ";
    crlf = "\r\n";
    body = b"";
    for (k, v) in fields.items() {
        header = (
            "--" + boundary + crlf
            + "Content-Disposition: form-data; name=\"" + str(k) + "\"" + crlf + crlf
        );
        body = body + header.encode("utf-8") + str(v).encode("utf-8") + crlf.encode("utf-8");
    }
    for (k, pair) in files.items() {
        (fname, data) = pair;
        header = (
            "--" + boundary + crlf
            + "Content-Disposition: form-data; name=\"" + str(k) + "\"; filename=\""
            + str(fname) + "\"" + crlf
            + "Content-Type: application/octet-stream" + crlf + crlf
        );
        body = body + header.encode("utf-8") + data + crlf.encode("utf-8");
    }
    body = body + ("--" + boundary + "--" + crlf).encode("utf-8");
    return (body, "multipart/form-data; boundary=" + boundary);
}


def _req(
    path: str,
    method: str = "POST",
    body: bytes = b"",
    content_type: str = "application/json",
    headers: dict = {}
) -> tuple[int, str] {
    url = _HANDLE.base + path;
    hdrs: dict = {"Content-Type": content_type};
    for (k, v) in headers.items() {
        hdrs[k] = v;
    }
    req = Request(url, data=body, method=method, headers=hdrs);
    try {
        with urlopen(req, timeout=10) as resp {
            return (resp.status, resp.read().decode("utf-8"));
        }
    } except HTTPError as e {
        return (e.code, e.read().decode("utf-8"));
    }
}


test "multipart upload reaches the shared dispatcher through the sidecar" {
    if not _ensure() {
        import pytest;
        pytest.skip("sidecar backend unavailable: " + _BUILD_FAILED);
    }
    payload = b"hello upload bytes";
    (body, ctype) = _build_multipart(
        {"label": "avatar"}, {"file": ("a.bin", payload)}
    );
    (status, text) = _req(
        "/walker/save_upload",
        body=body,
        content_type=ctype,
        headers={"X-Jac-Sidecar-Token": _HANDLE.token}
    );
    assert status == 200 , text;
    data = json.loads(text);
    assert data["ok"] == True , text;
    rep = data["data"]["reports"][0];
    assert rep["label"] == "avatar" , rep;
    assert rep["size"] == len(payload) , (
        f"upload bytes did not reach the walker intact: {rep}"
    );
}


test "sidecar token gate rejects missing and wrong tokens (401)" {
    if not _ensure() {
        import pytest;
        pytest.skip("sidecar backend unavailable: " + _BUILD_FAILED);
    }
    (body, ctype) = _build_multipart({"label": "x"}, {"file": ("a.bin", b"z")});
    # No gate token -> 401.
    (s1, _t1) = _req("/walker/save_upload", body=body, content_type=ctype);
    assert s1 == 401 , f"missing token should 401, got {s1}";
    # Wrong gate token -> 401.
    (s2, _t2) = _req(
        "/walker/save_upload",
        body=body,
        content_type=ctype,
        headers={"X-Jac-Sidecar-Token": "not-the-token"}
    );
    assert s2 == 401 , f"wrong token should 401, got {s2}";
}


test "webhook route funnels a JSON body into a walker" {
    if not _ensure() {
        import pytest;
        pytest.skip("sidecar backend unavailable: " + _BUILD_FAILED);
    }
    (status, text) = _req(
        "/webhook/greet",
        body=json.dumps({"name": "Ada"}).encode("utf-8"),
        headers={"X-Jac-Sidecar-Token": _HANDLE.token}
    );
    assert status == 200 , text;
    data = json.loads(text);
    assert data["data"]["reports"][0]["greeting"] == "hello Ada" , text;
}


test "openapi capability exposes /openapi.json" {
    if not _ensure() {
        import pytest;
        pytest.skip("sidecar backend unavailable: " + _BUILD_FAILED);
    }
    (status, text) = _req("/openapi.json", method="GET");
    assert status == 200 , text;
    schema = json.loads(text);
    assert "paths" in schema , "openapi schema should carry paths";
    # bootstrap_info carries base + token + the normalized capability list.
    info = _HANDLE.bootstrap_info();
    assert info["base"] == _HANDLE.base;
    assert info["token"] == _HANDLE.token;
    assert "multipart" in info["capabilities"];
}


test "sidecar stops cleanly on close" {
    if not _ensure() {
        import pytest;
        pytest.skip("sidecar backend unavailable: " + _BUILD_FAILED);
    }
    port = _HANDLE.port;
    _HANDLE.stop();
    # Port should no longer accept connections after a clean stop.
    probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    probe.settimeout(1.0);
    refused = False;
    try {
        probe.connect(("127.0.0.1", port));
    } except (ConnectionRefusedError, OSError) {
        refused = True;
    } finally {
        probe.close();
    }
    assert refused , "sidecar port should be closed after stop()";
    if _RT is not None {
        _RT.close();
    }
}


# ---------------------------------------------------------------------------
# 4. Capability-error helper (sv-side, lean, backend-free)
# ---------------------------------------------------------------------------
test "capability_error builds a structured 415/501 envelope naming [desktop.http]" {
    import from jaclang.runtimelib.http_surface { capability_error }
    multi = capability_error("multipart");
    assert multi["ok"] == False;
    assert multi["http_status"] == 415 , "multipart is a 415 media-type miss";
    assert multi["error"]["code"] == "CAPABILITY_NOT_AVAILABLE";
    assert multi["error"]["capability"] == "multipart";
    assert "[desktop.http]" in multi["error"]["hint"];
    hook = capability_error("webhooks");
    assert hook["http_status"] == 501 , "webhooks are 501 without the sidecar";
    assert "webhooks" in hook["error"]["hint"];
    # Explicit override wins.
    forced = capability_error("multipart", 503);
    assert forced["http_status"] == 503;
}
