# T7 known-na-cliffs conformance reference (jac-py/PLAN.md §6.7, TODO.md D4 #4).
#
# Each function here mirrors a pattern jacpython's na-clean core ALREADY uses,
# and each targets a documented na landmine. This file pins the CORRECT answer
# on the bytecode backend; CI nacompiles the identical logic (the sibling
# cliff_*.na.jac fixtures) and diffs against these values. A divergence is a
# real na miscompile on a pattern the port depends on -- discovered here on
# day one instead of at P7.
#
# Measured na status (local `jac nacompile`, 2026-07-15): all four reach
# capability-clean + LLVM IR + object-code emit; only the final musl link is
# blocked locally (env, not code). Runtime-correctness legs (NUL-drop,
# union-receiver-drop) require the linked binary and run in CI. See README.md.

# --- cliff 1: list[int] subscript. Core site: marshal Reader.r_byte ---
def r_byte(data: list[int], pos: int) -> int {
    b = data[pos];
    return b & 0xFF;
}

# --- cliff 2: dict[str,T] build + return + subscript. Core site: exec_module ---
def exec_module_like -> dict[str, int] {
    g: dict[str, int] = {};
    g["y"] = 43;
    return g;
}

# --- cliff 3: method/field on a T|None receiver. Core site: deref_cell ---
obj Cell {
    has val: int;
}

def find_cell(hit: bool) -> Cell | None {
    if hit {
        return Cell(val=7);
    }
    return None;
}

def cell_value(hit: bool) -> int {
    c = find_cell(hit);
    if c is None {
        return -1;
    }
    return c.val;
}

# --- cliff 4: binary buffer via chr concat incl NUL. Core site: bytes_to_str ---
def build_binary -> str {
    s = "";
    s = s + chr(0);
    s = s + chr(65);
    return s;
}

# --- cliff 5: data-driven dict-lookup method/attr dispatch over an MRO.
# Core site: PyUserObj.tp_getattro (pyc_first.jac) -- instance-dict-wins then a
# class_mro walk, the looked-up PyObj narrowed via isinstance/as and invoked
# through a vtable (no function values / no fn-pointer table; na resolves every
# call statically). na landmines mirrored: the T|None-shaped receiver-drop is
# guarded (narrow before call), and the dict-literal-subclass-upcast ICE is
# worked around by building attrs empty and subscript-storing through a
# PyObj-typed local -- exactly as the sibling cliff_user_dispatch.na.jac does.
obj DObj {
    has t: str;
}

obj DInt(DObj) {
    has val: int;
}

obj DMethod(DObj) {
    def invoke(receiver: DUserObj) -> DObj {
        return DObj(t="error");
    }
}

obj DAddMethod(DMethod) {
    has delta: int;

    def invoke(receiver: DUserObj) -> DObj {
        base = d_expect_int(receiver.getattr("val"));
        return DInt(t="int", val=base + self.delta);
    }
}

obj DMulMethod(DMethod) {
    has factor: int;

    def invoke(receiver: DUserObj) -> DObj {
        base = d_expect_int(receiver.getattr("val"));
        return DInt(t="int", val=base * self.factor);
    }
}

obj DClass(DObj) {
    has name: str,
        attrs: dict[str, DObj],
        bases: list[DObj] = [];
}

obj DUserObj(DObj) {
    has cls: DClass,
        attrs: dict[str, DObj];

    def getattr(name: str) -> DObj {
        if name in self.attrs {
            return self.attrs[name];
        }
        return d_lookup(self.cls, name);
    }
}

def d_mro(cls: DClass) -> list[DClass] {
    result: list[DClass] = [cls];
    for base in cls.bases {
        if isinstance(base, DClass) {
            for klass in d_mro(base as DClass) {
                result.append(klass);
            }
        }
    }
    return result;
}

def d_lookup(cls: DClass, name: str) -> DObj {
    for klass in d_mro(cls) {
        if name in klass.attrs {
            return klass.attrs[name];
        }
    }
    return DObj(t="error");
}

def d_expect_int(o: DObj) -> int {
    if isinstance(o, DInt) {
        return (o as DInt).val;
    }
    return 0;
}

def d_dispatch(o: DUserObj, name: str) -> int {
    m = o.getattr(name);
    if m.t == "error" {
        return -1;
    }
    if not isinstance(m, DMethod) {
        return -2;
    }
    method = m as DMethod;  # narrow the union before the call
    return d_expect_int(method.invoke(o));
}

def d_make_class(nm: str, bases: list[DObj]) -> DClass {
    a: dict[str, DObj] = {};
    return DClass(t="type", name=nm, attrs=a, bases=bases);
}

def d_make_inst(c: DClass, v: int) -> DUserObj {
    a: dict[str, DObj] = {};
    boxed: DObj = DInt(t="int", val=v);
    a["val"] = boxed;
    return DUserObj(t="obj", cls=c, attrs=a);
}

