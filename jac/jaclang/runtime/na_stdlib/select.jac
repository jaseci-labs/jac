import time;

glob POLLIN: int = _POLLIN,
     POLLOUT: int = _POLLOUT,
     POLLERR: int = _POLLERR,
     POLLHUP: int = _POLLHUP,
     POLLNVAL: int = _POLLNVAL;

def _check_fd(fd: int);

def _add_fds(lst: list[int], events: int, fds: list[int], masks: list[int]);

def _ready(lst: list[int], fds: list[int], res: list[int], ready: int) -> list[int];

def:pub select(
    rlist: list[int], wlist: list[int], xlist: list[int], timeout: (float | None) = -1.0
) -> tuple[(list[int], list[int], list[int])];
