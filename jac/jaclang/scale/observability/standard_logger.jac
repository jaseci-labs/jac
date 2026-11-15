class StandardLogger(Logger) {
    def init(self: StandardLogger, config: dict[str, any] = {});
    def info(self: StandardLogger, message: str, context: dict[str, any] = {});
    def error(self: StandardLogger, message: str, context: dict[str, any] = {});
    def warn(self: StandardLogger, message: str, context: dict[str, any] = {});
    def debug(self: StandardLogger, message: str, context: dict[str, any] = {});
}
