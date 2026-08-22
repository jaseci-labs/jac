# na cliff: Python's REFLECTED binary-operator dispatch over user classes -- the
# exact nb_binop protocol jac-py's `user_binop` in pyc_first.jac (~3165) runs:
#   a <op> b  =>  try type(a).__op__(a, b)   (forward, MRO-resolved)
#                 if it returns NotImplemented, try type(b).__rop__(b, a)  (reflected)
#                 if BOTH NotImplemented -> TypeError.
#
# There are NO function values and NO fn-pointer table (na resolves every call
# statically). A dunder is DATA: which PyMethod object sits in a class
# `dict[str, PyObj]`, keyed by an op-id-derived name, decides behavior. The only
# call is a resolved virtual dispatch on the PyMethod base (a real na vtable),
# reached only after isinstance/as narrowing of the union the dict lookup returns
# (the documented na `T|None` receiver-drop landmine -- narrow before calling).
#
# NotImplemented is an EXPLICIT sentinel PyObj (t == "notimpl"), never a null:
# the whole point of the reflected protocol is distinguishing "the forward slot
# declined" from "the forward slot produced a value". TypeError is another
# sentinel (t == "error").
#
# Uncheatable properties (a naive forward-only dispatch gets these WRONG):
#  * op_id and operands are RUNTIME-iterated from parallel data lists;
#  * case 1/2: the LEFT operand's forward dunder returns NotImplemented and only
#    the RIGHT operand's REFLECTED dunder supplies the answer -- the fixture
#    asserts the REFLECTED path's marker value (a.val+b.val+1000 / *+2000), which
#    a forward-only machine could NEVER produce (it would fall to TypeError);
#  * the reflected dunder is defined on a BASE class and the right operand is a
#    Leaf two levels down, so the reflected lookup genuinely WALKS the MRO;
#  * case 3 proves ORDERING: a working forward __add__ is tried FIRST and the
#    reflected slot is NOT consulted (asserts the forward value, not the +1000);
#  * case 4: BOTH slots return NotImplemented -> TypeError sentinel asserted;
#  * every observed result flows into an accumulator the final assert reads.
# Memory: na-method-call-on-union-receiver, na-dict-literal-subclass-upcast-ice.

# ---- minimal PyObj core (self-contained; no `import from`) ----
obj PyObj {
    has t: str;
}

obj PyInt(PyObj) {
    has val: int;
}

# ---- sentinels: NotImplemented and TypeError are DISTINCT tagged singletons ----
def py_notimpl -> PyObj {
    return PyObj(t="notimpl");
}

def py_typeerror -> PyObj {
    return PyObj(t="error");
}

def is_notimpl(o: PyObj) -> bool {
    return o.t == "notimpl";
}

def is_error(o: PyObj) -> bool {
    return o.t == "error";
}

def expect_int(o: PyObj) -> int {
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    return 0;
}

# ---- op_id -> dunder name, forward and reflected (data-driven, bounds-checked) --
def forward_name(op_id: int) -> str {
    names = ["__add__", "__mul__"];
    if op_id >= 0 and op_id < len(names) {
        return names[op_id];
    }
    return "";
}

def reflected_name(op_id: int) -> str {
    names = ["__radd__", "__rmul__"];
    if op_id >= 0 and op_id < len(names) {
        return names[op_id];
    }
    return "";
}

# ---- a dunder is DATA: PyMethod base declares the virtual slot; subtypes carry
# the operator behavior and override `invoke`. `invoke(recv, other)` reads both
# operands' boxed ints out of their instance dicts (more runtime lookups) and
# computes -- no branching on the dunder KEY, so this is a real method body. ----
obj PyMethod(PyObj) {
    def invoke(recv: PyUserObj, other: PyObj) -> PyObj {
        return py_typeerror();
    }
}

# A dunder that DECLINES: returns the NotImplemented sentinel (models e.g. a
# __add__ that doesn't know how to handle the right operand's type).
obj PyDeclineMethod(PyMethod) {
    def invoke(recv: PyUserObj, other: PyObj) -> PyObj {
        return py_notimpl();
    }
}

# Reflected __radd__: recv is the RIGHT operand, other is the LEFT. The +1000
# marker makes the reflected path's value unforgeable by a forward-only machine.
obj PyRAddMethod(PyMethod) {
    def invoke(recv: PyUserObj, other: PyObj) -> PyObj {
        return PyInt(t="int", val=user_val(recv) + user_val(other) + 1000);
    }
}

