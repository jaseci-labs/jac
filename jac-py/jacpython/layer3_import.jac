# Layer 3 harness (jac-py/PLAN.md Layer 3 -- "real unittest boots un-proxied").
#
# The milestone that proves the interpreter is real: instead of proxying the
# import closure to the host (Layer 2's shim, or PyHostProxy), jacpython runs the
# ACTUAL CPython source of each pure-Python module as bytecode inside its own
# ceval. `import_native` (pyc_first.jac) recurses through IMPORT_NAME, pulling the
# whole dependency closure in-VM; only C-extension / built-in / frozen modules
# (no .py source) stay host-proxied. When real `unittest` boots this way and runs
# a real test file end to end, Layer 3 is met.
#
# This file drives that bottom-up: leaf modules first (proving the mechanism),
# climbing toward the unittest closure, fixing each ceval/object gap it surfaces.
import from pyc_first {
    PyObj,
    PyModule,
    PyStr,
    PyInt,
    import_native,
    set_layer3_active,
    clear_sys3_modules,
    py_attr,
    to_host,
    is_error,
    py_invoke,
    exec_code,
    unmarshal,
    host_compile_marshal
}
import from objects { PyError }

# Import a module natively (proxy-free where source exists) and return it.
def layer3_import(name: str) -> PyObj {
    set_layer3_active(True);
    return import_native(name);
}

def layer3_reset {
    clear_sys3_modules();
    set_layer3_active(True);
}

# Import a module and return "" on success or "Type: message" on the first error
# encountered anywhere in its closure. Used to burn down the unittest closure.
def layer3_probe(name: str) -> str {
    layer3_reset();
    mod = import_native(name);
    if is_error(mod) {
        exc = (mod as PyError).exception;
        return exc.type_name + ": " + exc.message;
    }
    if not isinstance(mod, PyModule) {
        return "not-native: got a proxy for " + name;
    }
    return "";
}

# ---------------- tests ----------------

test "layer3: a caught builtin exception has real str/repr/type/args" {
    # Exceptions were value-structs whose to_host was None, so str(e) printed
    # "None", type(e) was NoneType, and e.args failed. A caught exception must
    # present as a real host exception: str(e)==message, type(e).__name__ matches,
    # e.args is the constructor tuple.
    layer3_reset();
    src = "def f():\n"
    "    try:\n"
    "        raise ValueError('boom', 42)\n"
    "    except ValueError as e:\n"
    "        return (str(e), type(e).__name__, e.args, repr(e))\n"
    "s, tn, a, r = f()\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["s"]) == "('boom', 42)";
    assert to_host(g["tn"]) == "ValueError";
    assert to_host(g["a"]) == ("boom", 42);
    assert to_host(g["r"]) == "ValueError('boom', 42)";
}

test "layer3: type(instance) is the class and Cls.__name__ is the class name" {
    # Two identity bugs: Cls.__name__ read the leaked module-name seed ("__main__")
    # from the class body namespace, and type(instance) went through host
    # type(to_host(x))=type(None)=NoneType because a plain user object has no host
    # form. type(self) is pervasive (repr, ==, dispatch) so both must be right.
    layer3_reset();
    src = "class Widget:\n"
    "    def kind(self):\n"
    "        return type(self).__name__\n"
    "w = Widget()\n"
    "cn = Widget.__name__\n"
    "tn = type(w).__name__\n"
    "same = type(w) is Widget\n"
    "km = w.kind()\n"
    "it = type(5).__name__\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["cn"]) == "Widget";
    assert to_host(g["tn"]) == "Widget";
    assert to_host(g["same"]) == True;
    assert to_host(g["km"]) == "Widget";
    assert to_host(g["it"]) == "int";
}

test "layer3: single-arg exception str is the message; args is a 1-tuple" {
    layer3_reset();
    src = "def f():\n"
    "    try:\n"
    "        raise KeyError('missing')\n"
    "    except Exception as e:\n"
    "        return (str(e), e.args, type(e).__name__)\n"
    "s, a, tn = f()\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    # KeyError.str quotes its key (CPython special-case); args is the raw tuple.
    assert to_host(g["s"]) == "'missing'";
    assert to_host(g["a"]) == ("missing", );
    assert to_host(g["tn"]) == "KeyError";
}

