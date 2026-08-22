# na cliff: a generator modeled as a suspended-frame state machine, exercising
# the parts a naive "yield 1,2,3" machine dodges. jac-py core site: PyFrame(ip +
# saved locals + value stack) / PyGenerator drive a `yield` one .send()/next() at
# a time (pyc_first.jac ~4652/5694); gen.close() injects GeneratorExit at the
# suspend point and MUST run an active finally (gen_close/frame_clear ~5878).
#
# Resumption is INTEGER ip/state advanced over DATA -- no stored function values,
# no indirect calls -- mirroring how CPython/jacpython carry a frame as data.
# Hard cases covered:
#   1. nested loop      -> loop state lives in saved locals (i, j), not fn frames.
#   2. try/finally      -> na exceptions are LEXICALLY structured: you cannot jump
#      into the middle of a try, so the finally is restructured into an ip state
#      that EVERY exit path (normal stop / close) passes through, guarded to run
#      exactly once. A second close() is then a proven no-op.
#   3. expression yield -> `swept += partial + (yield x)`: the partial expr is
#      SPILLED onto a saved stack field across the suspend, then completed by the
#      sent value on resume -- the value-stack claim a statement-only yield dodges.
#   4. yield-from       -> a sub-frame delegated to, its return value flowing back.
# Memories: na-container-capabilities (list[int] subscript),
# na-method-call-on-union-receiver (sub is a required field, never T|None).
obj PyObj {
    has t: str;
}

obj PyInt(PyObj) {
    has val: int;
}

# "frame returned normally" sentinel (StopIteration), carrying the return value.
obj PyGenStop(PyObj) {
    has val: int;
}

def expect_int(o: PyObj) -> int {
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    return 0;
}

# The delegated sub-generator: yields its seq, then RETURNS a value (StopIteration
# payload) that the delegating frame folds back into its own expression.
obj SubFrame(PyObj) {
    has seq: list[int],
        k: int = 0;

    def resume(sent: PyObj) -> PyObj {
        if self.k < len(self.seq) {
            v = self.seq[self.k];
            self.k = self.k + 1;
            return PyInt(t="int", val=v);
        }
        return PyGenStop(t="genstop", val=42);
    }
}

# The resumable frame. Models the generator body
#
#     def gen(data, sub):
#         swept = 0
#         try:
#             for i in rows:                       # outer loop
#                 for j in cols:                   # nested loop
#                     swept += data[i][j]*10 + (yield data[i][j])   # expr yield
#             swept += yield from sub              # delegation, value flows back
#         finally:
#             cleanup += 1                         # runs on return OR close()
#         return swept
#
# entirely as DATA + an integer ip + saved locals (i, j, swept) + a one-slot value
# stack (spill). The finally is an ip state (run_finally) every exit routes
# through; `in_try` guards it so it fires exactly once even on double close().
obj PyFrame(PyObj) {
    has data: list[int],
        sub: SubFrame,
        nrows: int,
        ncols: int,
        ip: int = 0,
        i: int = 0,
        j: int = 0,
        swept: int = 0,
        spill: int = 0,
        in_try: bool = False,
        finally_runs: int = 0;

    def resume(sent: PyObj) -> PyObj {
        # ip 2: woke inside the nested loop's expression yield. The sent value
        # completes the partial expression spilled at suspend, then advance j.
        if self.ip == 2 {
            self.swept = self.swept + (self.spill + expect_int(sent));
            self.j = self.j + 1;
        }
        # ip 3: woke inside the yield-from delegation; pump the sub-iterator.
        if self.ip == 3 {
            step = self.sub.resume(sent);
            if step.t != "genstop" {
                return step;
            }
            self.swept = self.swept + (step as PyGenStop).val;
            self.ip = 4;
        }
        # Enter / re-enter the try body.
        self.in_try = True;
        # Nested loop, driven purely by the saved integer indices over DATA.
        while self.i < self.nrows {
            while self.j < self.ncols {
                x = self.data[self.i * self.ncols + self.j];
                # Expression-position yield: compute the partial (x*10), SPILL it
                # onto the value stack, suspend. Resume completes swept += it+sent.
                self.spill = x * 10;
                self.ip = 2;
                return PyInt(t="int", val=x);
            }
            self.j = 0;
            self.i = self.i + 1;
        }
        # yield-from delegation: first entry pumps the sub and suspends at ip 3.
        if self.ip != 4 {
            self.ip = 3;
            first = self.sub.resume(sent);
            if first.t != "genstop" {
                return first;
            }
            self.swept = self.swept + (first as PyGenStop).val;
        }
        # Normal exit path -> route through the finally state, then StopIteration.
        self.run_finally();
        return PyGenStop(t="genstop", val=self.swept);
    }

    # The finally, restructured as an ip state passed through on every exit path
    # exactly once. `in_try` is the guard that makes a repeated close() a no-op --
    # the workaround for na's lexically-structured exceptions, which forbid
    # jumping into the middle of the try to reach an in-body finally.
    def run_finally {
        if self.in_try {
            self.finally_runs = self.finally_runs + 1;
            self.in_try = False;
        }
    }

    # gen.close(): inject GeneratorExit at the suspend point. If suspended inside
    # the try, route through the finally before tearing the frame down. Idempotent.
    def close -> PyObj {
        self.run_finally();
        self.ip = 99;
        return PyGenStop(t="genstop", val=self.swept);
    }
}

def make_frame -> PyFrame {
    sub = SubFrame(t="subframe", seq=[100, 200]);
    return PyFrame(t="frame", data=[1, 2, 3, 4], sub=sub, nrows=2, ncols=2);
}

# THE HARD CASE: next -> send(5) -> close() EARLY (mid-try, ip parked at 2, loop
# not exhausted). The finally must run exactly once; a SECOND close() must be a
# no-op. Both are folded into the result so a skipped or doubled finally, or a
# wrong-ip resume, changes the number.
def drive_close -> int {
    g = make_frame();
    collected = 0;
    y0 = g.resume(PyInt(t="int", val=0));  # next(): yields data[0]=1
    collected = collected + expect_int(y0);
    y1 = g.resume(PyInt(t="int", val=5));  # send(5): swept += 10+5=15; yields 2
    collected = collected + expect_int(y1);
    g.close();  # mid-try close -> finally runs (==1)
    first_ct = g.finally_runs;  # expect 1
    g.close();  # second close -> no-op (still 1)
    second_ct = g.finally_runs;  # expect 1
    # collected=1+2=3; swept=15; first_ct=1; second_ct=1.
    # Encode: 3_15_1_1 -> 3*1000000 + 15*10000 + 1*100 + 1 = 3150101.
    return collected * 1000000 + g.swept * 10000 + first_ct * 100 + second_ct;
}

# Drive to exhaustion, exercising nested loop + yield-from value flow-back and the
# finally running once on the NORMAL exit path.
def drive_full -> int {
    g = make_frame();
    collected = 0;
    steps = 0;
    sent: PyObj = PyInt(t="int", val=0);
    keep = True;
    while keep {
        y = g.resume(sent);
        if y.t == "genstop" {
            keep = False;
        } else {
            collected = collected + expect_int(y);
            steps = steps + 1;
            sent = PyInt(t="int", val=1);
        }
    }
    # yields 1,2,3,4 (loop) then 100,200 (delegation) -> collected 310, 6 steps;
    # finally ran once on normal return.
    return collected * 1000 + steps * 100 + g.finally_runs * 10;
}

with entry {
    print(drive_close());
    print(drive_full());
}