# Returns [accumulated total over the heterogeneous dispatch, post-mutation
# redispatch result]. Base <- Mid <- Leaf; Mid shadows "act"; "other" only on
# Base is reached two levels down.
def d_run -> list[int] {
    no_bases: list[DObj] = [];
    base_cls = d_make_class("Base", no_bases);
    m_add: DObj = DAddMethod(t="add", delta=100);
    m_other: DObj = DAddMethod(t="add", delta=1);
    base_cls.attrs["act"] = m_add;
    base_cls.attrs["other"] = m_other;

    mid_bases: list[DObj] = [base_cls];
    mid_cls = d_make_class("Mid", mid_bases);
    m_mul: DObj = DMulMethod(t="mul", factor=3);
    mid_cls.attrs["act"] = m_mul;

    leaf_bases: list[DObj] = [mid_cls];
    leaf_cls = d_make_class("Leaf", leaf_bases);

    insts: list[DUserObj] = [];
    leaf_inst = d_make_inst(leaf_cls, 5);
    base_inst = d_make_inst(base_cls, 7);
    insts.append(leaf_inst);
    insts.append(base_inst);

    names: list[str] = ["act", "other"];
    total = 0;
    for inst in insts {
        for nm in names {
            r = d_dispatch(inst, nm);
            total = total + r;
        }
    }

    # Killer: mutate the instance dict so "act" now hits the instance dict, then
    # redispatch from the same call site.
    `override: DObj = DAddMethod(t="add", delta=1000);
    leaf_inst.attrs["act"] = `override;
    again = d_dispatch(leaf_inst, names[0]);
    return [total, again];
}

test "cliff: list[int] subscript reads the right byte" {
    assert r_byte([227, 2, 0], 0) == 227;
    assert r_byte([227, 2, 0], 1) == 2;
}

test "cliff: dict build/return/subscript round-trips" {
    assert exec_module_like()["y"] == 43;
}

test "cliff: T|None receiver field access after None-guard" {
    assert cell_value(True) == 7;
    assert cell_value(False) == -1;
}

test "cliff: binary buffer preserves NUL (na len=strlen would report 1)" {
    # Bytecode truth: two code units. On na this is the canary -- if len()
    # degrades to strlen, this returns 1 and the CI differential goes red.
    assert len(build_binary()) == 2;
}

test "cliff: MRO dict dispatch resolves + mutates (na devirt/drop canary)" {
    # Leaf.act -> Mid.mul3(5)=15 ; Leaf.other -> Base.add1(5)=6 ;
    # Base.act -> Base.add100(7)=107 ; Base.other -> Base.add1(7)=8. Sum=136.
    # Post-mutation Leaf.act hits the instance dict: add1000(5)=1005.
    r = d_run();
    assert r[0] == 136;
    assert r[1] == 1005;
    assert r[0] + r[1] == 1141;
}

# --- cliff 6: generator as a suspended-frame state machine. Core site: the
# generator machinery in pyc_first.jac -- PyFrame(ip + saved locals + value
# stack) / PyGenerator drive a `yield` one .send()/next() at a time, and
# gen.close() injects GeneratorExit at the suspend point and must run an active
# finally. Resumption is INTEGER ip/state advanced over DATA -- no stored
# function values / no indirect calls (na resolves every call statically).
# na landmines mirrored: na exceptions are LEXICALLY structured, so you cannot
# jump into the middle of a try to reach an in-body finally -- it is lifted to an
# ip state (g_run_finally) that EVERY exit path (normal stop + close) passes
# through, guarded by `in_try` so a repeated close() is an idempotent no-op; the
# T|None-shaped receiver-drop is avoided by making the delegated sub-frame a
# required field (never T|None) -- exactly as sibling cliff_gen_frame.na.jac does.
obj GObj {
    has t: str;
}

obj GInt(GObj) {
    has val: int;
}

obj GGenStop(GObj) {
    has val: int;
}

def g_expect_int(o: GObj) -> int {
    if isinstance(o, GInt) {
        return (o as GInt).val;
    }
    return 0;
}

# Delegated sub-generator: yields its seq, then RETURNS 42 (StopIteration payload)
# which the delegating frame folds back into its own expression.
obj GSubFrame(GObj) {
    has seq: list[int],
        k: int = 0;

    def resume(sent: GObj) -> GObj {
        if self.k < len(self.seq) {
            v = self.seq[self.k];
            self.k = self.k + 1;
            return GInt(t="int", val=v);
        }
        return GGenStop(t="genstop", val=42);
    }
}

