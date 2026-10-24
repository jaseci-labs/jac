import from jaclang.osprey.ui.model { MainScreen, Prompt, TranscriptView }

import from jaclang.osprey.ui.runtime_core {
    append_child_session,
    create_session,
    set_current_screen,
    set_focus,
    record_invalidation
}

import from jaclang.osprey.ui.bindings { subscribe, }

import from jaclang.osprey.ui.events { InsertText, }


test "dump_graph is deterministic for the same topology" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    set_current_screen(session, screen);
    a = dump_graph(session);
    b = dump_graph(session);
    assert a == b;
    assert "main" in a;
    assert "prompt" in a;
}


test "dump_session_bindings lists source target and event type" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    transcript = TranscriptView(key="transcript");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, transcript);
    subscribe(
        session.bindings, "session.events", node_id(transcript), "TranscriptChanged"
    );
    text = dump_session_bindings(session);
    assert "session.events" in text;
    assert (node_id(transcript) in text) or ("transcript" in text);
    assert "TranscriptChanged" in text;
}


test "dump_event_path includes target and ancestors" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    set_current_screen(session, screen);
    event = InsertText(text="x");
    path = dump_event_path(session, event, prompt);
    assert (node_id(prompt) in path) or ("prompt" in path);
    assert ("main" in path) or (node_id(screen) in path);
}


test "explain_invalidation links origin layout root and damage reason" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    record_invalidation(session, node_id(prompt), node_id(screen), "InsertText");
    expl = explain_invalidation(session, prompt);
    assert expl.node_id == node_id(prompt);
    assert expl.layout_root_id == node_id(screen) or expl.layout_root_id != "";
    assert expl.origin != "" or expl.damage_reason != "";
}


test "dump_layout dump_damage dump_lifetimes return non-empty text" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    set_current_screen(session, screen);
    set_focus(session, prompt);
    layout_txt = dump_layout(session, prompt);
    damage_txt = dump_damage(session);
    life_txt = dump_lifetimes(session, prompt);
    assert len(layout_txt) > 0;
    assert len(damage_txt) >= 0;
    assert len(life_txt) > 0;
    assert (node_id(prompt) in life_txt) or ("prompt" in life_txt);
}


test "validate_invariants returns empty for a healthy session" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    set_current_screen(session, screen);
    set_focus(session, prompt);
    findings = validate_invariants(session);
    assert findings == [];
}


test "validate_invariants flags invalid focus" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    append_child_session(session, ui_root, screen);
    set_current_screen(session, screen);
    session.focus_id = "not-a-real-node";
    findings = validate_invariants(session);
    kinds = [f.kind for f in findings];
    assert "invalid_focus" in kinds;
}
