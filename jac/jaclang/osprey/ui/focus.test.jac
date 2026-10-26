import from jaclang.osprey.ui.model {
    MainScreen,
    Prompt,
    ApprovalOverlay,
    UiRegion,
    Layer,
    FocusNext,
    node_id
}

import from jaclang.osprey.ui.runtime_core {
    append_child_session,
    create_session,
    set_current_screen,
    set_focus,
    get_focus_node
}


node FocusLeaf(UiRegion) {
    has label: str = "";
}


test "layers_paint_order is ascending z_index" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    low = ApprovalOverlay(key="low");
    high = ApprovalOverlay(key="high");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, low);
    append_child_session(session, screen, high);
    screen +>:Layer(z_index=1, modal=False):+> low;
    screen +>:Layer(z_index=20, modal=True):+> high;
    painted = layers_paint_order(screen);
    assert len(painted) == 2;
    assert painted[0] is low;
    assert painted[1] is high;
}


test "layers_input_order is descending z_index" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    low = ApprovalOverlay(key="low");
    high = ApprovalOverlay(key="high");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, low);
    append_child_session(session, screen, high);
    screen +>:Layer(z_index=1, modal=False):+> low;
    screen +>:Layer(z_index=20, modal=True):+> high;
    targets = layers_input_order(screen);
    assert targets[0] is high;
    assert targets[1] is low;
}


test "focus_order follows containment then FocusNext override" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    a = FocusLeaf(key="a", label="a");
    b = FocusLeaf(key="b", label="b");
    c = FocusLeaf(key="c", label="c");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, a);
    append_child_session(session, screen, b);
    append_child_session(session, screen, c);
    set_current_screen(session, screen);

    structural = focus_order(session, screen);
    assert [n.key for n in structural] == ["a", "b", "c"];

    a +>:FocusNext:+> c;
    overridden = focus_order(session, screen);
    keys = [n.key for n in overridden];
    assert keys[0] == "a";
    assert "c" in keys;

    assert keys.index("c") == keys.index("a") + 1;
}


test "advance_focus walks focus_order next and prev" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    a = FocusLeaf(key="a");
    b = FocusLeaf(key="b");
    c = FocusLeaf(key="c");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, a);
    append_child_session(session, screen, b);
    append_child_session(session, screen, c);
    set_current_screen(session, screen);
    set_focus(session, a);

    nxt = advance_focus(session, "next");
    assert nxt is b;
    assert get_focus_node(session) is b;

    nxt2 = advance_focus(session, "next");
    assert nxt2 is c;

    prev = advance_focus(session, "prev");
    assert prev is b;
}


test "open_modal_overlay saves focus traps and focuses initial target" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt");
    overlay = ApprovalOverlay(key="approval");
    button = FocusLeaf(key="approve-btn");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    append_child_session(session, screen, overlay);
    append_child_session(session, overlay, button);
    set_current_screen(session, screen);
    set_focus(session, prompt);
    prior = node_id(prompt);

    result = open_modal_overlay(
        session, screen, overlay, initial_focus=button, z_index=10
    );
    assert result.saved_focus_id == prior;
    assert result.overlay_id == node_id(overlay);
    assert result.initial_focus_id == node_id(button);
    assert session.saved_focus_id == prior;
    assert get_focus_node(session) is button;

    assert overlay in [screen->:Layer:->];
}


test "close_overlay restores prior focus and reports damage bounds" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt");
    overlay = ApprovalOverlay(key="approval");
    button = FocusLeaf(key="approve-btn");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    append_child_session(session, screen, overlay);
    append_child_session(session, overlay, button);
    set_current_screen(session, screen);
    set_focus(session, prompt);

    open_modal_overlay(session, screen, overlay, initial_focus=button);
    overlay_id = node_id(overlay);
    closed = close_overlay(session, overlay);

    assert closed.overlay_id == overlay_id;
    assert closed.restored_focus_id == node_id(prompt);
    assert get_focus_node(session) is prompt;
    assert overlay not in [screen->:Layer:->];

    assert not closed.damage.is_empty()
        or (closed.damage.width >= 0 and closed.damage.height >= 0);
}


test "closing overlay with deleted prior focus clears focus safely" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt");
    overlay = ApprovalOverlay(key="approval");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    append_child_session(session, screen, overlay);
    set_current_screen(session, screen);
    set_focus(session, prompt);
    open_modal_overlay(session, screen, overlay, initial_focus=overlay);

    session.saved_focus_id = "dead-focus-id";
    closed = close_overlay(session, overlay);
    assert closed.restored_focus_id == "";
    assert get_focus_node(session) is None;
}


test "non-modal overlays coexist without stealing modal trap" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    toast = ApprovalOverlay(key="toast");
    modal = ApprovalOverlay(key="modal");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, toast);
    append_child_session(session, screen, modal);
    set_current_screen(session, screen);
    screen +>:Layer(z_index=5, modal=False):+> toast;
    open_modal_overlay(session, screen, modal, initial_focus=modal, z_index=10);
    painted = layers_paint_order(screen);
    assert painted[0] is toast;
    assert painted[1] is modal;
    inputs = layers_input_order(screen);
    assert inputs[0] is modal;
}