test "layer3: a builtin subclass with a custom __new__ controls its boxed value" {
    # re._constants._NamedIntConstant(int) pattern: __new__(cls, value, name)
    # boxes only `value` through super().__new__(cls, value) and stashes name.
    # PyClass.tp_call must honor the user __new__ (not auto-box all args), and
    # super().__new__ on a builtin base must produce a tagged PyUserObj.
    layer3_reset();
    src = "class NIC(int):\n"
    "    def __new__(cls, value, name):\n"
    "        self = super(NIC, cls).__new__(cls, value)\n"
    "        self.name = name\n"
    "        return self\n"
    "x = NIC(42, 'ANSWER')\n"
    "asint = int(x)\n"
    "nm = x.name\n"
    "summed = x + 8\n"
    "isint = isinstance(x, int)\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["asint"]) == 42;
    assert to_host(g["nm"]) == "ANSWER";
    assert to_host(g["summed"]) == 50;
    assert to_host(g["isint"]) == True;
}

test "layer3: object.__new__/super().__new__ build plain instances (singleton __new__)" {
    # functools._PlaceholderType pattern: __new__ caches a single instance via
    # object.__new__(cls). object.__new__ must yield an in-VM PyUserObj.
    layer3_reset();
    src = "class Singleton:\n"
    "    _inst = None\n"
    "    def __new__(cls):\n"
    "        if cls._inst is None:\n"
    "            cls._inst = object.__new__(cls)\n"
    "        return cls._inst\n"
    "a = Singleton()\n"
    "b = Singleton()\n"
    "same = a is b\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["same"]) == True;
}

test "layer3: a builtin-int subclass indexes a list, and slice-deletion works" {
    layer3_reset();
    src = "class NI(int):\n"
    "    pass\n"
    "xs = [10, 20, 30, 40, 50]\n"
    "at = xs[NI(2)]\n"
    "del xs[-2:]\n"
    "kept = list(xs)\n"
    "atbool = xs[True]\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["at"]) == 30;
    assert to_host(g["kept"]) == [10, 20, 30];
    assert to_host(g["atbool"]) == 20;
}

test "layer3: globals() is a live view -- update binds module names" {
    # re._constants._makecodes does globals().update({...}); the names must become
    # real module globals a later LOAD_GLOBAL resolves.
    layer3_reset();
    src = "def install():\n"
    "    globals().update({'INJECTED': 7, 'OTHER': 9})\n"
    "install()\n"
    "total = INJECTED + OTHER\n"
    "names = sorted(n for n in globals() if not n.startswith('_'))\n"
    "got = globals().get('INJECTED', 0)\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["total"]) == 16;
    assert to_host(g["got"]) == 7;
    assert "INJECTED" in to_host(g["names"]);
}

test "layer3: a leaf pure-Python module (keyword) boots in-VM proxy-free" {
    layer3_reset();
    mod = layer3_import("keyword");
    assert not is_error(mod);
    # keyword is a native PyModule (ran in-VM), not a PyHostProxy.
    assert isinstance(mod, PyModule);
    # keyword.kwlist is the real list of Python keywords, built by its own code.
    kwlist = py_attr(mod, "kwlist");
    assert not is_error(kwlist);
    host_kwlist = to_host(kwlist);
    assert len(host_kwlist) > 30;
    assert "if" in host_kwlist;
    assert "class" in host_kwlist;
    # keyword.iskeyword('if') is True -- a real in-VM function call.
    iskeyword = py_attr(mod, "iskeyword");
    assert not is_error(iskeyword);
    yes = py_invoke(iskeyword, [PyStr(t="str", val="if")], {});
    assert to_host(yes) == True;
    no = py_invoke(iskeyword, [PyStr(t="str", val="banana")], {});
    assert to_host(no) == False;
}


