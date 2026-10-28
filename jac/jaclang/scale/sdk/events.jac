obj EventLogger(Logger) {
    has sink: EventSink;

    def _forward(status: str, message: str, context: dict[str, any]);
    def info(message: str, context: dict[str, any] = {});
    def error(message: str, context: dict[str, any] = {});
    def warn(message: str, context: dict[str, any] = {});
    def debug(message: str, context: dict[str, any] = {});
}