# Reflected __rmul__: distinct +2000 marker.
obj PyRMulMethod(PyMethod) {
    def invoke(recv: PyUserObj, other: PyObj) -> PyObj {
        return PyInt(t="int", val=user_val(recv) * user_val(other) + 2000);
    }
}

# A WORKING forward __add__ (no marker) -- used to prove forward-first ordering.
obj PyFwdAddMethod(PyMethod) {
    def invoke(recv: PyUserObj, other: PyObj) -> PyObj {
        return PyInt(t="int", val=user_val(recv) + user_val(other));
    }
}

obj PyClass(PyObj) {
    has name: str,
        attrs: dict[str, PyObj],
        bases: list[PyObj] = [];
}

obj PyUserObj(PyObj) {
    has cls: PyClass,
        attrs: dict[str, PyObj];

    def tp_getattro(name: str) -> PyObj {
        if name in self.attrs {
            return self.attrs[name];
        }
        return class_lookup_attr(self.cls, name);
    }
}

# read the boxed int of a user operand (instance dict "val"), or of a raw PyInt.
def user_val(o: PyObj) -> int {
    if isinstance(o, PyUserObj) {
        return expect_int((o as PyUserObj).tp_getattro("val"));
    }
    return expect_int(o);
}

# ---- MRO helpers (recursive linearization + dict walk) ----
def class_mro(cls: PyClass) -> list[PyClass] {
    result: list[PyClass] = [cls];
    for base in cls.bases {
        if isinstance(base, PyClass) {
            for klass in class_mro(base as PyClass) {
                result.append(klass);
            }
        }
    }
    return result;
}

# returns the error sentinel on miss (isinstance(_, PyMethod) is then False).
def class_lookup_attr(cls: PyClass, name: str) -> PyObj {
    for klass in class_mro(cls) {
        if name in klass.attrs {
            return klass.attrs[name];
        }
    }
    return py_typeerror();
}

# does type(u) resolve a callable dunder `name` anywhere on its MRO?
def user_has_dunder(u: PyUserObj, name: str) -> bool {
    m = class_lookup_attr(u.cls, name);
    return isinstance(m, PyMethod);
}

# ---- THE reflected binary-operator protocol (the ONE generic call surface) ----
# forward on type(a), then -- only on NotImplemented -- reflected on type(b),
# then TypeError. Every dict lookup returns a PyObj union that MUST be narrowed
# via isinstance/as before the vtable invoke, or na silently drops the call.
def binop(op_id: int, a: PyObj, b: PyObj) -> PyObj {
    fname = forward_name(op_id);
    rname = reflected_name(op_id);

    # (1) forward: type(a).__op__(a, b)
    if isinstance(a, PyUserObj) and fname != "" {
        au = a as PyUserObj;
        fm = class_lookup_attr(au.cls, fname);
        if isinstance(fm, PyMethod) {
            fmethod = fm as PyMethod;  # narrow union before call
            res = fmethod.invoke(au, b);
            if not is_notimpl(res) {
                return res;  # value OR raised error: done
            }
        }
    }

    # (2) reflected: type(b).__rop__(b, a) -- fires ONLY after forward declined
    if isinstance(b, PyUserObj) and rname != "" {
        bu = b as PyUserObj;
        rm = class_lookup_attr(bu.cls, rname);
        if isinstance(rm, PyMethod) {
            rmethod = rm as PyMethod;  # narrow union before call
            res = rmethod.invoke(bu, a);
            if not is_notimpl(res) {
                return res;
            }
        }
    }

    # (3) both declined
    return py_typeerror();
}

# observed result -> int for the accumulator; TypeError sentinel -> -1.
def result_int(o: PyObj) -> int {
    if is_error(o) {
        return -1;
    }
    return expect_int(o);
}

def make_class(nm: str, bases: list[PyObj]) -> PyClass {
    a: dict[str, PyObj] = {};
    return PyClass(t="type", name=nm, attrs=a, bases=bases);
}

def make_inst(c: PyClass, v: int) -> PyUserObj {
    a: dict[str, PyObj] = {};
    boxed: PyObj = PyInt(t="int", val=v);
    a["val"] = boxed;  # subscript-store, base-typed
    return PyUserObj(t="obj", cls=c, attrs=a);
}

