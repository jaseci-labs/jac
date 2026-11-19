"""One status document, one renderer, across every dev-loop channel.

`.jac-dev-status.json` (written by a Vite plugin, holding a `.js` module id)
and `.jac-build-error.json` (written by the hot reloader, holding free text)
are gone. Both are replaced by one status document,
`{"status": ..., "diagnostics": [...]}` -- the same shape `/__build_status`
returns on the core and the scale server, and the same diagnostic value the
`/cl/__error__` endpoint logs. The jac process keeps it in memory and sends it
to the dev server as a message. It is never a file: anything written into the
folder Vite serves is a project change to Vite (#10799).
"""

import from jaclang.server.build_status { BuildMonitor }

import io;
import json;
import logging;
import uuid;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.server.hmr { HotReloader }
import from jaclang.server.build_status { get_build_status }
import from jaclang.server.watcher { JacFileWatcher }
import from jaclang.testing.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

"""Records every message the logger accepts, before any handler sees it.

A logger filter runs at emit time on the logger object itself, so an empty
tap separates "nothing was ever emitted to this logger" from "a handler or
its stream dropped the record" -- the two causes an empty buffer conflates.
"""
obj _EmitTap {
    has seen: list[str] = [];

    def filter(record: any) -> bool {
        self.seen.append(record.getMessage());
        return True;
    }
}

def _as_any(v: any) -> any {
    return v;
}

"""Return every process-global this file touches to its default.

Test workers are pooled, so a locator cache keyed on a deleted temp dir, a
latched rate limiter or a live HotReloader would ride into whatever runs
next in the same worker.
"""
def _reset_client_globals {
    import from jaclang.client.source_mapping {
        _locator_cache,
        _mapper_cache,
        _error_rate_limiter
    }
    _locator_cache.clear();
    _mapper_cache.clear();
    _error_rate_limiter._seen = {};
    _error_rate_limiter._count = 0;
    _error_rate_limiter._window_start = 0.0;
    active = BuildMonitor.active;
    if active is not None {
        active.stop();
    }
    BuildMonitor.active = None;
}

"""Forget a module this file compiled into the long-lived global program."""
def _drop_module(path: str) -> None {
    import from jaclang { JacRuntime as Jac }
    program = Jac.program;
    if program is None {
        return;
    }
    try {
        program.invalidate_module(path);
        program.drop_module_alerts(path);
    } except Exception {}
}

def _reloader(base: Path) -> HotReloader {
    _reset_client_globals();
    watcher = JacFileWatcher(watch_paths=[str(base)], _debounce_ms=50);
    return HotReloader(base_path=str(base), module_name="app", watcher=watcher);
}

"""Stands in for the bundler that owns the dev server, recording what the hot
reloader sends it."""
obj _DevBundler {
    has on_client_event: any = None,
        statuses: list[dict[str, any]] = [],
        reloads: int = 0;

    def publish_dev_status(status: dict[str, any]) {
        self.statuses.append(status);
    }

    def request_dev_reload {
        self.reloads += 1;
    }
}

"""Everything the dev loop has ever used as a signal file under a client dir."""
def _signal_files(client_dir: Path) -> list[str] {
    return [
        name
        for name in [
            ".jac-status.json",
            ".jac-force-reload",
            ".jac-build-error.json",
            ".jac-dev-status.json",
            ".jac-client-events.json"
        ]
        if (client_dir / name).exists()
    ];
}

