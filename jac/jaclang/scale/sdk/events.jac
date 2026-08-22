import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.models.progress { EventSink, ProgressEvent }


obj EventLogger(Logger) {
    has sink: EventSink;

    def _forward(status: str, message: str, context: dict[str, any]) {
        self.sink.emit(
            ProgressEvent(
                phase='log', status=status, message=message, detail=dict(context)
            )
        );
    }

    def info(message: str, context: dict[str, any] = {}) {
        self._forward('info', message, context);
    }

    def error(message: str, context: dict[str, any] = {}) {
        self._forward('error', message, context);
    }

    def warn(message: str, context: dict[str, any] = {}) {
        self._forward('warn', message, context);
    }

    def debug(message: str, context: dict[str, any] = {}) {
        self._forward('debug', message, context);
    }
}
