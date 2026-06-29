import from jac_scale.observability.logger { Logger }
import from jaclang.cli.console { console }

class StandardLogger(Logger) {
    def init(self: StandardLogger, config: dict[str, any] = {}) { }
    def info(self: StandardLogger, message: str, context: dict[str, any] = {}) {
        if context {
            console.info(f"{message} | Context: {context}");
        } else {
            console.info(message);
        }
    }

    def error(self: StandardLogger, message: str, context: dict[str, any] = {}) {
        if context {
            console.error(f"{message} | Context: {context}");
        } else {
            console.error(message);
        }
    }

    def warn(self: StandardLogger, message: str, context: dict[str, any] = {}) {
        if context {
            console.warning(f"{message} | Context: {context}");
        } else {
            console.warning(message);
        }
    }

    def debug(self: StandardLogger, message: str, context: dict[str, any] = {}) {
        if context {
            console.print(f"[DEBUG] {message} | Context: {context}", style="muted");
        } else {
            console.print(f"[DEBUG] {message}", style="muted");
        }
    }
}