test "a real client compile failure becomes a located diagnostic" {
    with TemporaryDirectory() as tmpdir {
        proj = Path(tmpdir) / f"project_{uuid.uuid4().hex[:8]}";
        (proj / ".jac" / "client" / "compiled").mkdir(parents=True);
        app = proj / "app.jac";
        app.write_text("def app() -> any {\n    return <div UNCLOSED;\n}\n");
        reloader = _reloader(proj);
        bundler = _DevBundler();
        reloader.attach_client_bundler(bundler);
        try {
            reloader._recompile_client_code(str(app));
            status = reloader.build_status();
            assert set(status.keys()) == {"status", "diagnostics"} , status;
            assert status["status"] == "error";
            diags = status["diagnostics"];
            assert len(diags) >= 1 , diags;
            first = diags[0];
            assert first["file"].endswith("app.jac") , first["file"];
            assert first["line"] > 0 , first;
            assert first["code"] , "a compile diagnostic must carry the compiler's code";
            assert first["channel"] == "jac" , first["channel"];
            assert "-->" in first["rendered"] , first["rendered"];
            # The dev server is sent the document; no file carries it.
            client_dir = proj / ".jac" / "client";
            assert bundler.statuses[-1] == status , bundler.statuses;
            assert _signal_files(client_dir) == [] , _signal_files(client_dir);
            # Recovery empties the document.
            app.write_text("def app() -> any {\n    return <div>ok</div>;\n}\n");
            reloader._recompile_client_code(str(app));
            reloader.record_ok();
            assert reloader.build_status() == {"status": "ok", "diagnostics": []};
            assert bundler.statuses[-1] == {"status": "ok", "diagnostics": []};
        } finally {
            # This test compiles into the long-lived global program; drop what
            # it left there so a pooled worker's later tests do not inherit it.
            _drop_module(str(app));
            _drop_module(str(app.resolve()));
            _reset_client_globals();
        }
    }
}

test "the hot reloader ignores the retired status files entirely" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        client_dir = proj / ".jac" / "client";
        client_dir.mkdir(parents=True);
        # Every retired file, holding an error each. None may be read.
        (client_dir / ".jac-dev-status.json").write_text(
            json.dumps(
                {"vite": {"message": "stale vite error", "file": ""}, "client": None}
            )
        );
        (client_dir / ".jac-build-error.json").write_text(
            json.dumps({"file": "app.jac", "message": "stale jac error"})
        );
        (client_dir / ".jac-client-events.json").write_text(
            json.dumps({"vite": {"message": "stale event"}, "client": None})
        );
        reloader = _reloader(proj);
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
    }
}

test "raw client events arrive on the callback and are classified once" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        client_dir = proj / ".jac" / "client";
        (client_dir / "compiled").mkdir(parents=True);
        reloader = _reloader(proj);
        bundler = _DevBundler();
        reloader.attach_client_bundler(bundler);
        # The plugin forwards RAW payloads only; the Jac process classifies.
        reloader.record_client_event(
            "client",
            {
                "type": "SyntaxError",
                "message": "The requested module '/.vite/deps/left-pad.js?v=1' "
                "does not provide an export named 'Nope'",
                "stack": "",
                "source": "",
                "phase": "load"
            }
        );
        status = reloader.build_status();
        assert status["status"] == "error";
        diag = status["diagnostics"][0];
        assert diag["code"] == "E7001" , diag;
        assert diag["channel"] == "browser" , diag;
        # Nothing on disk maps it, so the diagnostic must say so and still
        # name an owner rather than an empty file field.
        assert diag["file"] != "" , diag;
        assert diag["unmapped_reason"] != "" , diag;
        # Classification happened on arrival: the dev server already has the
        # document, and no file was written to carry it.
        assert bundler.statuses[-1] == status , bundler.statuses;
        assert _signal_files(client_dir) == [] , _signal_files(client_dir);
        # The browser's clean-load beacon clears the browser slots.
        reloader.record_client_event("ready", None);
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
    }
}

test "event slots rank vite over browser, and a jac failure over both" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        (proj / ".jac" / "client" / "compiled").mkdir(parents=True);
        reloader = _reloader(proj);
        reloader.record_client_event(
            "vite",
            {
                "message": 'Failed to resolve import "totally-missing-pkg"',
                "id": "compiled/pages/index.js",
                "plugin": "vite:import-analysis"
            }
        );
        reloader.record_client_event(
            "client", {"message": "load broke", "source": "", "phase": "load"}
        );
        assert reloader.build_status()["diagnostics"][0]["channel"] == "vite";
        reloader.record_error("app.jac", "syntax");
        assert reloader.build_status()["diagnostics"][0]["channel"] == "jac";
        reloader.record_ok();
        assert reloader.build_status()["diagnostics"][0]["channel"] == "vite";
        # A null payload clears the slot the plugin sent it for.
        reloader.record_client_event("vite", None);
        assert reloader.build_status()["diagnostics"][0]["channel"] == "browser";
        # The app came up: whatever Vite or the browser reported no longer blocks it.
        reloader.record_client_event(
            "vite", {"message": "still recorded", "id": "x.js"}
        );
        reloader.record_client_event("ready", None);
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
    }
}

