"""Congruence probe: `import signal` must answer what CPython answers.

Runs on the sv pathway (CPython's signal) and the na pathway
(na_stdlib/signal.linux.jac). Only deterministic, lane-identical lines are
printed; the handler frame argument is ignored because na delivers None.
"""

import from signal {
    signal,
    getsignal,
    raise_signal,
    alarm,
    strsignal,
    valid_signals,
    pthread_sigmask,
    default_int_handler,
    SIGUSR1,
    SIGUSR2,
    SIGKILL,
    SIG_DFL,
    SIG_IGN,
    SIG_BLOCK,
    SIG_UNBLOCK,
    NSIG
}

glob fired: int = 0;

def h1(signum: int, frame: any) {
    fired = signum;
}

def h2(signum: int, frame: any) {
    fired = 1200 + signum;
}

with entry {
    print("SIGUSR1=" + str(SIGUSR1) + " NSIG=" + str(NSIG));
    print("dih=" + str(default_int_handler is not None));

    old = signal(SIGUSR1, h1);
    print("old-not-none=" + str(old is not None));
    raise_signal(SIGUSR1);
    print("fired=" + str(fired));

    gs = getsignal(SIGUSR1);
    print("gs-not-none=" + str(gs is not None));

    signal(SIGUSR2, h2);
    raise_signal(SIGUSR2);
    print("fired2=" + str(fired));

    signal(SIGUSR1, SIG_IGN);
    fired = 0;
    raise_signal(SIGUSR1);
    print("ign-fired=" + str(fired));

    signal(SIGUSR1, SIG_DFL);
    signal(SIGUSR1, h1);

    print("strsignal=" + str(strsignal(SIGUSR1)));
    print("strsig33=" + str(strsignal(33)));
    print("strsig34=" + str(strsignal(34)));
    print("alarm=" + str(alarm(0)));

    vs = valid_signals();
    print("vs-len=" + str(len(vs)));
    print("vs-usr1=" + str(SIGUSR1 in vs));
    print("vs-kill=" + str(SIGKILL in vs));

    fired = 0;
    oldm = pthread_sigmask(SIG_BLOCK, [SIGUSR1]);
    print("mask-old-len=" + str(len(oldm)));
    raise_signal(SIGUSR1);
    print("blocked-fired=" + str(fired));
    pthread_sigmask(SIG_UNBLOCK, [SIGUSR1]);
    print("unblocked-fired=" + str(fired));

    print("done");
}
