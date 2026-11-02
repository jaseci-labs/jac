test "Child edges order siblings by sparse rank" {
    screen = MainScreen(key="main");
    header = Header(key="header", title="Osprey");
    transcript = TranscriptView(key="transcript", source_id="session.events");
    status = Status(key="status", phase="ready");
    prompt = Prompt(key="prompt", draft="");

    screen +>:Child(rank=1024):+> header;
    screen +>:Child(rank=2048):+> transcript;
    screen +>:Child(rank=3072):+> status;
    screen +>:Child(rank=4096):+> prompt;

    assert ordered_child_keys(screen) == ["header", "transcript", "status", "prompt", ];
    assert child_rank(screen, header) == 1024;
    assert child_rank(screen, transcript) == 2048;
}


test "duplicate sibling keys are detectable under one parent" {
    screen = MainScreen(key="main");
    first = Header(key="dup");
    second = Header(key="dup");
    screen +>:Child(rank=1024):+> first;
    screen +>:Child(rank=2048):+> second;
    assert duplicate_sibling_keys(screen) == ["dup"];
}


test "semantic nodes expose stable jid identity and local state only" {
    prompt = Prompt(key="prompt", draft="hello");
    prompt_id = node_id(prompt);
    assert len(prompt_id) == 32;
    assert prompt.draft == "hello";
    assert prompt.mode == "insert";
    assert not hasattr(prompt, "dirty");
    assert not hasattr(prompt, "runtime_id");
    assert not hasattr(prompt, "cached_lines");
}


test "overlay layer edges attach outside Child containment" {
    screen = MainScreen(key="main");
    overlay = ApprovalOverlay(key="approval");
    screen +>:Child(rank=1024):+> overlay;
    screen +>:Layer(z_index=10, modal=True):+> overlay;
    assert overlay in [screen->:Layer:->];
    assert enclosing_screen(overlay) is screen;
}


test "Feeds and FocusNext edges connect semantic regions" {
    screen = MainScreen(key="main");
    transcript = TranscriptView(key="transcript");
    prompt = Prompt(key="prompt");
    screen +>:Child(rank=1024):+> transcript;
    screen +>:Child(rank=2048):+> prompt;
    transcript +>:Feeds:+> prompt;
    transcript +>:FocusNext:+> prompt;
    assert prompt in [transcript->:Feeds:->];
    assert prompt in [transcript->:FocusNext:->];
}


test "Owns edge scopes UI-local ownership without Child containment" {
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt");
    draft_holder = Status(key="draft-meta", phase="owned");
    screen +>:Child(rank=1024):+> prompt;
    prompt +>:Owns:+> draft_holder;
    assert draft_holder in [prompt->:Owns:->];
    assert draft_holder not in [screen->:Child:->];
}


test "product archetypes keep only semantic fields on the node" {
    screen = MainScreen(key="main");
    tv = TranscriptView(
        key="transcript", source_id="session.events", follow_tail=True, scroll_offset=3,
    );
    status = Status(key="status", phase="streaming");
    prompt = Prompt(key="prompt", draft="partial", mode="insert");
    overlay = ApprovalOverlay(key="approval");
    header = Header(key="header", title="Osprey");

    assert screen.key == "main";
    assert tv.source_id == "session.events";
    assert tv.follow_tail;
    assert tv.scroll_offset == 3;
    assert status.phase == "streaming";
    assert prompt.draft == "partial";
    assert prompt.mode == "insert";
    assert overlay.key == "approval";
    assert header.title == "Osprey";

    for field in ["dirty", "rect", "cached_lines", "cells", "damage", "runtime_id"] {
        assert not hasattr(screen, field);
        assert not hasattr(tv, field);
        assert not hasattr(prompt, field);
        assert not hasattr(overlay, field);
    }
}


test "UiSessionRoot is a detachable session root with stable identity" {
    ui_root = UiSessionRoot(key="session");
    screen = MainScreen(key="main");
    ui_root +>:Child(rank=1024):+> screen;
    assert node_id(ui_root) != node_id(screen);
    assert len(node_id(ui_root)) == 32;
    assert ordered_child_keys(ui_root) == ["main"];
}
