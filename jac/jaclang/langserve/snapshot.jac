"""Program snapshot for non-blocking LSP queries."""

import threading;
import pickle;
import time;
import from typing { Optional, Any, Callable, Tuple }
import from multiprocessing { shared_memory }

"""Immutable snapshot of program state.

Once created, this snapshot is never modified. This allows
foreground queries (hover, definition, etc.) to read state
without any locking - the snapshot is thread-safe by immutability.
"""
obj ProgramSnapshot {
    has hub: dict,  # path -> uni.Module (AST)
        sem_managers: dict,  # path -> SemTokManager
        errors: list,  # list[Alert]
        warnings: list,  # list[Alert]
        version: int = 0,  # Monotonically increasing version
        timestamp: float = 0;  # Creation time

    """Initialize snapshot (called after field assignment)."""
    def postinit -> None;

    """Get module AST for a file path."""
    def get_module(path: str) -> Optional[Any];

    """Get semantic token manager for a file path."""
    def get_semantic_manager(path: str) -> Optional[Any];

    """Get all diagnostics for a file path."""
    def get_diagnostics(path: str) -> list;

    """Get all errors across all files."""
    def get_all_errors -> list;

    """Get all warnings across all files."""
    def get_all_warnings -> list;

    """Check if snapshot has any data."""
    def is_empty -> bool;

    """Serialize snapshot to bytes for IPC."""
    def serialize -> bytes;

    """Deserialize snapshot from bytes."""
    static def deserialize(data: bytes) -> ProgramSnapshot;

    """Serialize snapshot to shared memory (zero-copy IPC).

    Returns tuple of (shm_name, size) for the receiver to attach.
    Caller must NOT close the shared memory - receiver will unlink it.
    """
    def serialize_to_shared_memory -> Tuple[str, int];

    """Deserialize snapshot from shared memory and cleanup.

    Attaches to shared memory, deserializes, then unlinks the block.
    """
    static def deserialize_from_shared_memory(shm_name: str, size: int) -> ProgramSnapshot;

    """Create snapshot from program state."""
    static def from_program_state(
        hub: dict, sem_managers: dict, errors: list, warnings: list, version: int = 0
    ) -> ProgramSnapshot;
}

"""Thread-safe manager for current program snapshot.

Provides atomic read/write access to the current snapshot.
Queries call get_snapshot() which returns immediately.
Background worker calls update_snapshot() after compilation.
"""
obj SnapshotManager {
    has _snapshot: ProgramSnapshot | None = None,
        _lock: threading.Lock | None = None,
        _version_counter: int = 0,
        _update_callbacks: list | None = None;

    """Initialize the manager."""
    def postinit -> None;

    """Get current snapshot (thread-safe, non-blocking)."""
    def get_snapshot -> Optional[ProgramSnapshot];

    """Update to new snapshot (atomic swap)."""
    def update_snapshot(new_snapshot: ProgramSnapshot) -> None;

    """Create and store initial empty snapshot."""
    def initialize_empty -> None;

    """Create snapshot from JacProgram state."""
    def create_snapshot_from_program(
        hub: dict, sem_managers: dict, errors: list, warnings: list
    ) -> ProgramSnapshot;

    """Get current version number."""
    def get_version -> int;

    """Check if manager has any snapshot."""
    def has_snapshot -> bool;

    """Register callback for snapshot updates."""
    def on_update(callback: Callable) -> None;
}

"""Create an empty snapshot for initialization."""
def create_empty_snapshot -> ProgramSnapshot;
