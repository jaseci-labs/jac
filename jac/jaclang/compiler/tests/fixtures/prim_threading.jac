"""Bundled native `threading` cross-backend equivalence fixture (#10614).

`import threading` binds the bundled `na_stdlib/threading.jac` (POSIX threads
over the `_threading_native` FFI floor) on the na lane; the sv reference is
CPython's real `threading`. Every row is deterministic: an 8-thread locked
increment that must land exactly, join semantics (joined threads die,
timeout-joined live threads stay alive), `Event` waits and a cross-thread
set/wait hand-off, and the error contract the POSIX-mutex lane shares with
CPython (release of an un-acquired lock, a timeout on a non-blocking
acquire, a negative timeout, a double `start`, a `join` before `start`).
ES/JS opts out (no thread floor).
"""

import threading;
import time;

glob _counter: list[int] = [0],
     _done: list[int] = [0],
     _lock: threading.Lock = threading.Lock(),
     _ev: threading.Event = threading.Event(),
     _cross_lock: threading.Lock = threading.Lock(),
     _child_daemon: list[bool] = [False];

def _bump {
    for i in range(200) {
        _lock.acquire();
        _counter[0] += 1;
        _lock.release();
    }
}

def _mark {
    time.sleep(0.05);
    _ev.set();
}

def _wait {
    if _ev.wait(2.0) {
        _done[0] += 1;
    }
}

def _slow {
    time.sleep(0.2);
}

def _spawn_daemon_child {
    child = threading.Thread(target=_slow);
    _child_daemon[0] = child.daemon;
    child.start();
    child.join();
}

def _release_cross_lock {
    _cross_lock.release();
}


def threading_py -> dict[any, any] {
    _counter[0] = 0;
    _done[0] = 0;
    _ev.clear();
    threads: list[threading.Thread] = [];
    for i in range(8) {
        threads.append(threading.Thread(target=_bump));
    }
    for t in threads {
        t.start();
    }
    for t in threads {
        t.join();
    }
    lk = threading.Lock();
    nb_first = lk.acquire(False);
    nb_held = lk.acquire(False);
    lk.release();
    rel_unheld: str = "no-raise";
    try {
        lk.release();
    } except RuntimeError {
        rel_unheld = "RuntimeError";
    } except Exception {
        rel_unheld = "WRONG-TYPE";
    }
    nb_timeout: str = "no-raise";
    try {
        lk.acquire(False, timeout=0.1);
    } except ValueError {
        nb_timeout = "ValueError";
    } except Exception {
        nb_timeout = "WRONG-TYPE";
    }
    neg_timeout: str = "no-raise";
    try {
        lk.acquire(True, timeout=-2.0);
    } except ValueError {
        neg_timeout = "ValueError";
    } except Exception {
        neg_timeout = "WRONG-TYPE";
    }
    neg_fractional_timeout: str = "no-raise";
    try {
        lk.acquire(True, timeout=-0.5);
    } except ValueError {
        neg_fractional_timeout = "ValueError";
    } except Exception {
        neg_fractional_timeout = "WRONG-TYPE";
    }
    dbl_start: str = "no-raise";
    t2 = threading.Thread(target=_slow);
    t2.start();
    try {
        t2.start();
    } except RuntimeError {
        dbl_start = "RuntimeError";
    } except Exception {
        dbl_start = "WRONG-TYPE";
    }
    t2.join();
    join_early: str = "no-raise";
    try {
        threading.Thread(target=_slow).join();
    } except RuntimeError {
        join_early = "RuntimeError";
    } except Exception {
        join_early = "WRONG-TYPE";
    }
    ev2 = threading.Event();
    ev_timeout = ev2.wait(0.02);
    ev2.set();
    ev_set_wait = ev2.wait(0.02);
    s = threading.Thread(target=_mark);
    wt = threading.Thread(target=_wait);
    wt.start();
    s.start();
    wt.join();
    s.join();
    _cross_lock.acquire();
    cross_releaser = threading.Thread(target=_release_cross_lock);
    cross_releaser.start();
    cross_releaser.join();
    cross_release_ok = _cross_lock.acquire(False);
    if cross_release_ok {
        _cross_lock.release();
    }
    with_ok: bool = False;
    with _lock {
        with_ok = True;
    }
    d = threading.Thread(target=_slow, daemon=True);
    d.start();
    daemon_flag = d.daemon;
    daemon_parent = threading.Thread(target=_spawn_daemon_child, daemon=True);
    daemon_parent.start();
    daemon_parent.join();
    t3 = threading.Thread(target=_slow);
    t3.start();
    t3.join(0.01);
    join_timeout_alive = t3.is_alive();
    t3.join();
    joined_dead = t3.is_alive();
    return {
        "inc": _counter[0],
        "nb_first": nb_first,
        "nb_held": nb_held,
        "rel_unheld": rel_unheld,
        "nb_timeout": nb_timeout,
        "neg_timeout": neg_timeout,
        "neg_fractional_timeout": neg_fractional_timeout,
        "dbl_start": dbl_start,
        "join_early": join_early,
        "ev_timeout": ev_timeout,
        "ev_set_wait": ev_set_wait,
        "ev_handoff": _done[0],
        "cross_thread_release": cross_release_ok,
        "with_block": with_ok,
        "daemon_flag": daemon_flag,
        "daemon_inherit": _child_daemon[0],
        "join_timeout_alive": join_timeout_alive,
        "joined_dead": joined_dead,

    };
}


