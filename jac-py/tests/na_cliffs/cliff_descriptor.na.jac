# na cliff: the FULL attribute-precedence protocol -- the real shape jac-py's
# `obj PyUserObj` uses in pyc_first.jac tp_getattro (~line 1526) once descriptors
# enter the picture. cliff_user_dispatch proves the plain MRO walk; THIS cliff
# proves the part CPython actually runs on every method bind and every property:
#
#   (1) a DATA-descriptor in the type (has __get__ AND __set__) PREEMPTS the
#       instance dict -- `o.v` runs the getter even when o.__dict__["v"] exists;
#   (2) otherwise the instance dict wins;
#   (3) otherwise a NON-data descriptor / plain class attr, resolved by MRO walk;
#   (4) __getattr__ fires ONLY on a total miss, returning a sentinel.
#
# This is descriptor_get + tp_getattro's precedence, modeled data-only. There are
# NO function values and NO fn-pointer table (na resolves every call statically).
# A descriptor carries a KIND tag (an integer method-id); its "__get__" is a
# switch on that id inside a real na method body (like PyObj.tp_hashkey in the
# leaf), reached only after isinstance/as narrowing of the PyObj union the dict
# lookup returns -- never a call on an un-narrowed T|None receiver.
#
# Uncheatable properties (an easy compile proves nothing):
#  * attribute names are RUNTIME-iterated from a data list, never string literals
#    at the resolve site;
#  * the data-descriptor GENUINELY preempts a same-named instance-dict entry --
#    the instance dict holds "temp"=999 yet the getter's 105 is what surfaces
#    (assert 105, not 999);
#  * __get__ reads the instance's OWN raw slot at runtime and computes from it,
#    so it is a real descriptor body, not a constant in descriptor costume;
#  * THE KILLER -- after phase A the instance dict is MUTATED so the NON-data name
#    "scaled" now has an instance-dict entry (777); the same resolve site must now
#    return 777 (instance beats non-data descriptor) while "temp" STILL returns
#    105 (data descriptor still beats the instance dict). One mutation, two
#    opposite precedence outcomes -- defeats any "descriptor always/never wins"
#    shortcut and any lookup caching;
#  * __getattr__ fires only for "ghost" (absent from instance dict AND every class
#    in the MRO) and its sentinel is data-derived (base + len(name)).
# Memory: jac-py-metaclass-descriptors, na-method-call-on-union-receiver,
# na-dict-literal-subclass-upcast-ice.

# ---- minimal PyObj core (self-contained; no `import from`) ----
obj PDObj {
    has t: str;
}

obj PDInt(PDObj) {
    has val: int;
}

# A descriptor is DATA. `kind` is a method-id switched inside __get__; `has_set`
# marks it a DATA descriptor (a real property has fset) vs a non-data descriptor
# (a plain function / method has only __get__). `operand` is the getter's data.
# __get__ reads the receiver's own raw slot (a runtime lookup on the instance)
# and computes -- no branching on the attribute KEY, so this is a genuine
# descriptor body, not a switch wearing a descriptor mask.
obj PDDescriptor(PDObj) {
    has kind: int,
        operand: int,
        has_set: bool;

    # A data descriptor (__set__ present) outranks the instance dict.
    def is_data -> bool {
        return self.has_set;
    }

    # The descriptor protocol's __get__, dispatched by method-id (no fn values).
    def dunder_get(instance: PDUserObj) -> PDObj {
        base = pd_expect_int(instance.raw_slot());
        if self.kind == 1 {
            # data-descriptor getter: raw + operand (a computed property)
            return PDInt(t="int", val=base + self.operand);
        }
        if self.kind == 2 {
            # non-data-descriptor getter: raw * operand
            return PDInt(t="int", val=base * self.operand);
        }
        return PDObj(t="error");
    }
}

# The __getattr__ hook: fired only on a total miss. Its result is data-derived
# from the requested name so it cannot be a folded constant.
obj PDGetAttr(PDObj) {
    has sentinel: int;

    def fire(name: str) -> PDObj {
        return PDInt(t="int", val=self.sentinel + len(name));
    }
}

obj PDClass(PDObj) {
    has name: str,
        attrs: dict[str, PDObj],
        bases: list[PDObj] = [];
}

obj PDUserObj(PDObj) {
    has cls: PDClass,
        attrs: dict[str, PDObj],
        raw: int;

    # The instance's own underlying value, boxed -- what a descriptor's __get__
    # reads (another runtime lookup, on the instance itself).
    def raw_slot -> PDObj {
        return PDInt(t="int", val=self.raw);
    }
}

# ---- MRO helpers (recursive linearization + dict walk) ----
def pd_mro(cls: PDClass) -> list[PDClass] {
    result: list[PDClass] = [cls];
    for base in cls.bases {
        if isinstance(base, PDClass) {
            for klass in pd_mro(base as PDClass) {
                result.append(klass);
            }
        }
    }
    return result;
}

def pd_lookup(cls: PDClass, name: str) -> PDObj {
    for klass in pd_mro(cls) {
        if name in klass.attrs {
            return klass.attrs[name];
        }
    }
    return PDObj(t="error");
}

def pd_expect_int(o: PDObj) -> int {
    if isinstance(o, PDInt) {
        return (o as PDInt).val;
    }
    return 0;
}

