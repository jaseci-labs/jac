obj ProgressEvent {
    has phase: str,
        step: str = "",
        status: str = "info",
        message: str = "",
        detail: dict[str, any] = {};
}

class EventSink {
    def emit(self: EventSink, event: ProgressEvent) -> None;
}

obj NoopSink(EventSink) {
    def emit(event: ProgressEvent) { }
}

obj CallbackSink(EventSink) {
    has callback: Callable[[ProgressEvent], None];

    def emit(event: ProgressEvent) {
        self.callback(event);
    }
}