test "a post-load runtime event is reported without breaking the build" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        (proj / ".jac" / "client" / "compiled").mkdir(parents=True);
        reloader = _reloader(proj);
        reloader.record_client_event(
            "runtime",
            {"type": "TypeError", "message": "x is not a function", "phase": ""}
        );
        # Reported to the terminal, but the build is not broken by it.
        assert reloader.build_status() == {"status": "ok", "diagnostics": []};
    }
}

test "get_build_status reports the new shape when no reloader is running" {
    assert get_build_status() == {"status": "unavailable", "diagnostics": []};
}

test "the core /__build_status route serves the status document shape" {
    with TemporaryDirectory() as tmp {
        client = JacTestClient.from_file(
            str((Path(FIXTURES) / "serve_api.jac").resolve()), base_path=str(tmp)
        );
        reloader = _reloader(Path(tmp));
        try {
            reloader.start();
            resp = client.get("/__build_status");
            assert resp.ok , resp.status_code;
            body = _as_any(resp.data);
            assert body == {"status": "ok", "diagnostics": []} , body;
            reloader.record_error("app.jac", "boom", line=3, column=5);
            body = _as_any(client.get("/__build_status").data);
            assert body["status"] == "error" , body;
            assert len(body["diagnostics"]) == 1 , body;
            diag = body["diagnostics"][0];
            assert diag["file"] == "app.jac" , diag;
            assert diag["line"] == 3 and diag["column"] == 5 , diag;
            assert diag["rendered"].startswith("error[") , diag["rendered"];
        } finally {
            reloader.stop();
            client.close();
            _reset_client_globals();
        }
    }
}

test "the /cl/__error__ endpoint logs a rendered diagnostic with a Jac location" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        compiled = proj / ".jac" / "client" / "compiled";
        compiled.mkdir(parents=True);
        src = proj / "app.jac";
        src.write_text(
            "def:pub app() -> any {\n    marker = 1;\n    return marker;\n}\n"
        );
        # A minimal compiled artifact plus a segment map, standing in for a
        # client build: the endpoint must resolve the frame through it.
        (compiled / "app.js").write_text(
            f"/* Source: {src} */\nfunction app() {{\n  let marker = 1;\n"
            "  return marker;\n}\nexport {app};\n"
        );
        (compiled / "app.js.map").write_text(
            json.dumps(
                {
                    "version": 3,
                    "file": "app.js",
                    "sources": [str(src)],
                    "names": ["marker"],
                    "mappings": ";;EACIA"
                }
            )
        );
        buf = io.StringIO();
        sink = logging.StreamHandler(buf);
        logger = logging.getLogger("jaclang.client_errors");
        tap = _EmitTap();
        logger.addHandler(sink);
        # The sink must see the record whatever level the root logger was left
        # at, so the level is pinned here and restored below.
        old_level = logger.level;
        logger.setLevel(logging.ERROR);
        logger.addFilter(tap);
        attached_to = id(logger);
        client = JacTestClient.from_file(
            str((Path(FIXTURES) / "serve_api.jac").resolve()), base_path=str(proj)
        );
        try {
            resp = client.post(
                "/cl/__error__",
                json={
                    "message": "marker is not a function",
                    "stack": "TypeError: marker is not a function\n"
                    "    at app (http://localhost:8000/compiled/app.js:3:4)",
                    "url": "http://localhost:8000/",
                    "source": "http://localhost:8000/compiled/app.js"
                }
            );
            assert resp.ok , resp.status_code;
            body = resp.json();
            # A throttled request is ok=True with nothing logged; failing on
            # it here names the actual suppression instead of a blank assert.
            assert not body.get("throttled") , (
                f"rate limiter throttled the request: {body}"
            );
            sink.flush();
            logged = buf.getvalue();
            live = logging.getLogger("jaclang.client_errors");
            assert "error[E7003]" in logged , (
                f"diagnostic never reached the sink; response={body}; "
                f"emitted={len(tap.seen)} records={tap.seen}; "
                f"logger id at attach={attached_to} at assert={id(live)}; "
                f"sink still attached={sink in live.handlers}; "
                f"disabled={live.disabled} level={live.level} "
                f"effective={live.getEffectiveLevel()} "
                f"global_disable={logging.root.manager.disable}; "
                f"handlers={live.handlers} propagate={live.propagate}; "
                f"buffer={logged!r}"
            );
            assert "--> app.jac:2" in logged , logged;
            # One classification, one renderer: the stack is resolved on the
            # diagnostic (not a second time by the endpoint) and logged from it.
            assert "  Stack: TypeError" in logged , logged;
            assert "at app (app.jac:2:" in logged , logged;
        } finally {
            logger.removeFilter(tap);
            logger.removeHandler(sink);
            logger.setLevel(old_level);
            client.close();
            _reset_client_globals();
        }
    }
}


