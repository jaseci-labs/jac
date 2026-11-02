import from jaclang.osprey.ui.model { MainScreen, Prompt, node_id, }

import from jaclang.osprey.ui.runtime_core {
    create_session,
    append_child_session,
    dispose_session
}

import from jaclang.osprey.ui.bindings { subscribe }


test "create_session tracked jids are not reachable from persistent root" {
    handle = create_session();
    session = handle.session;
    assert session.ui_root is not None;
    reachable = ui_jids_reachable_from_persistent_root(session.tracked_node_ids);
    assert reachable == [];
}


test "populated session stays detached from persistent root until dispose" {
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
    session.renderer.layout[node_id(prompt)] = {"width": 80};
    assert ui_jids_reachable_from_persistent_root(session.tracked_node_ids) == [];
    dispose_session(session);
}