def threading_cl -> dict[any, any] {
    return {};
}


def threading_na -> dict[str, any] {
    _counter[0] = 0;
    _done[0] = 0;
    _ev.clear();
    threads: list[threading.Thread] = [];
    for i in range(8) {
        threads.append(threading.Thread(target=_bump));
    }
    for t in threads {
        t.start();
    }
    for t in threads {
        t.join();
    }
    lk = threading.Lock();
    nb_first = lk.acquire(False);
    nb_held = lk.acquire(False);
    lk.release();
    rel_unheld: str = "no-raise";
    try {
        lk.release();
    } except RuntimeError {
        rel_unheld = "RuntimeError";
    } except Exception {
        rel_unheld = "WRONG-TYPE";
    }
    nb_timeout: str = "no-raise";
    try {
        lk.acquire(False, timeout=0.1);
    } except ValueError {
        nb_timeout = "ValueError";
    } except Exception {
        nb_timeout = "WRONG-TYPE";
    }
    neg_timeout: str = "no-raise";
    try {
        lk.acquire(True, timeout=-2.0);
    } except ValueError {
        neg_timeout = "ValueError";
    } except Exception {
        neg_timeout = "WRONG-TYPE";
    }
    neg_fractional_timeout: str = "no-raise";
    try {
        lk.acquire(True, timeout=-0.5);
    } except ValueError {
        neg_fractional_timeout = "ValueError";
    } except Exception {
        neg_fractional_timeout = "WRONG-TYPE";
    }
    dbl_start: str = "no-raise";
    t2 = threading.Thread(target=_slow);
    t2.start();
    try {
        t2.start();
    } except RuntimeError {
        dbl_start = "RuntimeError";
    } except Exception {
        dbl_start = "WRONG-TYPE";
    }
    t2.join();
    join_early: str = "no-raise";
    try {
        threading.Thread(target=_slow).join();
    } except RuntimeError {
        join_early = "RuntimeError";
    } except Exception {
        join_early = "WRONG-TYPE";
    }
    ev2 = threading.Event();
    ev_timeout = ev2.wait(0.02);
    ev2.set();
    ev_set_wait = ev2.wait(0.02);
    s = threading.Thread(target=_mark);
    wt = threading.Thread(target=_wait);
    wt.start();
    s.start();
    wt.join();
    s.join();
    _cross_lock.acquire();
    cross_releaser = threading.Thread(target=_release_cross_lock);
    cross_releaser.start();
    cross_releaser.join();
    cross_release_ok = _cross_lock.acquire(False);
    if cross_release_ok {
        _cross_lock.release();
    }
    with_ok: bool = False;
    with _lock {
        with_ok = True;
    }
    d = threading.Thread(target=_slow, daemon=True);
    d.start();
    daemon_flag = d.daemon;
    daemon_parent = threading.Thread(target=_spawn_daemon_child, daemon=True);
    daemon_parent.start();
    daemon_parent.join();
    t3 = threading.Thread(target=_slow);
    t3.start();
    t3.join(0.01);
    join_timeout_alive = t3.is_alive();
    t3.join();
    joined_dead = t3.is_alive();
    return {
        "inc": _counter[0],
        "nb_first": 1 if nb_first else 0,
        "nb_held": 1 if nb_held else 0,
        "rel_unheld": rel_unheld,
        "nb_timeout": nb_timeout,
        "neg_timeout": neg_timeout,
        "neg_fractional_timeout": neg_fractional_timeout,
        "dbl_start": dbl_start,
        "join_early": join_early,
        "ev_timeout": 1 if ev_timeout else 0,
        "ev_set_wait": 1 if ev_set_wait else 0,
        "ev_handoff": _done[0],
        "cross_thread_release": cross_release_ok,
        "with_block": 1 if with_ok else 0,
        "daemon_flag": 1 if daemon_flag else 0,
        "daemon_inherit": 1 if _child_daemon[0] else 0,
        "join_timeout_alive": 1 if join_timeout_alive else 0,
        "joined_dead": 1 if joined_dead else 0,

    };
}