obj _FakeStream {
    has lines: list[str] = [],
        _at: int = 0;

    def readline -> str {
        if self._at >= len(self.lines) {
            return "";
        }
        self._at += 1;
        return self.lines[self._at - 1];
    }
}

obj _FakeProc {
    has stdout: any = None,
        stdin: any = None;
}

obj _FakeOut {
    has written: list[str] = [];

    def write(text: str) {
        self.written.append(text);
    }

    def flush {}
}

obj _FakeSys {
    has stdout: any;
}

"""Give the command writer's thread up to two seconds to get there."""
def _wait_for(done: any) {
    import time;
    deadline = time.monotonic() + 2.0;
    while not done() and time.monotonic() < deadline {
        time.sleep(0.01);
    }
}

obj _ClosedPipe {
    def write(text: str) {
        raise BrokenPipeError("the dev server exited");
    }

    def flush {}
}

test "tagged lines cross the dev server's pipes both ways and are never echoed" {
    import json;
    import threading;
    import from jaclang.client.vite_bundler {
        ViteBundler,
        _forward_vite_output,
        CLIENT_EVENT_PREFIX,
        DEV_COMMAND_PREFIX
    }
    with TemporaryDirectory() as tmp {
        seen: list[any] = [];
        bundler = ViteBundler(Path(tmp));
        bundler.on_client_event = lambda (slot: str, payload: any) { seen.append(
            (slot, payload)
        ); };
        tagged = CLIENT_EVENT_PREFIX
            + json.dumps(
                {"slot": "vite", "payload": {"message": "boom", "id": "compiled/x.js"}}
            )
            + "\n";
        stream = _FakeStream(
            lines=[
                "  VITE v5.0.0  ready in 120 ms\n",
                tagged,
                "some ordinary vite chatter\n"
            ]
        );
        out = _FakeOut();
        _forward_vite_output(
            _FakeProc(stdout=stream),
            threading.Event(),
            _FakeSys(stdout=out),
            [],
            bundler._dispatch_client_event
        );
        assert seen == [("vite", {"message": "boom", "id": "compiled/x.js"})] , seen;
        echoed = "".join(out.written);
        assert CLIENT_EVENT_PREFIX not in echoed , echoed;
        assert "ordinary vite chatter" in echoed , echoed;
        # The other way: one tagged line per command on the dev server's stdin.
        # A status published before the server exists is the first thing it gets.
        broken = {"status": "error", "diagnostics": [{"code": "E7002"}]};
        bundler.publish_dev_status({"status": "ok", "diagnostics": []});
        bundler.publish_dev_status(broken);
        bundler.request_dev_reload();
        stdin = _FakeOut();
        bundler._attach_dev_commands(_FakeProc(stdin=stdin));
        bundler.request_dev_reload();
        # Commands leave on their own thread, so the one that reads the dev
        # server's output can never block on writing to it.
        _wait_for(lambda -> bool { return len(stdin.written) == 2; });
        assert all(line.endswith("\n") for line in stdin.written) , stdin.written;
        commands = [
            json.loads(line[len(DEV_COMMAND_PREFIX):]) for line in stdin.written
        ];
        assert commands
            == [{"type": "status", "status": broken}, {"type": "reload"}] , commands;
        # A dev server that has gone away is dropped, not raised about.
        bundler._attach_dev_commands(_FakeProc(stdin=_ClosedPipe()));
        bundler.request_dev_reload();
        _wait_for(lambda -> bool { return bundler._dev_stdin is None; });
        assert bundler._dev_stdin is None;
    }
}

