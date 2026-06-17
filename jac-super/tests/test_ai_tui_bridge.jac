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
        dispatch("SEND:hi", DummyProc(), DummyStopEvt());
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
        dispatch("QUIT", proc, stop_evt);
        assert stop_evt.is_set();
        assert proc.terminated;
    } finally {
        setattr(ai_mod, "ui_stop", old_stop);
    }

    assert seen == ["stop"] , f"expected QUIT to call ui_stop exactly once; seen={seen!r}";
}


test "backend defaults to js and normalizes case" {
    tui_mod = importlib.import_module("jac_super.ai_agent.run_tui_session");
    resolve_backend = getattr(tui_mod, "_resolve_tui_backend");
    old = os.environ.get("JAC_AI_TUI_BACKEND");
    try {
        os.environ.pop("JAC_AI_TUI_BACKEND", None);
        assert resolve_backend() == "js" , "empty env must default to js";
        os.environ["JAC_AI_TUI_BACKEND"] = "  NA  ";
        assert resolve_backend() == "na" , "backend must be trimmed and lowercased";
    } finally {
        if old is None {
            os.environ.pop("JAC_AI_TUI_BACKEND", None);
        } else {
            os.environ["JAC_AI_TUI_BACKEND"] = old;
        }
    }
}


test "command resolution reports missing backends and unknown names" {
    tui_mod = importlib.import_module("jac_super.ai_agent.run_tui_session");
    resolve_cmd = getattr(tui_mod, "_resolve_tui_command");
    # run_tui_session lives in jac_super/ai_agent/; the sidecars are in
    # jac_super/ai_tui_*/, so pkg_root is jac_super/ (mirrors the launcher's own
    # `Path(__file__).resolve().parent.parent`).
    pkg_root = Path(tui_mod.__file__).resolve().parent.parent;

    # Unknown backend never resolves.
    bogus = resolve_cmd("bogus", pkg_root, "");
    assert not bogus["ok"] , "unknown backend must not resolve";
    assert "unknown TUI backend" in bogus["error"];

    # JS sidecar resolves to the built dist/main.js when present; otherwise it
    # fails gracefully with a build hint pointing back at na.
    js = resolve_cmd("js", pkg_root, "seed prompt");
    if js["ok"] {
        assert js["cmd_args"][-1] == "seed prompt" , "initial prompt must be last arg";
        assert js["cmd_args"][0] != "" , "js runtime must be set";
        assert js["cmd_args"][1] == "run" , "js spawn form is `<runtime> run <entry> [seed]`";
        assert js["cmd_args"][2].endswith("dist/main.js") , "js entry must be the built dist/main.js";
    } else {
        assert "JAC_AI_TUI_BACKEND=na" in js["hint"];
    }

    # na resolution depends only on the built binary; when present, the seed
    # prompt is threaded through as the first positional arg.
    na = resolve_cmd("na", pkg_root, "seed prompt");
    if na["ok"] {
        assert na["cmd_args"][-1] == "seed prompt" , "initial prompt must be last arg";
    } else {
        assert "jac-na-tui not found" in na["error"];
    }
}


test "run_tui_session suppresses terminal prints only for the session lifetime" {
    tui_mod = importlib.import_module("jac_super.ai_agent.run_tui_session");
    runner = getattr(tui_mod, "run_tui_session");
    old_resolve = getattr(tui_mod, "_resolve_tui_command");
    old_spawn = getattr(tui_mod, "_spawn_tui_backend");
    old_configure = getattr(ai_mod, "ui_configure");
    old_stream = getattr(ai_mod, "ui_stream");
    old_stop = getattr(ai_mod, "ui_stop");
    prior = os.environ.get("JAC_AI_SUPPRESS_TERM_OUTPUT");
    seen: list[str] = [];

    def fake_resolve(_backend: str, _pkg_root: any, _initial: str) -> dict {
        return {"ok": True, "cmd_args": ["dummy"], "error": "", "hint": ""};
    }

    def fake_spawn(_cmd_args: list) -> DummySpawnedProc {
        return DummySpawnedProc();
    }

    def fake_configure {
        seen.append(os.environ.get("JAC_AI_SUPPRESS_TERM_OUTPUT", ""));
    }

    def fake_stream -> any {
        for item in [] {
            yield item;
        }
    }

    def fake_stop { }

    setattr(tui_mod, "_resolve_tui_command", fake_resolve);
    setattr(tui_mod, "_spawn_tui_backend", fake_spawn);
    setattr(ai_mod, "ui_configure", fake_configure);
    setattr(ai_mod, "ui_stream", fake_stream);
    setattr(ai_mod, "ui_stop", fake_stop);
    try {
        os.environ.pop("JAC_AI_SUPPRESS_TERM_OUTPUT", None);
        rc = runner(AgentRequest(tui=True, cwd=os.getcwd()));
    } finally {
        setattr(tui_mod, "_resolve_tui_command", old_resolve);
        setattr(tui_mod, "_spawn_tui_backend", old_spawn);
        setattr(ai_mod, "ui_configure", old_configure);
        setattr(ai_mod, "ui_stream", old_stream);
        setattr(ai_mod, "ui_stop", old_stop);
        if prior is None {
            os.environ.pop("JAC_AI_SUPPRESS_TERM_OUTPUT", None);
        } else {
            os.environ["JAC_AI_SUPPRESS_TERM_OUTPUT"] = prior;
        }
    }

    assert rc == 0 , rc;
    assert seen == ["1"] , seen;
    assert os.environ.get("JAC_AI_SUPPRESS_TERM_OUTPUT") is None;
}