# The resumable frame: nested loop (state in i/j) + expression-position yield
# (partial spilled onto `spill`, completed by the sent value on resume) + a
# try/finally lifted to an ip state + yield-from delegation with value flow-back.
obj GFrame(GObj) {
    has data: list[int],
        sub: GSubFrame,
        nrows: int,
        ncols: int,
        ip: int = 0,
        i: int = 0,
        j: int = 0,
        swept: int = 0,
        spill: int = 0,
        in_try: bool = False,
        finally_runs: int = 0;

    def resume(sent: GObj) -> GObj {
        if self.ip == 2 {
            self.swept = self.swept + (self.spill + g_expect_int(sent));
            self.j = self.j + 1;
        }
        if self.ip == 3 {
            step = self.sub.resume(sent);
            if step.t != "genstop" {
                return step;
            }
            self.swept = self.swept + (step as GGenStop).val;
            self.ip = 4;
        }
        self.in_try = True;
        while self.i < self.nrows {
            while self.j < self.ncols {
                x = self.data[self.i * self.ncols + self.j];
                self.spill = x * 10;
                self.ip = 2;
                return GInt(t="int", val=x);
            }
            self.j = 0;
            self.i = self.i + 1;
        }
        if self.ip != 4 {
            self.ip = 3;
            first = self.sub.resume(sent);
            if first.t != "genstop" {
                return first;
            }
            self.swept = self.swept + (first as GGenStop).val;
        }
        self.run_finally();
        return GGenStop(t="genstop", val=self.swept);
    }

    # Finally lifted to an ip state, guarded to fire exactly once (idempotent
    # double-close). The workaround for na's lexically-structured exceptions.
    def run_finally {
        if self.in_try {
            self.finally_runs = self.finally_runs + 1;
            self.in_try = False;
        }
    }

    # gen.close(): route through the finally, then tear down. Idempotent.
    def close -> GObj {
        self.run_finally();
        self.ip = 99;
        return GGenStop(t="genstop", val=self.swept);
    }
}

def g_make_frame -> GFrame {
    sub = GSubFrame(t="subframe", seq=[100, 200]);
    return GFrame(t="frame", data=[1, 2, 3, 4], sub=sub, nrows=2, ncols=2);
}

# next -> send(5) -> close() EARLY (mid-try, ip parked at 2). Finally must run
# once; a second close() must be a no-op.
def g_drive_close -> int {
    g = g_make_frame();
    collected = 0;
    y0 = g.resume(GInt(t="int", val=0));
    collected = collected + g_expect_int(y0);
    y1 = g.resume(GInt(t="int", val=5));
    collected = collected + g_expect_int(y1);
    g.close();
    first_ct = g.finally_runs;
    g.close();
    second_ct = g.finally_runs;
    return collected * 1000000 + g.swept * 10000 + first_ct * 100 + second_ct;
}

# Drive to exhaustion: nested loop + yield-from flow-back; finally once on stop.
def g_drive_full -> int {
    g = g_make_frame();
    collected = 0;
    steps = 0;
    sent: GObj = GInt(t="int", val=0);
    keep = True;
    while keep {
        y = g.resume(sent);
        if y.t == "genstop" {
            keep = False;
        } else {
            collected = collected + g_expect_int(y);
            steps = steps + 1;
            sent = GInt(t="int", val=1);
        }
    }
    return collected * 1000 + steps * 100 + g.finally_runs * 10;
}

test "cliff: generator suspend/resume frame -- try/finally on close + yield-from" {
    # Mid-try close: yields data[0]=1 then data[1]=2 (collected=3); send(5) makes
    # swept = 10+5 = 15; close() runs the finally once (1), second close is a
    # no-op (still 1). Encoded 3_15_1_1 -> 3150101.
    assert g_drive_close() == 3150101;
    # Exhaustion: nested loop yields 1,2,3,4 then delegation yields 100,200
    # (collected=310) over 6 steps; finally runs once on the normal exit.
    # Encoded 310_06_1 -> 310610.
    assert g_drive_full() == 310610;
}

# --- cliff 7: dict-value -> native-call boundary AT SCALE. Core site:
# pyc_first.jac binop_dunder/compare_dunder + objects.jac PyInt.nb_binop(kind:int)
# -- an int "kind" pulled from a dict[str,int] selects a static call target through
# a closed N-way switch (na resolves every call statically, so an operator table
# CANNOT be a fn-pointer array; it is a switch on an int slot-id). This block pins
# a 40-arm switch driven by a RUNTIME-computed method_id (dict-keyed, DATA operands)
# so no arm folds; the accumulator weights each arm by (mid+1). na landmine:
# op-switch scale + T|None-receiver-drop (operand union narrowed before its int).
obj OpObj {
    has t: str;
}

obj OpInt(OpObj) {
    has val: int;
}

obj OpBool(OpObj) {
    has val: bool;
}

def op_error -> OpObj {
    return OpObj(t="error");
}

def op_expect_num(o: OpObj) -> int {
    if isinstance(o, OpInt) {
        return (o as OpInt).val;
    }
    if isinstance(o, OpBool) {
        if (o as OpBool).val {
            return 1;
        }
        return 0;
    }
    return 0;
}

