---
description: The native modules of the POSIX system, as CPython's - signal, errno, pwd, grp, resource, fcntl, termios, tty, pty and syslog - with each system's own constants, and what they leave out.
keywords: posix modules, signal, signal.signal, signal.getsignal, signal.raise_signal, signal.alarm, signal.setitimer, signal.pthread_sigmask, signal.sigwait, signal.Signals, signal.SIGINT, signal.SIGTERM, signal.SIG_DFL, signal.SIG_IGN, signal.strsignal, signal.valid_signals, errno, errno.errorcode, errno.ENOENT, pwd, pwd.getpwnam, pwd.getpwuid, pwd.getpwall, pwd.struct_passwd, grp, grp.getgrnam, grp.getgrgid, grp.getgrall, grp.struct_group, resource, resource.getrlimit, resource.setrlimit, resource.prlimit, resource.getrusage, resource.getpagesize, fcntl, fcntl.fcntl, fcntl.ioctl, fcntl.flock, fcntl.lockf, termios, termios.tcgetattr, termios.tcsetattr, tty, tty.setraw, tty.setcbreak, pty, pty.openpty, pty.fork, syslog, syslog.syslog, syslog.openlog
---
# The POSIX modules: signal, errno, pwd, grp, resource, fcntl, termios, tty, pty, syslog

These modules are CPython's interface to the POSIX system: signals, error numbers, the user and
group databases, resource limits and usage, file-descriptor control, the terminal, pseudo
terminals and the system log. Their constants are each system's own, generated from its C
headers, so a program built for Linux and one built for macOS each see the values CPython sees
there. They are native (see [The library](index.md), `jac docs library`), and reach the
system only through jac's platform layer.

```jac
import errno;
import grp;
import os;
import pwd;
import resource;
import signal;

def on_usr1(signum: int, frame: any) {
    print("got", signal.Signals(signum).name);
}

with entry {
    me = pwd.getpwuid(os.getuid());
    print(me.pw_uid == os.getuid(), me.pw_name == pwd.getpwnam(me.pw_name).pw_name);
    print(grp.getgrgid(0).gr_gid, pwd.getpwuid(0).pw_name);
    try {
        pwd.getpwnam("no-such-user-here");
    } except KeyError as e {
        print("KeyError:", e);
    }
    (soft, hard) = resource.getrlimit(resource.RLIMIT_NOFILE);
    print(soft > 0, resource.getrusage(resource.RUSAGE_SELF).ru_maxrss > 0);
    print(errno.ENOENT, errno.errorcode[errno.ENOENT], os.strerror(errno.ENOENT));
    old = signal.signal(signal.SIGUSR1, on_usr1);
    print(old == signal.SIG_DFL);
    signal.raise_signal(signal.SIGUSR1);
    print(signal.strsignal(signal.SIGTERM).startswith("Terminated"), signal.SIGINT.value);
}
```

```output
True True
0 root
KeyError: "getpwnam(): name not found: 'no-such-user-here'"
True True
2 ENOENT No such file or directory
True
got SIGUSR1
True 2
```

## The modules

| Module | What it has | Platforms |
|---|---|---|
| `signal` | `signal`, `getsignal`, `raise_signal`, `strsignal`, `valid_signals`, `alarm`, `pause`, `setitimer`, `getitimer`, `siginterrupt`, `pthread_sigmask`, `pthread_kill`, `sigpending`, `sigwait`, `sigwaitinfo`, `sigtimedwait`, `pidfd_send_signal`, `set_wakeup_fd`, the `Signals`, `Handlers` and `Sigmasks` enums and the target's signal numbers | All; Windows has CPython's few signals there |
| `errno` | The target's error numbers and `errorcode` | All |
| `pwd`, `grp` | `getpwnam`, `getpwuid`, `getpwall`, `struct_passwd`; `getgrnam`, `getgrgid`, `getgrall`, `struct_group` | Linux, macOS |
| `resource` | `getrlimit`, `setrlimit`, `prlimit`, `getrusage`, `struct_rusage`, `getpagesize`, the `RLIMIT_*` and `RUSAGE_*` constants, `error` | Linux, macOS |
| `fcntl` | `fcntl`, `ioctl`, `flock`, `lockf` and the target's `F_*`, `LOCK_*` and `FD_*` constants | Linux, macOS; on Windows and WASI each call raises `RuntimeError` and the constants are 0 |
| `termios`, `tty` | `tcgetattr`, `tcsetattr`, `tcsendbreak`, `tcdrain`, `tcflush`, `tcflow`, `tcgetwinsize`, `tcsetwinsize` and the constants; `tty`'s `setraw`, `setcbreak`, `cfmakeraw`, `cfmakecbreak` | Linux, macOS; on Windows and WASI each call raises `RuntimeError` and the constants are 0 |
| `pty` | `openpty`, `fork`, `spawn` | Linux, macOS |
| `syslog` | `openlog`, `syslog`, `closelog`, `setlogmask`, `LOG_MASK`, `LOG_UPTO` and the priorities and facilities | Linux, macOS |

