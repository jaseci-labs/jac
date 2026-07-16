"""Regression tests for the `jac ai --tui` command bridge + shared helpers.

The command dispatcher (`_dispatch_cmd`) and the env/tty/project helpers live in
`tui_shared` and are imported VERBATIM by the embed host's embedded interpreter
(`ai_tui_na/host_embed.na.jac`), so these tests guard the one wire/env contract
that host runs. The trailing block covers the byLLM provider-error capture in
`ai_agent`, independent of any TUI transport.
"""

import importlib;
import os;
import pytest;
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


test "SEND dispatch resolves the UI bridge in dispatcher scope" {
    seen: list[str] = [];
    tui_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
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


test "QUIT dispatch resolves ui_stop and tears down a present proc" {
    seen: list[str] = [];
    tui_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
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


test "_list_project_files enumerates files under a project dir" {
    import tempfile;
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
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


test "_configure_ui_env populates every JAC_AI_UI_* key from the request" {
    # run_tui_embed copies os.environ into the child and os.execve's the native
    # host immediately after this, so the env is write-only here -- the contract
    # is just "all five keys land with the request's values".
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    configure = getattr(shared_mod, "_configure_ui_env");
    keys = [
        "JAC_AI_UI_PROJECT",
        "JAC_AI_UI_MODEL",
        "JAC_AI_UI_NCTX",
        "JAC_AI_UI_FILES",
        "JAC_AI_UI_MODEL_PRESETS",

    ];
    try {
        for key in keys {
            os.environ.pop(key, None);
        }
        configure(
            AgentRequest(tui=True, cwd=os.getcwd(), model="new-model", n_ctx=4096,)
        );
        assert os.environ.get("JAC_AI_UI_MODEL") == "new-model";
        assert os.environ.get("JAC_AI_UI_NCTX") == "4096";
        assert os.environ.get("JAC_AI_UI_PROJECT") == os.getcwd();
        for key in keys {
            assert key in os.environ , f"expected {key} to be set by configure";
        }
    } finally {
        for key in keys {
            os.environ.pop(key, None);
        }
    }
}


test "native TUI runtime keeps embed transport dispatch concrete" {
    # Regression for the broken `jac ai --tui --model ...` path: the UI env did
    # carry the model override into the embed host, but the native runtime typed
    # `rt.transport` as the base `Transport`, so `.flush_outbound_cmds()` and
    # `.recv_blob()` resolved to base no-ops. The TUI looked loaded, but sends
    # never reached `ui_send()` and agent frames (including the model-bearing
    # full snapshot) never rendered.
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    cli_dir = Path(shared_mod.__file__).resolve().parent.parent;
    runtime_src = (cli_dir / "ai_tui_na" / "runtime.na.jac").read_text();
    transport_src = (cli_dir / "ai_tui_na" / "transport.na.jac").read_text();
    loop_src = (cli_dir / "ai_tui_na" / "tui_loop.na.jac").read_text();
    host_src = (cli_dir / "ai_tui_na" / "host_embed.na.jac").read_text();

    assert "transport: EmbedPyTransport = EmbedPyTransport()" in runtime_src , (
        "TuiRuntime.transport must stay concretely typed as EmbedPyTransport or "
        "native dispatch falls back to Transport's no-op recv/send methods"
    );
    assert "obj EmbedPyTransport(TtyFdTransport)" in transport_src , (
        "Embed transport implementation missing from transport.na.jac"
    );
    assert "import from jacpyembed" not in transport_src , (
        "Phase 4: transport must not import CPython symbols; EmbedRuntime owns them"
    );
    assert "def poll_gil(timeout_ms: int)" in transport_src , (
        "TtyFdTransport must expose poll_gil for tests and injected-key harnesses"
    );
    assert "tty_poll(50);" in loop_src , (
        "TUI loop must poll the tty without virtual dispatch so the Python feed can run"
    );
    assert "tui_drain_session" in loop_src , (
        "Phase 4 loop drains typed session batches via EmbedSessionClient"
    );
    assert "rt.transport.close_py();" not in host_src , (
        "host teardown must not dispatch through rt.transport after the loop"
    );
    assert "import from jacpyembed" not in host_src , (
        "Phase 4: host_embed must not import jacpyembed; EmbedRuntime owns C-API"
    );
    # Phase 1+4: tty restore precedes managed dispose / conditional finalize.
    finally_i = host_src.rfind("} finally {");
    assert finally_i > 0 , "host _run_embed must have a finally teardown block";
    teardown = host_src[finally_i:];
    leave_i = teardown.find("tui_leave_screen(state);");
    tty_i = teardown.find("tty_close();");
    disp_i = teardown.find("session.dispose(");
    fin_i = teardown.find("finalize_if_safe(");
    assert leave_i > 0 and tty_i > leave_i , "leave_screen must precede tty_close";
    assert disp_i > tty_i , "tty_close must precede session.dispose (terminal-first quit)";
    assert fin_i > disp_i , "finalize_if_safe must follow dispose";
}


test "every producer event kind is recognized by the native parser (no silent UNKNOWN drift)" {
    # Tripwire for the event-kind duplication flagged in the #6355 review:
    # the producer (ai_agent.impl.jac) emits kind strings via bus.emit/emit_stream,
    # the serializer (_ev_line) passes them through verbatim, and the native
    # parser (ipc.na.jac::parse_event_kind) maps a CLOSED set to EventKind --
    # anything else silently becomes UNKNOWN. This scans both sources so a new
    # producer kind fails CI here instead of rendering as a blank UNKNOWN row.
    import re;

    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    cli_dir = Path(shared_mod.__file__).resolve().parent.parent;
    producer_src = (cli_dir / "impl" / "ai_agent.impl.jac").read_text();
    parser_src = (cli_dir / "ai_tui_na" / "ipc.na.jac").read_text();

    producer_kinds = set(re.findall(r'\.emit(?:_stream)?\("([a-z_]+)"', producer_src));

    # Scope to parse_event_kind only -- parse_tui_status also matches `s == "..."`
    # but is a different closed set (idle/running).
    func_match = re.search(r'def parse_event_kind\b.*?\n\}', parser_src, re.S);
    assert func_match is not None , "could not locate parse_event_kind -- regex stale?";
    parser_kinds = set(re.findall(r's == "([a-z_]+)"', func_match.group(0)));

    assert producer_kinds , "no producer kinds extracted -- regex stale?";
    assert parser_kinds , "no parser kinds extracted -- regex stale?";
    for k in (
        "user",
        "answer",
        "reasoning",
        "system",
        "error",
        "phase",
        "call",
        "tool_result"
    ) {
        assert k in producer_kinds , f"expected producer kind {k!r} missing -- regex stale?";
        assert k in parser_kinds , f"expected parser kind {k!r} missing -- regex stale?";
    }

    # "status" is carried out-of-band by FIELD_STATUS, not as a transcript
    # event, so it is intentionally absent from parse_event_kind.
    out_of_band = {"status"};

    unknown = producer_kinds.difference(parser_kinds).difference(out_of_band);
    assert not unknown , (
        f"producer emits kind(s) {sorted(unknown)} that parse_event_kind maps to "
        f"UNKNOWN; teach ipc.na.jac::parse_event_kind or carry them out-of-band"
    );

    stale = out_of_band.difference(producer_kinds);
    assert not stale , (
        f"out-of-band kind(s) {sorted(stale)} are no longer emitted; drop them "
        f"from the out_of_band set"
    );
}


test "_resolve_jac_build_bin prefers JAC_BIN then repo zig-out binary" {
    import tempfile;
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    resolver = getattr(shared_mod, "_resolve_jac_build_bin");
    pkg_root = Path(shared_mod.__file__).resolve().parent.parent;
    repo_root = pkg_root.parent.parent.parent;
    repo_jac = repo_root / "jac" / "zig-out" / "bin" / "jac";

    with tempfile.NamedTemporaryFile(delete=False) as tmp {
        tmp.write(b"");
        explicit = tmp.name;
    }
    os.chmod(explicit, 0o755);
    prior_jac_bin = os.environ.get("JAC_BIN");
    try {
        os.environ["JAC_BIN"] = explicit;
        assert resolver(pkg_root) == explicit;
        os.environ.pop("JAC_BIN", None);
        if repo_jac.is_file() {
            assert resolver(pkg_root) == str(repo_jac);
        } else {
            assert resolver(pkg_root) is None;
        }
    } finally {
        os.unlink(explicit);
        if prior_jac_bin is None {
            os.environ.pop("JAC_BIN", None);
        } else {
            os.environ["JAC_BIN"] = prior_jac_bin;
        }
    }
}


test "_probe_tty on posix resolves ttyname from first tty stream" {
    import os;
    import sys;
    import unittest.mock;

    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
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

    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
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

    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
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


test "na IPC schema mirrors the host wire constants" {
    # The host (ipc_schema.jac) and TUI (ipc_schema.na.jac) carry the wire
    # protocol in two Jac modules with no shared import; this test is the only
    # thing pinning that their wire *values* agree, so a silent drift in either
    # file fails CI instead of corrupting the runtime protocol between the embed
    # host and the native renderer.
    import re;
    import importlib;
    schema = importlib.import_module("jaclang.cli.ai_tui.ipc_schema");
    here = Path(schema.__file__).resolve().parent;
    wire_re = r':\s*str\s*=\s*"([^"]*)"';
    host_vals: set = set(re.findall(wire_re, (here / "ipc_schema.jac").read_text()));
    na_vals: set = set(
        re.findall(
            wire_re, (here.parent / "ai_tui_na" / "ipc_schema.na.jac").read_text()
        )
    );
    for v in host_vals {
        assert v in na_vals , f"wire value {v!r} in ipc_schema.jac missing from ipc_schema.na.jac";
    }
    for v in na_vals {
        assert v in host_vals , f"wire value {v!r} in ipc_schema.na.jac missing from ipc_schema.jac";
    }
}


test "embed_agent stub round-trips a frame through _frame_blob's wire shape" {
    # embed_agent.builds frames via tui_shared._frame_blob; a stub frame must
    # carry the schema's TYPE/EV tokens so the native parser accepts it.
    import importlib;
    shared = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    blob = shared._frame_blob(
        {
            "full": True,
            "status": "idle",
            "model_name": "stub",
            "events": [{"id": 1, "kind": "system", "node": "stub", "text": "hi"}],

        }
    );
    assert "TYPE:full" in blob , blob;
    assert "EV:1:system:stub:hi" in blob , blob;
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
    pytest.importorskip("loguru", reason="This test requires loguru to be installed");
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
    pytest.importorskip("loguru", reason="This test requires loguru to be installed");
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
    pytest.importorskip("loguru", reason="This test requires loguru to be installed");
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


test "SEND dispatch returns ACCEPTED or REJECTED receipt" {
    tui_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    schema = importlib.import_module("jaclang.cli.ai_tui.ipc_schema");
    dispatch = getattr(tui_mod, "_dispatch_cmd");
    old_send = getattr(ai_mod, "ui_send");

    def fake_ok(prompt: str) -> bool {
        return True;
    }

    def fake_busy(prompt: str) -> bool {
        return False;
    }

    setattr(ai_mod, "ui_send", fake_ok);
    try {
        rc = dispatch("SEND:hi", DummyStopEvt(), DummyProc());
        assert rc == schema.RECEIPT_ACCEPTED , rc;
    } finally {
        setattr(ai_mod, "ui_send", old_send);
    }

    setattr(ai_mod, "ui_send", fake_busy);
    try {
        rc = dispatch("SEND:hi", DummyStopEvt(), DummyProc());
        assert rc == schema.RECEIPT_REJECTED_BUSY , rc;
    } finally {
        setattr(ai_mod, "ui_send", old_send);
    }
}


test "Phase 1 native seams: stopping status, no id=-1, pending submission" {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    cli_dir = Path(shared_mod.__file__).resolve().parent.parent;
    ipc_src = (cli_dir / "ai_tui_na" / "ipc.na.jac").read_text();
    state_src = (cli_dir / "ai_tui_na" / "state.na.jac").read_text();
    input_src = (cli_dir / "ai_tui_na" / "input.na.jac").read_text();

    assert 'if s == "stopping"' in ipc_src , "parse_tui_status must map stopping";
    assert "STOPPING" in state_src , "TuiStatus must include STOPPING";
    assert "obj PendingSubmission" in state_src;
    assert "status_blocks_prompt" in state_src;
    assert "upsert_event(-1," not in input_src , "no optimistic id=-1 user row";
    assert "pending_submission" in input_src;
    assert "_adopt_pending_user" not in state_src , "id=-1 adoption path must be removed";
}