def is_error(value: PDObj) -> bool {
    return value.t == "error";
}

# ---- the ONE generic attribute-resolution site: the full precedence chain ----
# Mirrors PyUserObj.tp_getattro: data-descriptor > instance dict > non-data
# descriptor / plain class attr (MRO) > __getattr__ hook. Every branch narrows
# the PyObj union via isinstance/as before any method call.
def resolve_attr(o: PDUserObj, name: str) -> PDObj {
    classattr = pd_lookup(o.cls, name);

    # (1) DATA descriptor in the type preempts the instance dict.
    if isinstance(classattr, PDDescriptor) {
        d = classattr as PDDescriptor;  # narrow before the call
        if d.is_data() {
            return d.dunder_get(o);
        }
    }

    # (2) instance dict.
    if name in o.attrs {
        return o.attrs[name];
    }

    # (3) non-data descriptor / plain class attr via the MRO walk.
    if not is_error(classattr) {
        if isinstance(classattr, PDDescriptor) {
            nd = classattr as PDDescriptor;  # narrow before the call
            return nd.dunder_get(o);
        }
        return classattr;
    }

    # (4) total miss -> __getattr__ hook (only here, never otherwise).
    hook = pd_lookup(o.cls, "__getattr__");
    if isinstance(hook, PDGetAttr) {
        g = hook as PDGetAttr;  # narrow before the call
        return g.fire(name);
    }

    return PDObj(t="error");
}

# Resolve `name` and reduce to an int the accumulator can check; a dropped or
# mis-resolved call surfaces as a negative sentinel the caller's assert catches.
def resolve_int(o: PDUserObj, name: str) -> int {
    v = resolve_attr(o, name);
    if is_error(v) {
        return -1;
    }
    if not isinstance(v, PDInt) {
        return -2;
    }
    return (v as PDInt).val;
}

def make_class(nm: str, bases: list[PDObj]) -> PDClass {
    a: dict[str, PDObj] = {};
    return PDClass(t="type", name=nm, attrs=a, bases=bases);
}

def make_inst(c: PDClass, v: int) -> PDUserObj {
    a: dict[str, PDObj] = {};
    return PDUserObj(t="obj", cls=c, attrs=a, raw=v);
}

# Returns [phaseA_total, killer_scaled, killer_temp].
#   Base defines: data-descr "temp" (raw+100), non-data-descr "scaled" (raw*3),
#   and a "__getattr__" hook (sentinel 1000). MRO: Base <- Mid <- Leaf, both Mid
#   and Leaf empty, so every name walks two levels down.
def run_pd -> list[int] {
    no_bases: list[PDObj] = [];
    base_cls = make_class("Base", no_bases);

    # Build subclass values through PDObj-typed locals before subscript-store
    # (dict-literal subclass upcast ICEs na; store empty + subscript, base-typed).
    d_temp: PDObj = PDDescriptor(t="descr", kind=1, operand=100, has_set=True);
    d_scaled: PDObj = PDDescriptor(t="descr", kind=2, operand=3, has_set=False);
    hook: PDObj = PDGetAttr(t="getattr", sentinel=1000);
    base_cls.attrs["temp"] = d_temp;
    base_cls.attrs["scaled"] = d_scaled;
    base_cls.attrs["__getattr__"] = hook;

    mid_bases: list[PDObj] = [base_cls];
    mid_cls = make_class("Mid", mid_bases);

    leaf_bases: list[PDObj] = [mid_cls];
    leaf_cls = make_class("Leaf", leaf_bases);

    # Leaf instance, raw slot = 5. Seed the instance dict with a SAME-NAMED
    # "temp"=999: the data descriptor must preempt it (105, not 999).
    inst = make_inst(leaf_cls, 5);
    shadow: PDObj = PDInt(t="int", val=999);
    inst.attrs["temp"] = shadow;

    # Names iterated from DATA at runtime, never literal at the resolve site.
    names: list[str] = ["temp", "scaled", "ghost"];
    phase_a = 0;
    for nm in names {
        phase_a = phase_a + resolve_int(inst, nm);
    }
    # temp   -> data descriptor preempts instance-dict 999: 5 + 100      = 105
    # scaled -> non-data descriptor, no instance entry:     5 * 3        =  15
    # ghost  -> total miss -> __getattr__ hook:           1000 + len(5)  = 1005
    #                                                        phase_a      = 1125

    # THE KILLER: one mutation, two opposite precedence outcomes.
    # Give "scaled" (a NON-data name) an instance-dict entry -> instance now wins.
    # "temp" (a DATA name) already has an instance-dict entry (999) yet the data
    # descriptor STILL wins. Same resolve site, opposite rulings.
    `override: PDObj = PDInt(t="int", val=777);
    inst.attrs["scaled"] = `override;
    killer_scaled = resolve_int(inst, names[1]);  # 777 (instance beats non-data)
    killer_temp = resolve_int(inst, names[0]);  # 105 (data descr beats dict)

    result: list[int] = [phase_a, killer_scaled, killer_temp];
    return result;
}

# Encode the three observed outcomes into one checkable total:
#   1125 * 1000000 + 777 * 1000 + 105 = 1125777105
def run -> int {
    r = run_pd();
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

with entry {
    print(run());
}
