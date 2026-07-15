"""Tests for the byLLM model-serve stack: manifest, runner argv, api_base fix,
the supervisor's concurrency/eviction rules, and the daemon's routing/gating
(against a fake llama-server)."""

import os;
import sys;
import json;
import time;
import shutil;
import tempfile;
import threading;
import subprocess;
import urllib.request;
import urllib.error;
import from pathlib { Path }
import from unittest { mock }
import from http.server { BaseHTTPRequestHandler, ThreadingHTTPServer }

import from jaclang.byllm.serve.manifest {
    load_manifest, list_aliases, resolve_entry, to_cache_spec, parse_alias,
    refresh_index
}
import from jaclang.byllm.serve.runner { llama_server_argv }
import from jaclang.byllm.serve.daemon { ModelDaemon }
import from jaclang.byllm.serve.supervisor { RunnerSupervisor, RunnerHandle }
import from jaclang.byllm.model_cache { gguf_path }
import from jaclang.byllm.lib { Model }
import litellm;


test "manifest: defaults, resolve, to_cache_spec, unknown alias, dev override" {
    assert parse_alias("local:Gemma-4-E4B") == "gemma-4-e4b";
    assert parse_alias("openai/gpt-4o") is None;

    assert list_aliases() == ["gemma-4-e2b", "gemma-4-e4b", "qwen3.5-4b"];

    e = resolve_entry("gemma-4-e4b");
    assert e["ctx_window"] == 8192;
    assert e["supports_native_tools"] == False;
    q = resolve_entry("qwen3.5-4b");
    assert q["supports_native_tools"] == True;
    assert q["launch"]["jinja"] == True;

    spec = to_cache_spec(e);
    assert spec["file"] == "gemma-4-E4B-it-Q4_K_M.gguf";
    assert spec["repo"] == "unsloth/gemma-4-E4B-it-GGUF";

    try {
        resolve_entry("does-not-exist");
        assert False , "unknown alias must raise";
    } except ValueError as ve {
        assert "Available:" in str(ve);
    }

    # dev override deep-merges (later wins) and supports the url form.
    tmpd = Path(tempfile.mkdtemp(prefix="jac_test_manifest_"));
    tmp = tmpd / "override.json";
    tmp.write_text(json.dumps({
        "models": {
            "gemma-4-e4b": {"ctx_window": 4096},
            "cust": {"description": "c", "ctx_window": 2048, "supports_native_tools": True,
                     "weights": {"url": "https://e/m.gguf", "sha256": "ab", "file": "m.gguf", "size_mb": 1}}
        }
    }));
    prev = os.environ.get("JAC_MODELS_MANIFEST");
    os.environ["JAC_MODELS_MANIFEST"] = str(tmp);
    try {
        assert resolve_entry("gemma-4-e4b")["ctx_window"] == 4096 , "override wins";
        assert resolve_entry("gemma-4-e4b")["tool_family"] == "gemma" , "base fields kept";
        assert to_cache_spec(resolve_entry("cust"))["url"] == "https://e/m.gguf";
    } finally {
        if prev is None { os.environ.pop("JAC_MODELS_MANIFEST", None); }
        else { os.environ["JAC_MODELS_MANIFEST"] = prev; }
        shutil.rmtree(tmpd, ignore_errors=True);
    }
}


test "manifest: refresh_index installs the remote-index layer" {
    tmpd = Path(tempfile.mkdtemp(prefix="jac_test_index_"));
    prev = os.environ.get("JAC_MODELS_DIR");
    os.environ["JAC_MODELS_DIR"] = str(tmpd);
    remote = tmpd / "remote.json";
    remote.write_text(json.dumps({
        "version": 1,
        "models": {
            "newbie-1b": {
                "description": "n", "ctx_window": 1024,
                "weights": {"url": "https://e/n.gguf", "file": "n.gguf", "size_mb": 1}
            }
        }
    }));
    try {
        n = refresh_index(remote.as_uri());
        assert n == 1;
        assert (tmpd / "index.json").exists() , "index cache must be written";
        assert "newbie-1b" in list_aliases() , "index layer must merge in";
        assert resolve_entry("newbie-1b")["ctx_window"] == 1024;
        assert resolve_entry("gemma-4-e4b")["ctx_window"] == 8192 , "bundled layer kept";

        # A non-object document must be rejected and leave the cache intact.
        bad = tmpd / "bad.json";
        bad.write_text(json.dumps(["nope"]));
        try {
            refresh_index(bad.as_uri());
            assert False , "non-object index must raise";
        } except ValueError {}
        assert "newbie-1b" in list_aliases();
    } finally {
        if prev is None { os.environ.pop("JAC_MODELS_DIR", None); }
        else { os.environ["JAC_MODELS_DIR"] = prev; }
        shutil.rmtree(tmpd, ignore_errors=True);
    }
}


