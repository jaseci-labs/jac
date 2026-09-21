class Logger {
    def info(self: Logger, message: str, context: dict[str, any] = {}) -> None abst;
    def error(self: Logger, message: str, context: dict[str, any] = {}) -> None abst;
    def warn(self: Logger, message: str, context: dict[str, any] = {}) -> None abst;
    def debug(self: Logger, message: str, context: dict[str, any] = {}) -> None abst;
    def warning(self: Logger, message: str, context: dict[str, any] = {}) {
        self.warn(message, context);
    }
}
