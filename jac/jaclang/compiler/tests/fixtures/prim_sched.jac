"""Bundled native `sched` cross-backend equivalence fixture (#6978).

The same `import sched` binds CPython's `sched` on the sv backend and
`na_stdlib/sched.jac` on the na (native LLVM) backend. Pins the queue
discipline rather than wall-clock behaviour: absolute-time ordering, the
priority tie-break, the monotonically increasing sequence number that breaks
priority ties, `empty()`, `cancel()` (including the ValueError on an event that
is no longer queued), `queue` ordering, and that `run()` drains due events in
that order.

Actions are module-level zero-argument functions, duplicated per lane, writing
into a per-lane static list. A *capturing* closure cannot be passed as a value
on the native pathway ("capturing closure used as a value"), and a module-level
helper shared by both lane functions would be assigned to the Python side and
then called unregistered from native code, so both the actions and their store
are per-lane. The native module also does not marshal an `argument` tuple, so
the fixture never passes one. ES/JS opts out.
"""

import sched;


obj SchedTracePy {
    static has seq: list[int] = [];
}


obj SchedTraceNa {
    static has seq: list[int] = [];
}


def tick_a_py {
    SchedTracePy.seq.append(1);
}


def tick_b_py {
    SchedTracePy.seq.append(2);
}


def tick_c_py {
    SchedTracePy.seq.append(3);
}


def tick_a_na {
    SchedTraceNa.seq.append(1);
}


def tick_b_na {
    SchedTraceNa.seq.append(2);
}


def tick_c_na {
    SchedTraceNa.seq.append(3);
}


def sched_py -> dict[any, any] {
    SchedTracePy.seq = [];
    s = sched.scheduler();
    e1 = s.enterabs(-30.0, 1, tick_a_py);
    e2 = s.enterabs(-10.0, 5, tick_b_py);
    e3 = s.enterabs(-10.0, 1, tick_c_py);
    q = s.queue;
    first_pri = q[0].priority;
    order_len = len(q);
    seq_rising = 1 if (e1.sequence < e2.sequence and e2.sequence < e3.sequence) else 0;
    empty_before = 1 if s.empty() else 0;
    s.cancel(e1);
    cancelled_len = len(s.queue);
    cancel_err = "";
    try {
        s.cancel(e1);
    } except Exception as ex {
        cancel_err = str(ex);
    }
    s.run();
    empty_after = 1 if s.empty() else 0;
    trace = SchedTracePy.seq;
    return {
        "first_pri": first_pri,
        "order_len": order_len,
        "seq_rising": seq_rising,
        "empty_before": empty_before,
        "cancelled_len": cancelled_len,
        "cancel_err": cancel_err,
        "empty_after": empty_after,
        "trace_len": len(trace),
        "trace_0": trace[0],
        "trace_1": trace[1],

    };
}


def sched_cl -> dict[any, any] {
    return {};
}


def sched_na -> dict[str, any] {
    SchedTraceNa.seq = [];
    s = sched.scheduler();
    e1 = s.enterabs(-30.0, 1, tick_a_na);
    e2 = s.enterabs(-10.0, 5, tick_b_na);
    e3 = s.enterabs(-10.0, 1, tick_c_na);
    q = s.queue;
    first_pri = q[0].priority;
    order_len = len(q);
    seq_rising = 1 if (e1.sequence < e2.sequence and e2.sequence < e3.sequence) else 0;
    empty_before = 1 if s.empty() else 0;
    s.cancel(e1);
    cancelled_len = len(s.queue);
    cancel_err = "";
    try {
        s.cancel(e1);
    } except Exception as ex {
        cancel_err = str(ex);
    }
    s.run();
    empty_after = 1 if s.empty() else 0;
    trace = SchedTraceNa.seq;
    return {
        "first_pri": first_pri,
        "order_len": order_len,
        "seq_rising": seq_rising,
        "empty_before": empty_before,
        "cancelled_len": cancelled_len,
        "cancel_err": cancel_err,
        "empty_after": empty_after,
        "trace_len": len(trace),
        "trace_0": trace[0],
        "trace_1": trace[1],

    };
}
