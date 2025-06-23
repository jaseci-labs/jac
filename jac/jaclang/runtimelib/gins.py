"""
Gins thread module for Jac runtime.

This module provides the GinSThread class, which can be attached to the Jac machine state
when run with the --gins option. The GinSThread is currently a placeholder and not yet fully implemented.
"""

from threading import Thread


class GinSThread:
    """Jac Gins thread."""

    def __init__(self) -> None:
        """Create ExecutionContext."""
        self.ghost_thread: Thread = Thread(target=self.worker)
        self.__is_alive: bool = False

    def start_gins(self) -> None:
        """Attach the Gins thread to the Jac machine state."""
        self.__is_alive = True
        self.ghost_thread.start()

    def worker(self) -> None:
        """Worker thread for Gins."""
        print("Gins thread started")