test "layer3: a package (collections) and its transitive deps boot in-VM" {
    # collections is the deepest proxy-free boot in the closure: a package whose
    # __init__ subclasses builtins, builds closures (recursive_repr decorator),
    # and imports operator/reprlib/keyword -- each of which also runs in-VM. This
    # exercised the STORE_GLOBAL opcode, the merged-localsplus cell layout, native
    # getattr, and host-proxy identity. A native PyModule (not a proxy) proves it.
    layer3_reset();
    mod = import_native("collections");
    assert not is_error(mod);
    assert isinstance(mod, PyModule);
    attrs = (mod as PyModule).attrs;
    # Its own classes/functions are present, built by its own bytecode.
    assert "OrderedDict" in attrs;
    assert "defaultdict" in attrs;
    assert "namedtuple" in attrs;
    assert "deque" in attrs;
    # A transitively-imported pure-Python dependency is ALSO native, not proxied.
    op = import_native("operator");
    assert isinstance(op, PyModule);
    types_mod = import_native("types");
    assert isinstance(types_mod, PyModule);
    reprlib_mod = import_native("reprlib");
    assert isinstance(reprlib_mod, PyModule);
}

test "layer3: leaf modules across the unittest closure boot proxy-free" {
    # Each returns a native PyModule (ran its real CPython source in-VM), not a
    # host proxy -- the concrete proxy-free surface achieved so far.
    for name in ["keyword", "operator", "token", "reprlib", "types", "collections"] {
        layer3_reset();
        mod = import_native(name);
        assert not is_error(mod);
        assert isinstance(mod, PyModule);
    }
}

test "layer3: param that is also a cellvar keeps its slot (closure correctness)" {
    # Regression for the merged-localsplus cell layout: a parameter captured by an
    # inner function shares the cellvar region with sibling local-cells; the wrong
    # index math swapped them. Every decorator/closure in the closure depends on
    # this. `param` must read PRM, `local` must read LOC.
    layer3_reset();
    src = "def outer(param):\n"
    "    local = 'LOC'\n"
    "    def inner():\n"
    "        return (param, local)\n"
    "    return inner\n"
    "r = outer('PRM')()\n"
    "a = r[0]\n"
    "b = r[1]\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert to_host(g["a"]) == "PRM";
    assert to_host(g["b"]) == "LOC";
}

test "layer3: STORE_GLOBAL writes module globals from inside a function" {
    layer3_reset();
    src = "flag = 0\n"
    "def setflag():\n"
    "    global flag\n"
    "    flag = 42\n"
    "setflag()\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert to_host(g["flag"]) == 42;
}

test "layer3: from-import-star binds a module's public names" {
    layer3_reset();
    src = "from operator import *\n" "s = add(3, 4)\n" "p = mul(3, 4)\n";
    g: dict[str, PyObj] = {
        "__name__": PyStr(t="str", val="m"),
        "__package__": PyStr(t="str", val="")
    };
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["s"]) == 7;
    assert to_host(g["p"]) == 12;
}

test "layer3: *args / **kwargs collection binds surplus positional and keyword args" {
    # exec_code_frame lays out the [params][*args][**kwargs] localsplus region the
    # way CPython does: surplus positionals gather into the *args tuple, and
    # keywords that don't name a parameter flow into the **kwargs dict. Every
    # `def f(self, /, **kwds)` in the stdlib closure (namedtuple._replace, dozens
    # of dunder shims) depends on this.
    layer3_reset();
    src = "def f(a, *args, **kw):\n"
    "    return (a, args, sorted(kw.items()))\n"
    "r = f(1, 2, 3, x=4, y=5)\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["r"]) == (1, (2, 3), [("x", 4), ("y", 5)]);
}

test "layer3: a host builtin-subclass instance keeps its type across from_host" {
    # A host instance whose type is a proper subclass of a builtin (here a
    # tuple subclass) must not be flattened into a native PyTuple by from_host --
    # that would erase its real type and descriptors. It stays a proxy, so
    # `type(x).__name__` is the subclass and instance-specific attributes survive.
    layer3_reset();
    src = "T = type('T', (tuple,), {'tag': 'mine'})\n"
    "x = tuple.__new__(T, (1, 2))\n"
    "tn = type(x).__name__\n"
    "tg = x.tag\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["tn"]) == "T";
    assert to_host(g["tg"]) == "mine";
}

