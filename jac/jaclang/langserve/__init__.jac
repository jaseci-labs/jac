"""Jaclang langserve package.

Simplified Language Server Protocol implementation for Jaclang.

Architecture:
- Single worker process handles CPU-bound compilation (bypasses GIL)
- Scheduler: Simple debounce + cancel-on-new-edit
- Snapshots: Immutable state for lock-free foreground queries

Components:
- JacLangServer: Main LSP server (engine.jac)
- AnalysisScheduler: Simple debounce scheduler (scheduler.jac)
- CompilationWorker: Background compilation process (worker.jac)
- ProgramSnapshot: Immutable program state (snapshot.jac)
"""

import logging;
import sys;

"""Configure logging for the langserve module.

Args:
    level: Log level (DEBUG, INFO, WARNING, ERROR)
    log_file: Optional file path to write logs to
"""
def configure_logging(level: str = "INFO", log_file: str | None = None) -> None {
    # Get numeric level
    numeric_level = getattr(logging, level.upper(), logging.INFO);

    # Create formatter
    formatter = logging.Formatter(
        fmt="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    );

    # Configure root logger for jac.* loggers
    jac_logger = logging.getLogger("jac");
    jac_logger.setLevel(numeric_level);
    jac_logger.handlers.clear();

    # Console handler (stderr)
    console_handler = logging.StreamHandler(sys.stderr);
    console_handler.setFormatter(formatter);
    console_handler.setLevel(numeric_level);
    jac_logger.addHandler(console_handler);

    # File handler (if specified)
    if log_file {
        file_handler = logging.FileHandler(log_file);
        file_handler.setFormatter(formatter);
        file_handler.setLevel(numeric_level);
        jac_logger.addHandler(file_handler);
    }

    jac_logger.info(f"Logging configured: level={level}, file={log_file}");
}

"""Re-export key components."""
import from .engine { JacLangServer }
import from .scheduler { AnalysisScheduler, SchedulerConfig }
import from .worker { WorkerManager, WorkerConfig, WorkerHealth }
import from .snapshot { ProgramSnapshot, SnapshotManager }
import from .cancellation { OperationCancelledException, CancellationToken, CancellationTokenSource }
