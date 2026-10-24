import time;


obj HostLoop {
    has normalizer: InputNormalizer,
        last_now_ms: float = 0.0,
        saw_eof: bool = False,
        interrupt_pending: bool = False;
}


def create_host_loop(esc_timeout_ms: int = 50) -> HostLoop;


def note_interrupt(loop: HostLoop);


def note_resize(loop: HostLoop, width: int, height: int);


def run_host_tick(
    loop: HostLoop, term: Terminal, timeout_s: float = 0.0, now_ms: float | None = None,
) -> list[HostEvent];


def host_events_to_effects(events: list[HostEvent]) -> list[dict[str, any]];

impl create_host_loop(esc_timeout_ms: int = 50) -> HostLoop {
    norm = InputNormalizer();
    norm.esc_timeout_ms = esc_timeout_ms;
    return HostLoop(normalizer=norm);
}


impl note_interrupt(loop: HostLoop) {
    loop.interrupt_pending = True;
}


impl note_resize(loop: HostLoop, width: int, height: int) {
    loop.normalizer.feed_resize(width, height);
}


impl run_host_tick(
    loop: HostLoop, term: Terminal, timeout_s: float = 0.0, now_ms: float | None = None,
) -> list[HostEvent] {
    clock = now_ms if now_ms is not None else (time.monotonic() * 1000.0);
    loop.last_now_ms = clock;
    out: list[HostEvent] = [];

    if loop.interrupt_pending {
        loop.interrupt_pending = False;
        out.append(InterruptEvent());
    }

    raw = "";
    try {
        poll_fn = getattr(term, "poll_input");
        raw = str(poll_fn(timeout_s));
    } except Exception {
        raw = "";
    }
    if raw {
        fed = loop.normalizer.feed(raw);
        out.extend(fed);
        if loop.normalizer.buffer == "\x1b" {
            loop.normalizer.arm_esc(clock);
        }
    } else {
        if loop.normalizer.buffer == "\x1b" and loop.normalizer.esc_armed_at_ms < 0.0 {
            loop.normalizer.arm_esc(clock);
        }
    }

    esc_events = loop.normalizer.flush_esc_timeout(clock);
    out.extend(esc_events);

    if hasattr(term, "eof") and getattr(term, "eof") and not loop.saw_eof {
        loop.saw_eof = True;
        out.append(EofEvent());
    }

    out.extend(loop.normalizer.flush_coalesced());
    return coalesce_events(out);
}


impl host_events_to_effects(events: list[HostEvent]) -> list[dict[str, any]] {
    effects: list[dict[str, any]] = [];
    for event in events {
        if isinstance(event, InterruptEvent) {
            effects.append({"kind": "cancel"});
        } elif isinstance(event, EofEvent) {
            effects.append({"kind": "exit"});
        } elif isinstance(event, KeyEvent) {
            if event.key == "ctrl+c" {
                effects.append({"kind": "cancel"});
            } elif event.key == "enter" {
                effects.append({"kind": "submit"});
            } elif event.key == "escape" {
                effects.append({"kind": "escape"});
            } else {
                effects.append({"kind": "key", "key": event.key});
            }
        } else {
            effects.append({"kind": event.kind});
        }
    }
    return effects;
}
