class Logger {
    def info(self: Logger, message: str, context: dict[str, any] = {}) -> None;
    def error(self: Logger, message: str, context: dict[str, any] = {}) -> None;
    def warn(self: Logger, message: str, context: dict[str, any] = {}) -> None;
    def debug(self: Logger, message: str, context: dict[str, any] = {}) -> None;
}
