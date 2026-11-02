import from c { def poll(fds: int, nfds: u64, timeout: i32) -> i32;  }
import from c { def malloc(size: int) -> int;  }
import from c { def free(p: int);  }

glob _FD_SETSIZE: int = 1024,
     _POLLIN: int = 1,
     _POLLOUT: int = 4,
     _POLLERR: int = 8,
     _POLLHUP: int = 16,
     _POLLNVAL: int = 32;

def:pub do_poll(fds: list[int], masks: list[int], timeout: int) -> list[int];
