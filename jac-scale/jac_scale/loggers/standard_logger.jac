"""Standard Python logging implementation."""
import logging;
import from jac_scale.engine.logger { Logger }

"""Standard Python logger implementation."""
class StandardLogger(Logger) {
    has _logger: logging.Logger;
    
    def init(self: StandardLogger, name: str = 'jac_scale') -> None {
        self._logger = logging.getLogger(name);
    }
    
    def info(self: StandardLogger, message: str, context: dict = {}) -> None {
        self._logger.info(self._format(message, context));
    }
    
    def error(self: StandardLogger, message: str, context: dict = {}) -> None {
        self._logger.error(self._format(message, context));
    }
    
    def warning(self: StandardLogger, message: str, context: dict = {}) -> None {
        self._logger.warning(self._format(message, context));
    }
    
    def debug(self: StandardLogger, message: str, context: dict = {}) -> None {
        self._logger.debug(self._format(message, context));
    }
    
    def with_context(self: StandardLogger, context: dict) -> Logger {
        # Simple implementation - just return self
        # Future: could create a context-aware logger
        return self;
    }
    
    def _format(self: StandardLogger, message: str, context: dict) -> str {
        if context {
            return f"{message} | Context: {context}";
        }
        return message;
    }
}
