"""Jaclang langserve package.

Simplified Language Server Protocol implementation for Jaclang.

Architecture:
- Single worker process with debounce scheduling
- Foreground LSP requests handled in worker (hover, definition, etc.)
- Lightweight diagnostics-only IPC (no full AST transfer)

Components:
- JacLangServer: Main LSP server (engine.jac)
- WorkerManager: Background compilation with debounce (worker.jac)
"""

import logging;
import sys;

"""Configure logging for the langserve module."""
def configure_logging(level: str = "INFO", log_file: str | None = None) -> None {
    numeric_level = getattr(logging, level.upper(), logging.INFO);
    formatter = logging.Formatter(
        fmt="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    );

    jac_logger = logging.getLogger("jac");
    jac_logger.setLevel(numeric_level);
    jac_logger.handlers.clear();

    console_handler = logging.StreamHandler(sys.stderr);
    console_handler.setFormatter(formatter);
    console_handler.setLevel(numeric_level);
    jac_logger.addHandler(console_handler);

    if log_file {
        file_handler = logging.FileHandler(log_file);
        file_handler.setFormatter(formatter);
        file_handler.setLevel(numeric_level);
        jac_logger.addHandler(file_handler);
    }

    jac_logger.info(f"Logging configured: level={level}, file={log_file}");
}