"""A subprocess that idles like a runner would (portable `sleep`)."""
def _fake_proc -> subprocess.Popen {
    return subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"]);
}

def _mk_handle(alias: str, proc: subprocess.Popen) -> RunnerHandle {
    return RunnerHandle(
        alias=alias, proc=proc, port=1, pid=proc.pid,
        last_used=time.time(), ngl=0, variant="cpu"
    );
}


test "supervisor: concurrent cold requests spawn exactly one runner" {
    sup = RunnerSupervisor(serve_cfg={"max_loaded": 2});
    calls = [0];
    def fake_spawn(alias: str, model_entry: dict, gguf: str) -> RunnerHandle {
        calls[0] += 1;
        time.sleep(0.3);   # widen the race window a real model load would have
        return _mk_handle(alias, _fake_proc());
    }
    results: list = [];
    def hit -> None {
        results.append(sup.ensure("a", {}, "/x"));
    }
    with mock.patch.object(sup, "_spawn", fake_spawn) {
        threads = [threading.Thread(target=hit) for i in range(4)];
        for t in threads { t.start(); }
        for t in threads { t.join(); }
    }
    try {
        assert calls[0] == 1 , "concurrent cold requests must share one spawn";
        assert len(results) == 4;
        assert len({id(r) for r in results}) == 1 , "all callers get the same handle";
    } finally {
        sup.stop_all();
    }
}


test "supervisor: reap_idle never evicts an in-flight runner" {
    sup = RunnerSupervisor(serve_cfg={});
    handle = _mk_handle("a", _fake_proc());
    sup.runners["a"] = handle;
    try {
        sup.begin_request("a");
        handle.last_used = time.time() - 999;   # stale mid-request
        sup.reap_idle(1);
        assert "a" in sup.runners , "in-flight runner must survive the reaper";

        sup.end_request("a");
        assert handle.inflight == 0;
        handle.last_used = time.time() - 999;
        sup.reap_idle(1);
        assert "a" not in sup.runners , "idle runner must be reaped";
    } finally {
        sup.stop_all();
    }
}


test "runner: llama_server_argv maps launch flags" {
    e = resolve_entry("qwen3.5-4b");
    argv = llama_server_argv(
        "/x/llama-server", "qwen3.5-4b", "/w/m.gguf", 9999,
        {"n_ctx": 0, "n_gpu_layers": 0, "n_threads": 4, "verbose": False}, e, False
    );
    assert argv[0] == "/x/llama-server";
    assert "--jinja" in argv , "qwen wants --jinja";
    assert "-c" in argv and "8192" in argv , "ctx from manifest";
    assert "-t" in argv and "4" in argv , "threads";
    assert "--alias" in argv and "qwen3.5-4b" in argv;
}


test "api_base reaches litellm only when configured" {
    captured: dict = {};
    def fake_completion(*args: any, **kwargs: any) -> any {
        captured.clear();
        captured.update(kwargs);
        return {"choices": [{"message": {"content": "ok"}}]};
    }
    with mock.patch.object(litellm, "completion", fake_completion) {
        m = Model(model_name="openai/gpt-4o-mini");
        m.api_base = None;
        m.model_call_no_stream({"model": "openai/gpt-4o-mini", "messages": []});
        assert "api_base" not in captured , "cloud must not leak api_base";
        m.api_base = "http://127.0.0.1:9/v1";
        m.model_call_no_stream({"model": "openai/gpt-4o-mini", "messages": []});
        assert captured.get("api_base") == "http://127.0.0.1:9/v1" , "configured api_base must reach litellm";
    }
}


# Bodies the fake runner received, so tests can assert what the daemon forwards.
glob _runner_bodies: list = [];

