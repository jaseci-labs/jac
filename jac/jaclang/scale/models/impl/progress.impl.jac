impl NoopSink.emit(event: ProgressEvent) {}

impl CallbackSink.emit(event: ProgressEvent) {
    self.callback(event);
}
