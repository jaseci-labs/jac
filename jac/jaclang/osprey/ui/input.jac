obj InputNormalizer {
    has buffer: str = "",
        paste_mode: bool = False,
        paste_buffer: str = "",
        pending_resize: ResizeEvent | None = None,
        pending_mouse: MouseEvent | None = None,
        pending_stream: str = "",
        esc_timeout_ms: int = 50,
        esc_armed_at_ms: float = -1.0;

    def feed(data: str) -> list[HostEvent];
    def arm_esc(now_ms: float);
    def flush_esc_timeout(now_ms: float) -> list[HostEvent];
    def feed_resize(width: int, height: int);
    def feed_stream(text: str);
    def flush_buffer -> list[HostEvent];
    def flush_coalesced -> list[HostEvent];
    def clear;
}


def coalesce_events(events: list[HostEvent]) -> list[HostEvent];
