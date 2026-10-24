test "plain ascii becomes text events" {
    norm = InputNormalizer();
    events = norm.feed("ab");
    assert len(events) == 2;
    a = events[0] as TextEvent;
    b = events[1] as TextEvent;
    assert a.text == "a";
    assert b.text == "b";
}


test "arrow escape stays one key event" {
    norm = InputNormalizer();
    events = norm.feed("\x1b[A");
    assert len(events) == 1;
    key = events[0] as KeyEvent;
    assert key.key == "up";
}


test "fragmented escape is held until complete" {
    norm = InputNormalizer();
    first = norm.feed("\x1b[");
    assert first == [];
    assert norm.buffer == "\x1b[";
    second = norm.feed("C");
    assert len(second) == 1;
    key = second[0] as KeyEvent;
    assert key.key == "right";
    assert norm.buffer == "";
}


test "flush_buffer emits incomplete escape remainder" {
    norm = InputNormalizer();
    norm.feed("\x1b[");
    flushed = norm.flush_buffer();
    assert len(flushed) == 1;
    assert isinstance(flushed[0], KeyEvent);
    assert norm.buffer == "";
}


test "bracketed paste becomes one PasteEvent including newlines" {
    norm = InputNormalizer();
    payload = "line1\nline2\n你好";
    events = norm.feed("\x1b[200~" + payload + "\x1b[201~");
    assert len(events) == 1;
    paste = events[0] as PasteEvent;
    assert paste.text == payload;
}


test "fragmented bracketed paste waits for end marker" {
    norm = InputNormalizer();
    mid = norm.feed("\x1b[200~hello");
    assert mid == [];
    assert norm.paste_mode;
    done = norm.feed(" world\x1b[201~");
    assert len(done) == 1;
    paste = done[0] as PasteEvent;
    assert paste.text == "hello world";
}


test "enter tab backspace and ctrl keys decode" {
    norm = InputNormalizer();
    enter = norm.feed("\r")[0] as KeyEvent;
    tab = norm.feed("\t")[0] as KeyEvent;
    backspace = norm.feed("\x7f")[0] as KeyEvent;
    ctrl_c = norm.feed("\x03")[0] as KeyEvent;
    assert enter.key == "enter";
    assert tab.key == "tab";
    assert backspace.key == "backspace";
    assert ctrl_c.key == "ctrl+c";
}


test "lone escape is held then flushed as escape key" {
    norm = InputNormalizer();
    held = norm.feed("\x1b");
    assert held == [];
    assert norm.buffer == "\x1b";
    flushed = norm.flush_buffer();
    assert len(flushed) == 1;
    escape = flushed[0] as KeyEvent;
    assert escape.key == "escape";
}


test "sgr mouse click decodes; motion is coalesced" {
    norm = InputNormalizer();
    click = norm.feed("\x1b[<0;10;20M");
    assert len(click) == 1;
    mouse = click[0] as MouseEvent;
    assert mouse.x == 10;
    assert mouse.y == 20;
    assert mouse.pressed;

    m1 = norm.feed("\x1b[<32;11;21M");
    m2 = norm.feed("\x1b[<32;12;22M");
    assert m1 == [];
    assert m2 == [];
    coalesced = norm.flush_coalesced();
    assert len(coalesced) == 1;
    moved = coalesced[0] as MouseEvent;
    assert moved.x == 12;
    assert moved.y == 22;
    assert moved.motion;
}


test "resize storms keep only the last size" {
    norm = InputNormalizer();
    norm.feed_resize(80, 24);
    norm.feed_resize(100, 30);
    norm.feed_resize(120, 40);
    out = norm.flush_coalesced();
    assert len(out) == 1;
    resize = out[0] as ResizeEvent;
    assert resize.width == 120;
    assert resize.height == 40;
}


test "stream chunks concatenate on flush" {
    norm = InputNormalizer();
    norm.feed_stream("hel");
    norm.feed_stream("lo");
    out = norm.flush_coalesced();
    assert len(out) == 1;
    chunk = out[0] as StreamChunkEvent;
    assert chunk.text == "hello";
}


