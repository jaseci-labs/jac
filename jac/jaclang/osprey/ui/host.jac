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