# returns [observed case results..., accumulated total].
def run -> list[int] {
    no_bases: list[PyObj] = [];

    # -- Punter: forward __add__ and __mul__ both DECLINE (NotImplemented). --
    punter_cls = make_class("Punter", no_bases);
    m_dec_add: PyObj = PyDeclineMethod(t="decline");
    m_dec_mul: PyObj = PyDeclineMethod(t="decline");
    punter_cls.attrs["__add__"] = m_dec_add;  # base-typed subscript-store
    punter_cls.attrs["__mul__"] = m_dec_mul;

    # -- Converter MRO: ConvBase <- ConvMid <- ConvLeaf. __radd__ lives on the
    #    BASE, so a ConvLeaf right-operand reaches it only by WALKING two levels. --
    convbase_cls = make_class("ConvBase", no_bases);
    m_radd: PyObj = PyRAddMethod(t="radd");
    convbase_cls.attrs["__radd__"] = m_radd;
    convmid_bases: list[PyObj] = [convbase_cls];
    convmid_cls = make_class("ConvMid", convmid_bases);  # defines nothing
    convleaf_bases: list[PyObj] = [convmid_cls];
    convleaf_cls = make_class("ConvLeaf", convleaf_bases);

    # -- MConv: reflected __rmul__ only. --
    mconv_cls = make_class("MConv", no_bases);
    m_rmul: PyObj = PyRMulMethod(t="rmul");
    mconv_cls.attrs["__rmul__"] = m_rmul;

    # -- Adder: a WORKING forward __add__ (no marker). --
    adder_cls = make_class("Adder", no_bases);
    m_fadd: PyObj = PyFwdAddMethod(t="fadd");
    adder_cls.attrs["__add__"] = m_fadd;

    # -- Deaf: reflected __radd__ that ALSO declines -> both-NI -> TypeError. --
    deaf_cls = make_class("Deaf", no_bases);
    m_rdec: PyObj = PyDeclineMethod(t="decline");
    deaf_cls.attrs["__radd__"] = m_rdec;

    # Heterogeneous operands + runtime op_ids in PARALLEL DATA lists.
    a_punter = make_inst(punter_cls, 5);
    b_leaf = make_inst(convleaf_cls, 7);
    p_punter2 = make_inst(punter_cls, 2);
    m_inst = make_inst(mconv_cls, 6);
    f_adder = make_inst(adder_cls, 8);
    p_punter3 = make_inst(punter_cls, 3);
    d_deaf = make_inst(deaf_cls, 4);

    op_ids: list[int] = [0, 1, 0, 0];  # __add__, __mul__, __add__, __add__
    lefts: list[PyUserObj] = [a_punter, p_punter2, f_adder, p_punter3];
    rights: list[PyUserObj] = [b_leaf, m_inst, b_leaf, d_deaf];

    observed: list[int] = [];
    total = 0;
    i = 0;
    while i < len(op_ids) {
        op = op_ids[i];  # op_id read from data at runtime
        lhs: PyObj = lefts[i];
        rhs: PyObj = rights[i];
        r = result_int(binop(op, lhs, rhs));
        observed.append(r);
        total = total + r;
        i = i + 1;
    }

    observed.append(total);
    return observed;
}

with entry {
    r = run();
    # r = [case1, case2, case3, case4, total]
    # case1: Punter(5) __add__ b -> NotImplemented; ConvLeaf(7).__radd__ WALKS
    #        two MRO levels to ConvBase -> 7+5+1000 = 1012  (REFLECTED fired;
    #        forward-only would yield TypeError). ANTI-CHEAT: assert the marker.
    if r[0] != 1012 {
        print(-1);
    } elif r[1] != 2012 {
        # case2: Punter(2) __mul__ MConv(6) -> NI; __rmul__ -> 6*2+2000 = 2012.
        print(-2);
    } elif r[2] != 15 {
        # case3: Adder(8).__add__(b=7) WORKS -> 15, tried FIRST; reflected NOT
        #        consulted (else 7+8+1000 = 1015). Proves forward-first ordering.
        print(-3);
    } elif r[3] != -1 {
        # case4: Punter(3) + Deaf(4): forward NI, reflected __radd__ NI -> both
        #        declined -> TypeError sentinel -> -1.
        print(-4);
    } elif r[4] != 3038 {
        # total = 1012 + 2012 + 15 + (-1) = 3038.
        print(-5);
    } else {
        print(r[4]);
    }
}
