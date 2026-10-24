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

def:pub strsignal(signalnum: int) -> (str | None);

def:pub valid_signals -> list[int];

def pthread_sigmask(how: int, mask: list[int]) -> list[int];