test "layer3: namedtuple's dynamic class boots in-VM (native<->host trampoline)" {
    # The named sub-milestone: collections.namedtuple builds a class at runtime
    # via host type(name, bases, ns) whose namespace holds NATIVE functions
    # (__new__ from eval, _make/_asdict/__repr__), then wraps some as
    # classmethod. to_host(PyFunction) hands each a host trampoline that calls
    # back into ceval, and from_host preserves the resulting tuple-subclass
    # instances. Field access, repr, _asdict, _make, ==, indexing, len, and
    # unpacking all run proxy-free end to end.
    layer3_reset();
    src = "from collections import namedtuple\n"
    "Point = namedtuple('Point', ['x', 'y'])\n"
    "p = Point(1, 2)\n"
    "tn = type(p).__name__\n"
    "a = p.x\n"
    "b = p.y\n"
    "s = str(p)\n"
    "d = p._asdict()\n"
    "m = Point._make([3, 4])\n"
    "ms = str(m)\n"
    "eq = (p == Point(1, 2))\n"
    "idx = p[0]\n"
    "cnt = len(p)\n"
    "ux, uy = p\n"
    "fields = p._fields\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["tn"]) == "Point";
    assert to_host(g["a"]) == 1;
    assert to_host(g["b"]) == 2;
    assert to_host(g["s"]) == "Point(x=1, y=2)";
    assert to_host(g["d"]) == {"x": 1, "y": 2};
    assert to_host(g["ms"]) == "Point(x=3, y=4)";
    assert to_host(g["eq"]) == True;
    assert to_host(g["idx"]) == 1;
    assert to_host(g["cnt"]) == 2;
    assert to_host(g["ux"]) == 1;
    assert to_host(g["uy"]) == 2;
    assert to_host(g["fields"]) == ("x", "y");
}

test "layer3: CALL_FUNCTION_EX drives f(*args, **kwargs) and forwarding" {
    # The unpacked-call opcode plus the DICT_MERGE target-index fix. Arg
    # forwarding (def f(*a, **k): g(*a, **k)) is the backbone of decorators
    # across the closure; functools.wraps needs it too.
    layer3_reset();
    src = "def f(a, b, c): return (a, b, c)\n"
    "star = f(*(1, 2, 3))\n"
    "starkw = f(*(1,), **{'b': 2, 'c': 3})\n"
    "def target(a, b, x=0): return a + b + x\n"
    "def fwd(*a, **k): return target(*a, **k)\n"
    "forwarded = fwd(10, 20, x=5)\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["star"]) == (1, 2, 3);
    assert to_host(g["starkw"]) == (1, 2, 3);
    assert to_host(g["forwarded"]) == 35;
}

test "layer3: EXTENDED_ARG decodes a wide oparg" {
    # A large constant/name index needs the EXTENDED_ARG prefix to carry the high
    # bits; big modules (typing) rely on it. Subscript past 255 forces a wide arg
    # only indirectly, so exercise a large tuple display which emits EXTENDED_ARG.
    layer3_reset();
    src = "xs = list(range(300))\n"
    "hi = xs[257]\n"
    "big = tuple(range(280))\n"
    "last = big[279]\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["hi"]) == 257;
    assert to_host(g["last"]) == 279;
}

test "layer3: functools.wraps copies name/doc and forwards through the wrapper" {
    layer3_reset();
    src = "import functools\n"
    "def deco(fn):\n"
    "    @functools.wraps(fn)\n"
    "    def w(*a, **k):\n"
    "        return fn(*a, **k)\n"
    "    return w\n"
    "@deco\n"
    "def g(x):\n"
    "    'the doc'\n"
    "    return x + 1\n"
    "called = g(5)\n"
    "nm = g.__name__\n"
    "dc = g.__doc__\n";
    g: dict[str, PyObj] = {
        "__name__": PyStr(t="str", val="m"),
        "__package__": PyStr(t="str", val="")
    };
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["called"]) == 6;
    assert to_host(g["nm"]) == "g";
    assert to_host(g["dc"]) == "the doc";
}