```jac
import fcntl;
import getpass;
import os;
import pty;
import syslog;
import termios;
import tty;

with entry {
    (r, w) = os.pipe();
    flags = fcntl.fcntl(w, fcntl.F_GETFL);
    fcntl.fcntl(w, fcntl.F_SETFL, flags | os.O_NONBLOCK);
    print(fcntl.fcntl(w, fcntl.F_GETFL) & os.O_NONBLOCK != 0);
    (leader, follower) = pty.openpty();
    attrs = termios.tcgetattr(follower);
    tty.setraw(follower);
    print(termios.tcgetattr(follower)[3] & termios.ECHO == 0, attrs[3] & termios.ECHO != 0);
    print(os.isatty(follower), len(getpass.getuser()) > 0);
    syslog.openlog("docs-example", syslog.LOG_PID, syslog.LOG_USER);
    print(syslog.LOG_MASK(syslog.LOG_ERR), syslog.LOG_UPTO(syslog.LOG_WARNING));
    syslog.closelog();
    for fd in [r, w, leader, follower] {
        os.close(fd);
    }
}
```

```output
True
True True
True True
8 31
```

## Signal handlers

A handler is a Jac function `(signum: int, frame: any)`; `frame` is always `None`, as a native
program has no frame objects. The system's handler only notes the signal, and the Jac handler
runs later, on the main thread, as CPython's does:

- **when the program waits.** A call that waits runs the handlers of the signals that have come
  as it begins, and again when a signal interrupts it; it then goes on for what is left of its
  wait, unless a handler raised, which ends the call with that exception (PEP 475). The calls
  are `time.sleep`, a read or a write, `select` and `poll` and the selectors over them, a
  socket's calls, the TLS handshake, read and write, a wait for a child process, and a wait for
  a lock or a thread (`Lock.acquire`, `Thread.join`, `Event.wait`, `Queue.get`);
- when `raise_signal`, `pause`, `pthread_sigmask` or `pthread_kill` returns, before `signal()`
  changes a handler, and when `sigwaitinfo` or `sigtimedwait` is interrupted.

CPython also runs handlers between any two statements of the main thread; a native program does
not, so a signal that arrives while a loop computes is handled at the loop's next call that
waits. `SIGINT` raises `KeyboardInterrupt` at the same points.

```jac
import signal;
import time;

glob stopped: list[int] = [];

def stop(signum: int, frame: any) {
    stopped.append(signum);
}

with entry {
    signal.signal(signal.SIGALRM, stop);
    signal.setitimer(signal.ITIMER_REAL, 0.05, 0.05);
    slept = 0;
    while len(stopped) == 0 {
        time.sleep(0.3);
        slept += 1;
    }
    signal.setitimer(signal.ITIMER_REAL, 0);
    print("stopped by", signal.Signals(stopped[0]).name, "in its first sleep:", slept == 1);
}
```

```output
stopped by SIGALRM in its first sleep: True
```

## Differences from CPython

- **Enum aliases are left out** (E5142): `Signals.SIGCLD`, `Signals.SIGIOT` and
  `Signals.SIGPOLL` are other names for `SIGCHLD`, `SIGABRT` and `SIGIO`, and a Jac enum member
  cannot be another's alias. `signal.SIGCLD`, the module's name, is there.
- **`SIGRTMIN` and `SIGRTMAX` are left out** (E5142): the C library sets their numbers as the
  program starts, and an enum member's value is a literal. Use the number (`signal.NSIG - 1` is
  the highest).
- **`resource.RLIM_INFINITY`, `RLIM_SAVED_CUR` and `RLIM_SAVED_MAX` are left out on Linux**
  (E5142): their value, 2\*\*64 - 1, is past a 64-bit int. `setrlimit` and `prlimit` take `-1`
  for an unlimited limit, and `getrlimit` raises `OverflowError` for one.
- **`fcntl`'s STREAMS ioctls (`I_PUSH`, `I_POP`, ...) and `termios.NCC` and
  `TIOCTTYGSTRUCT`** are left out, as CPython has none of them on Linux or macOS either.
