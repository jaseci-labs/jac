import from jaclang.osprey.ui.model { MainScreen, UiRegion }

import from jaclang.osprey.ui.runtime_core {
    append_child_session,
    create_session,
    dispose_session,
    set_current_screen,
    set_focus
}


node EchoRegion(UiRegion) {
    has seen: list[str] = [];

    can on_insert with InsertText entry;
    can on_submit with Submit entry;
    can on_stop with Cancel entry;
}


node BubbleParent(UiContainer) {
    has arrivals: int = 0;

    can on_insert with InsertText entry;
}


node SilentRegion(UiRegion) {}


node FocusableA(UiRegion) {}


node FocusableB(UiRegion) {}


test "node ability receives dispatched event and mutates state" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    region = EchoRegion(key="echo");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, region);
    set_current_screen(session, screen);

    event = dispatch_event(session, InsertText(text="hi"), region);
    assert event.handled;
    assert region.seen == ["insert:hi"];
}


test "event bubbles to ancestors as the same instance" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    parent = BubbleParent(key="parent");
    child = SilentRegion(key="child");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, parent);
    append_child_session(session, parent, child);
    set_current_screen(session, screen);

    event = InsertText(text="up");
    dispatch_event(session, event, child);
    assert parent.arrivals == 1;
    assert not event.propagation_stopped;
}


test "propagation_stopped prevents ancestor delivery but handled does not" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    stopping = EchoRegion(key="stopping");
    parent = BubbleParent(key="parent");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, parent);
    append_child_session(session, parent, stopping);
    set_current_screen(session, screen);

    event = dispatch_event(session, Cancel(), stopping);
    assert event.propagation_stopped;
    assert stopping.seen == ["cancel"];
    assert parent.arrivals == 0;

    handled_event = dispatch_event(session, InsertText(text="keep"), stopping);
    assert handled_event.handled;
    assert parent.arrivals == 1;
}


test "effects accumulate during propagation and consume clears them" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = EchoRegion(key="prompt");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    set_current_screen(session, screen);

    event = dispatch_event(session, Submit(), prompt);
    assert event.default_prevented;
    effects = pending_effects(event);
    assert len(effects) == 1;
    assert isinstance(effects[0], SendPrompt);
    taken = consume_effects(event);
    assert len(taken) == 1;
    assert pending_effects(event) == [];
}


test "target resolution prefers modal overlay then focus then screen" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    focused = FocusableA(key="focused");
    overlay = Overlay(key="overlay");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, focused);
    append_child_session(session, screen, overlay);
    set_current_screen(session, screen);

    assert resolve_input_target(session) is screen;
    set_focus(session, focused);
    assert resolve_input_target(session) is focused;

    screen +>:Layer(z_index=10, modal=True):+> overlay;
    assert topmost_modal_overlay(session) is overlay;
    assert resolve_input_target(session) is overlay;

    set_focus(session, None);
    assert resolve_input_target(session) is overlay;
}


test "explicit target bypasses modal and focus chain" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    bound = EchoRegion(key="bound");
    overlay = Overlay(key="overlay");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, bound);
    append_child_session(session, screen, overlay);
    set_current_screen(session, screen);
    screen +>:Layer(z_index=1, modal=True):+> overlay;

    change = TranscriptChanged(revision=7);
    dispatch_event(session, change, bound);
    assert bound.seen == [];
    assert change.revision == 7;
    assert trace_event_path(session, bound)[0] == node_id(bound);
}


test "MoveFocus default action walks structural siblings" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    first = FocusableA(key="first");
    second = FocusableB(key="second");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, first);
    append_child_session(session, screen, second);
    set_current_screen(session, screen);
    set_focus(session, first);

    dispatch_event(session, MoveFocus(direction="next"));
    assert session.focus_id == node_id(second);

    dispatch_event(session, MoveFocus(direction="prev"));
    assert session.focus_id == node_id(first);
}


test "default_prevented suppresses the framework default action" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    first = FocusableA(key="first");
    second = FocusableB(key="second");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, first);
    append_child_session(session, screen, second);
    set_current_screen(session, screen);
    set_focus(session, first);

    blocker = SilentRegion(key="blocker");
    append_child_session(session, screen, blocker);
    event = MoveFocus(direction="next");
    event.default_prevented = True;
    dispatch_event(session, event, blocker);
    assert session.focus_id == node_id(first);
}


test "events pass through nodes without matching abilities" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    silent = SilentRegion(key="silent");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, silent);
    set_current_screen(session, screen);

    event = dispatch_event(session, StreamChunk(text="abc"), silent);
    assert not event.handled;
    assert not event.propagation_stopped;
    assert pending_effects(event) == [];
}


test "dispatch on a disposed session raises" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    dispose_session(session);
    failed = False;
    try {
        dispatch_event(session, Submit());
    } except ValueError {
        failed = True;
    }
    assert failed;
}


test "dispatch_event_with_effects returns effects after propagation" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = EchoRegion(key="prompt");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    set_current_screen(session, screen);

    effects = dispatch_event_with_effects(session, Submit(), prompt);
    assert len(effects) == 1;
    assert isinstance(effects[0], SendPrompt);
}


test "containment path runs target to screen inclusive" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    mid = BubbleParent(key="mid");
    leaf = SilentRegion(key="leaf");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, mid);
    append_child_session(session, mid, leaf);
    set_current_screen(session, screen);

    ids = trace_event_path(session, leaf);
    assert ids == [node_id(leaf), node_id(mid), node_id(screen), ];
}


test "handled default_prevented and propagation_stopped are independent flags" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    region = EchoRegion(key="echo");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, region);
    set_current_screen(session, screen);

    cancel = dispatch_event(session, Cancel(), region);
    assert cancel.propagation_stopped;
    assert not cancel.handled;
    assert not cancel.default_prevented;

    submit = dispatch_event(session, Submit(), region);
    assert submit.handled;
    assert submit.default_prevented;
    assert not submit.propagation_stopped;
}


test "Resize walker carries terminal dimensions" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    append_child_session(session, ui_root, screen);
    set_current_screen(session, screen);

    event = Resize(width=120, height=40);
    dispatch_event(session, event, screen);
    assert event.width == 120;
    assert event.height == 40;
    assert not event.handled;
}

impl EchoRegion.on_insert with InsertText entry {
    self.seen.append("insert:" + visitor.text);
    visitor.handled = True;
}

impl EchoRegion.on_submit with Submit entry {
    self.seen.append("submit");
    visitor.effects.append(SendPrompt(text="x"));
    visitor.default_prevented = True;
    visitor.handled = True;
}

impl EchoRegion.on_stop with Cancel entry {
    self.seen.append("cancel");
    visitor.propagation_stopped = True;
}


impl BubbleParent.on_insert with InsertText entry {
    self.arrivals += 1;
}
