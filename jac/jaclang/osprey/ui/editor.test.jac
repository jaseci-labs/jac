import from jaclang.osprey.ui.model { MainScreen }

import from jaclang.osprey.ui.runtime_core {
    create_session,
    dispose_session,
    append_child_session,
    set_current_screen
}

import from jaclang.osprey.ui.events { dispatch_event }


test "editor_insert advances caret" {
    p = Prompt(key="p");
    editor_insert(p, "ab");
    assert p.draft == "ab";
    assert p.caret == 2;
    editor_insert(p, "c");
    assert p.draft == "abc";
    assert p.caret == 3;
}


test "editor_backspace and selection replace" {
    p = Prompt(key="p");
    editor_insert(p, "hello");
    editor_set_selection(p, 1, 4);
    editor_insert(p, "i");
    assert p.draft == "hio";
    assert p.caret == 2;
}


test "editor_move_up_down across lines" {
    p = Prompt(key="p");
    editor_insert(p, "aa\nbbb");
    p.caret = len(p.draft);
    editor_move_up(p);
    assert p.caret == 2;
    editor_move_down(p);

    assert p.caret == 5;
}


test "editor_history_prev_next" {
    p = Prompt(key="p");
    editor_insert(p, "one");
    editor_submit(p);
    editor_insert(p, "two");
    editor_submit(p);
    editor_history_prev(p);
    assert p.draft == "two";
    editor_history_prev(p);
    assert p.draft == "one";
    editor_history_next(p);
    assert p.draft == "two";
}


test "caret display col respects wide glyph width" {
    p = Prompt(key="p");
    editor_insert(p, "あ");
    assert display_width(p.draft) >= 1;
    assert editor_caret_display_col(p) == display_width(p.draft);
}


test "AblePrompt abilities handle insert submit cancel" {
    handle = create_session();
    session = handle.session;
    ui_root = session.ui_root;
    assert ui_root is not None;
    screen = MainScreen(key="main");
    prompt = AblePrompt(key="prompt");
    append_child_session(session, ui_root, screen);
    append_child_session(session, screen, prompt);
    set_current_screen(session, screen);

    ins = dispatch_event(session, InsertText(text="hi"), prompt);
    assert ins.handled;
    assert prompt.draft == "hi";

    sub = dispatch_event(session, Submit(), prompt);
    assert sub.handled;
    assert prompt.draft == "";
    assert len(sub.effects) == 1;

    dispatch_event(session, InsertText(text="bye"), prompt);
    cancel_ev = dispatch_event(session, Cancel(), prompt);
    assert cancel_ev.handled;
    assert prompt.draft == "";
    dispose_session(session);
}
