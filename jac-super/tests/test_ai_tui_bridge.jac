"""Regression tests for the `jac ai --tui` sidecar command bridge."""

import importlib;
import os;
import from pathlib { Path }
import jaclang.cli.ai_agent as ai_mod;
import from jaclang.cli.agent_api { AgentRequest }


obj DummyProc {
    has terminated: bool = False;

    def terminate {
        self.terminated = True;
    }
}


obj DummyStopEvt {
    has stopped: bool = False;

    def set {
        self.stopped = True;
    }

    def is_set -> bool {
        return self.stopped;
    }
}


obj DummyPipe {
    def write(_text: str) { }
    def flush { }
    def close { }
}


obj DummySpawnedProc {
    has pid: int = 1234,
        returncode: int = 0,
        stdin: DummyPipe = DummyPipe(),
        stdout: list[str] = [];

    def poll -> int {
        return 0;
    }

    def wait -> int {
        self.returncode = 0;
        return 0;
    }

    def terminate {
        self.returncode = 0;
    }
}


test "SEND dispatch resolves the UI bridge in dispatcher scope" {
    seen: list[str] = [];
    tui_mod = importlib.import_module("jac_super.ai_agent.run_tui_session");
    dispatch = getattr(tui_mod, "_dispatch_cmd");
    old_send = getattr(ai_mod, "ui_send");

    def fake_send(prompt: str) -> bool {
        seen.append(prompt);
        return True;
    }

    setattr(ai_mod, "ui_send", fake_send);
    try {
        dispatch("SEND:hi", DummyStopEvt(), DummyProc());
    } finally {
        setattr(ai_mod, "ui_send", old_send);
    }

    assert seen == ["hi"] , f"expected SEND payload to reach ui_send; seen={seen!r}";
}


test "QUIT dispatch resolves ui_stop and tears down the sidecar" {
    seen: list[str] = [];
    tui_mod = importlib.import_module("jac_super.ai_agent.run_tui_session");
    dispatch = getattr(tui_mod, "_dispatch_cmd");
    old_stop = getattr(ai_mod, "ui_stop");

    def fake_stop {
        seen.append("stop");
    }

    setattr(ai_mod, "ui_stop", fake_stop);
    try {
        proc = DummyProc();
        stop_evt = DummyStopEvt();
        # Shared dispatcher signature is (line, stop_evt, proc); proc is optional
        # (None for the in-process backend) and terminated only when present.
        dispatch("QUIT", stop_evt, proc);
        assert stop_evt.is_set();
        assert proc.terminated;
    } finally {
        setattr(ai_mod, "ui_stop", old_stop);
    }

    assert seen == ["stop"] , f"expected QUIT to call ui_stop exactly once; seen={seen!r}";
}


test "command resolution reports missing binary and threads seed prompt" {
    tui_mod = importlib.import_module("jac_super.ai_agent.run_tui_session");
    resolve_cmd = getattr(tui_mod, "_resolve_tui_command");
    # run_tui_session lives in jac_super/ai_agent/; the sidecar is in
    # jac_super/ai_tui_na/, so pkg_root is jac_super/ (mirrors the launcher's own
    # `Path(__file__).resolve().parent.parent`).
    pkg_root = Path(tui_mod.__file__).resolve().parent.parent;

    na = resolve_cmd(pkg_root, "seed prompt");
    if na["ok"] {
        assert na["cmd_args"][-1] == "seed prompt" , "initial prompt must be last arg";
        assert na["cmd_args"][0].endswith("jac-na-tui") , "spawn must use jac-na-tui binary";
    } else {
        assert "jac-na-tui not found" in na["error"];
        assert "build.sh" in na["hint"];
    }
}


test "_list_project_files enumerates files under a project dir" {
    import tempfile;
    shared_mod = importlib.import_module("jac_super.ai_agent.tui_shared");
    lister = getattr(shared_mod, "_list_project_files");
    with tempfile.TemporaryDirectory() as d {
        os.makedirs(os.path.join(d, "sub"));
        with open(os.path.join(d, "a.txt"), "w") as f {
            f.write("x");
        }
        with open(os.path.join(d, "sub", "b.txt"), "w") as f {
            f.write("y");
        }
        listing = lister(d);
        names: list[str] = [];
        for line in listing.split("\n") {
            s = line.strip();
            if s {
                names.append(s);
            }
        }
        assert "a.txt" in names , f"expected a.txt in {names!r}";
        has_b: bool = False;
        for n in names {
            if n.endswith("b.txt") {
                has_b = True;
            }
        }
        assert has_b , f"expected b.txt in {names!r}";
    }
}


test "_probe_tty on win32 returns available=True with empty device and skips ttyname" {
    import os;
    import sys;
    import unittest.mock;

    shared_mod = importlib.import_module("jac_super.ai_agent.tui_shared");
    probe_tty = getattr(shared_mod, "_probe_tty");

    mock_stream = unittest.mock.MagicMock();
    mock_stream.fileno.return_value = 3;

    with unittest.mock.patch.object(sys, "platform", "win32") {
        with unittest.mock.patch.object(
            shared_mod, "_first_tty_stream", return_value=mock_stream
        ) {
            with unittest.mock.patch(
                "os.ttyname",
                side_effect=AssertionError("ttyname must not run on win32")
            ) {
                result = probe_tty();
                assert result["available"] == True , result;
                assert result["device"] == "" , result;
            }
        }
    }
}