test "layer3: native objects expose __dict__ (functions, classes, instances, modules)" {
    # __dict__ backs introspection and functools.wraps/update_wrapper. It reads the
    # object's writable attribute map (a snapshot; live-mapping is a later refinement).
    layer3_reset();
    src = "def f(): pass\n"
    "f.tag = 7\n"
    "fd = f.__dict__['tag']\n"
    "class C:\n"
    "    cvar = 5\n"
    "cd = 'cvar' in C.__dict__\n"
    "o = C()\n"
    "o.iv = 9\n"
    "od = o.__dict__['iv']\n"
    "import operator\n"
    "md = 'add' in operator.__dict__\n";
    g: dict[str, PyObj] = {
        "__name__": PyStr(t="str", val="m"),
        "__package__": PyStr(t="str", val="")
    };
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["fd"]) == 7;
    assert to_host(g["cd"]) == True;
    assert to_host(g["od"]) == 9;
    assert to_host(g["md"]) == True;
}

test "layer3: functools and contextlib boot in-VM (wraps / __dict__ / type-keyed dispatch)" {
    # functools trips on @wraps(reduce) needing wrapper.__dict__; contextlib on
    # the same closure machinery. Both now boot proxy-free, proving __dict__ plus
    # the hashable-proxy and trampoline work compose into a real module load.
    layer3_reset();
    fmod = import_native("functools");
    assert not is_error(fmod);
    assert isinstance(fmod, PyModule);
    assert "reduce" in (fmod as PyModule).attrs;
    assert "wraps" in (fmod as PyModule).attrs;
    assert "lru_cache" in (fmod as PyModule).attrs;
    cmod = import_native("contextlib");
    assert isinstance(cmod, PyModule);
    assert "contextmanager" in (cmod as PyModule).attrs;
}

test "layer3: a proxied host object (a type) is usable as a dict/set key" {
    # Type-keyed dispatch tables are everywhere in the stdlib closure
    # (functools.singledispatch, copyreg, typing, contextlib). A PyHostProxy now
    # buckets by its host hash so it can key a native dict/set; the dict layer
    # confirms a bucket hit with a real ==, so distinct classes stay distinct.
    layer3_reset();
    src = "X = type('X', (), {})\n"
    "Y = type('Y', (), {})\n"
    "d = {int: 'i', str: 's', X: 'x'}\n"
    "by_type = d[str]\n"
    "by_cls = d[X]\n"
    "x_in = X in d\n"
    "y_in = Y in d\n"
    "s = {X, Y}\n"
    "s_has = X in s\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["by_type"]) == "s";
    assert to_host(g["by_cls"]) == "x";
    assert to_host(g["x_in"]) == True;
    assert to_host(g["y_in"]) == False;
    assert to_host(g["s_has"]) == True;
}

test "layer3: namedtuple with defaults instantiates with omitted trailing fields" {
    layer3_reset();
    src = "from collections import namedtuple\n"
    "C = namedtuple('C', ['a', 'b', 'c'], defaults=[10, 20])\n"
    "x = C(1)\n"
    "s = str(x)\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["s"]) == "C(a=1, b=10, c=20)";
}

test "layer3: a custom metaclass drives class creation (metaclass= + super().__new__)" {
    # `class C(metaclass=Meta)` resolves Meta, runs its __new__, and reaches
    # type.__new__ via super() -- the class factory that builds the real class
    # object. Meta stamps an attribute onto the finished class. This is the
    # machinery enum/ABCMeta/typing need: metaclass resolution, the type.__new__
    # super-call producing a PyClass, and the metaclass recorded on it.
    layer3_reset();
    src = "class Meta(type):\n"
    "    def __new__(mcls, name, bases, ns, **kw):\n"
    "        cls = super().__new__(mcls, name, bases, ns)\n"
    "        cls.tag = 99\n"
    "        return cls\n"
    "class C(metaclass=Meta):\n"
    "    x = 1\n"
    "tag = C.tag\n"
    "xval = C.x\n"
    "inst = C()\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["tag"]) == 99;
    assert to_host(g["xval"]) == 1;
}

