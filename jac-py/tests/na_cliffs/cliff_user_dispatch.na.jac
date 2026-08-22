# na cliff: data-driven dict-lookup method/attr dispatch over an MRO -- the exact
# shape jac-py's `obj PyUserObj(PyObj)` uses in pyc_first.jac tp_getattro:
#   if name in self.attrs { return self.attrs[name]; }  # instance dict wins
#   classattr = class_lookup_attr(self.cls, name);      # else walk class_mro
#   isinstance(classattr, PyProperty) -> narrow -> descriptor_get(...)
#
# There are NO function values and NO fn-pointer table (na resolves every call
# statically). Behavior is carried by DATA: which PyMethod object sits in a
# `dict[str, PyObj]` decides the result. The only call is a resolved virtual
# dispatch on the PyMethod base (a real na vtable, like PyObj.tp_hashkey in the
# leaf), reached only after isinstance/as narrowing of the union the dict
# lookup returns.
#
# Uncheatable properties (an easy compile proves nothing):
#  * keys are RUNTIME-iterated from a data list, never string literals;
#  * two classes bind the same name "act" to DIFFERENT PyMethod subtypes, and
#    dispatch runs over a HETEROGENEOUS list of instances in a loop, so na
#    cannot monomorphize the receiver and devirtualize;
#  * the MRO genuinely WALKS: "other" is defined only on the base and reached
#    two levels down, and Mid's "act" SHADOWS Base's "act";
#  * every invoke result flows into an accumulator that the final assert reads;
#  * THE KILLER -- after the first dispatch the instance attrs dict is MUTATED
#    at runtime and the SAME call site re-dispatches, asserting a different
#    result (defeats any lookup-caching / devirtualization).
# Memory: jac-py-metaclass-descriptors, na-method-call-on-union-receiver.

# ---- minimal PyObj core (self-contained; no `import from`) ----
obj PyObj {
    has t: str;
}

obj PyInt(PyObj) {
    has val: int;
}

# A method is DATA. The base declares the virtual slot; subtypes carry their
# operand and override `invoke`. `invoke` reads the receiver's boxed value out
# of the instance dict (another runtime lookup) and computes -- no branching on
# the lookup KEY, so this is a real method body, not a switch in dict costume.
obj PyMethod(PyObj) {
    def invoke(receiver: PyUserObj) -> PyObj {
        return py_error("TypeError", "not callable");
    }
}

obj PyAddMethod(PyMethod) {
    has delta: int;

    def invoke(receiver: PyUserObj) -> PyObj {
        base = expect_int(receiver.tp_getattro("val"));
        return PyInt(t="int", val=base + self.delta);
    }
}

obj PyMulMethod(PyMethod) {
    has factor: int;

    def invoke(receiver: PyUserObj) -> PyObj {
        base = expect_int(receiver.tp_getattro("val"));
        return PyInt(t="int", val=base * self.factor);
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
        # instance dict wins over the class MRO (PyUserObj order)
        if name in self.attrs {
            return self.attrs[name];
        }
        return class_lookup_attr(self.cls, name);
    }
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

def class_lookup_attr(cls: PyClass, name: str) -> PyObj {
    for klass in class_mro(cls) {
        if name in klass.attrs {
            return klass.attrs[name];
        }
    }
    return py_error("AttributeError", name);
}

def expect_int(o: PyObj) -> int {
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    return 0;
}

def is_error(value: PyObj) -> bool {
    return value.t == "error";
}

def py_error(type_name: str, message: str) -> PyObj {
    return PyObj(t="error");
}

# ---- the ONE generic dispatch call site ----
# Look `name` up (instance dict then MRO), narrow the PyObj union to PyMethod,
# then invoke through the vtable. The receiver `m` is a T|None-shaped union in
# spirit: if the lookup missed or the value isn't a method we return a sentinel
# the caller's assert catches, rather than silently dropping the call (the
# documented na `T|None` receiver-drop landmine).
def dispatch(o: PyUserObj, name: str) -> int {
    m = o.tp_getattro(name);
    if is_error(m) {
        return -1;
    }
    if not isinstance(m, PyMethod) {
        return -2;
    }
    method = m as PyMethod;  # narrow the union before the call
    return expect_int(method.invoke(o));
}

def make_class(nm: str, bases: list[PyObj]) -> PyClass {
    a: dict[str, PyObj] = {};
    return PyClass(t="type", name=nm, attrs=a, bases=bases);
}

def make_inst(c: PyClass, v: int) -> PyUserObj {
    a: dict[str, PyObj] = {};
    boxed: PyObj = PyInt(t="int", val=v);
    a["val"] = boxed;
    return PyUserObj(t="obj", cls=c, attrs=a);
}

def run -> int {
    # Three-level MRO: Base <- Mid <- Leaf.
    no_bases: list[PyObj] = [];
    base_cls = make_class("Base", no_bases);
    # Base defines both "act" (add 100) and "other" (add 1).
    m_add: PyObj = PyAddMethod(t="add", delta=100);
    m_other: PyObj = PyAddMethod(t="add", delta=1);
    base_cls.attrs["act"] = m_add;
    base_cls.attrs["other"] = m_other;

    mid_bases: list[PyObj] = [base_cls];
    mid_cls = make_class("Mid", mid_bases);
    # Mid SHADOWS "act" with a different behavior (multiply by 3); it does NOT
    # define "other", so an "other" lookup from a Leaf instance must WALK two
    # levels (Leaf -> Mid -> Base).
    m_mul: PyObj = PyMulMethod(t="mul", factor=3);
    mid_cls.attrs["act"] = m_mul;

    leaf_bases: list[PyObj] = [mid_cls];
    leaf_cls = make_class("Leaf", leaf_bases);

    # Heterogeneous instances: one Leaf, one Base -- same call site sees
    # different runtime types AND different resolved methods.
    insts: list[PyUserObj] = [];
    leaf_inst = make_inst(leaf_cls, 5);  # act -> Mid.mul3 => 15 ; other -> Base.add1 => 6
    base_inst = make_inst(base_cls, 7);  # act -> Base.add100 => 107 ; other -> Base.add1 => 8
    insts.append(leaf_inst);
    insts.append(base_inst);

    # Keys are iterated from DATA at runtime, never literal at the call site.
    names: list[str] = ["act", "other"];

    total = 0;
    for inst in insts {
        for nm in names {
            r = dispatch(inst, nm);
            if r < 0 {
                return r;  # a dropped/failed call would surface here
            }
            total = total + r;
        }
    }
    # 15 + 6 + 107 + 8 = 136
    if total != 136 {
        return -100;
    }

    # THE KILLER: mutate the Leaf instance's own dict at runtime so "act" now
    # hits the INSTANCE dict (add 1000) instead of walking to Mid, then
    # re-dispatch from the SAME call site. 5 + 1000 = 1005, not 15.
    `override: PyObj = PyAddMethod(t="add", delta=1000);
    leaf_inst.attrs["act"] = `override;
    again = dispatch(leaf_inst, names[0]);
    if again != 1005 {
        return -200;
    }

    return total + again;  # 136 + 1005 = 1141
}

with entry {
    print(run());
}
