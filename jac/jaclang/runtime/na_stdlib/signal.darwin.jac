import from ._signal_native {
    sig_install_fn,
    sig_install_addr,
    sig_kill_self,
    sig_alarm,
    sig_pause,
    sig_mask
}
import from ._errno_native { last_errno, raise_errno }

glob:pub SIGHUP: int = 1,
     SIGINT: int = 2,
     SIGQUIT: int = 3,
     SIGILL: int = 4,
     SIGTRAP: int = 5,
     SIGABRT: int = 6,
     SIGIOT: int = 6,
     SIGEMT: int = 7,
     SIGFPE: int = 8,
     SIGKILL: int = 9,
     SIGBUS: int = 10,
     SIGSEGV: int = 11,
     SIGSYS: int = 12,
     SIGPIPE: int = 13,
     SIGALRM: int = 14,
     SIGTERM: int = 15,
     SIGURG: int = 16,
     SIGSTOP: int = 17,
     SIGTSTP: int = 18,
     SIGCONT: int = 19,
     SIGCHLD: int = 20,
     SIGTTIN: int = 21,
     SIGTTOU: int = 22,
     SIGIO: int = 23,
     SIGXCPU: int = 24,
     SIGXFSZ: int = 25,
     SIGVTALRM: int = 26,
     SIGPROF: int = 27,
     SIGWINCH: int = 28,
     SIGINFO: int = 29,
     SIGUSR1: int = 30,
     SIGUSR2: int = 31,
     NSIG: int = 32,
     SIG_BLOCK: int = 1,
     SIG_UNBLOCK: int = 2,
     SIG_SETMASK: int = 3,
     ITIMER_REAL: int = 0,
     ITIMER_VIRTUAL: int = 1,
     ITIMER_PROF: int = 2;

glob _shadow: dict[int, Callable[[int, any], None]] = {};

def _check_signum(signum: int);

def _sig_dfl_impl(signum: int, frame: any);

def _sig_ign_impl(signum: int, frame: any);

glob:pub SIG_DFL: Callable[[int, any], None] = _sig_dfl_impl,
     SIG_IGN: Callable[[int, any], None] = _sig_ign_impl;

def:pub default_int_handler(signalnum: int, frame: any);

def:pub signal(signalnum: int, handler: Callable[[int, any], None]) -> any;

def:pub getsignal(signalnum: int) -> any;

def:pub raise_signal(signalnum: int);

def alarm(seconds: int) -> int;

def pause;

glob _SIG_DESCR: list[str] = [
         "",
         "Hangup",
         "Interrupt",
         "Quit",
         "Illegal instruction",
         "Trace/BPT trap",
         "Abort trap",
         "EMT trap",
         "Floating point exception",
         "Killed",
         "Bus error",
         "Segmentation fault",
         "Bad system call",
         "Broken pipe",
         "Alarm clock",
         "Terminated",
         "Urgent I/O condition",
         "Suspended (signal)",
         "Suspended",
         "Continued",
         "Child exited",
         "Stopped (tty input)",
         "Stopped (tty output)",
         "I/O possible",
         "Cputime limit exceeded",
         "Filesize limit exceeded",
         "Virtual timer expired",
         "Profiling timer expired",
         "Window size changes",
         "Information request",
         "User defined signal 1",
         "User defined signal 2"
     ];

def:pub strsignal(signalnum: int) -> (str | None);

def:pub valid_signals -> list[int];

def pthread_sigmask(how: int, mask: list[int]) -> list[int];

impl _check_signum(signum: int) {
    if signum < 1 or signum >= NSIG {
        raise ValueError("signal number out of range");
    }
}

impl _sig_dfl_impl(signum: int, frame: any) {}

impl _sig_ign_impl(signum: int, frame: any) {}

impl default_int_handler(signalnum: int, frame: any) {
    raise KeyboardInterrupt();
}

impl signal(signalnum: int, handler: Callable[[int, any], None]) -> any {
    _check_signum(signalnum);
    prev = getsignal(signalnum);
    if handler is SIG_DFL {
        old = sig_install_addr(signalnum, 0);
    } elif handler is SIG_IGN {
        old = sig_install_addr(signalnum, 1);
    } else {
        old = sig_install_fn(signalnum, handler);
    }
    if old == -1 {
        raise_errno(last_errno());
    }
    _shadow[signalnum] = handler;
    return prev;
}

impl getsignal(signalnum: int) -> any {
    _check_signum(signalnum);
    if signalnum in _shadow {
        return _shadow[signalnum];
    }
    return SIG_DFL;
}

impl raise_signal(signalnum: int) {
    _check_signum(signalnum);
    rc = sig_kill_self(signalnum);
    if rc != 0 {
        raise_errno(last_errno());
    }
}

impl alarm(seconds: int) -> int {
    if seconds < 0 {
        raise ValueError("alarm() arg must be positive");
    }
    old = sig_alarm(seconds);
    if old == -1 {
        raise_errno(last_errno());
    }
    return old;
}

impl pause {
    sig_pause();
}

impl strsignal(signalnum: int) -> (str | None) {
    _check_signum(signalnum);
    return _SIG_DESCR[signalnum] + ": " + str(signalnum);
}

impl valid_signals -> list[int] {
    return list(range(1, NSIG));
}

impl pthread_sigmask(how: int, mask: list[int]) -> list[int] {
    if how < SIG_BLOCK or how > SIG_SETMASK {
        raise ValueError("value specified for how (" + str(how) + ") invalid");
    }
    (rc, out) = sig_mask(how, mask, NSIG);
    if rc != 0 {
        raise_errno(rc);
    }
    return out;
}
