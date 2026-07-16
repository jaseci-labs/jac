"""Phase 2 tests: bridge schema, projector, queue, legacy normalizer."""

import importlib;
import pytest;


test "bridge schema receipt round-trip with unicode" {
    schema = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    raw = schema.encode_receipt(
        True, schema.DISP_STARTED, command_id="c1", prompt_id="p1"
    );
    assert "schema_id" in raw;
    assert ("\\u" in raw) == False;  # ensure_ascii=False
    receipt = schema.decode_receipt(raw);
    assert receipt["accepted"] == True;
    assert receipt["disposition"] == schema.DISP_STARTED;
    assert receipt["command_id"] == "c1";

    bad = '{"schema_id":"wrong","kind":"command_receipt","accepted":true,"disposition":"started","command_id":"","prompt_id":"","error":{"code":"","message":"","retryable":false}}';
    try {
        schema.decode_receipt(bad);
        assert False , "expected schema_id mismatch";
    } except ValueError { }
}


test "bridge schema batch and snapshot reject malformed without partial apply" {
    schema = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    batch = schema.encode_batch(1, 1, 2, [{"kind": "diagnostic", "text": "émoji 😀"}]);
    decoded = schema.decode_batch(batch);
    assert decoded["epoch"] == 1;
    assert decoded["mutations"][0]["text"] == "émoji 😀";

    snap = schema.encode_snapshot(1, 2, schema.LIFE_IDLE, [], model_name="m");
    assert schema.decode_snapshot(snap)["lifecycle"] == schema.LIFE_IDLE;

    try {
        schema.decode_batch(
            '{"schema_id":"' + schema.SCHEMA_ID + '","kind":"session_event_batch","epoch":1,"first_seq":1,"last_seq":1}'
        );
        assert False , "missing mutations must fail";
    } except ValueError { }

    try {
        schema.decode_snapshot(
            '{"schema_id":"' + schema.SCHEMA_ID + '","kind":"ui_snapshot","epoch":1,"base_seq":0,"lifecycle":"idle"}'
        );
        assert False , "missing messages must fail";
    } except ValueError { }
}


test "legacy normalizer maps stopping and rejects unknown kinds" {
    norm = importlib.import_module("jaclang.cli.ai_tui.legacy_event_normalizer");
    assert norm.normalize_status("stopping") == "stopping";
    assert norm.normalize_status("RUNNING") == "running";
    try {
        norm.normalize_status("nope");
        assert False;
    } except ValueError { }
    try {
        norm.normalize_event_kind("mystery");
        assert False;
    } except ValueError { }

    muts = norm.legacy_frame_to_mutations(
        {
            "status": "stopping",
            "ev": {"id": 7, "kind": "user", "node": "t", "text": "hi"}
        },
        epoch=3,
        seq_start=1
    );
    assert len(muts) == 2;
    assert muts[0].lifecycle == "stopping";
    assert muts[1].message_id == "7";
    assert muts[1].text == "hi";
}


test "projector orders events and emits agent_settled exactly once" {
    proj_mod = importlib.import_module("jaclang.cli.ai_tui.ui_event_projector");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    p = proj_mod.UiEventProjector();

    p.apply(models.UiMutation(kind=bridge.MUT_AGENT_START, seq=1, lifecycle="running"));
    p.apply(
        models.UiMutation(
            kind=bridge.MUT_MESSAGE_START,
            seq=2,
            message_id="u1",
            part_id="u1:text",
            text="hello",
            payload={"role": "user"}
        )
    );
    p.apply(
        models.UiMutation(
            kind=bridge.MUT_MESSAGE_UPDATE,
            seq=3,
            message_id="a1",
            part_id="a1:text",
            op="text_append",
            text="ans"
        )
    );
    p.apply(models.UiMutation(kind=bridge.MUT_AGENT_END, seq=4, will_retry=False));
    p.apply(models.UiMutation(kind=bridge.MUT_AGENT_SETTLED, seq=5));

    snap = p.snapshot();
    assert snap.lifecycle == "idle";
    assert len(snap.messages) >= 1;
    assert snap.messages[0].parts[0].text == "hello";
    assert snap.messages[1].parts[0].text == "ans";

    try {
        p.apply(models.UiMutation(kind=bridge.MUT_AGENT_SETTLED, seq=6));
        assert False , "second agent_settled must fail";
    } except ValueError { }
}


test "projector rejects sequence gaps" {
    proj_mod = importlib.import_module("jaclang.cli.ai_tui.ui_event_projector");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    p = proj_mod.UiEventProjector();
    p.apply(models.UiMutation(kind=bridge.MUT_AGENT_START, seq=1));
    try {
        p.apply(models.UiMutation(kind=bridge.MUT_AGENT_END, seq=3));
        assert False;
    } except ValueError { }
}


test "event queue coalesces appends and overflows to snapshot_required" {
    qmod = importlib.import_module("jaclang.cli.ai_tui.event_queue");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    q = qmod.TuiEventQueue(max_records=3, max_bytes=10_000_000);
    q.submit(
        models.UiMutation(
            kind=bridge.MUT_MESSAGE_UPDATE,
            seq=1,
            epoch=1,
            message_id="a",
            part_id="a:t",
            op="text_append",
            text="a"
        )
    );
    q.submit(
        models.UiMutation(
            kind=bridge.MUT_MESSAGE_UPDATE,
            seq=2,
            epoch=1,
            message_id="a",
            part_id="a:t",
            op="text_append",
            text="b"
        )
    );
    # Coalesced into one record.
    assert len(q._items) == 1;
    assert q._items[0].text == "ab";

    q2 = qmod.TuiEventQueue(max_records=2, max_bytes=10_000_000);
    q2.submit(models.UiMutation(kind=bridge.MUT_DIAGNOSTIC, seq=1, epoch=1, text="1"));
    q2.submit(models.UiMutation(kind=bridge.MUT_DIAGNOSTIC, seq=2, epoch=1, text="2"));
    q2.submit(models.UiMutation(kind=bridge.MUT_DIAGNOSTIC, seq=3, epoch=1, text="3"));
    assert q2.snapshot_required == True;
    assert q2._items[0].kind == bridge.MUT_SNAPSHOT_REQUIRED;

    batch = q2.drain(64);
    assert len(batch.mutations) == 1;
    assert batch.mutations[0].kind == bridge.MUT_SNAPSHOT_REQUIRED;
}
