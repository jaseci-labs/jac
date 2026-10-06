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

def _trampoline(signum: int) {
    if signum in _fn_handlers {
        _fn_handlers[signum](signum, None);
    }
}

def:pub sig_install_fn(signum: int, handler: Callable[[int, any], None]) -> int {
    _fn_handlers[signum] = handler;
    old = bsd_signal(i32(signum), _trampoline);
    if old == -1 {
        del _fn_handlers[signum];
    }
    return old;
}

def:pub sig_install_addr(signum: int, handler: int) -> int {
    if signum in _fn_handlers {
        del _fn_handlers[signum];
    }
    return bsd_signal(i32(signum), handler);
}

def:pub sig_kill_self(signum: int) -> int {
    return kill(getpid(), i32(signum));
}

def:pub sig_alarm(seconds: int) -> int {
    new_it = malloc(32);
    old_it = malloc(32);
    __mem_store_i64(new_it + 0, 0);
    __mem_store_i64(new_it + 8, 0);
    __mem_store_i64(new_it + 16, seconds);
    __mem_store_i64(new_it + 24, 0);
    rc = setitimer(i32(_ITIMER_REAL), new_it, old_it);
    old_sec = __mem_load_i64(old_it + 16);
    old_usec = __mem_load_i64(old_it + 24);
    free(new_it);
    free(old_it);
    if rc != 0 {
        return -1;
    }
    return int(old_sec + (1 if old_usec > 0 else 0));
}

def:pub sig_pause {
    select(i32(0), 0, 0, 0, 0);
}

def:pub sig_mask(how: int, signums: list[int], nsig: int) -> tuple[(int, list[int])] {
    set_bits = b"\x00" * 128;
    sigemptyset(set_bits);
    for s in signums {
        if s >= 1 and s < nsig {
            sigaddset(set_bits, i32(s));
        }
    }
    old_bits = b"\x00" * 128;
    rc = sigprocmask(i32(how), set_bits, old_bits);
    if rc != 0 {
        return (int(rc), []);
    }
    out: list[int] = [];
    for s in range(1, nsig) {
        if sigismember(old_bits, i32(s)) == 1 {
            out.append(s);
        }
    }
    return (0, out);
}