test "the shared client-error path classifies once and carries both stacks" {
    import from jaclang.client.client_diagnostics { log_client_error }
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        compiled = proj / ".jac" / "client" / "compiled";
        compiled.mkdir(parents=True);
        src = proj / "app.jac";
        src.write_text(
            "def:pub app() -> any {\n    marker = 1;\n    return marker;\n}\n"
        );
        (compiled / "app.js").write_text(
            f"/* Source: {src} */\nfunction app() {{\n  let marker = 1;\n"
            "  return marker;\n}\nexport {app};\n"
        );
        (compiled / "app.js.map").write_text(
            json.dumps(
                {
                    "version": 3,
                    "file": "app.js",
                    "sources": [str(src)],
                    "names": ["marker"],
                    "mappings": ";;EACIA"
                }
            )
        );
        raw_stack = "TypeError: marker is not a function\n"
        "    at app (http://localhost:8000/compiled/app.js:3:4)";
        raw_component = "    at App (http://localhost:8000/compiled/app.js:3:4)";
        diag = log_client_error(
            str(proj),
            {
                "message": "marker is not a function",
                "stack": raw_stack,
                "componentStack": raw_component,
                "url": "http://localhost:8000/"
            }
        );
        assert diag.code == "E7003" , diag.code;
        # The raw stacks are kept verbatim alongside the resolved ones.
        assert diag.stack == raw_stack;
        assert diag.component_stack == raw_component;
        assert "app.jac:2:" in diag.resolved_stack , diag.resolved_stack;
        assert "compiled/app.js" not in diag.resolved_stack , diag.resolved_stack;
        assert "app.jac:2:" in diag.resolved_component_stack , diag.resolved_component_stack;
        # Both stacks survive the status-document round trip.
        wire = diag.to_dict();
        assert wire["resolved_stack"] == diag.resolved_stack;
        assert wire["component_stack"] == raw_component;
    }
}

glob _DEV_PLUGINS_HARNESS: str = r"""
import { EventEmitter } from "events";

const stdin = new EventEmitter();
stdin.setEncoding = () => {};
stdin.isTTY = false;
Object.defineProperty(process, "stdin", { value: stdin, configurable: true });
const written = [];
const print = process.stdout.write.bind(process.stdout);
process.stdout.write = (text) => { written.push(String(text)); return true; };

// The generated dev config, with its plugins in the order Vite would run them.
const config = (await import("./vite.dev.config.js")).default;

const failures = [];
const check = (label, ok, detail) => {
  print(`${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : "  -- " + detail}\n`);
  if (!ok) failures.push(label);
};
const EVENT = "@@jac-client-event ";
const events = () => written
  .filter((line) => line.startsWith(EVENT))
  .map((line) => JSON.parse(line.slice(EVENT.length)));
const command = (body) => "@@jac-dev-command " + JSON.stringify(body) + "\n";
const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

// A dev server with one connected tab and one module that fails to transform.
const MAIN = "/app/.jac/client/compiled/main.js";
const failing = new Set([MAIN]);
const sent = [];
const listeners = {};
const ws = {
  clients: new Set([{}]),
  send: (payload) => { sent.push(payload); },
  on: (name, fn) => { listeners[name] = fn; },
};
const server = {
  ws: ws,
  hot: ws,
  watcher: { on: () => {} },
  moduleGraph: { getModuleById: (id) => ({ url: id }), getModulesByFile: () => null },
  transformRequest: async (url) => {
    if (failing.has(url)) throw new Error("Failed to resolve import");
    return {};
  },
};
const DEV_LOOP = ["jac-build-error-overlay", "jac-client-events", "jac-force-reload"];
const wired = config.plugins.filter((p) => p && DEV_LOOP.includes(p.name));
for (const plugin of wired) plugin.configureServer(server);

const kind = (p) => (p.type === "error" ? "overlay:" + p.err.plugin : p.type + (p.jacTriggered ? ":jac" : ""));
const since = (start) => sent.slice(start).map(kind).join();
const viteError = {
  type: "error",
  err: { message: "Failed to resolve import", id: MAIN, plugin: "vite:import-analysis" },
};
const broken = {
  status: "error",
  diagnostics: [{ code: "E7002", message: "missing package", rendered: "error[E7002]" }],
};
const healthy = { status: "ok", diagnostics: [] };

check("the dev config wires the three dev-loop plugins", wired.length === 3, wired.map((p) => p.name).join());
check("starting healthy sends nothing", sent.length === 0, since(0));
server.ws.send(viteError);
check("a Vite error reaches jac with the module that failed",
  events().length === 1 && events()[0].slot === "vite" && events()[0].payload.id === MAIN,
  JSON.stringify(events()));

// A pipe may deliver one command in pieces.
const line = command({ type: "status", status: broken });
stdin.emit("data", line.slice(0, 20));
stdin.emit("data", line.slice(20));
check("the status jac sends shows its rendered diagnostic",
  since(0) === "overlay:vite:import-analysis,overlay:jac" && sent[1].err.frame === "error[E7002]",
  since(0));

// #10799: Vite reloads for a file that merely appeared. Nothing was fixed.
server.ws.send({ type: "full-reload", triggeredBy: "/app/.jac/client/new-file" });
await settle();
check("a reload that fixed nothing is not reported as a recovery",
  events().length === 1, JSON.stringify(events()));

let mark = sent.length;
server.ws.send(viteError);
check("the rendered diagnostic follows Vite's own overlay",
  since(mark) === "overlay:vite:import-analysis,overlay:jac", since(mark));
mark = sent.length;
listeners.connection();
check("a tab that connects while broken gets the diagnostic",
  since(mark) === "overlay:jac", since(mark));

failing.clear();
server.ws.send({ type: "update", updates: [] });
await settle();
let last = events()[events().length - 1];
check("the error clears once the module that failed transforms again",
  last.slot === "vite" && last.payload === null, JSON.stringify(last));

mark = sent.length;
stdin.emit("data", command({ type: "status", status: healthy }) + command({ type: "status", status: healthy }));
check("a change back to healthy reloads the page once", since(mark) === "full-reload:jac", since(mark));
stdin.emit("data", command({ type: "reload" }));
check("a reload command reloads the page", since(mark) === "full-reload:jac,full-reload:jac", since(mark));

const count = events().length;
server.ws.send(viteError);
server.ws.send({ type: "full-reload", path: "*", jacTriggered: true });
await settle();
check("jac's own reload is not taken as a hint", events().length === count + 1, JSON.stringify(events()));
listeners["jac:client-ready"]();
last = events()[events().length - 1];
check("the browser's clean load clears what was recorded", last.slot === "ready", JSON.stringify(last));
server.ws.send({ type: "update", updates: [] });
await settle();
check("with nothing recorded, an update reports nothing",
  events().length === count + 2, JSON.stringify(events()));

print(failures.length ? `FAILED: ${failures.join(", ")}\n` : "OK\n");
process.exit(failures.length ? 1 : 0);
""";

