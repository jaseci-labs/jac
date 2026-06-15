"""Regression tests for the `jac ai --tui` sidecar command bridge."""

import importlib;
import jaclang.cli.ai_agent as ai_mod;


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
