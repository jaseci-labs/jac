"""Phase 4 tests: typed embed surface, ownership seams, dispose/finalize gates."""

import importlib;
import json;
import from pathlib { Path }


test "typed start submit poll snapshot dispose round-trip on stub" {
    mod = importlib.import_module("jaclang.cli.ai_tui.embed_agent");
    schema = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    if mod?._adapter is not None {
        mod.dispose(
            '{"schema_id":"jac.ai_tui.bridge.v1","kind":"dispose_spec","reason":"reset","deadline_ms":500}'
        );
    }

    start_raw = mod.start(
        '{"schema_id":"jac.ai_tui.bridge.v1","kind":"agent_request","stub":true,"model_name":"stub"}'
    );
    start = schema.decode_start_result(start_raw);
    assert start["ok"] == True;
    assert start["epoch"] >= 1;

    cmd = schema.encode_command(schema.CMD_KIND_PROMPT, {"text": "phase4-hi"});
    receipt = schema.decode_receipt(mod.submit(cmd));
    assert receipt["accepted"] == True;

    batch = schema.decode_batch(mod.poll("64"));
    assert batch["kind"] == "session_event_batch";
    assert isinstance(batch["mutations"], list);

    snap = schema.decode_snapshot(mod.snapshot());
    assert snap["kind"] == "ui_snapshot";

    d1 = schema.decode_dispose_result(
        mod.dispose(
            '{"schema_id":"jac.ai_tui.bridge.v1","kind":"dispose_spec","reason":"t1","deadline_ms":2000}'
        )
    );
    assert d1["ok"] == True;
    d2 = schema.decode_dispose_result(
        mod.dispose(
            '{"schema_id":"jac.ai_tui.bridge.v1","kind":"dispose_spec","reason":"t2","deadline_ms":2000}'
        )
    );
    assert d2["ok"] == True;
    assert mod?._adapter is None;
}


test "phase4 native ownership: only EmbedRuntime imports jacpyembed" {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    cli_dir = Path(shared_mod.__file__).resolve().parent.parent;
    na = cli_dir / "ai_tui_na";
    offenders = [];
    for path in sorted(na.glob("*.na.jac")) {
        if path.name == "embed_runtime.na.jac" {
            continue;
        }
        text = path.read_text();
        if "import from jacpyembed" in text or "jpy_Py" in text {
            offenders.append(path.name);
        }
    }
    assert offenders == [] , f"CPython symbols leaked outside EmbedRuntime: {offenders}";
    rt_src = (na / "embed_runtime.na.jac").read_text();
    assert "import from jacpyembed" in rt_src;
    assert "def finalize_if_safe" in rt_src;
    assert "mark_workers_safe" in rt_src;
    client_src = (na / "embed_session_client.na.jac").read_text();
    assert "import from jacpyembed" not in client_src;
    assert "def drain_into" in client_src;
}


test "phase4 host wires EmbedSessionClient and skips finalize on timeout" {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    cli_dir = Path(shared_mod.__file__).resolve().parent.parent;
    host_src = (cli_dir / "ai_tui_na" / "host_embed.na.jac").read_text();
    assert "EmbedRuntime" in host_src;
    assert "EmbedSessionClient" in host_src;
    assert "finalize_if_safe" in host_src;
    assert "mark_workers_safe(not disp2.timed_out)" in host_src;
    assert "jpy_Py_Finalize" not in host_src;
}


test "bridge schema encodes start and dispose results" {
    schema = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    s = schema.encode_start_result(True, session_id="abc", epoch=2);
    assert schema.decode_start_result(s)["session_id"] == "abc";
    d = schema.encode_dispose_result(True, True, "quit", 3);
    got = schema.decode_dispose_result(d);
    assert got["timed_out"] == True;
    assert got["joined_workers"] == 3;
}