"""The generated dev config's plugins, run against a stand-in dev server.

#10799: jac reported a build error by creating a file in the folder Vite
serves. Vite retries every unresolved import when a file appears and reloads
the page, and the plugins took any reload for a recovery, cleared the error
and reloaded again, forever. The status now arrives as a command on stdin, and
a reload is only the moment to check: the error clears when the module that
failed transforms again, or when the browser reports a clean load."""
test "the dev plugins clear a Vite error on proof, never on a passing reload" {
    import subprocess;
    import from jaclang.testing.requires { require_tool }
    import from jaclang.client.vite_bundler { ViteBundler }
    import from tests.support { js_runtime_or_none }
    require_tool("bun");
    bun = js_runtime_or_none();
    if bun is None {
        testskip("bun is required but could not be located/installed");
    }
    with TemporaryDirectory() as tmp {
        config = ViteBundler(Path(tmp)).create_vite_config(
            Path(tmp) / "main.js", is_dev=True
        );
        # The config's outside imports; nothing here needs the real packages.
        modules = config.parent.parent / "node_modules";
        for (name, source) in [
            ("vite", "export const defineConfig = (c) => c;\n"),
            ("@vitejs/plugin-react", "export default () => ({ name: 'react' });\n")
        ] {
            (modules / name).mkdir(parents=True);
            (modules / name / "package.json").write_text(
                '{"type": "module", "main": "index.js"}'
            );
            (modules / name / "index.js").write_text(source);
        }
        harness = config.parent / "harness.mjs";
        harness.write_text(_DEV_PLUGINS_HARNESS, encoding="utf-8");
        run = subprocess.run(
            [bun, str(harness)], capture_output=True, text=True, timeout=60
        );
        assert run.returncode == 0 , f"{run.stdout}\n{run.stderr}";
    }
}

