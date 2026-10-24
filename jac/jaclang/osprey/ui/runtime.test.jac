import from jaclang.osprey.ui.model { MainScreen, Prompt, TranscriptView }

import from jaclang.osprey.ui.bindings { subscribe }

test "create_session builds detached ui_root not connected to persistent root" {
    handle = create_session();
    session = handle.session;
    assert session.ui_root is not None;
    assert session.ui_root.key == "session";
    assert handle.ui_root_id == node_id(session.ui_root);
    assert node_id(session.ui_root) in session.tracked_node_ids;
    assert not session.disposed;
}


test "append_child_session only accepts parents under ui_root" {
    handle = create_session();
    session = handle.session;
    orphan = MainScreen(key="orphan");
    child = Prompt(key="prompt");
    failed = False;
    try {
        append_child_session(session, orphan, child);
    } except ValueError {
        failed = True;
    }
    assert failed;
    assert node_id(child) not in session.tracked_node_ids;
}


test "set_focus and get_focus round trip" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt", draft="hi");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    set_focus(session, prompt);
    focused = get_focus_node(session);
    assert focused is prompt;
    set_focus(session, None);
    assert get_focus_node(session) is None;
}


test "graph_revision increments on append_child_session" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    assert session.graph_revision == 0;
    screen = MainScreen(key="main");
    append_child_session(session, ui_root, screen);
    assert session.graph_revision == 1;
    prompt = Prompt(key="prompt");
    append_child_session(session, screen, prompt);
    assert session.graph_revision == 2;
}


test "Gate 1 lifecycle dispose releases bindings renderer and capabilities" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt", draft="");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    subscribe(
        session.bindings, "session.events", node_id(prompt), "TranscriptChanged",
    );
    register_capability(session, node_id(prompt), "input");
    session.renderer.layout[node_id(prompt)] = {"width": 80};
    assert not is_empty(session.bindings);
    dispose_session(session);
    assert session.disposed;
    assert is_empty(session.bindings);
    assert len(session.renderer.layout) == 0;
    assert len(session.capabilities.by_node) == 0;
    assert validate_session(session) == [];
}


test "validate_session detects orphan binding" {
    handle = create_session();
    session = handle.session;
    subscribe(
        session.bindings,
        "fake.source",
        "00000000000000000000000000000000",
        "TranscriptChanged",
    );
    leaks = validate_session(session);
    kinds = [leak.kind for leak in leaks];
    assert "orphan_binding" in kinds;
}


test "validate_session detects invalid focus_id" {
    handle = create_session();
    session = handle.session;
    session.focus_id = "00000000000000000000000000000000";
    leaks = validate_session(session);
    kinds = [leak.kind for leak in leaks];
    assert "invalid_focus" in kinds;
}


test "validate_session detects stale Feeds edge to untracked node" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    transcript = TranscriptView(key="transcript");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, transcript);
    orphan = Prompt(key="orphan");
    transcript +>:Feeds:+> orphan;
    leaks = validate_session(session);
    kinds = [leak.kind for leak in leaks];
    assert "stale_edge" in kinds;
}


test "dispose clears renderer layout keys" {
    handle = create_session();
    session = handle.session;
    session.renderer.layout["00000000000000000000000000000000"] = {"x": 0};
    assert len(session.renderer.layout) != 0;
    dispose_session(session);
    assert len(session.renderer.layout) == 0;
}


test "failed mutation under session does not bump graph_revision" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    append_child_session(session, ui_root, screen);
    first = Prompt(key="same");
    second = Prompt(key="same");
    append_child_session(session, screen, first);
    rev = session.graph_revision;
    failed = False;
    try {
        append_child_session(session, screen, second);
    } except ValueError {
        failed = True;
    }
    assert failed;
    assert session.graph_revision == rev;
}