def op_invoke(method_id: int, a: OpObj, b: OpObj) -> OpObj {
    x = op_expect_num(a);
    y = op_expect_num(b);
    if method_id == 0 {
        return OpInt(t="int", val=x + y);
    }
    if method_id == 1 {
        return OpInt(t="int", val=x - y);
    }
    if method_id == 2 {
        return OpInt(t="int", val=x * y);
    }
    if method_id == 3 {
        return OpInt(t="int", val=x // y);
    }
    if method_id == 4 {
        return OpInt(t="int", val=x % y);
    }
    if method_id == 5 {
        return OpInt(t="int", val=x & y);
    }
    if method_id == 6 {
        return OpInt(t="int", val=x | y);
    }
    if method_id == 7 {
        return OpInt(t="int", val=x ^ y);
    }
    if method_id == 8 {
        return OpInt(t="int", val=x << (y % 8));
    }
    if method_id == 9 {
        return OpInt(t="int", val=x >> (y % 8));
    }
    if method_id == 10 {
        return OpBool(t="bool", val=x < y);
    }
    if method_id == 11 {
        return OpBool(t="bool", val=x <= y);
    }
    if method_id == 12 {
        return OpBool(t="bool", val=x == y);
    }
    if method_id == 13 {
        return OpBool(t="bool", val=x != y);
    }
    if method_id == 14 {
        return OpBool(t="bool", val=x > y);
    }
    if method_id == 15 {
        return OpBool(t="bool", val=x >= y);
    }
    if method_id == 16 {
        return OpInt(t="int", val=-x);
    }
    if method_id == 17 {
        return OpInt(t="int", val=-y);
    }
    if method_id == 18 {
        return OpInt(t="int", val=x + 2 * y);
    }
    if method_id == 19 {
        return OpInt(t="int", val=2 * x + y);
    }
    if method_id == 20 {
        return OpInt(t="int", val=x * x - y);
    }
    if method_id == 21 {
        return OpInt(t="int", val=x + y * y);
    }
    if method_id == 22 {
        return OpInt(t="int", val=(x + y) * (x - y));
    }
    if method_id == 23 {
        return OpInt(t="int", val=x * y + x + y);
    }
    if method_id == 24 {
        return OpInt(t="int", val=x % (y + 1));
    }
    if method_id == 25 {
        return OpInt(t="int", val=(x + 1) * (y + 1));
    }
    if method_id == 26 {
        return OpInt(t="int", val=x - y - 1);
    }
    if method_id == 27 {
        return OpInt(t="int", val=x * 3 - y * 2);
    }
    if method_id == 28 {
        return OpInt(t="int", val=x ^ (y << 1));
    }
    if method_id == 29 {
        return OpInt(t="int", val=(x & y) + (x | y));
    }
    if method_id == 30 {
        return OpInt(t="int", val=x * x + y * y);
    }
    if method_id == 31 {
        return OpInt(t="int", val=x + y + 17);
    }
    if method_id == 32 {
        return OpInt(t="int", val=x * 7 % 100);
    }
    if method_id == 33 {
        return OpInt(t="int", val=y * 7 % 100);
    }
    if method_id == 34 {
        return OpInt(t="int", val=(x << 2) - y);
    }
    if method_id == 35 {
        return OpInt(t="int", val=x * x * x - y);
    }
    if method_id == 36 {
        d = x - y;
        if d < 0 {
            return OpInt(t="int", val=-d);
        }
        return OpInt(t="int", val=d);
    }
    if method_id == 37 {
        if x > y {
            return OpInt(t="int", val=x);
        }
        return OpInt(t="int", val=y);
    }
    if method_id == 38 {
        if x < y {
            return OpInt(t="int", val=x);
        }
        return OpInt(t="int", val=y);
    }
    if method_id == 39 {
        return OpInt(t="int", val=x * y - (x + y));
    }
    return op_error();
}

def op_build_table(names: list[str]) -> dict[str, int] {
    table: dict[str, int] = {};
    idx = 0;
    for nm in names {
        table[nm] = idx;
        idx = idx + 1;
    }
    return table;
}

def op_run -> int {
    names: list[str] = [
        "add",
        "sub",
        "mul",
        "floordiv",
        "mod",
        "and",
        "or",
        "xor",
        "lshift",
        "rshift",
        "lt",
        "le",
        "eq",
        "ne",
        "gt",
        "ge",
        "neg",
        "rneg",
        "add2y",
        "twox",
        "sqsub",
        "addsq",
        "diffsq",
        "poly",
        "modp1",
        "incprod",
        "subm1",
        "affine",
        "xorshift",
        "andor",
        "sumsq",
        "plus17",
        "x7",
        "y7",
        "shl2",
        "cube",
        "absd",
        "maxxy",
        "minxy",
        "prodsub"
    ];
    table = op_build_table(names);

    lefts: list[OpObj] = [
        OpInt(t="int", val=7),
        OpInt(t="int", val=12),
        OpInt(t="int", val=9)
    ];
    rights: list[OpObj] = [
        OpInt(t="int", val=3),
        OpInt(t="int", val=5),
        OpInt(t="int", val=4)
    ];

    total = 0;
    pair = 0;
    while pair < len(lefts) {
        a: OpObj = lefts[pair];
        b: OpObj = rights[pair];
        for nm in names {
            mid = table[nm];
            r = op_invoke(mid, a, b);
            v = op_expect_num(r);
            total = total + v * (mid + 1);
        }
        pair = pair + 1;
    }
    return total;
}

test "cliff: 40-arm op-switch on runtime method_id (na op-switch-scale canary)" {
    # dict[str,int]-keyed method_id drives a closed 40-way switch over 3 operand
    # pairs; each arm weighted by (mid+1). A single mislowered arm shifts the sum.
    assert op_run() == 163283;
}

# --- cliff 8: full attribute-precedence protocol (descriptor / __getattr__).
# Core site: pyc_first.jac PyUserObj.tp_getattro (~1526) + descriptor_get: a DATA
# descriptor (has __set__) PREEMPTS the instance dict; else instance dict; else a
# non-data descriptor / plain class attr via MRO walk; else __getattr__ on a total
# miss. __get__ is a method-id switch in a real na method body reached only after
# isinstance/as narrowing the dict-lookup union. na landmine: descriptor/__getattr__
# precedence + T|None-receiver-drop (narrow before call) + dict-subclass-upcast ICE.
obj DescObj {
    has t: str;
}

obj DescInt(DescObj) {
    has val: int;
}

obj DescDescriptor(DescObj) {
    has kind: int,
        operand: int,
        has_set: bool;

    def is_data -> bool {
        return self.has_set;
    }

    def dunder_get(instance: DescUserObj) -> DescObj {
        base = desc_expect_int(instance.raw_slot());
        if self.kind == 1 {
            return DescInt(t="int", val=base + self.operand);
        }
        if self.kind == 2 {
            return DescInt(t="int", val=base * self.operand);
        }
        return DescObj(t="error");
    }
}

obj DescGetAttr(DescObj) {
    has sentinel: int;

    def fire(name: str) -> DescObj {
        return DescInt(t="int", val=self.sentinel + len(name));
    }
}

obj DescClass(DescObj) {
    has name: str,
        attrs: dict[str, DescObj],
        bases: list[DescObj] = [];
}

obj DescUserObj(DescObj) {
    has cls: DescClass,
        attrs: dict[str, DescObj],
        raw: int;

    def raw_slot -> DescObj {
        return DescInt(t="int", val=self.raw);
    }
}

def desc_mro(cls: DescClass) -> list[DescClass] {
    result: list[DescClass] = [cls];
    for base in cls.bases {
        if isinstance(base, DescClass) {
            for klass in desc_mro(base as DescClass) {
                result.append(klass);
            }
        }
    }
    return result;
}

def desc_lookup(cls: DescClass, name: str) -> DescObj {
    for klass in desc_mro(cls) {
        if name in klass.attrs {
            return klass.attrs[name];
        }
    }
    return DescObj(t="error");
}

def desc_expect_int(o: DescObj) -> int {
    if isinstance(o, DescInt) {
        return (o as DescInt).val;
    }
    return 0;
}

def desc_is_error(value: DescObj) -> bool {
    return value.t == "error";
}

def desc_resolve_attr(o: DescUserObj, name: str) -> DescObj {
    classattr = desc_lookup(o.cls, name);

    if isinstance(classattr, DescDescriptor) {
        d = classattr as DescDescriptor;
        if d.is_data() {
            return d.dunder_get(o);
        }
    }

    if name in o.attrs {
        return o.attrs[name];
    }

    if not desc_is_error(classattr) {
        if isinstance(classattr, DescDescriptor) {
            nd = classattr as DescDescriptor;
            return nd.dunder_get(o);
        }
        return classattr;
    }

    hook = desc_lookup(o.cls, "__getattr__");
    if isinstance(hook, DescGetAttr) {
        g = hook as DescGetAttr;
        return g.fire(name);
    }

    return DescObj(t="error");
}

def desc_resolve_int(o: DescUserObj, name: str) -> int {
    v = desc_resolve_attr(o, name);
    if desc_is_error(v) {
        return -1;
    }
    if not isinstance(v, DescInt) {
        return -2;
    }
    return (v as DescInt).val;
}

def desc_make_class(nm: str, bases: list[DescObj]) -> DescClass {
    a: dict[str, DescObj] = {};
    return DescClass(t="type", name=nm, attrs=a, bases=bases);
}

def desc_make_inst(c: DescClass, v: int) -> DescUserObj {
    a: dict[str, DescObj] = {};
    return DescUserObj(t="obj", cls=c, attrs=a, raw=v);
}

def desc_run_pd -> list[int] {
    no_bases: list[DescObj] = [];
    base_cls = desc_make_class("Base", no_bases);

    d_temp: DescObj = DescDescriptor(t="descr", kind=1, operand=100, has_set=True);
    d_scaled: DescObj = DescDescriptor(t="descr", kind=2, operand=3, has_set=False);
    hook: DescObj = DescGetAttr(t="getattr", sentinel=1000);
    base_cls.attrs["temp"] = d_temp;
    base_cls.attrs["scaled"] = d_scaled;
    base_cls.attrs["__getattr__"] = hook;

    mid_bases: list[DescObj] = [base_cls];
    mid_cls = desc_make_class("Mid", mid_bases);

    leaf_bases: list[DescObj] = [mid_cls];
    leaf_cls = desc_make_class("Leaf", leaf_bases);

    inst = desc_make_inst(leaf_cls, 5);
    shadow: DescObj = DescInt(t="int", val=999);
    inst.attrs["temp"] = shadow;

    names: list[str] = ["temp", "scaled", "ghost"];
    phase_a = 0;
    for nm in names {
        phase_a = phase_a + desc_resolve_int(inst, nm);
    }

    # THE KILLER: one mutation, two opposite precedence outcomes.
    `override: DescObj = DescInt(t="int", val=777);
    inst.attrs["scaled"] = `override;
    killer_scaled = desc_resolve_int(inst, names[1]);
    killer_temp = desc_resolve_int(inst, names[0]);

    result: list[int] = [phase_a, killer_scaled, killer_temp];
    return result;
}

def desc_run -> int {
    r = desc_run_pd();
    if r[0] != 1125 {
        return -100;
    }
    if r[1] != 777 {
        return -200;
    }
    if r[2] != 105 {
        return -300;
    }
    return r[0] * 1000000 + r[1] * 1000 + r[2];
}

test "cliff: descriptor/__getattr__ precedence chain (na attr-protocol canary)" {
    # data-descr "temp" (105) preempts a same-named instance-dict 999; non-data
    # "scaled" beaten by an instance-dict override (777); "ghost" misses to
    # __getattr__ (1005). phase_a=1125. Encoded 1125_777_105 -> 1125777105.
    assert desc_run() == 1125777105;
}

# --- cliff 9: reflected binary-operator dispatch. Core site: pyc_first.jac
# user_binop (~3165): forward type(a).__op__(a,b); if it returns the explicit
# NotImplemented sentinel, try reflected type(b).__rop__(b,a); if both decline ->
# TypeError. Dunders are DATA (which PyMethod sits in a class dict), invoked as a
# resolved virtual dispatch on the PyMethod base reached only after isinstance/as
# narrowing. na landmine: reflected-binop NotImplemented fallback (a forward-only
# machine gets cases 1/2 wrong) + T|None-receiver-drop.
obj ReflObj {
    has t: str;
}

obj ReflInt(ReflObj) {
    has val: int;
}

def refl_notimpl -> ReflObj {
    return ReflObj(t="notimpl");
}

def refl_typeerror -> ReflObj {
    return ReflObj(t="error");
}

def refl_is_notimpl(o: ReflObj) -> bool {
    return o.t == "notimpl";
}

def refl_is_error(o: ReflObj) -> bool {
    return o.t == "error";
}

def refl_expect_int(o: ReflObj) -> int {
    if isinstance(o, ReflInt) {
        return (o as ReflInt).val;
    }
    return 0;
}

def refl_forward_name(op_id: int) -> str {
    names = ["__add__", "__mul__"];
    if op_id >= 0 and op_id < len(names) {
        return names[op_id];
    }
    return "";
}

def refl_reflected_name(op_id: int) -> str {
    names = ["__radd__", "__rmul__"];
    if op_id >= 0 and op_id < len(names) {
        return names[op_id];
    }
    return "";
}

obj ReflMethod(ReflObj) {
    def invoke(recv: ReflUserObj, other: ReflObj) -> ReflObj {
        return refl_typeerror();
    }
}

obj ReflDeclineMethod(ReflMethod) {
    def invoke(recv: ReflUserObj, other: ReflObj) -> ReflObj {
        return refl_notimpl();
    }
}

obj ReflRAddMethod(ReflMethod) {
    def invoke(recv: ReflUserObj, other: ReflObj) -> ReflObj {
        return ReflInt(t="int", val=refl_user_val(recv) + refl_user_val(other) + 1000);
    }
}

obj ReflRMulMethod(ReflMethod) {
    def invoke(recv: ReflUserObj, other: ReflObj) -> ReflObj {
        return ReflInt(t="int", val=refl_user_val(recv) * refl_user_val(other) + 2000);
    }
}

obj ReflFwdAddMethod(ReflMethod) {
    def invoke(recv: ReflUserObj, other: ReflObj) -> ReflObj {
        return ReflInt(t="int", val=refl_user_val(recv) + refl_user_val(other));
    }
}

obj ReflClass(ReflObj) {
    has name: str,
        attrs: dict[str, ReflObj],
        bases: list[ReflObj] = [];
}

obj ReflUserObj(ReflObj) {
    has cls: ReflClass,
        attrs: dict[str, ReflObj];

    def tp_getattro(name: str) -> ReflObj {
        if name in self.attrs {
            return self.attrs[name];
        }
        return refl_class_lookup_attr(self.cls, name);
    }
}

def refl_user_val(o: ReflObj) -> int {
    if isinstance(o, ReflUserObj) {
        return refl_expect_int((o as ReflUserObj).tp_getattro("val"));
    }
    return refl_expect_int(o);
}

def refl_class_mro(cls: ReflClass) -> list[ReflClass] {
    result: list[ReflClass] = [cls];
    for base in cls.bases {
        if isinstance(base, ReflClass) {
            for klass in refl_class_mro(base as ReflClass) {
                result.append(klass);
            }
        }
    }
    return result;
}

def refl_class_lookup_attr(cls: ReflClass, name: str) -> ReflObj {
    for klass in refl_class_mro(cls) {
        if name in klass.attrs {
            return klass.attrs[name];
        }
    }
    return refl_typeerror();
}

def refl_binop(op_id: int, a: ReflObj, b: ReflObj) -> ReflObj {
    fname = refl_forward_name(op_id);
    rname = refl_reflected_name(op_id);

    if isinstance(a, ReflUserObj) and fname != "" {
        au = a as ReflUserObj;
        fm = refl_class_lookup_attr(au.cls, fname);
        if isinstance(fm, ReflMethod) {
            fmethod = fm as ReflMethod;
            res = fmethod.invoke(au, b);
            if not refl_is_notimpl(res) {
                return res;
            }
        }
    }

    if isinstance(b, ReflUserObj) and rname != "" {
        bu = b as ReflUserObj;
        rm = refl_class_lookup_attr(bu.cls, rname);
        if isinstance(rm, ReflMethod) {
            rmethod = rm as ReflMethod;
            res = rmethod.invoke(bu, a);
            if not refl_is_notimpl(res) {
                return res;
            }
        }
    }

    return refl_typeerror();
}

def refl_result_int(o: ReflObj) -> int {
    if refl_is_error(o) {
        return -1;
    }
    return refl_expect_int(o);
}

def refl_make_class(nm: str, bases: list[ReflObj]) -> ReflClass {
    a: dict[str, ReflObj] = {};
    return ReflClass(t="type", name=nm, attrs=a, bases=bases);
}

def refl_make_inst(c: ReflClass, v: int) -> ReflUserObj {
    a: dict[str, ReflObj] = {};
    boxed: ReflObj = ReflInt(t="int", val=v);
    a["val"] = boxed;
    return ReflUserObj(t="obj", cls=c, attrs=a);
}

def refl_run -> list[int] {
    no_bases: list[ReflObj] = [];

    punter_cls = refl_make_class("Punter", no_bases);
    m_dec_add: ReflObj = ReflDeclineMethod(t="decline");
    m_dec_mul: ReflObj = ReflDeclineMethod(t="decline");
    punter_cls.attrs["__add__"] = m_dec_add;
    punter_cls.attrs["__mul__"] = m_dec_mul;

    convbase_cls = refl_make_class("ConvBase", no_bases);
    m_radd: ReflObj = ReflRAddMethod(t="radd");
    convbase_cls.attrs["__radd__"] = m_radd;
    convmid_bases: list[ReflObj] = [convbase_cls];
    convmid_cls = refl_make_class("ConvMid", convmid_bases);
    convleaf_bases: list[ReflObj] = [convmid_cls];
    convleaf_cls = refl_make_class("ConvLeaf", convleaf_bases);

    mconv_cls = refl_make_class("MConv", no_bases);
    m_rmul: ReflObj = ReflRMulMethod(t="rmul");
    mconv_cls.attrs["__rmul__"] = m_rmul;

    adder_cls = refl_make_class("Adder", no_bases);
    m_fadd: ReflObj = ReflFwdAddMethod(t="fadd");
    adder_cls.attrs["__add__"] = m_fadd;

    deaf_cls = refl_make_class("Deaf", no_bases);
    m_rdec: ReflObj = ReflDeclineMethod(t="decline");
    deaf_cls.attrs["__radd__"] = m_rdec;

    a_punter = refl_make_inst(punter_cls, 5);
    b_leaf = refl_make_inst(convleaf_cls, 7);
    p_punter2 = refl_make_inst(punter_cls, 2);
    m_inst = refl_make_inst(mconv_cls, 6);
    f_adder = refl_make_inst(adder_cls, 8);
    p_punter3 = refl_make_inst(punter_cls, 3);
    d_deaf = refl_make_inst(deaf_cls, 4);

    op_ids: list[int] = [0, 1, 0, 0];
    lefts: list[ReflUserObj] = [a_punter, p_punter2, f_adder, p_punter3];
    rights: list[ReflUserObj] = [b_leaf, m_inst, b_leaf, d_deaf];

    observed: list[int] = [];
    total = 0;
    i = 0;
    while i < len(op_ids) {
        op = op_ids[i];
        lhs: ReflObj = lefts[i];
        rhs: ReflObj = rights[i];
        r = refl_result_int(refl_binop(op, lhs, rhs));
        observed.append(r);
        total = total + r;
        i = i + 1;
    }

    observed.append(total);
    return observed;
}

test "cliff: reflected-binop NotImplemented fallback (na reflected-op canary)" {
    # case1 Punter(5)+ConvLeaf(7): forward NI, reflected __radd__ WALKS to ConvBase
    # -> 1012. case2 __rmul__ -> 2012. case3 forward-first __add__ -> 15 (reflected
    # NOT consulted). case4 both NI -> TypeError -> -1. total=1012+2012+15-1=3038.
    r = refl_run();
    assert r[0] == 1012;
    assert r[1] == 2012;
    assert r[2] == 15;
    assert r[3] == -1;
    assert r[4] == 3038;
}

# --- cliff 10: exception matching as data. Core site: pyc_first.jac
# CHECK_EXC_MATCH / exception_matches (~3772) + class_mro (~3915): a raised
# instance's class is matched by walking its MRO against each except arm's class,
# arms tested in LEXICAL order so the FIRST arm whose class is the raised class OR a
# base of it wins (CPython first-match, NOT best/most-derived). na exceptions are
# lexically structured, so handler SELECTION is lifted to a DATA except-table whose
# winning handler_id is returned as an int. na landmine: except-match first-match
# over MRO (a best-match miscompile picks Mid over Base in scenario B).
obj ExcObj {
    has t: str;
}

obj ExcClass(ExcObj) {
    has name: str,
        cid: int,
        bases: list[ExcObj] = [];
}

obj ExcInstance(ExcObj) {
    has cls: ExcClass;
}

obj ExcArm(ExcObj) {
    has cls: ExcClass,
        handler_id: int;
}

def exc_mro(cls: ExcClass) -> list[ExcClass] {
    result: list[ExcClass] = [cls];
    for base in cls.bases {
        if isinstance(base, ExcClass) {
            for klass in exc_mro(base as ExcClass) {
                result.append(klass);
            }
        }
    }
    return result;
}

def exc_instance_of(inst: ExcInstance, target: ExcClass) -> bool {
    for klass in exc_mro(inst.cls) {
        if klass.cid == target.cid {
            return True;
        }
    }
    return False;
}

def exc_dispatch_raise(raised: ExcInstance, table: list[ExcArm]) -> int {
    for arm in table {
        if exc_instance_of(raised, arm.cls) {
            return arm.handler_id;
        }
    }
    return -1;
}

def exc_make_class(nm: str, id: int, bases: list[ExcObj]) -> ExcClass {
    return ExcClass(t="type", name=nm, cid=id, bases=bases);
}

def exc_make_inst(c: ExcClass) -> ExcInstance {
    return ExcInstance(t="obj", cls=c);
}

def exc_make_arm(c: ExcClass, hid: int) -> ExcArm {
    return ExcArm(t="arm", cls=c, handler_id=hid);
}

def exc_run -> int {
    no_bases: list[ExcObj] = [];
    base_cls = exc_make_class("Base", 1, no_bases);

    mid_bases: list[ExcObj] = [base_cls];
    mid_cls = exc_make_class("Mid", 2, mid_bases);

    leaf_bases: list[ExcObj] = [mid_cls];
    leaf_cls = exc_make_class("Leaf", 3, leaf_bases);

    sib_bases: list[ExcObj] = [base_cls];
    sib_cls = exc_make_class("Sib", 4, sib_bases);

    classes: list[ExcClass] = [];
    classes.append(base_cls);
    classes.append(mid_cls);
    classes.append(leaf_cls);
    classes.append(sib_cls);
    raise_idx: list[int] = [2, 2, 3, 2];

    # Scenario A -- BASE match: [Mid->20, Base->10], raise Leaf -> first arm 20.
    tblA: list[ExcArm] = [];
    tblA.append(exc_make_arm(mid_cls, 20));
    tblA.append(exc_make_arm(base_cls, 10));

    # Scenario B -- ARM-ORDER: [Base->10, Mid->20], raise Leaf -> broad Base 10.
    tblB: list[ExcArm] = [];
    tblB.append(exc_make_arm(base_cls, 10));
    tblB.append(exc_make_arm(mid_cls, 20));

    # Scenario C -- NO match: [Mid->20], raise Sib -> propagate -1.
    tblC: list[ExcArm] = [];
    tblC.append(exc_make_arm(mid_cls, 20));

    # Scenario D -- EXACT: [Leaf->30, Mid->20], raise Leaf -> 30.
    tblD: list[ExcArm] = [];
    tblD.append(exc_make_arm(leaf_cls, 30));
    tblD.append(exc_make_arm(mid_cls, 20));

    instA = exc_make_inst(classes[raise_idx[0]]);
    instB = exc_make_inst(classes[raise_idx[1]]);
    instC = exc_make_inst(classes[raise_idx[2]]);
    instD = exc_make_inst(classes[raise_idx[3]]);

    rA = exc_dispatch_raise(instA, tblA);
    rB = exc_dispatch_raise(instB, tblB);
    rC = exc_dispatch_raise(instC, tblC);
    rD = exc_dispatch_raise(instD, tblD);

    if rA != 20 {
        return -10;
    }
    if rB != 10 {
        return -20;
    }
    if rC != -1 {
        return -30;
    }
    if rD != 30 {
        return -40;
    }

    no_match_flag = 0;
    if rC == -1 {
        no_match_flag = 1;
    }
    # 20_10_1_30 -> 20*1000000 + 10*10000 + 1*100 + 30 = 20100130.
    return rA * 1000000 + rB * 10000 + no_match_flag * 100 + rD;
}

test "cliff: except-match first-match over MRO (na except-match canary)" {
    # base match (20), broad-before-specific first-match (10 not 20), no-match
    # propagate (-1 flagged 1), exact (30). Encoded 20_10_1_30 -> 20100130.
    assert exc_run() == 20100130;
}