test "an unchanged status document is not sent again" {
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        reloader = _reloader(proj);
        bundler = _DevBundler();
        reloader.attach_client_bundler(bundler);
        try {
            reloader.record_error(str(proj / "app.jac"), "boom");
            sent = len(bundler.statuses);
            reloader.record_client_event("ready", None);
            reloader.record_client_event("runtime", None);
            reloader._publish_status();
            assert len(bundler.statuses) == sent , (
                "an unchanged status document was sent again"
            );
            reloader.record_error(str(proj / "app.jac"), "a different failure");
            assert len(bundler.statuses) == sent + 1;
            assert bundler.statuses[-1] != bundler.statuses[-2];
            reloader.record_ok();
            assert bundler.statuses[-1] == {"status": "ok", "diagnostics": []};
        } finally {
            _reset_client_globals();
        }
    }
}

test "a workspace app's status and reload signal reach its dev server without a file" {
    import from jaclang { JacRuntime as Jac }
    import from jaclang.project.config { JacConfig, get_config, set_config }
    import from jaclang.client.vite_client_bundle { make_client_bundle_builder }
    previous = get_config();
    with TemporaryDirectory() as tmp {
        project = Path(tmp).resolve();
        manifest = '[project]\nname = "status-paths"\ndefault-app = "web"\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n';
        (project / "jac.toml").write_text(manifest);
        target = project / "web" / "main.jac";
        target.parent.mkdir();
        target.write_text("def:pub app -> JsxElement {\n    return <div/>;\n}\n");
        try {
            set_config(JacConfig.from_toml_str(manifest, project / "jac.toml"));
            compiler = make_client_bundle_builder(
                project, entry_path=str(target), program=Jac.get_program()
            )._get_compiler();
            compiled = Path(str(compiler.jac_client_compiler.compiled_dir));
            config_path = compiler.vite_bundler.create_vite_config(target, is_dev=True);
            build_dir = config_path.parent.parent;
            assert compiled.parent != build_dir , (
                f"not a workspace layout: {compiled} compiles beside the dev config"
            );
            # The dev config names no signal file, so there is no directory for
            # the reloader and the plugins to disagree about (#10069).
            generated = config_path.read_text()
                + (config_path.parent / "jac-client-events.js").read_text();
            assert ".jac-status.json" not in generated;
            assert ".jac-force-reload" not in generated;
            _reset_client_globals();
            reloader = HotReloader(
                base_path=str(project),
                module_name="app",
                watcher=JacFileWatcher(watch_paths=[str(project)]),
                client_compiler=compiler
            );
            bundler = _DevBundler();
            reloader.attach_client_bundler(bundler);
            reloader.record_error(str(target), "boom");
            assert bundler.statuses[-1]["status"] == "error" , bundler.statuses;
            reloader._signal_full_reload();
            assert bundler.reloads == 1;
            reloader.record_ok();
            assert bundler.statuses[-1] == {"status": "ok", "diagnostics": []};
            for folder in [build_dir, compiled.parent] {
                assert _signal_files(folder) == [] , (folder, _signal_files(folder));
            }
        } finally {
            set_config(previous);
            _reset_client_globals();
        }
    }
}

test "the suite leaves no dev-loop global behind" {
    import from jaclang.client.source_mapping {
        _locator_cache,
        _mapper_cache,
        _error_rate_limiter
    }
    _reset_client_globals();
    # A pooled worker runs later suites in this same process.
    assert BuildMonitor.active is None;
    assert _locator_cache == {};
    assert _mapper_cache == {};
    assert _error_rate_limiter._seen == {};
    assert _error_rate_limiter._count == 0;
}


test "a vite that exits before it is ready raises at once with its exit code and last line" {
    import sys;
    import time;
    import from jaclang.client.vite_bundler { ViteBundler }
    import from jaclang.client.artifact { ClientBundleError }
    with TemporaryDirectory() as tmp {
        bundler = ViteBundler(Path(tmp));
        command = [
            sys.executable,
            "-c",
            "print('vite: bad config'); raise SystemExit(3)"
        ];
        started = time.monotonic();
        raised = "";
        try {
            bundler._start_vite_with_output_capture(command, Path(tmp), sys);
        } except ClientBundleError as e {
            raised = str(e);
        }
        assert "exited with code 3" in raised , raised;
        assert "vite: bad config" in raised , raised;
        assert time.monotonic() - started < 20 , "waited out the ready timeout";
        # The dev server is gone: its command pipe and the thread that writes
        # to it are released, not held until the jac process exits.
        _wait_for(lambda -> bool { return not bundler._dev_writer.is_alive(); });
        assert not bundler._dev_writer.is_alive();
        assert bundler._dev_stdin is None;
    }
}
