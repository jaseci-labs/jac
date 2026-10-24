import from jaclang.osprey.ui.virtual_terminal { VirtualTerminal, }

import from jaclang.osprey.ui.input_events { TextEvent }


test "host tick drains inject and maps interrupt" {
    loop = create_host_loop(esc_timeout_ms=50);
    term = VirtualTerminal(columns=20, rows=5);
    term.start();
    term.inject("a");
    events = run_host_tick(loop, term, 0.0, now_ms=0.0);
    assert len(events) >= 1;
    assert isinstance(events[0], TextEvent);
    note_interrupt(loop);
    more = run_host_tick(loop, term, 0.0, now_ms=1.0);
    kinds = [e.kind for e in more];
    assert "interrupt" in kinds;
    term.stop();
}


test "host tick esc timeout" {
    loop = create_host_loop(esc_timeout_ms=30);
    term = VirtualTerminal(columns=20, rows=5);
    term.start();
    term.inject("\x1b");
    run_host_tick(loop, term, 0.0, now_ms=0.0);
    loop.normalizer.arm_esc(0.0);
    late = run_host_tick(loop, term, 0.0, now_ms=50.0);
    found = False;
    for e in late {
        if isinstance(e, KeyEvent) and e.key == "escape" {
            found = True;
        }
    }
    assert found;
    term.stop();
}