test "_probe_tty on win32 returns available=False when no stream is a tty" {
    import sys;
    import unittest.mock;

    shared_mod = importlib.import_module("jac_super.ai_agent.tui_shared");
    probe_tty = getattr(shared_mod, "_probe_tty");

    with unittest.mock.patch.object(sys, "platform", "win32") {
        with unittest.mock.patch.object(
            shared_mod, "_first_tty_stream", return_value=None
        ) {
            result = probe_tty();
            assert result["available"] == False , result;
            assert result["device"] == "" , result;
        }
    }
}


test "_probe_tty on posix resolves ttyname from first tty stream" {
    import os;
    import sys;
    import unittest.mock;

    shared_mod = importlib.import_module("jac_super.ai_agent.tui_shared");
    probe_tty = getattr(shared_mod, "_probe_tty");

    mock_stream = unittest.mock.MagicMock();
    mock_stream.fileno.return_value = 7;

    with unittest.mock.patch.object(sys, "platform", "linux") {
        with unittest.mock.patch.object(
            shared_mod, "_first_tty_stream", return_value=mock_stream
        ) {
            with unittest.mock.patch.object(
                os, "ttyname", return_value="/dev/pts/42"
            ) as ttyname {
                result = probe_tty();
                assert result["available"] == True , result;
                assert result["device"] == "/dev/pts/42" , result;
                ttyname.assert_called_once_with(7);
            }
        }
    }
}


test "_probe_tty on posix returns available=False when no tty stream" {
    import sys;
    import unittest.mock;

    shared_mod = importlib.import_module("jac_super.ai_agent.tui_shared");
    probe_tty = getattr(shared_mod, "_probe_tty");

    with unittest.mock.patch.object(sys, "platform", "linux") {
        with unittest.mock.patch.object(
            shared_mod, "_first_tty_stream", return_value=None
        ) {
            result = probe_tty();
            assert result["available"] == False , result;
            assert result["device"] == "" , result;
        }
    }
}


test "_probe_tty on posix falls back to empty device when ttyname raises" {
    import os;
    import sys;
    import unittest.mock;

    shared_mod = importlib.import_module("jac_super.ai_agent.tui_shared");
    probe_tty = getattr(shared_mod, "_probe_tty");

    mock_stream = unittest.mock.MagicMock();
    mock_stream.fileno.return_value = 5;

    with unittest.mock.patch.object(sys, "platform", "linux") {
        with unittest.mock.patch.object(
            shared_mod, "_first_tty_stream", return_value=mock_stream
        ) {
            with unittest.mock.patch.object(
                os, "ttyname", side_effect=OSError("not a tty")
            ) {
                result = probe_tty();
                assert result["available"] == True , result;
                assert result["device"] == "" , result;
            }
        }
    }
}


test "run_tui_session suppresses terminal prints only for the session lifetime" {
    tui_mod = importlib.import_module("jac_super.ai_agent.run_tui_session");
    runner = getattr(tui_mod, "run_tui_session");
    old_ensure = getattr(tui_mod, "_ensure_tui_binary");
    old_resolve = getattr(tui_mod, "_resolve_tui_command");
    old_spawn = getattr(tui_mod, "_spawn_tui_backend");
    old_require_tty = getattr(tui_mod, "_require_tty");
    old_configure = getattr(ai_mod, "ui_configure");
    old_stream = getattr(ai_mod, "ui_stream");
    old_stop = getattr(ai_mod, "ui_stop");
    prior = os.environ.get("JAC_AI_UI_ACTIVE");
    seen: list[str] = [];

    def fake_ensure(_pkg_root: any) -> dict {
        return {"ok": True, "error": "", "hint": ""};
    }

    def fake_resolve(_pkg_root: any, _initial: str) -> dict {
        return {"ok": True, "cmd_args": ["dummy"], "error": "", "hint": ""};
    }

    def fake_spawn(_cmd_args: list) -> DummySpawnedProc {
        return DummySpawnedProc();
    }

    def fake_require_tty -> str {
        # Patch the gate directly: _probe_tty lives in tui_shared and is not
        # reachable via tui_mod, so patching tui_mod._require_tty (which IS in
        # tui_mod's namespace) is the stable bypass for headless CI.
        return "/dev/pts/99";
    }

    def fake_configure {
        seen.append(os.environ.get("JAC_AI_UI_ACTIVE", ""));
    }

    def fake_stream -> any {
        for item in [] {
            yield item;
        }
    }

    def fake_stop { }

    setattr(tui_mod, "_ensure_tui_binary", fake_ensure);
    setattr(tui_mod, "_resolve_tui_command", fake_resolve);
    setattr(tui_mod, "_spawn_tui_backend", fake_spawn);
    setattr(tui_mod, "_require_tty", fake_require_tty);
    setattr(ai_mod, "ui_configure", fake_configure);
    setattr(ai_mod, "ui_stream", fake_stream);
    setattr(ai_mod, "ui_stop", fake_stop);
    try {
        os.environ.pop("JAC_AI_UI_ACTIVE", None);
        rc = runner(AgentRequest(tui=True, cwd=os.getcwd()));
    } finally {
        setattr(tui_mod, "_ensure_tui_binary", old_ensure);
        setattr(tui_mod, "_resolve_tui_command", old_resolve);
        setattr(tui_mod, "_spawn_tui_backend", old_spawn);
        setattr(tui_mod, "_require_tty", old_require_tty);
        setattr(ai_mod, "ui_configure", old_configure);
        setattr(ai_mod, "ui_stream", old_stream);
        setattr(ai_mod, "ui_stop", old_stop);
        if prior is None {
            os.environ.pop("JAC_AI_UI_ACTIVE", None);
        } else {
            os.environ["JAC_AI_UI_ACTIVE"] = prior;
        }
    }

    assert rc == 0 , rc;
    assert seen == ["1"] , seen;
    assert os.environ.get("JAC_AI_UI_ACTIVE") is None;
}