class _FakeRunner(BaseHTTPRequestHandler) {
    def log_message(self: _FakeRunner, fmt: str, *args: any) -> None { return; }
    def do_GET(self: _FakeRunner) -> None {
        b = b'{"status":"ok"}';
        self.send_response(200 if self.path == "/health" else 404);
        self.send_header("Content-Length", str(len(b)));
        self.end_headers();
        self.wfile.write(b);
    }
    def do_POST(self: _FakeRunner) -> None {
        n = int(self.headers.get("Content-Length", 0) or 0);
        raw = self.rfile.read(n);
        try {
            _runner_bodies.append(json.loads(raw));
        } except Exception {}
        b = json.dumps({"choices": [{"message": {"content": "PROXIED"}}]}).encode();
        self.send_response(200);
        self.send_header("Content-Length", str(len(b)));
        self.end_headers();
        self.wfile.write(b);
    }
}

obj _FakeHandle {
    has url: str;
    def base_url -> str { return self.url; }
}
obj _FakeSupervisor {
    has url: str;
    def ensure(alias: str, model_entry: dict, gguf_path: str) -> _FakeHandle { return _FakeHandle(url=self.url); }
    def touch(alias: str) -> None { return; }
    def begin_request(alias: str) -> None { return; }
    def end_request(alias: str) -> None { return; }
    def running -> list { return []; }
    def reap_idle(idle_ttl: int) -> None { return; }
    def stop_all -> None { return; }
}

test "daemon: routing, unknown -> 404, not-pulled -> 409, proxy, stop merge" {
    tmp = Path(tempfile.mkdtemp(prefix="jac_test_daemon_"));
    prev = os.environ.get("JAC_MODELS_DIR");
    os.environ["JAC_MODELS_DIR"] = str(tmp);
    # Dev-override manifest: give gemma stop strings so we can see them forwarded.
    override = tmp / "override.json";
    override.write_text(json.dumps({"models": {"gemma-4-e4b": {"stop": ["<END>"]}}}));
    prev_manifest = os.environ.get("JAC_MODELS_MANIFEST");
    os.environ["JAC_MODELS_MANIFEST"] = str(override);
    gpath = gguf_path("gemma-4-e4b", to_cache_spec(resolve_entry("gemma-4-e4b")));
    gpath.parent.mkdir(parents=True, exist_ok=True);
    gpath.write_text("W");

    runner = ThreadingHTTPServer(("127.0.0.1", 0), _FakeRunner);
    threading.Thread(target=runner.serve_forever, daemon=True).start();
    md = ModelDaemon(
        serve_cfg={"serve_port": 0, "idle_ttl": 0},
        supervisor=_FakeSupervisor(url=f"http://127.0.0.1:{runner.server_address[1]}")
    );
    threading.Thread(target=md.serve, daemon=True).start();
    for _ in range(60) {
        if md.port { break; }
        time.sleep(0.05);
    }
    base = f"http://127.0.0.1:{md.port}";

    def post(model: str) -> dict {
        req = urllib.request.Request(
            f"{base}/v1/chat/completions",
            data=json.dumps({"model": model, "messages": []}).encode(),
            headers={"Content-Type": "application/json"}, method="POST"
        );
        try {
            with urllib.request.urlopen(req, timeout=5) as r { return {"s": r.status, "b": r.read().decode()}; }
        } except urllib.error.HTTPError as he { return {"s": he.code, "b": he.read().decode()}; }
    }
    try {
        with urllib.request.urlopen(f"{base}/healthz", timeout=5) as r { assert r.status == 200; }
        _runner_bodies.clear();
        assert "PROXIED" in post("openai/gemma-4-e4b")["b"] , "downloaded -> proxied";
        assert _runner_bodies[-1]["model"] == "gemma-4-e4b" , "wire name normalized to alias";
        assert _runner_bodies[-1]["stop"] == ["<END>"] , "manifest stop strings forwarded";
        assert post("nope")["s"] == 404 , "unknown -> 404";
        r409 = post("qwen3.5-4b");
        assert r409["s"] == 409 and "model_not_pulled" in r409["b"] , "not pulled -> 409";
    } finally {
        md.shutdown();
        runner.shutdown();
        if prev is None { os.environ.pop("JAC_MODELS_DIR", None); }
        else { os.environ["JAC_MODELS_DIR"] = prev; }
        if prev_manifest is None { os.environ.pop("JAC_MODELS_MANIFEST", None); }
        else { os.environ["JAC_MODELS_MANIFEST"] = prev_manifest; }
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