test "layer3: a dict subclass with __setitem__ / super() / native dict methods" {
    # The _EnumDict shape: a dict subclass whose __setitem__ tracks keys and calls
    # super().__setitem__ to store. get/setdefault/pop/items must hit the real
    # backing storage (not a to_host copy), and a subscript assignment dispatches
    # the overridden __setitem__.
    layer3_reset();
    src = "class Track(dict):\n"
    "    def __init__(self):\n"
    "        super().__init__()\n"
    "        self.seen = []\n"
    "    def __setitem__(self, k, v):\n"
    "        self.seen.append(k)\n"
    "        super().__setitem__(k, v)\n"
    "d = Track()\n"
    "d['a'] = 1\n"
    "d['b'] = 2\n"
    "sd = d.setdefault('a', 99)\n"
    "sd2 = d.setdefault('c', 3)\n"
    "g = d.get('b')\n"
    "gm = d.get('z', -1)\n"
    "popped = d.pop('b')\n"
    "keys = list(d.keys())\n"
    "seen = d.seen\n"
    "n = len(d)\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["sd"]) == 1;
    assert to_host(g["sd2"]) == 3;
    assert to_host(g["g"]) == 2;
    assert to_host(g["gm"]) == -1;
    assert to_host(g["popped"]) == 2;
    assert to_host(g["keys"]) == ["a", "c"];
    assert to_host(g["seen"]) == ["a", "b"];
    assert to_host(g["n"]) == 2;
}

test "layer3: del attr, bare raise re-raise, and DELETE_FAST" {
    # delattr / `del obj.x` on a native instance, a bare `raise` re-raising the
    # active exception from an except block, and `del local`.
    layer3_reset();
    src = "class C:\n"
    "    pass\n"
    "o = C()\n"
    "o.x = 5\n"
    "had = hasattr(o, 'x')\n"
    "del o.x\n"
    "gone = not hasattr(o, 'x')\n"
    "caught = 0\n"
    "reached = 0\n"
    "def f():\n"
    "    try:\n"
    "        raise ValueError('boom')\n"
    "    except ValueError:\n"
    "        raise\n"
    "try:\n"
    "    f()\n"
    "except ValueError:\n"
    "    caught = 1\n"
    "tmp = 10\n"
    "del tmp\n"
    "reached = 1\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["had"]) == True;
    assert to_host(g["gone"]) == True;
    assert to_host(g["caught"]) == 1;
    assert to_host(g["reached"]) == 1;
}

test "layer3: native classmethod / staticmethod / property descriptors resolve in-VM" {
    # classmethod binds the class as the first arg, staticmethod unwraps to a
    # plain function, and property invokes its getter on instance access. All
    # three are pervasive in enum/abc/typing/dataclasses. The setter rebuilds the
    # property; namedtuple reads `.__func__` off a classmethod.
    layer3_reset();
    src = "class C:\n"
    "    tag = 'cls'\n"
    "    def __init__(self, v):\n"
    "        self._v = v\n"
    "    @classmethod\n"
    "    def make(cls, v):\n"
    "        return (cls.tag, v)\n"
    "    @staticmethod\n"
    "    def add(a, b):\n"
    "        return a + b\n"
    "    @property\n"
    "    def v(self):\n"
    "        return self._v\n"
    "    @v.setter\n"
    "    def v(self, nv):\n"
    "        self._v = nv * 2\n"
    "cm = C.make(7)\n"
    "sm = C.add(2, 3)\n"
    "o = C(10)\n"
    "pg = o.v\n"
    "o.v = 5\n"
    "pg2 = o.v\n"
    "fn = C.make.__func__\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["cm"]) == ("cls", 7);
    assert to_host(g["sm"]) == 5;
    assert to_host(g["pg"]) == 10;
    assert to_host(g["pg2"]) == 10;
}

test "layer3: a subclass re-derives its base's metaclass and re-runs it" {
    # `class D(C)` where C was made by Meta must resolve Meta from C (no explicit
    # metaclass= kwarg) and run it again -- the inheritance path enum members rely
    # on (every Enum subclass is created by EnumType).
    layer3_reset();
    src = "class Meta(type):\n"
    "    def __new__(mcls, name, bases, ns, **kw):\n"
    "        cls = super().__new__(mcls, name, bases, ns)\n"
    "        cls.stamp = name\n"
    "        return cls\n"
    "class C(metaclass=Meta):\n"
    "    pass\n"
    "class D(C):\n"
    "    pass\n"
    "cstamp = C.stamp\n"
    "dstamp = D.stamp\n";
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    assert to_host(g["cstamp"]) == "C";
    assert to_host(g["dstamp"]) == "D";
}
