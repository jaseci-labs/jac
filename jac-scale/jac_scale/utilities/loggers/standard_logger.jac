"""Standard logger implementation using jac console."""
import from typing { Any }
import from jac_scale.abstractions.logger { Logger }
import from jaclang.cli.console { console }

"""Standard logger using jac console for Rich-styled output."""
class StandardLogger(Logger) {
    def init(self: StandardLogger, config: dict[str, Any] = {}) -> None { }
    def info(self: StandardLogger, message: str, context: dict[str, Any] = {}) -> None {
        if context {
            console.info(f"{message} | Context: {context}");
        } else {
            console.info(message);
        }
    }

    def error(self: StandardLogger, message: str, context: dict[str, Any] = {}) -> None {
        if context {
            console.error(f"{message} | Context: {context}");
        } else {
            console.error(message);
        }
    }

    def warn(self: StandardLogger, message: str, context: dict[str, Any] = {}) -> None {
        if context {
            console.warning(f"{message} | Context: {context}");
        } else {
            console.warning(message);
        }
    }

    def debug(self: StandardLogger, message: str, context: dict[str, Any] = {}) -> None {
        if context {
            console.print(f"[DEBUG] {message} | Context: {context}", style="muted");
        } else {
            console.print(f"[DEBUG] {message}", style="muted");
        }
    }
}