test "coalesce_events merges mixed resize mouse and stream" {
    events: list[HostEvent] = [
        ResizeEvent(width=1, height=1),
        TextEvent(text="a"),
        ResizeEvent(width=2, height=2),
        StreamChunkEvent(text="x"),
        StreamChunkEvent(text="y"),
        MouseEvent(button=0, x=1, y=1, motion=True),
        MouseEvent(button=0, x=5, y=5, motion=True),

    ];
    out = coalesce_events(events);
    kinds = [e.kind for e in out];
    assert kinds == ["resize", "text", "resize", "mouse", "stream"];
    r0 = out[0] as ResizeEvent;
    assert r0.width == 1;
    r2 = out[2] as ResizeEvent;
    assert r2.width == 2;
    m = out[3] as MouseEvent;
    assert m.x == 5;
    s = out[4] as StreamChunkEvent;
    assert s.text == "xy";
}


test "mixed printable and escape stay ordered" {
    norm = InputNormalizer();
    events = norm.feed("x\x1b[Cy");
    assert len(events) == 3;
    t0 = events[0] as TextEvent;
    k1 = events[1] as KeyEvent;
    t2 = events[2] as TextEvent;
    assert t0.text == "x";
    assert k1.key == "right";
    assert t2.text == "y";
}


test "extract_sequences leaves incomplete csi as remainder" {
    part = extract_sequences("a\x1b[");
    assert part["sequences"] == ["a"];
    assert part["remainder"] == "\x1b[";
}


test "host events never include raw unparsed escape bytes as TextEvent" {
    norm = InputNormalizer();
    events = norm.feed("\x1b[A");
    assert len(events) == 1;
    assert isinstance(events[0], KeyEvent);
    assert not isinstance(events[0], TextEvent);
}


test "unicode text survives normalization as TextEvent" {
    norm = InputNormalizer();
    events = norm.feed("你");
    assert len(events) == 1;
    text = events[0] as TextEvent;
    assert text.text == "你";
}


test "shift tab decodes from csi z" {
    norm = InputNormalizer();
    events = norm.feed("\x1b[Z");
    assert len(events) == 1;
    k = events[0] as KeyEvent;
    assert k.key == "shift+tab";
}


test "modified arrows decode with modifier prefixes" {
    norm = InputNormalizer();
    k1 = norm.feed("\x1b[1;5C")[0] as KeyEvent;
    assert k1.key == "ctrl+right";
    k2 = norm.feed("\x1b[1;2A")[0] as KeyEvent;
    assert k2.key == "shift+up";
    k3 = norm.feed("\x1b[1;3D")[0] as KeyEvent;
    assert k3.key == "alt+left";
    k4 = norm.feed("\x1b[1;6B")[0] as KeyEvent;
    assert k4.key == "ctrl+shift+down";
}


test "modified home end and tilde keys decode" {
    norm = InputNormalizer();
    k1 = norm.feed("\x1b[1;5H")[0] as KeyEvent;
    assert k1.key == "ctrl+home";
    k2 = norm.feed("\x1b[1;2F")[0] as KeyEvent;
    assert k2.key == "shift+end";
    k3 = norm.feed("\x1b[3;5~")[0] as KeyEvent;
    assert k3.key == "ctrl+delete";
}


test "unmapped modifier falls back to unknown key event" {
    norm = InputNormalizer();
    events = norm.feed("\x1b[1;9C");
    assert len(events) == 1;
    k = events[0] as KeyEvent;
    assert k.key.startswith("unknown:");
}


test "esc timeout emits escape after armed delay" {
    norm = InputNormalizer();
    norm.esc_timeout_ms = 40;
    held = norm.feed("\x1b");
    assert held == [];
    norm.arm_esc(100.0);
    assert norm.flush_esc_timeout(120.0) == [];
    late = norm.flush_esc_timeout(150.0);
    assert len(late) == 1;
    assert (late[0] as KeyEvent).key == "escape";
    assert norm.buffer == "";
}
