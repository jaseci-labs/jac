"""Standard logger implementation using Python logging."""
import logging;
import from typing { Any }
import from jac_scale.abstractions.logger { Logger }

"""Standard logger using Python's logging module."""
class StandardLogger(Logger) {
    has logger: logging.Logger;

    def init(self: StandardLogger, config: dict[str, Any] = {}) -> None {
        name = config.get('name', 'jac_scale');
        level = config.get('level', 'INFO');
        self.logger = logging.getLogger(name);
        self.logger.setLevel(getattr(logging, level.upper(), logging.INFO));
        if not self.logger.handlers {
            handler = logging.StreamHandler();
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            );
            handler.setFormatter(formatter);
            self.logger.addHandler(handler);
        }
    }

    def info(self: StandardLogger, message: str, context: dict[str, Any] = {}) -> None {
        if context {
            self.logger.info(f"{message} | Context: {context}");
        } else {
            self.logger.info(message);
        }
    }

    def error(self: StandardLogger, message: str, context: dict[str, Any] = {}) -> None {
        if context {
            self.logger.error(f"{message} | Context: {context}");
        } else {
            self.logger.error(message);
        }
    }

    def warn(self: StandardLogger, message: str, context: dict[str, Any] = {}) -> None {
        if context {
            self.logger.warn(f"{message} | Context: {context}");
        } else {
            self.logger.warn(message);
        }
    }

    def debug(self: StandardLogger, message: str, context: dict[str, Any] = {}) -> None {
        if context {
            self.logger.debug(f"{message} | Context: {context}");
        } else {
            self.logger.debug(message);
        }
    }
}
