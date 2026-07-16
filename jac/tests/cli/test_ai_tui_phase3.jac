"""Phase 3 tests: instance-owned sessions, dispose, runtime replacement."""

import importlib;
import time;
import from threading { Event, Thread }


test "session manager in_memory isolates ledgers across instances" {
    mgr_mod = importlib.import_module("jaclang.cli.ai_tui.core.session_manager");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    a = mgr_mod.SessionManager.in_memory("/tmp/a");
    b = mgr_mod.SessionManager.in_memory("/tmp/b");
    a.append(models.SessionMutation(kind="user", text="one"));
    b.append(models.SessionMutation(kind="user", text="two"));
    assert a.entries is not b.entries;
    assert len(a.entries) == 1;
    assert len(b.entries) == 1;
    assert a.entries[0].text == "one";
    assert b.entries[0].text == "two";
    assert a.cwd == "/tmp/a";
    assert b.cwd == "/tmp/b";
    a.dispose();
    try {
        a.append(models.SessionMutation(kind="user", text="x"));
        assert False , "disposed manager must reject append";
    } except RuntimeError { }
}


test "sequential adapters share no queue ledger stop or subscription state" {
    adapter_mod = importlib.import_module("jaclang.cli.ai_tui.tui_session_adapter");
    first = adapter_mod.TuiSessionAdapter(
        cwd="/tmp/s1", stub=True, model_name="stub-a"
    );
    r1 = first.start({"cwd": "/tmp/s1", "stub": True, "model_name": "stub-a"});
    assert r1.ok;
    sid1 = r1.session_id;
    q1 = first.queue;
    mgr1 = first.runtime.current().manager;
    stop1 = first.runtime.current()._stop;

    receipt = first.submit(adapter_mod.make_prompt_command("hello-one"));
    assert receipt.accepted == True;
    deadline = time.monotonic() + 2.0;
    while time.monotonic() < deadline {
        if first.runtime.current().settled {
            break;
        }
        time.sleep(0.02);
    }
    batch1 = first.poll(64);
    assert len(batch1.mutations) > 0;
    assert len(mgr1.entries) >= 1;

    d1 = first.dispose(reason="done", deadline_ms=2000);
    assert d1.ok == True;
    assert d1.timed_out == False;
    assert d1.joined_workers >= 1;

    second = adapter_mod.TuiSessionAdapter(
        cwd="/tmp/s2", stub=True, model_name="stub-b"
    );
    r2 = second.start({"cwd": "/tmp/s2", "stub": True, "model_name": "stub-b"});
    assert r2.ok;
    assert r2.session_id != sid1;
    assert second.queue is not q1;
    assert second.runtime.current().manager is not mgr1;
    assert second.runtime.current()._stop is not stop1;
    assert len(second.runtime.current().manager.entries) == 0;

    receipt2 = second.submit(adapter_mod.make_prompt_command("hello-two"));
    assert receipt2.accepted == True;
    deadline = time.monotonic() + 2.0;
    while time.monotonic() < deadline {
        if second.runtime.current().settled {
            break;
        }
        time.sleep(0.02);
    }
    assert second.runtime.current().manager.entries[0].text == "hello-two";
    assert mgr1.entries[0].text == "hello-one";
    d2 = second.dispose(reason="done", deadline_ms=2000);
    assert d2.ok == True;
}


test "abort settles deterministically and idle abort is no-op" {
    adapter_mod = importlib.import_module("jaclang.cli.ai_tui.tui_session_adapter");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    ad = adapter_mod.TuiSessionAdapter(cwd="/tmp/abort", stub=True);
    ad.start({"cwd": "/tmp/abort", "stub": True});

    idle_abort = ad.submit(adapter_mod.make_abort_command("a0"));
    assert idle_abort.accepted == True;
    assert idle_abort.disposition == bridge.DISP_NO_OP;

    sess = ad.runtime.current();
    sess.lifecycle = bridge.LIFE_RUNNING;
    sess.settled = False;
    abort = ad.submit(adapter_mod.make_abort_command("a1"));
    assert abort.accepted == True;
    assert sess.lifecycle == bridge.LIFE_STOPPING;

    sess.cancel_requested = True;
    sess._settle_abort();
    assert sess.lifecycle == bridge.LIFE_IDLE;
    assert sess.settled == True;
    ad.dispose(deadline_ms=2000);
}


test "runtime replace recreates cwd services and bumps epoch" {
    rt_mod = importlib.import_module("jaclang.cli.ai_tui.core.agent_session_runtime");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    rt = rt_mod.AgentSessionRuntime(cwd="/tmp/old", stub=True, model_name="m1");
    s1 = rt.current();
    s1.manager.append(models.SessionMutation(kind="user", text="keep-old"));
    old_mgr = s1.manager;
    old_id = s1.session_id;
    epoch0 = rt.epoch;

    seen: list[str] = [];

    def on_ev(ev: any) {
        seen.append(str(ev.kind));
    }

    rt.subscribe(on_ev);

    result = rt.replace(models.SessionTarget(cwd="/tmp/new", mode="new"));
    assert result.ok == True;
    assert result.epoch == epoch0 + 1;
    assert result.session_id != old_id;
    s2 = rt.current();
    assert s2.cwd == "/tmp/new";
    assert s2.manager is not old_mgr;
    assert len(s2.manager.entries) == 0;
    assert old_mgr.disposed == True;
    assert "runtime_replaced" in seen;
    rt.dispose(deadline_ms=2000);
}


test "dispose reports timeout when a worker ignores stop" {
    sess_mod = importlib.import_module("jaclang.cli.ai_tui.core.agent_session");
    sess = sess_mod.AgentSession(cwd="/tmp/hang", stub=True);
    sess.start_feed();
    hang_stop = Event();

    def hang {
        hang_stop.wait(5.0);
    }

    tw = Thread(target=hang, daemon=False);
    sess._workers.append(tw);
    tw.start();
    result = sess.dispose(reason="test", deadline_ms=50);
    assert result.timed_out == True;
    assert result.ok == False;
    hang_stop.set();
    tw.join(1.0);
}
