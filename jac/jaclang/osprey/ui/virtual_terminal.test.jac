import from jaclang.osprey.ui.terminal { synchronized_write }


test "start enables paste and alternate screen; stop restores" {
    term = VirtualTerminal(columns=40, rows=12);
    assert term.restored;
    term.start();
    assert term.started;
    assert not term.restored;
    assert term.bracketed_paste;
    assert term.alternate_screen;
    assert not term.cursor_visible;
    term.stop();
    assert term.restored;
    assert not term.started;
    assert not term.bracketed_paste;
    assert not term.alternate_screen;
    assert term.cursor_visible;
}


test "inject queues input and invokes callback" {
    seen: list[str] = [];
    term = VirtualTerminal(
        columns=20, rows=5, on_input=lambda (data: str) { seen.append(data); },
    );
    term.start();
    term.inject("abc");
    term.inject("\x1b[A");
    assert term.pending_input() == ["abc", "\x1b[A"];
    assert seen == ["abc", "\x1b[A"];
    taken = term.take_input();
    assert taken == ["abc", "\x1b[A"];
    assert term.pending_input() == [];
    term.stop();
}


test "inject_resize updates size and notifies" {
    sizes: list[tuple[int, int]] = [];
    term = VirtualTerminal(
        columns=80,
        rows=24,
        on_resize=lambda (c: int, r: int) { sizes.append((c, r)); },
    );
    term.inject_resize(100, 30);
    assert term.columns == 100;
    assert term.rows == 30;
    assert sizes == [(100, 30)];
    assert len(term.capture_cells()) == 30;
}


test "inject_sigint restores terminal" {
    hits = [0];
    term = VirtualTerminal(on_interrupt=lambda() { hits[0] = hits[0] + 1; },);
    term.start();
    assert not term.restored;
    term.inject_sigint();
    assert term.restored;
    assert hits[0] == 1;
    assert term.interrupt_count == 1;
}


test "exception exit path still restores" {
    term = VirtualTerminal(columns=10, rows=4);
    failed = False;
    try {
        term.run_with_exception_guard(
            lambda (t: VirtualTerminal) {
                t.write("hi");
                raise ValueError("boom");
            }
        );
    } except ValueError {
        failed = True;
    }
    assert failed;
    assert term.restored;
    assert term.exception_exits == 1;
}


test "normal exit path restores via stop" {
    term = VirtualTerminal();
    term.start();
    term.write("ok");
    term.stop();
    assert term.restored;
}


test "write updates cell capture for printable text" {
    term = VirtualTerminal(columns=10, rows=3);
    term.start();
    term.clear_writes();
    term.move_cursor(1, 1);
    term.write("Hi");
    rows = term.capture_cells();
    assert rows[0].startswith("Hi");
    term.stop();
}


test "SGR sequences consumed without polluting cells" {
    term = VirtualTerminal(columns=10, rows=3);
    term.start();
    term.clear_writes();
    term.move_cursor(1, 1);
    term.write("\x1b[1;32mAB\x1b[0m");
    term.write("CD");
    rows = term.capture_cells();
    assert rows[0].startswith("ABCD");
    assert len(rows[0].rstrip()) == 4;
    term.stop();
}


test "synchronized_write emits begin and end markers" {
    term = VirtualTerminal();
    term.start();
    term.clear_writes();
    synchronized_write(term, "x");
    blob = term.written_text();
    assert "\x1b[?2026h" in blob;
    assert "\x1b[?2026l" in blob;
    assert "x" in blob;
    term.stop();
}
