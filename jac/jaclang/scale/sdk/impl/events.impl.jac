impl EventLogger._forward(status: str, message: str, context: dict[str, any]) {
    self.sink.emit(
        ProgressEvent(phase='log', status=status, message=message, detail=dict(context))
    );
}

impl EventLogger.info(message: str, context: dict[str, any] = {}) {
    self._forward('info', message, context);
}

impl EventLogger.error(message: str, context: dict[str, any] = {}) {
    self._forward('error', message, context);
}

impl EventLogger.warn(message: str, context: dict[str, any] = {}) {
    self._forward('warn', message, context);
}

impl EventLogger.debug(message: str, context: dict[str, any] = {}) {
    self._forward('debug', message, context);
}
