import from c { def bsd_signal(signum: i32, handler: int) -> int;  }
import from c { def kill(pid: i32, signum: i32) -> i32;  }
import from c { def getpid -> i32;  }
import from c { def setitimer(which: i32, new_value: int, old_value: int) -> i32;  }
import from c { def malloc(size: int) -> int;  }
import from c { def free(p: int);  }
import from c {
    def select(
        nfds: i32, readfds: int, writefds: int, exceptfds: int, timeout: int
    ) -> i32;
}
import from c { def sigprocmask(how: i32, set: bytes, oldset: bytes) -> i32;  }
import from c { def sigemptyset(set: bytes) -> i32;  }
import from c { def sigaddset(set: bytes, signum: i32) -> i32;  }
import from c { def sigismember(set: bytes, signum: i32) -> i32;  }

glob _ITIMER_REAL: int = 0,
     _fn_handlers: dict[int, Callable[[int, any], None]] = {};

def _trampoline(signum: int);

def:pub sig_install_fn(signum: int, handler: Callable[[int, any], None]) -> int;

def:pub sig_install_addr(signum: int, handler: int) -> int;

def:pub sig_kill_self(signum: int) -> int;

def:pub sig_alarm(seconds: int) -> int;

def:pub sig_pause;

def:pub sig_mask(how: int, signums: list[int], nsig: int) -> tuple[(int, list[int])];
