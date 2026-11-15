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
    if signalnum >= SIGRTMIN and signalnum <= SIGRTMAX {
        return "Real-time signal " + str(signalnum - SIGRTMIN);
    }
    if signalnum == 32 or signalnum == 33 {
        return None;
    }
    return _SIG_DESCR[signalnum];
}

impl valid_signals -> list[int] {
    out: list[int] = [];
    for s in range(1, NSIG) {
        if s != 32 and s != 33 {
            out.append(s);
        }
    }
    return out;
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
