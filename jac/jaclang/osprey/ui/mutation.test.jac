test "append_child maintains sparse rank ordering" {
    screen = MainScreen(key="main");
    header = Header(key="header", title="Osprey");
    transcript = TranscriptView(key="transcript", source_id="session.events");
    status = Status(key="status", phase="ready");
    prompt = Prompt(key="prompt", draft="");

    append_child(screen, header);
    append_child(screen, transcript);
    append_child(screen, status);
    append_child(screen, prompt);

    assert ordered_child_keys(screen) == ["header", "transcript", "status", "prompt", ];
    assert child_rank(screen, transcript) > child_rank(screen, header);
    assert child_rank(screen, prompt) > child_rank(screen, status);
}


test "move_before reorders siblings without remounting unrelated nodes" {
    screen = MainScreen(key="main");
    header = Header(key="header");
    transcript = TranscriptView(key="transcript");
    status = Status(key="status");
    prompt = Prompt(key="prompt");

    append_child(screen, header);
    append_child(screen, transcript);
    append_child(screen, status);
    append_child(screen, prompt);

    move_before(prompt, header);
    assert ordered_child_keys(screen) == ["prompt", "header", "transcript", "status", ];
    assert child_parent(prompt) is screen;
    assert child_parent(header) is screen;
}


test "replace swaps one mounted node for another at the same slot" {
    screen = MainScreen(key="main");
    old_status = Status(key="status", phase="booting");
    prompt = Prompt(key="prompt");
    append_child(screen, old_status);
    append_child(screen, prompt);

    new_status = Status(key="status", phase="ready");
    replace(old_status, new_status);

    assert ordered_child_keys(screen) == ["status", "prompt"];
    assert new_status.phase == "ready";
    assert child_parent(old_status) is None;
}


test "append_child rejects duplicate sibling keys atomically" {
    screen = MainScreen(key="main");
    first = Header(key="dup");
    second = Header(key="dup");
    append_child(screen, first);
    failed = False;
    try {
        append_child(screen, second);
    } except ValueError {
        failed = True;
    }
    assert failed;
    assert ordered_child_keys(screen) == ["dup"];
}


test "detach and dispose_subtree clear containment without touching jid keys" {
    ui_root = UiSessionRoot(key="session");
    screen = MainScreen(key="main");
    prompt = Prompt(key="prompt", draft="hi");
    prompt_id = node_id(prompt);

    append_child(ui_root, screen);
    append_child(screen, prompt);
    detach(prompt);
    assert child_parent(prompt) is None;
    assert node_id(prompt) == prompt_id;

    dispose_subtree(ui_root);
    assert child_parent(screen) is None;
}


test "insert_before and insert_after place relative to a sibling" {
    screen = MainScreen(key="main");
    a = Header(key="a");
    b = Status(key="b");
    c = Prompt(key="c");
    append_child(screen, a);
    append_child(screen, c);

    insert_before(screen, b, c);
    assert ordered_child_keys(screen) == ["a", "b", "c"];
    d = TranscriptView(key="d");
    insert_after(screen, d, a);
    assert ordered_child_keys(screen) == ["a", "d", "b", "c"];
}


test "move_after reorders without changing parent" {
    screen = MainScreen(key="main");
    a = Header(key="a");
    b = Status(key="b");
    c = Prompt(key="c");
    append_child(screen, a);
    append_child(screen, b);
    append_child(screen, c);
    move_after(a, c);
    assert ordered_child_keys(screen) == ["b", "c", "a"];
    assert child_parent(a) is screen;
}


test "append_child rejects containment cycles atomically" {
    outer = MainScreen(key="outer");
    inner = MainScreen(key="inner");
    append_child(outer, inner);
    failed = False;
    try {
        append_child(inner, outer);
    } except ValueError {
        failed = True;
    }
    assert failed;
    assert ordered_child_keys(outer) == ["inner"];
    assert child_parent(outer) is None;
}


test "move into own descendant is rejected without partial mutation" {
    screen = MainScreen(key="main");
    mid = MainScreen(key="mid");
    leaf = Prompt(key="leaf");
    append_child(screen, mid);
    append_child(mid, leaf);
    before = ordered_child_keys(screen);
    failed = False;
    try {
        move_before(screen, leaf);
    } except ValueError {
        failed = True;
    }
    assert failed;
    assert ordered_child_keys(screen) == before;
    assert child_parent(mid) is screen;
    assert child_parent(leaf) is mid;
}


test "sparse ranks keep a positive gap after successive appends" {
    screen = MainScreen(key="main");
    nodes = [Header(key="h0"), Header(key="h1"), Header(key="h2"), Header(key="h3"), ];
    for n in nodes {
        append_child(screen, n);
    }
    ranks = [child_rank(screen, n) for n in nodes];
    assert ranks == sorted(ranks);
    for i in range(1, len(ranks)) {
        assert ranks[i] - ranks[i - 1] >= 1;
    }

    assert ranks[1] - ranks[0] >= 1024 or ranks[1] > ranks[0];
}


test "second parent attachment is rejected (single visual parent)" {
    left = MainScreen(key="left");
    right = MainScreen(key="right");
    child = Prompt(key="shared");
    append_child(left, child);
    failed = False;
    try {
        append_child(right, child);
    } except ValueError {
        failed = True;
    }
    assert failed;
    assert child_parent(child) is left;
    assert ordered_child_keys(right) == [];
}