obj CaptureBus {
    has events: list = [];

    def emit(kind: str, fields: dict) {
        ev = {"kind": kind};
        ev.update(fields);
        self.events.append(ev);
    }
}


test "ui output capture dedups provider loguru errors after agent registration" {
    import from jaclang.cli.ai_agent {
        _install_ui_provider_capture,
        register_ui_provider_error
    }
    import from loguru { logger }

    bus = CaptureBus();
    _install_ui_provider_capture(bus);
    register_ui_provider_error(RuntimeError("LLM call failed with APIError: boom"));
    logger.error("LLM call failed with APIError: boom");
    assert len(bus.events) == 0 , bus.events;
    logger.error("LLM AuthenticationError: bad key");
    assert len(bus.events) == 1 , bus.events;
    assert bus.events[0]["kind"] == "error" , bus.events[0];
    assert "provider:" in str(bus.events[0].get("text", "")) , bus.events[0];
}


test "ui output capture dedups when the loguru sink fires before the worker emit" {
    import from jaclang.cli.ai_agent {
        _install_ui_provider_capture,
        register_ui_provider_error
    }
    import from loguru { logger }

    # `_ui_is_duplicate_provider_error` is an impl-annex helper (no decl), reached
    # as a module attribute like the worker's except path resolves it at runtime.
    is_dup = getattr(ai_mod, "_ui_is_duplicate_provider_error");
    # Stale fingerprints from a prior test would poison the 2s dedup window.
    getattr(ai_mod, "_ui_recent_errors").clear();
    bus = CaptureBus();
    _install_ui_provider_capture(bus);

    # Real ordering: byllm logs the failure via loguru *first* (our sink surfaces
    # it), and the re-raised exception only reaches the worker's except block
    # afterwards. byllm labels the loguru record ("LLM AuthenticationError: ...")
    # while the worker sees the bare re-raised message; the fingerprint must
    # collapse both onto one row.
    logger.error("LLM AuthenticationError: litellm bad key 42");
    assert len(bus.events) == 1 , bus.events;

    # Worker except path for the *same* failure -- must not add a second row.
    err_text = "provider: litellm bad key 42";
    if not is_dup(err_text) {
        bus.emit("error", {"text": err_text});
    }
    register_ui_provider_error(RuntimeError("litellm bad key 42"));
    assert len(bus.events) == 1 , bus.events;

    # A genuinely different provider failure still earns its own row.
    err2 = "provider: litellm rate limit on gpt-x";
    if not is_dup(err2) {
        bus.emit("error", {"text": err2});
    }
    assert len(bus.events) == 2 , bus.events;
}


test "ui output capture removes loguru's default sink and gags litellm" {
    import from jaclang.cli.ai_agent { _install_ui_provider_capture }
    import from loguru { logger }

    getattr(ai_mod, "_ui_recent_errors").clear();
    bus = CaptureBus();
    _install_ui_provider_capture(bus);

    # logger.remove() must have dropped loguru's default stderr sink (the one
    # thing a stderr relay can't do), leaving exactly one handler -- ours -- so
    # byllm's logger.error() reaches the bus, not the real terminal. A
    # redirect_stderr probe would be meaningless: loguru binds its sink to the
    # original stderr at import. Single-handler count *plus* the log landing on
    # the bus proves the default stderr sink is gone (count==1 alone wouldn't,
    # since the lone handler could still be the default).
    handlers = logger?._core?.handlers;
    if handlers is not None {
        assert len(handlers) == 1 , len(handlers);
    }
    logger.error("LLM call failed with APIError: routed to bus not tty");
    assert len(bus.events) == 1 , bus.events;
    assert bus.events[0]["kind"] == "error" , bus.events[0];

    # Phase 2b: litellm's stdout footer print() is gated by suppress_debug_info.
    try {
        import litellm;
        assert litellm.suppress_debug_info == True , litellm.suppress_debug_info;
    } except ImportError { }
}
