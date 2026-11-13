import logging;
import os;

glob logger = logging.getLogger(__name__),
     _backend_holder: dict[str, StateBackend] = {};


def _after_fork_in_child;


with entry {
    if hasattr(os, 'register_at_fork') {
        os.register_at_fork(after_in_child=_after_fork_in_child);
    }
}


def in_fleet -> bool;


def get_state_backend(shared: bool = False) -> StateBackend;
