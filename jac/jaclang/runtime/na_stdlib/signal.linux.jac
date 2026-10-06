import from _signal_native {
    sig_install_fn,
    sig_install_addr,
    sig_kill_self,
    sig_alarm,
    sig_pause,
    sig_mask
}
import from _errno_native { last_errno, raise_errno }

glob:pub SIGHUP: int = 1,
     SIGINT: int = 2,
     SIGQUIT: int = 3,
     SIGILL: int = 4,
     SIGTRAP: int = 5,
     SIGABRT: int = 6,
     SIGIOT: int = 6,
     SIGBUS: int = 7,
     SIGEMT: int = 7,
     SIGFPE: int = 8,
     SIGKILL: int = 9,
     SIGUSR1: int = 10,
     SIGSEGV: int = 11,
     SIGUSR2: int = 12,
     SIGPIPE: int = 13,
     SIGALRM: int = 14,
     SIGTERM: int = 15,
     SIGSTKFLT: int = 16,
     SIGCHLD: int = 17,
     SIGCLD: int = 17,
     SIGCONT: int = 18,
     SIGSTOP: int = 19,
     SIGTSTP: int = 20,
     SIGTTIN: int = 21,
     SIGTTOU: int = 22,
     SIGURG: int = 23,
     SIGXCPU: int = 24,
     SIGXFSZ: int = 25,
     SIGVTALRM: int = 26,
     SIGPROF: int = 27,
     SIGWINCH: int = 28,
     SIGIO: int = 29,
     SIGPOLL: int = 29,
     SIGPWR: int = 30,
     SIGSYS: int = 31,
     SIGUNUSED: int = 31,
     SIGRTMIN: int = 34,
     SIGRTMAX: int = 64,
     NSIG: int = 65,
     SIG_BLOCK: int = 0,
     SIG_UNBLOCK: int = 1,
     SIG_SETMASK: int = 2,
     ITIMER_REAL: int = 0,
     ITIMER_VIRTUAL: int = 1,
     ITIMER_PROF: int = 2;

glob _shadow: dict[int, Callable[[int, any], None]] = {};

def _check_signum(signum: int) {
    if signum < 1 or signum >= NSIG {
        raise ValueError("signal number out of range");
    }
}

def _sig_dfl_impl(signum: int, frame: any) {}

def _sig_ign_impl(signum: int, frame: any) {}

glob:pub SIG_DFL: Callable[[int, any], None] = _sig_dfl_impl,
     SIG_IGN: Callable[[int, any], None] = _sig_ign_impl;

def:pub default_int_handler(signum: int, frame: any) {
    raise KeyboardInterrupt();
}

def:pub signal(signum: int, handler: Callable[[int, any], None]) -> any {
    _check_signum(signum);
    prev = getsignal(signum);
    if handler is SIG_DFL {
        old = sig_install_addr(signum, 0);
    } elif handler is SIG_IGN {
        old = sig_install_addr(signum, 1);
    } else {
        old = sig_install_fn(signum, handler);
    }
    if old == -1 {
        raise_errno(last_errno());
    }
    _shadow[signum] = handler;
    return prev;
}

def:pub getsignal(signum: int) -> any {
    _check_signum(signum);
    if signum in _shadow {
        return _shadow[signum];
    }
    return SIG_DFL;
}

def:pub raise_signal(signum: int) {
    _check_signum(signum);
    rc = sig_kill_self(signum);
    if rc != 0 {
        raise_errno(last_errno());
    }
}

def:pub alarm(seconds: int) -> int {
    if seconds < 0 {
        raise ValueError("alarm() arg must be positive");
    }
    old = sig_alarm(seconds);
    if old == -1 {
        raise_errno(last_errno());
    }
    return old;
}

def:pub pause {
    sig_pause();
}

glob _SIG_DESCR: list[str] = [
         "",
         "Hangup",
         "Interrupt",
         "Quit",
         "Illegal instruction",
         "Trace/breakpoint trap",
         "Aborted",
         "Bus error",
         "Floating point exception",
         "Killed",
         "User defined signal 1",
         "Segmentation fault",
         "User defined signal 2",
         "Broken pipe",
         "Alarm clock",
         "Terminated",
         "Stack fault",
         "Child exited",
         "Continued",
         "Stopped (signal)",
         "Stopped",
         "Stopped (tty input)",
         "Stopped (tty output)",
         "Urgent I/O condition",
         "CPU time limit exceeded",
         "File size limit exceeded",
         "Virtual timer expired",
         "Profiling timer expired",
         "Window changed",
         "I/O possible",
         "Power failure",
         "Bad system call"
     ];

def:pub strsignal(signum: int) -> (str | None) {
    _check_signum(signum);
    if signum >= SIGRTMIN and signum <= SIGRTMAX {
        return "Real-time signal " + str(signum - SIGRTMIN);
    }
    if signum == 32 or signum == 33 {
        return None;
    }
    return _SIG_DESCR[signum];
}

def:pub valid_signals -> list[int] {
    out: list[int] = [];
    for s in range(1, NSIG) {
        if s != 32 and s != 33 {
            out.append(s);
        }
    }
    return out;
}

def:pub pthread_sigmask(how: int, mask: list[int]) -> list[int] {
    if how < SIG_BLOCK or how > SIG_SETMASK {
        raise ValueError("value specified for how (" + str(how) + ") invalid");
    }
    (rc, out) = sig_mask(how, mask, NSIG);
    if rc != 0 {
        raise_errno(rc);
    }
    return out;
}
