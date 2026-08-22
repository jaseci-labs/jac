# ceval + host bridge (jac-py/PLAN.md §4 module-boundary constraint).
# Callable/heap/proxy types, Layer 3 import, py_* dispatch, exec_code_frame/run_frame,
# generator machinery, Track B builtin subclassing, native set/dict methods.
# Imports the na-clean leaf (objects.jac + object-type modules) but NOT pyc_first.

# ---------------- host bridge ----------------
import marshal;

::py::
def _jac_host_import(name, fromlist):
    import importlib
    try:
        if fromlist:
            return (True, importlib.import_module(name))
        return (True, importlib.import_module(name.split(".")[0]))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_getattr(value, name):
    try:
        return (True, getattr(value, name))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_setattr(value, name, field):
    try:
        setattr(value, name, field)
        return (True, None)
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_call(fn, args, kwargs):
    try:
        return (True, fn(*args, **kwargs))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_getitem(value, index):
    try:
        return (True, value[index])
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_len(value):
    try:
        return (True, len(value))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_is_object_type(value):
    # True iff value is exactly the builtin `object` type. object.__new__(cls) is
    # the canonical plain-instance constructor (functools._PlaceholderType, any
    # singleton). Other types' __new__ stays host-routed so namedtuple's
    # tuple.__new__(HostClass, ...) is unaffected.
    return value is object

def _jac_is_type_type(value):
    # True iff value is exactly the builtin `type`. A user class listing `type`
    # among its bases is a metaclass; super().__new__ inside its __new__ must
    # build a class object (type.__new__), not a plain instance.
    return value is type

def _jac_host_hashkey(value) -> str:
    # Bucket a proxied host object by its host hash so it can be a dict/set key
    # (type-keyed dispatch tables in functools/copyreg/typing/contextlib). Equal
    # host objects share a hash, hence a bucket; the dict layer confirms a bucket
    # hit with a real == (PyHostProxy needs_eq_confirm). '' means unhashable.
    try:
        return "host:" + str(hash(value))
    except BaseException:
        return ""

def _jac_host_contains(member, container):
    try:
        return (True, member in container)
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_is_notimpl(v):
    return v is NotImplemented

def _jac_host_iter(value):
    try:
        return (True, list(value))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_builtin(name):
    import builtins
    try:
        return (True, getattr(builtins, name))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_type_name(value):
    return type(value).__name__

def _jac_host_type(value):
    # type(value) for a host object -- the fallback for py_type_of when the
    # argument has no in-VM class (a proxied host value, or a native scalar whose
    # to_host round-trips cleanly to int/str/float/...).
    return type(value)

def _jac_host_delattr(host_obj, name):
    try:
        delattr(host_obj, name)
        return (True, None)
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_wrap_classmethod(host_fn):
    return classmethod(host_fn)

def _jac_wrap_staticmethod(host_fn):
    return staticmethod(host_fn)

def _jac_wrap_property(fget, fset, fdel):
    return property(fget, fset, fdel)

# Track B (builtin subclassing) host helpers.
_JAC_BUILTIN_BASES = (
    "int", "str", "float", "bool", "list", "dict",
    "tuple", "set", "frozenset", "bytes", "object",
)

def _jac_builtin_base_name(host_val) -> str:
    # If host_val is one of the subclassable builtin TYPES, return its name.
    import builtins
    if isinstance(host_val, type):
        n = getattr(host_val, "__name__", "")
        if n in _JAC_BUILTIN_BASES:
            return n
    return ""

def _jac_construct_builtin(name, raw_args):
    import builtins
    t = getattr(builtins, name)
    try:
        if raw_args:
            return (True, t(*raw_args))
        return (True, t())
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_builtin_new(name, host_cls, raw_args):
    # builtin.__new__(host_cls, *raw_args): the host builtin constructor over a
    # HOST class (namedtuple's dynamic tuple subclass). Keeps the host subclass
    # instance intact instead of collapsing it to a native value.
    import builtins
    t = getattr(builtins, name)
    try:
        return (True, t.__new__(host_cls, *raw_args))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_builtin_new_slot(name):
    import builtins
    if name == "" or name == "object":
        return object.__new__
    return getattr(builtins, name).__new__

def _jac_isinstance_of_builtin(host_val, name) -> bool:
    # True iff host_val is an instance of the named builtin type.
    import builtins
    t = getattr(builtins, name, None)
    if t is None:
        return False
    return isinstance(host_val, t)

def _jac_host_isinstance(host_obj, host_type):
    try:
        return isinstance(host_obj, host_type)
    except BaseException:
        return False

def _jac_type_has_flag(host_obj, flag_bit) -> bool:
    try:
        return bool(type(host_obj).__flags__ & flag_bit)
    except BaseException:
        return False

def _jac_host_type_name(host_obj):
    try:
        return type(host_obj).__name__
    except BaseException:
        return "?"

def _jac_is_exception_type(host_val):
    # True iff host_val is a class deriving from BaseException (used to recognize
    # a user class like `class Exc(Exception)` whose host base proxy is here).
    return isinstance(host_val, type) and issubclass(host_val, BaseException)

def _jac_host_exception_instance(raw):
  # True with (type_name, message) when raw is a raised host BaseException instance.
    if isinstance(raw, BaseException):
        return (True, type(raw).__name__, str(raw))
    return (False, "", "")

def _jac_host_issubclass(host_cls, host_type) -> bool:
    try:
        return issubclass(host_cls, host_type)
    except BaseException:
        return False

def _jac_host_class_name(value):
    # The class's own __name__ (for an except-target that is an exception CLASS),
    # falling back to type(value).__name__ for a non-class value.
    return getattr(value, "__name__", None) or type(value).__name__

def _jac_exc_name_subclass(target_name, exc_name):
    # True iff a builtin exception named exc_name is target_name or a subclass of
    # it -- e.g. FileNotFoundError is-a OSError, ValueError is-a Exception. Both
    # names are resolved against builtins; user/native names not found there fall
    # back to the exact-name compare done by the caller (returns False here).
    try:
        t = getattr(builtins, target_name, None)
        e = getattr(builtins, exc_name, None)
        if (isinstance(t, type) and isinstance(e, type)
                and issubclass(t, BaseException)):
            return issubclass(e, t)
        return False
    except BaseException:
        return False

def _jac_host_format(value, spec):
    try:
        return (True, format(value, spec))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_unbound_method_info(value):
    # (True, owner_type_name, method_name) when value is an unbound builtin
    # method descriptor of a container type mirrored natively (list/dict/set).
    try:
        objclass = getattr(value, "__objclass__", None)
        if objclass is None:
            return (False, "", "")
        name = getattr(value, "__name__", "")
        if objclass in (list, dict, set):
            return (True, objclass.__name__, name)
        return (False, "", "")
    except BaseException:
        return (False, "", "")

def _jac_bound_method_type():
    # CPython: a bound method of a Python function is exactly `method`.
    class _M:
        def m(self):
            return None
    return type(_M().m)

def _jac_list_iterator_type():
    # Native PyIter mirrors list iteration; use the host list_iterator type.
    return type(iter([]))

def _jac_builtin_function_or_method_type():
    import builtins
    # CPython: type(len) is builtin_function_or_method; grab the type object
    # itself so isinstance/name checks on native callables answer correctly.
    return type(builtins.len)

def _jac_host_same_object(a, b):
    return a is b

def _jac_host_eq(a, b):
    try:
        return (True, bool(a == b))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_binop(kind, a, b):
    import operator
    _NB = {
        0: operator.add, 1: operator.and_, 2: operator.floordiv,
        3: operator.lshift, 4: operator.matmul, 5: operator.mul,
        6: operator.mod, 7: operator.or_, 8: operator.pow,
        9: operator.rshift, 10: operator.sub, 11: operator.truediv,
        12: operator.xor,
    }
    fn = _NB.get(kind)
    if fn is None:
        return (False, "TypeError", "unsupported binary op " + str(kind))
    try:
        return (True, fn(a, b))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_host_convert(value, conv):
    try:
        if conv == 2:
            return (True, repr(value))
        if conv == 3:
            return (True, ascii(value))
        return (True, str(value))
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_module_info(absname):
    # Layer 3 module locator: resolve a fully-qualified module name to its source.
    # Returns (status, source, is_pkg, origin):
    #   "py"      -> pure-Python module; `source` is its text, run in-VM proxy-free
    #   "native"  -> built-in / frozen / C extension (no .py); caller host-proxies it
    #   "missing" -> no such module (ModuleNotFoundError)
    # find_spec locates the file the same way CPython's import system does; it may
    # host-import parent packages purely to read their __path__ (never the module
    # itself), which is fine -- only the .py bytes cross back for in-VM execution.
    import importlib.util as _u
    try:
        spec = _u.find_spec(absname)
    except BaseException:
        return ("missing", "", False, "")
    if spec is None:
        return ("missing", "", False, "")
    origin = spec.origin or ""
    is_pkg = spec.submodule_search_locations is not None
    if origin.endswith(".py"):
        try:
            with open(origin, "r", encoding="utf-8") as fh:
                return ("py", fh.read(), is_pkg, origin)
        except OSError:
            return ("native", "", is_pkg, origin)
    return ("native", "", is_pkg, origin)

def _jac_star_names(host_val):
    # `from proxied_module import *` name set: __all__ if defined, else every
    # public (non-underscore) attribute -- CPython's import_all_from rule.
    try:
        alln = getattr(host_val, "__all__", None)
        if alln is not None:
            return (True, [str(n) for n in alln])
        return (True, [n for n in dir(host_val) if not n.startswith("_")])
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))

def _jac_make_host_trampoline(native_fn):
    # Native-callable -> host round-trip. When a native PyFunction crosses the
    # host boundary (to_host), it can't become None -- host machinery that wraps
    # or invokes it (type(name, bases, ns) installing a native __repr__, a
    # classmethod/property over a native function, functools.partial, a callback
    # handed to a proxied C module) needs a REAL callable. Return a host closure
    # that marshals host args back into PyObjs, runs the function in jacpython's
    # own ceval via tp_call, and marshals the result back out. A raised PyError
    # is re-raised as the matching host exception so host control flow sees it.
    import builtins as _b
    def _trampoline(*args, **kwargs):
        pyargs = [from_host(a) for a in args]
        pykwargs = {}
        for k in kwargs:
            pykwargs[k] = from_host(kwargs[k])
        result = native_fn.tp_call(pyargs, pykwargs)
        if isinstance(result, PyError):
            exc = result.exception
            etype = getattr(_b, exc.type_name, None)
            if etype is None or not isinstance(etype, type):
                etype = RuntimeError
            raise etype(exc.message)
        return to_host(result)
    # Present as the wrapped function so introspection (functools.wraps,
    # type()'s method registration, repr) sees the right identity. Keep a
    # back-pointer so a round-trip (from_host of this trampoline) recovers the
    # native function instead of re-wrapping it as an opaque proxy.
    try:
        _trampoline.__name__ = native_fn.name
        # PyFunction carries code/_func_doc; other callables (PyNativeBuiltin,
        # bound/method wrappers) only carry .name.
        if hasattr(native_fn, "code"):
            _trampoline.__qualname__ = native_fn.code.qualname
            doc = native_fn._func_doc()
            _trampoline.__doc__ = doc.val if isinstance(doc, PyStr) else None
        else:
            _trampoline.__qualname__ = native_fn.name
        _trampoline.__jac_native__ = native_fn
    except BaseException:
        pass
    return _trampoline

def _jac_make_weakref(target):
    # Host weakref over the RAW jacpython object. PyUserObj/PyClass/native
    # wrappers are ordinary CPython objects, so the host weakref tracks their
    # exact refcount lifetime: when the last strong reference dies, ref()
    # returns None with no extra bookkeeping. Returns None on TypeError.
    import weakref
    try:
        return weakref.ref(target)
    except TypeError:
        return None

def _jac_weakref_deref(wr):
    return wr()

def _jac_dbg_dead_check_simple(r):
    # Minimal: alive or dead, no walking.
    import sys
    wr = getattr(r, "wr")
    return wr() is None

def _py_dict_del(d, k):
    del d[k]

def _jac_recover_native(raw) -> PyObj | None:
    # If raw is a trampoline we minted, hand back the native function it wraps
    # so a host->native round-trip collapses instead of nesting proxies. Read the
    # marker from the object's OWN __dict__, not via getattr: a bound method
    # delegates attribute access to its __func__, so getattr(bound_method,
    # '__jac_native__') would unwrap it to the UNBOUND native function and lose
    # the receiver -- exactly what breaks `instance.method()`.
    import types as _types
    if not isinstance(raw, _types.FunctionType):
        return None
    return raw.__dict__.get("__jac_native__")

_JAC_EXACT_BUILTINS = (
    int, float, str, bytes, tuple, list, dict, set, frozenset, bool,
)

def _jac_is_builtin_subclass_instance(raw):
    # True iff raw is an instance of a container/scalar builtin whose type is a
    # PROPER SUBCLASS (namedtuple, IntEnum, a user `class X(list)` built on the
    # host, ...). Such an instance must stay a PyHostProxy: converting it to a
    # native PyTuple/PyList/PyInt would discard its real type and its own
    # attributes/descriptors (namedtuple field access, enum .name/.value).
    t = type(raw)
    if t in _JAC_EXACT_BUILTINS:
        return False
    return isinstance(raw, _JAC_EXACT_BUILTINS)

def _jac_host_val_is_type(val):
    return isinstance(val, type)
::py::



import from marshal_reader { unmarshal, }

# Bootstrap transport duplicate (pyc_first.jac keeps the canonical copy for re-export).
def host_compile_marshal(source: str) -> list[int] {
    raw = marshal.dumps(compile(source, "<jacpython-host>", "exec"));
    return raw as list[int];
}

# The object core -- the PyObj data-type hierarchy, value/container slots, and
# pure helpers -- lives in the na-clean leaf `objects.jac`. This module (the
# ceval + host bridge + marshal transport) imports it and adds the callable/
# heap/proxy types that OVERRIDE the call/attr slots (cross-module inheritance),
# because those slots re-enter the interpreter or the host and so cannot live in
# the acyclic leaf. See PLAN.md §4 (module-boundary constraint).
import from hash_dispatch { hash_element, }
import from objects {
    Py_EQ,
    Py_LE,
    Py_GE,
}
import from abstract_protocol {
    PyObject_GetIter,
    PyObject_HashNotImplemented,
    PyObject_RichCompare,
    PyObject_RichCompareBool,
}
import from tupleobject { tuple_hash, tuple_richcompare, }
import from longobject { long_hash_obj, int_repr, }
import from setobject { set_hash_obj, set_richcompare, }
import from typeobject {
    type_repr,
    type_richcompare,
    type_richcompare_same,
    type_tp_name,
    type_ready,
    Py_TPFLAGS_READY,
}
import from bytesobject { bytes_hash_obj, bytes_richcompare, bytes_repr, }
import from strobject { str_repr, }
import from floatobject { float_repr, }
import from listobject { list_richcompare, list_repr, }
import from dictobject { dict_richcompare, dict_repr, }
import from exceptions_core { exc_name_matches, baseexception_str, baseexception_repr, }
import from objects {
    _py_container_del,
    PyObj,
    PyInt,
    PyStr,
    PyBytes,
    PyFloat,
    PyBool,
    PyNoneType,
    PyComplex,
    PySlice,
    PyTuple,
    PyList,
    PyCode,
    PyCell,
    PyDict,
    PyDictIter,
    PySet,
    PyExceptionType,
    PyException,
    PyError,
    PyIter,
    PyHandler,
    bytes_value,
    tuple_value,
    str_value,
    str_values,
    int_values,
    expect_int,
    expect_str,
    expect_float,
    expect_bool,
    list_value,
    concat_items,
    find_name,
    py_none,
    py_error,
    py_exception_type,
    dict_key_repr,
    _pyobj_repr,
    is_error,
    PY_NOT_IMPLEMENTED
}
import from opcode_meta {
    OP_CACHE,
    OP_RESUME,
    OP_LOAD_BUILD_CLASS,
    OP_LOAD_LOCALS,
    OP_NOT_TAKEN,
    OP_POP_TOP,
    OP_PUSH_EXC_INFO,
    OP_PUSH_NULL,
    OP_RETURN_VALUE,
    OP_BINARY_SLICE,
    OP_BUILD_SLICE,
    OP_STORE_SUBSCR,
    OP_UNARY_NOT,
    OP_WITH_EXCEPT_START,
    OP_BINARY_OP,
    OP_BUILD_LIST,
    OP_BUILD_MAP,
    OP_BUILD_TUPLE,
    OP_CALL,
    OP_CALL_KW,
    OP_COMPARE_OP,
    OP_COPY,
    OP_COPY_FREE_VARS,
    OP_END_FOR,
    OP_END_ASYNC_FOR,
    OP_GET_AITER,
    OP_GET_ANEXT,
    OP_GET_ITER,
    OP_IMPORT_FROM,
    OP_IMPORT_NAME,
    OP_IS_OP,
    OP_JUMP_BACKWARD,
    OP_JUMP_BACKWARD_NO_INTERRUPT,
    OP_JUMP_FORWARD,
    OP_LIST_APPEND,
    OP_SET_ADD,
    OP_LIST_EXTEND,
    OP_LOAD_ATTR,
    OP_LOAD_SUPER_ATTR,
    OP_LOAD_CONST,
    OP_LOAD_DEREF,
    OP_LOAD_CLOSURE,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
    OP_LOAD_FAST_CHECK,
    OP_LOAD_FAST_LOAD_FAST,
    OP_LOAD_GLOBAL,
    OP_LOAD_NAME,
    OP_LOAD_SMALL_INT,
    OP_LOAD_SPECIAL,
    OP_MAKE_CELL,
    OP_MAKE_FUNCTION,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_NONE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_JUMP_IF_TRUE,
    OP_RAISE_VARARGS,
    OP_RERAISE,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_STORE_ATTR,
    OP_DELETE_ATTR,
    OP_STORE_DEREF,
    OP_STORE_FAST,
    OP_DELETE_FAST,
    OP_STORE_NAME,
    OP_STORE_GLOBAL,
    OP_DELETE_GLOBAL,
    OP_DELETE_NAME,
    OP_SWAP,
    OP_CHECK_EXC_MATCH,
    OP_POP_EXCEPT,
    OP_BUILD_SET,
    OP_SET_UPDATE,
    OP_CONVERT_VALUE,
    OP_FORMAT_SIMPLE,
    OP_FORMAT_WITH_SPEC,
    OP_BUILD_STRING,
    OP_RETURN_GENERATOR,
    OP_YIELD_VALUE,
    OP_STORE_FAST_LOAD_FAST,
    OP_TO_BOOL,
    OP_CONTAINS_OP,
    OP_LOAD_COMMON_CONSTANT,
    OP_CALL_INTRINSIC_1,
    OP_LOAD_FAST_AND_CLEAR,
    OP_SEND,
    OP_END_SEND,
    OP_GET_YIELD_FROM_ITER,
    OP_GET_AWAITABLE,
    OP_CLEANUP_THROW,
    OP_UNARY_NEGATIVE,
    OP_UNARY_INVERT,
    OP_UNPACK_SEQUENCE,
    OP_UNPACK_EX,
    OP_GET_LEN,
    OP_MATCH_SEQUENCE,
    OP_MATCH_MAPPING,
    OP_MATCH_KEYS,
    OP_MATCH_CLASS,
    OP_DELETE_SUBSCR,
    OP_MAP_ADD,
    OP_DICT_MERGE,
    OP_DICT_UPDATE,
    OP_STORE_FAST_STORE_FAST,
    OP_EXTENDED_ARG,
    OP_CALL_FUNCTION_EX,
    OP_NOP,
    OP_FOR_ITER,
    OP_POP_ITER,
    opcode_cache_count,
}

def dict_from_str_map(m: dict[str, PyObj]) -> PyDict {
    # Wrap an inherently str-keyed implementation map (frame locals / class
    # namespace / __dict__) into a PyDict with PyStr keys under the hash-key
    # protocol.
    d = PyDict(t="dict", items={});
    for k in m {
        d.dict_set(PyStr(t="str", val=k), m[k]);
    }
    return d;
}

# The proxy archetype (PLAN.md §5, TODO.md Layer 1): wraps a host object and
# routes every slot across the substrate boundary. Born here on the same slot
# mechanism as PyUserObj so bootstrap-time module proxying (import re -> host
# re wrapped in a PyHostProxy) has its socket from day one, not bolted on later.
# Native module object for Layer 2 shim imports (unittest, test.support).
# Installed via register_shim_module so IMPORT_NAME resolves proxy-free.
obj PyModule(PyObj) {
    has name: str,
        attrs: dict[str, PyObj] = {};

    def tp_getattro(attr: str) -> PyObj {
        if attr in self.attrs {
            return self.attrs[attr];
        }
        if attr == "__dict__" {
            return dict_from_str_map(self.attrs);
        }
        return py_error("AttributeError", attr);
    }

    def tp_setattro(attr: str, value: PyObj) -> PyObj {
        self.attrs[attr] = value;
        return py_none();
    }
}

# Layer 2 shim registry: name -> PyModule. Checked before host import.
glob shim_modules: dict[str, PyObj] = {};

def register_shim_module(name: str, module: PyObj) {
    shim_modules[name] = module;
}

def clear_shim_modules {
    shim_modules = {};
}

def shim_module_get(name: str) -> PyObj {
    if name in shim_modules {
        return shim_modules[name];
    }
    return py_error("ImportError", "shim module '" + name + "' is not installed");
}

# ---------------- Layer 3: real un-proxied module import ---------------------
# (jac-py/PLAN.md Layer 3 -- "real unittest boots un-proxied".) When
# layer3_active is set, IMPORT_NAME resolves a module by running its actual
# CPython source as bytecode INSIDE jacpython's own ceval, building a native
# PyModule from the resulting namespace -- rather than wrapping the host module
# in a PyHostProxy. C-extension / built-in / frozen modules (no .py source) stay
# host-proxied; every pure-Python module in the closure executes proxy-free. The
# recursion through IMPORT_NAME pulls the whole dependency closure in-VM. This is
# the milestone that proves the interpreter is real: unittest exercises classes,
# descriptors, exceptions, comprehensions, and the full language surface.

glob sys3_modules: dict[str, PyObj] = {},
     layer3_force_host: list[str] = [],
     layer3_flag: list[bool] = [False];

# Modules deliberately kept host-proxied even though pure-Python source exists,
# because they rely on VM features not yet native (custom metaclasses: enum's
# EnumType drives __prepare__/__new__/__iter__). Proxying a metaclass-heavy leaf
# is the same pragmatic line drawn for C extensions -- it keeps the rest of the
# closure (unittest's own code) running proxy-free. Revisit when metaclasses land.

# One-slot holder rather than a bare `glob layer3_active: bool` -- a scalar glob
# rebound inside a function is scoped local and never persists (see PLAN/memory);
# a list mutated in place does. Read via layer3_is_active() on the IMPORT_NAME path.
def set_layer3_active(flag: bool) {
    layer3_flag[0] = flag;
}

def layer3_is_active -> bool {
    return layer3_flag[0];
}

def clear_sys3_modules {
    sys3_modules = {};
}

# Drop one key from the module cache (used to un-register a module whose in-VM
# execution raised, so a retry re-runs it instead of seeing a half-built shell).
def _sys3_forget(name: str) {
    if name in sys3_modules {
        _py_container_del(sys3_modules, name);
    }
}

def _last_component(dotted: str) -> str {
    parts = dotted.split(".");
    return parts[len(parts) - 1];
}

def _parent_package(dotted: str) -> str {
    parts = dotted.split(".");
    if len(parts) <= 1 {
        return "";
    }
    out = parts[0];
    i = 1;
    while i < len(parts) - 1 {
        out = out + "." + parts[i];
        i = i + 1;
    }
    return out;
}

# Resolve a (possibly relative) import to its absolute module name. `level` is the
# IMPORT_NAME dot-count: 0 = absolute, 1 = current package, 2 = its parent, ...
def _resolve_relative(current_package: str, name: str, level: int) -> str {
    if level == 0 {
        return name;
    }
    parts = current_package.split(".");
    drop = level - 1;
    keep = len(parts) - drop;
    if keep < 0 {
        keep = 0;
    }
    base = "";
    i = 0;
    while i < keep {
        if base == "" {
            base = parts[i];
        } else {
            base = base + "." + parts[i];
        }
        i = i + 1;
    }
    if name == "" {
        return base;
    }
    if base == "" {
        return name;
    }
    return base + "." + name;
}

# Import one fully-qualified module natively, caching it in sys3_modules. Parent
# packages import first (and the submodule is bound as an attribute on its
# parent, per CPython). Pure-Python source runs in-VM; anything else is proxied.
def import_native(absname: str) -> PyObj {
    if absname == "weakref" and not ("weakref" in shim_modules) {
        # Register before the module-info lookup: weakref.py is pure-Python
        # stdlib and would otherwise be executed in-VM against C internals.
        shim_modules["weakref"] = build_weakref_module();
    }
    if absname in sys3_modules {
        return sys3_modules[absname];
    }
    if absname in shim_modules {
        return shim_modules[absname];
    }
    if absname in layer3_force_host {
        star2: list[PyObj] = [PyStr(t="str", val="*")];
        forced = host_import(absname, PyList(t="list", items=star2));
        if is_error(forced) {
            return forced;
        }
        sys3_modules[absname] = forced;
        return forced;
    }
    info = _jac_module_info(absname);
    status = str(info[0]);
    if status == "missing" {
        return py_error("ModuleNotFoundError", "No module named '" + absname + "'");
    }
    if status == "native" {
        # C extension / built-in / frozen: no source to run in-VM. Proxy the real
        # host module (fromlist truthy so importlib returns the named submodule,
        # not just the top package).
        star: list[PyObj] = [PyStr(t="str", val="*")];
        proxy = host_import(absname, PyList(t="list", items=star));
        if is_error(proxy) {
            return proxy;
        }
        sys3_modules[absname] = proxy;
        return proxy;
    }
    source = str(info[1]);
    is_pkg = info[2] as bool;
    origin = str(info[3]);
    parent = _parent_package(absname);
    if parent != "" {
        pmod = import_native(parent);
        if is_error(pmod) {
            return pmod;
        }
    }
    pkg_name = parent;
    if is_pkg {
        pkg_name = absname;
    }
    modglobals: dict[str, PyObj] = {
        "__name__": PyStr(t="str", val=absname),
        "__package__": PyStr(t="str", val=pkg_name),
        "__file__": PyStr(t="str", val=origin),
        "__doc__": py_none(),

    };
    module = PyModule(t="module", name=absname, attrs=modglobals);
    # Register the (still-executing) module before running its body so a circular
    # import mid-closure resolves to this partial module instead of re-entering.
    sys3_modules[absname] = module;
    outcome = exec_code(unmarshal(host_compile_marshal(source)), [], modglobals);
    if is_error(outcome) {
        _sys3_forget(absname);
        return outcome;
    }
    # attrs aliases modglobals (same dict), so STORE_NAME writes are already live.
    if parent != "" and isinstance(sys3_modules[parent], PyModule) {
        (sys3_modules[parent] as PyModule).attrs[_last_component(absname)] = module;
    }
    return module;
}

# The public names `from module import *` binds: a native PyModule's __all__ (or
# its non-underscore keys); a proxied module's __all__/dir() via the host.
def import_star_names(module: PyObj) -> list[str] {
    if isinstance(module, PyModule) {
        attrs = (module as PyModule).attrs;
        if "__all__" in attrs {
            # __all__ is commonly a list literal (not only a tuple); read either.
            allobj = attrs["__all__"];
            items: list[PyObj] = [];
            if isinstance(allobj, PyList) {
                items = (allobj as PyList).items;
            } else {
                items = tuple_value(allobj);
            }
            allnames: list[str] = [];
            for it in items {
                allnames.append(str_value(it));
            }
            return allnames;
        }
        out: list[str] = [];
        for k in attrs {
            if not k.startswith("_") {
                out.append(k);
            }
        }
        return out;
    }
    result = _jac_star_names(to_host(module));
    if host_result_ok(result) {
        names: list[str] = [];
        for n in result[1] {
            names.append(str(n));
        }
        return names;
    }
    return [];
}

# INTRINSIC_IMPORT_STAR: bind every exported name of `module` into `globals`.
def import_star_into(module: PyObj, globals: dict[str, PyObj]) -> PyObj {
    for nm in import_star_names(module) {
        val = py_attr(module, nm);
        if is_error(val) {
            return val;
        }
        globals[nm] = val;
    }
    return py_none();
}

# IMPORT_NAME entry point under Layer 3. Mirrors CPython's __import__ contract:
# with no fromlist, `import a.b.c` binds and returns the TOP package `a`; with a
# fromlist, returns the named module and ensures each requested submodule exists.
def py_import_name(
    name: str, fromlist: PyObj, level: int, globals: dict[str, PyObj]
) -> PyObj {
    current_package = "";
    if "__package__" in globals {
        pkg = globals["__package__"];
        if isinstance(pkg, PyStr) {
            current_package = (pkg as PyStr).val;
        }
    }
    if current_package == "" and "__name__" in globals {
        nm = globals["__name__"];
        if isinstance(nm, PyStr) {
            current_package = (nm as PyStr).val;
        }
    }
    absname = _resolve_relative(current_package, name, level);
    mod = import_native(absname);
    if is_error(mod) {
        return mod;
    }
    has_fromlist = False;
    from_names: list[str] = [];
    if fromlist.t != "none" {
        from_names = str_values(fromlist);
        if len(from_names) > 0 {
            has_fromlist = True;
        }
    }
    if not has_fromlist {
        if level == 0 and "." in absname {
            # `import a.b.c` returns the top package a (STORE_NAME binds `a`).
            top = absname.split(".")[0];
            return import_native(top);
        }
        return mod;
    }
    # `from pkg import x, y`: x/y may be submodules that aren't imported yet. Try
    # to import each as a submodule; a plain attribute (not a module) simply
    # isn't found here and is resolved later by IMPORT_FROM off `mod`.
    for item in from_names {
        if item == "*" {
            continue;
        }
        existing = py_attr(mod, item);
        if is_error(existing) {
            sub = import_native(absname + "." + item);
            # A ModuleNotFoundError just means `item` is a plain attribute, not a
            # submodule -- IMPORT_FROM resolves it off `mod`. Any other error is a
            # real failure importing the submodule and must propagate.
            if is_error(sub)
                and (sub as PyError).exception.type_name != "ModuleNotFoundError" {
                return sub;
            }
        }
    }
    return mod;
}

obj PyHostProxy(PyObj) {
    has val: any;

    # Proxies follow the wrapped host object's identity/equality so dict/set
    # bucketing by tp_hashkey (the host hash) stays consistent: same host
    # object -> equal; distinct host objects defer to host ==. Non-proxy
    # operands defer to the caller's fallback (PY_NOT_IMPLEMENTED).
    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if kind != 2 and kind != 3 {
            return PY_NOT_IMPLEMENTED;
        }
        if isinstance(other, PyHostProxy) {
            mine = self.val;
            theirs = (other as PyHostProxy).val;
            if _jac_host_same_object(mine, theirs) {
                return PyBool(t="bool", val=kind == 2);
            }
            res = _jac_host_eq(mine, theirs);
            if not ((res[0] as bool)) {
                return py_error(str(res[1]), str(res[2]));
            }
            if (res[1] as bool) {
                return PyBool(t="bool", val=True);
            }
            return PY_NOT_IMPLEMENTED;
        }
        return PY_NOT_IMPLEMENTED;
    }

    def tp_getattro(name: str) -> PyObj {
        # object.__new__ builds a plain in-VM instance (so a user class's __new__
        # that calls it produces a PyUserObj, not a host object). Narrow to the
        # exact `object` type; every other type's __new__ stays host-routed.
        if name == "__new__" and _jac_is_object_type(self.val) {
            return PyNativeNew(t="native_new", base_name="object");
        }
        # A subclassable builtin's __new__ (str.__new__, int.__new__, ...) builds a
        # native subclass instance boxing that value, so `str.__new__(EnumCls, v)`
        # (enum member creation for a str/int mixin) yields a PyUserObj tagged with
        # the native class -- not a host str.__new__(None) on a lost to_host class.
        if name == "__new__" {
            builtin_name: str = str(_jac_builtin_base_name(self.val));
            if builtin_name != "" {
                return PyNativeNew(t="native_new", base_name=builtin_name);
            }
        }
        return host_getattr(self, name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        return host_setattr(self, name, value);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # `type(x)` (one positional arg) must be answered in-VM: a native user
        # instance's type is its own PyClass, not host type(to_host(x)) -- which
        # was NoneType because to_host of a plain user object is None. The 3-arg
        # `type(name, bases, ns)` class constructor and every real metaclass call
        # stay host-routed. `type` is the exact builtin here, never a subclass.
        if len(args) == 1 and len(kwargs) == 0 and bool(_jac_is_type_type(self.val)) {
            return py_type_of(args[0]);
        }
        return py_call_host(self, args, kwargs);
    }

    def tp_hashkey -> str {
        return _jac_host_hashkey(self.val) as str;
    }

    def mp_subscript(index: PyObj) -> PyObj {
        return host_getitem(self, index);
    }

    def tp_iter -> PyObj {
        return host_iter(self);
    }
}

obj PyClass(PyObj) {
    has name: str,
        attrs: dict[str, PyObj],
        bases: list[PyObj] = [],
        native_base: str = "",
        # The type OF this class (its metaclass). None means the default `type`.
        # A user metaclass (EnumType, ABCMeta) is recorded here by type.__new__ so
        # `class Sub(Base)` can re-derive it from a base and re-run the protocol.
        metaclass: any = None,
        # ``PyType_Ready`` lifecycle flags (P5 heap types).
        tp_flags: int = 0;

    # Attribute lookup walks the MRO (self first, then bases) so an inherited
    # method/attr is visible on a subclass. Instance access binds via PyUserObj.
    def tp_getattro(name: str) -> PyObj {
        # A class's __name__ is its own name, NOT whatever the body namespace left
        # behind: the class-body frame seeds `__name__` to the module name (correct
        # inside the body), and that entry leaks into attrs. Answer from self.name
        # before the attribute lookup so `Cls.__name__` isn't the module. (__module__
        # legitimately IS that seeded module name, so it stays an attrs lookup.)
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        found = class_lookup_attr(self, name);
        if not is_error(found) {
            # Class-level access: a classmethod binds this class, a staticmethod
            # unwraps, a property object is returned as-is (no instance to invoke).
            return descriptor_get(found, py_none(), self);
        }
        # Standard type dunders CPython always answers: a missing docstring is
        # None, and __name__/__qualname__ report the class name.
        if name == "__doc__" {
            return py_none();
        }
        if name == "__name__" or name == "__qualname__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__dict__" {
            return dict_from_str_map(self.attrs);
        }
        if name == "__mro__" {
            mro_items: list[PyObj] = [];
            for klass in class_mro(self) {
                mro_items.append(klass);
            }
            return PyTuple(t="tuple", items=mro_items);
        }
        if name == "__bases__" {
            return PyTuple(t="tuple", items=self.bases);
        }
        if name == "__base__" {
            if len(self.bases) > 0 {
                return self.bases[0];
            }
            return py_none();
        }
        # A class with no user __new__ inherits object.__new__ (or the builtin base
        # constructor). Attribute access -- unlike class_lookup_attr, which drives
        # construction -- exposes it so `Cls.__new__` reads and compares (enum's
        # _find_new_ tests target against object.__new__/Enum.__new__).
        if name == "__new__" {
            base = self.native_base;
            if base == "" or base == "type" {
                base = "object";
            }
            return PyNativeNew(t="native_new", base_name=base);
        }
        # A method defined on the metaclass (EnumType._add_member_, __call__) is
        # accessible on the class itself, bound to it -- the class is an instance
        # of its metaclass.
        meta_found = self._meta_dunder(name);
        if not is_error(meta_found) {
            return meta_found;
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        self.attrs[name] = value;
        return py_none();
    }

    # A class is hashable by identity (type-keyed dispatch tables, base_chain sets
    # in enum's _find_data_type_). Distinct classes get distinct buckets.
    def tp_hashkey -> str {
        return "obj:" + str(id(self));
    }

    # Classes compare by identity: `ReprEnum in (Enum,)` must be False so enum's
    # ReprEnum-mixin check doesn't misfire on distinct classes.
    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        return type_richcompare(kind, self as PyObj, other);
    }

    # A metaclass instance dunder: looked up on the class's metaclass MRO and bound
    # to this class. `for m in EnumColor` dispatches EnumType.__iter__(cls); the
    # same channel serves __getitem__/__contains__/__len__ on a class.
    def _meta_dunder(name: str) -> PyObj {
        if self.metaclass is not None and isinstance(self.metaclass, PyClass) {
            found = class_lookup_attr(self.metaclass as PyClass, name);
            if not is_error(found) {
                return bind_attribute(found, self);
            }
        }
        return py_error("AttributeError", name);
    }

    def tp_iter -> PyObj {
        it = self._meta_dunder("__iter__");
        if is_error(it) {
            return py_error("TypeError", "object is not iterable");
        }
        return it.tp_call([], {});
    }

    def mp_subscript(index: PyObj) -> PyObj {
        gi = self._meta_dunder("__getitem__");
        if is_error(gi) {
            return py_error("TypeError", "object is not subscriptable");
        }
        return gi.tp_call([index], {});
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # A python-level __new__ (common on builtin subclasses that control their
        # boxed value, e.g. re._constants._NamedIntConstant) governs construction:
        # call __new__(cls, *args) and use its return value. __init__ then runs
        # only if __new__ returned an instance of this class (CPython's rule).
        user_new = class_lookup_attr(self, "__new__");
        if not is_error(user_new) and isinstance(user_new, PyFunction) {
            new_args: list[PyObj] = [self];
            for a in args {
                new_args.append(a);
            }
            made = py_invoke(user_new, new_args, kwargs);
            if is_error(made) {
                return made;
            }
            if isinstance(made, PyUserObj)
                and instance_of_class(made as PyUserObj, self) {
                init2 = class_lookup_attr(self, "__init__");
                if not is_error(init2) and isinstance(init2, PyFunction) {
                    ir = bind_attribute(init2, made).tp_call(args, kwargs);
                    if ir.t == "error" {
                        return ir;
                    }
                }
            }
            return made;
        }
        # A subclass of a builtin (native_base != "") boxes the underlying value.
        # An immutable base (int/str/...) takes its value at __new__ time from the
        # args. A mutable base (dict/list/set) WITH a user __init__ is created empty
        # -- __init__ (which typically calls super().__init__(...)) fills it -- so
        # `class D(dict): def __init__(self, name): super().__init__()` boxes an
        # empty dict, not dict(name). Without a user __init__ the args fill it
        # directly (MyList([1,2,3])).
        init = class_lookup_attr(self, "__init__");
        has_user_init = not is_error(init);
        boxed: PyObj = py_none();
        if self.native_base != "" {
            box_args = args;
            if has_user_init and is_mutable_base(self.native_base) {
                box_args = [];
            }
            boxed = construct_native_base(self.native_base, box_args);
            if is_error(boxed) {
                return boxed;
            }
        }
        instance = PyUserObj(t="instance", cls=self, attrs={}, base=boxed);
        if has_user_init {
            initialized = bind_attribute(init, instance).tp_call(args, kwargs);
            if initialized.t == "error" {
                return initialized;
            }
        }
        return instance;
    }
}

# The generic heap-type object (PLAN.md §5): one archetype for every user
# class instance; its slots resolve through instance/class dict lookup rather
# than a per-type vtable -- exactly the static-vs-heap line CPython draws.
obj PyUserObj(PyObj) {
    has cls: PyClass,
        attrs: dict[str, PyObj],
        base: any = None;

    # The boxed builtin value (int/str/...) for a builtin subclass, or a
    # PyNoneType sentinel for a plain user class. _has_base tells them apart.
    def _has_base -> bool {
        return self.base is not None and not isinstance(self.base, PyNoneType);
    }

    def _base_obj -> PyObj {
        return self.base as PyObj;
    }

    def tp_getattro(name: str) -> PyObj {
        # A property is a data descriptor: it wins over the instance dict, so
        # `o.v` runs the getter even after `o.v = ...` routed through the setter.
        classattr = class_lookup_attr(self.cls, name);
        if isinstance(classattr, PyProperty) {
            return descriptor_get(classattr, self, self.cls);
        }
        if name in self.attrs {
            return bind_attribute(self.attrs[name], self);
        }
        found = classattr;
        if not is_error(found) {
            # Instance access: bind a method, invoke a property getter, unwrap a
            # staticmethod, or bind a classmethod to the instance's class.
            return descriptor_get(found, self, self.cls);
        }
        # Fall through to the boxed builtin value's own attributes/methods
        # (str.upper on a str subclass, etc.).
        if self._has_base() {
            return py_attr(self._base_obj(), name);
        }
        # A plain instance's __dict__ is its own attribute namespace (an explicit
        # `self.__dict__ = ...` assignment, handled above, wins over this).
        if name == "__dict__" {
            return dict_from_str_map(self.attrs);
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        # A property with a setter is a data descriptor: assignment routes through
        # fset instead of writing the instance dict.
        classattr = class_lookup_attr(self.cls, name);
        if isinstance(classattr, PyProperty) {
            p = classattr as PyProperty;
            if p.fset is not None {
                res = py_invoke(p.fset as PyObj, [self, value], {});
                if is_error(res) {
                    return res;
                }
                return py_none();
            }
            return py_error("AttributeError", "can't set attribute '" + name + "'");
        }
        self.attrs[name] = value;
        return py_none();
    }

    # ---- boxed-builtin slot delegation (subclass of int/str/list/...) --------
    # When the class dict doesn't override a slot, a builtin subclass behaves as
    # its boxed value: MyInt(5)+1 == 6, MyInt(5) is a valid dict key, etc. The
    # right operand is unwrapped too so MyInt(5)+MyInt(1) works.
    def nb_binop(kind: int, other: PyObj) -> PyObj {
        return user_binop(kind, self, other);
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        return user_compare(kind, self, other);
    }

    def to_index -> PyObj {
        # A builtin-int subclass instance (re._constants._NamedIntConstant, an
        # IntEnum member, ...) indexes as its boxed int.
        if self._has_base() {
            return self._base_obj().to_index();
        }
        return py_error("TypeError", "object cannot be interpreted as an integer");
    }

    def tp_hashkey -> str {
        if self._has_base() {
            return self._base_obj().tp_hashkey();
        }
        # A user-defined __hash__ keys the object by value (shares the numeric
        # "n:" namespace so hash()-equal objects bucket together); otherwise a
        # plain user object hashes by identity, distinct per object.
        if user_has_dunder(self, "__hash__") {
            h = call_user_dunder(self, "__hash__", []);
            if isinstance(h, PyInt) {
                return "n:" + str((h as PyInt).val);
            }
        }
        return "obj:" + str(id(self));
    }

    def tp_bool -> bool {
        if self._has_base() {
            return self._base_obj().tp_bool();
        }
        return True;
    }

    def tp_iter -> PyObj {
        # A user-defined __iter__ returns the iterator (driven by FOR_ITER/SEND
        # via its __next__); fall back to a boxed builtin base, else not iterable.
        if user_has_dunder(self, "__iter__") {
            return call_user_dunder(self, "__iter__", []);
        }
        if self._has_base() {
            return self._base_obj().tp_iter();
        }
        return py_error("TypeError", "object is not iterable");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if user_has_dunder(self, "__getitem__") {
            return call_user_dunder(self, "__getitem__", [index]);
        }
        if self._has_base() {
            return self._base_obj().mp_subscript(index);
        }
        return py_error("TypeError", "object is not subscriptable");
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        if user_has_dunder(self, "__setitem__") {
            r = call_user_dunder(self, "__setitem__", [index, value]);
            if is_error(r) {
                return r;
            }
            return py_none();
        }
        if self._has_base() {
            return self._base_obj().mp_ass_subscript(index, value);
        }
        return py_error("TypeError", "object does not support item assignment");
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        if user_has_dunder(self, "__delitem__") {
            r = call_user_dunder(self, "__delitem__", [index]);
            if is_error(r) {
                return r;
            }
            return py_none();
        }
        if self._has_base() {
            return self._base_obj().mp_del_subscript(index);
        }
        return py_error("TypeError", "object does not support item deletion");
    }
}

obj PyBoundMethod(PyObj) {
    has function: PyObj,
        receiver: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        call_args: list[PyObj] = [self.receiver];
        call_args.extend(args);
        return self.function.tp_call(call_args, kwargs);
    }

    # A bound method exposes __func__/__self__ and otherwise forwards attribute
    # reads (__name__, __qualname__, __doc__) to the underlying function.
    def tp_getattro(name: str) -> PyObj {
        if name == "__func__" {
            return self.function;
        }
        if name == "__self__" {
            return self.receiver;
        }
        return py_attr(self.function, name);
    }
}

obj PyBuildClass(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_build_class(args, kwargs);
    }
}

# ---------------- native descriptors: classmethod / staticmethod / property ----
# These are pervasive across the stdlib closure (enum, typing, abc, dataclasses).
# Each is a descriptor: attribute lookup on a class/instance resolves it through
# descriptor_get, which binds the class (classmethod), unwraps (staticmethod), or
# invokes the getter (property).
obj PyClassMethod(PyObj) {
    has func: PyObj;

    # `__func__` exposes the wrapped function (namedtuple rewrites
    # `_make.__func__.__qualname__`; functools/abc read it too).
    def tp_getattro(name: str) -> PyObj {
        if name == "__func__" {
            return self.func;
        }
        return py_attr(self.func, name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        return self.func.tp_setattro(name, value);
    }
}

obj PyStaticMethod(PyObj) {
    has func: PyObj;

    def tp_getattro(name: str) -> PyObj {
        if name == "__func__" {
            return self.func;
        }
        return py_attr(self.func, name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        return self.func.tp_setattro(name, value);
    }
}

obj PyProperty(PyObj) {
    has fget: any = None,
        fset: any = None,
        fdel: any = None;

    # `@x.setter` / `.getter` / `.deleter` each yield a modifier that rebuilds the
    # property with one accessor replaced.
    def tp_getattro(name: str) -> PyObj {
        if name == "setter" {
            return PyPropModifier(t="propmod", prop=self, which="set");
        }
        if name == "getter" {
            return PyPropModifier(t="propmod", prop=self, which="get");
        }
        if name == "deleter" {
            return PyPropModifier(t="propmod", prop=self, which="del");
        }
        if name == "fget" {
            return self.fget if self.fget is not None else py_none();
        }
        return py_error("AttributeError", name);
    }
}

obj PyPropModifier(PyObj) {
    has prop: PyProperty,
        which: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        fn = args[0];
        p = self.prop;
        if self.which == "set" {
            return PyProperty(t="property", fget=p.fget, fset=fn, fdel=p.fdel);
        }
        if self.which == "del" {
            return PyProperty(t="property", fget=p.fget, fset=p.fset, fdel=fn);
        }
        return PyProperty(t="property", fget=fn, fset=p.fset, fdel=p.fdel);
    }
}

# object.__init__ / a builtin's default __init__: accepts any args, does nothing.
# Reached when `inst.__init__(*args)` runs on an object whose class defines no
# __init__ (enum calls enum_member.__init__(*args) unconditionally).
obj PyNoOpInit(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_none();
    }
}

obj PyClassMethodCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "classmethod expected 1 argument");
        }
        return PyClassMethod(t="classmethod", func=args[0]);
    }
}

obj PyStaticMethodCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "staticmethod expected 1 argument");
        }
        return PyStaticMethod(t="staticmethod", func=args[0]);
    }
}

obj PyPropertyCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        fget: PyObj = py_none();
        fset: PyObj = py_none();
        fdel: PyObj = py_none();
        if len(args) >= 1 {
            fget = args[0];
        }
        if len(args) >= 2 {
            fset = args[1];
        }
        if len(args) >= 3 {
            fdel = args[2];
        }
        if "fget" in kwargs {
            fget = kwargs["fget"];
        }
        if "fset" in kwargs {
            fset = kwargs["fset"];
        }
        if "fdel" in kwargs {
            fdel = kwargs["fdel"];
        }
        return PyProperty(
            t="property",
            fget=fget if not isinstance(fget, PyNoneType) else None,
            fset=fset if not isinstance(fset, PyNoneType) else None,
            fdel=fdel if not isinstance(fdel, PyNoneType) else None
        );
    }
}

# The descriptor protocol for attribute access. `instance` is the object the
# attribute was fetched from (None for class-level access); `owner` is the class
# that supplied the attribute. Plain functions bind to a real instance and stay
# unbound on class access; the native descriptors do their own binding.
def descriptor_get(value: PyObj, instance: PyObj, owner: PyObj) -> PyObj {
    if isinstance(value, PyClassMethod) {
        return PyBoundMethod(
            t="bound_method", function=(value as PyClassMethod).func, receiver=owner
        );
    }
    if isinstance(value, PyStaticMethod) {
        return (value as PyStaticMethod).func;
    }
    if isinstance(value, PyProperty) {
        prop = value as PyProperty;
        if not isinstance(instance, PyNoneType) {
            if prop.fget is None {
                return py_error("AttributeError", "unreadable attribute");
            }
            return py_invoke(prop.fget as PyObj, [instance], {});
        }
        return value;
    }
    if value.t == "function" and not isinstance(instance, PyNoneType) {
        return PyBoundMethod(t="bound_method", function=value, receiver=instance);
    }
    return value;
}

obj PyFunction(PyObj) {
    has code: PyCode,
        globals: dict[str, PyObj],
        name: str,
        defaults: list[PyObj] = [],
        kwdefaults: dict[str, PyObj] = {},
        closure: list[PyCell] = [],
        # The function's writable __dict__ + overridable dunders. functools.wraps
        # / update_wrapper copy __module__/__name__/__qualname__/__doc__ and set
        # __wrapped__ here, so decorators (pervasive in the unittest closure) work.
        attrs: dict[str, PyObj] = {};

    def _func_doc -> PyObj {
        if len(self.code.consts) > 0 and isinstance(self.code.consts[0], PyStr) {
            return self.code.consts[0];
        }
        return py_none();
    }

    def tp_getattro(name: str) -> PyObj {
        if name in self.attrs {
            return self.attrs[name];
        }
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__qualname__" {
            return PyStr(t="str", val=self.code.qualname);
        }
        if name == "__doc__" {
            return self._func_doc();
        }
        if name == "__module__" {
            if "__name__" in self.globals {
                return self.globals["__name__"];
            }
            return py_none();
        }
        if name == "__defaults__" {
            if len(self.defaults) == 0 {
                return py_none();
            }
            return PyTuple(t="tuple", items=self.defaults);
        }
        if name == "__code__" {
            return self.code;
        }
        if name == "__dict__" {
            # functools.wraps / update_wrapper reads and updates a function's
            # __dict__ (WRAPPER_UPDATES). Snapshot of the writable attr map.
            return dict_from_str_map(self.attrs);
        }
        if name == "__wrapped__" {
            return py_error("AttributeError", name);
        }
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        self.attrs[name] = value;
        return py_none();
    }

    # Functions are hashable by identity (enum keys candidate __new__ callables in
    # a set; dispatch tables key on functions).
    def tp_hashkey -> str {
        return "obj:" + str(id(self));
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return exec_code_frame(
            self.code,
            args,
            kwargs,
            self.globals,
            {},
            self.closure,
            self.defaults,
            self.kwdefaults
        );
    }
}

def host_result_ok(result: any) -> bool {
    return result[0] == True;
}

def from_host(raw: any) -> PyObj {
    if raw is None {
        return py_none();
    }
    # A host instance whose type is a PROPER subclass of a builtin container/
    # scalar (namedtuple, IntEnum, a host-built `class X(list)`) must not be
    # flattened into a native PyTuple/PyList/PyInt -- that would erase its real
    # type and its own descriptors. Keep it as a proxy so p.x / .name / repr all
    # route back to the host object. (A trampoline we minted is recovered first.)
    if _jac_is_builtin_subclass_instance(raw) {
        recovered = _jac_recover_native(raw);
        if recovered is not None {
            return recovered as PyObj;
        }
        return PyHostProxy(t="host", val=raw);
    }
    if isinstance(raw, bool) {
        return PyBool(t="bool", val=raw);
    }
    if isinstance(raw, int) {
        return PyInt(t="int", val=raw);
    }
    if isinstance(raw, float) {
        return PyFloat(t="float", val=raw);
    }
    if isinstance(raw, str) {
        return PyStr(t="str", val=raw);
    }
    if isinstance(raw, bytes) {
        byte_values: list[int] = [];
        for item in raw {
            byte_values.append(item);
        }
        return PyBytes(t="bytes", val=byte_values);
    }
    if isinstance(raw, range) {
        range_values: list[PyObj] = [];
        for item in raw {
            range_values.append(PyInt(t="int", val=item));
        }
        return PyList(t="list", items=range_values);
    }
    if isinstance(raw, list) {
        list_values: list[PyObj] = [];
        for item in raw {
            list_values.append(from_host(item));
        }
        return PyList(t="list", items=list_values);
    }
    if isinstance(raw, tuple) {
        tuple_values: list[PyObj] = [];
        for item in raw {
            tuple_values.append(from_host(item));
        }
        return PyTuple(t="tuple", items=tuple_values);
    }
    if isinstance(raw, dict) {
        # Native PyDict now keys on the hash-key protocol, so any hashable key
        # (int, tuple, float, ...) lands natively. A key whose from_host wrapper
        # is unhashable (e.g. an opaque host object) keeps the whole dict opaque
        # as a PyHostProxy -- it round-trips through to_host unchanged.
        native = PyDict(t="dict", items={});
        for key in raw {
            keyobj = from_host(key);
            if keyobj.tp_hashkey() == "" {
                return PyHostProxy(t="host", val=raw);
            }
            native.dict_set(keyobj, from_host(raw[key]));
        }
        return native;
    }
    if isinstance(raw, frozenset) {
        fs = PySet(t="frozenset", items={}, frozen=True);
        for member in raw {
            memberobj = from_host(member);
            if memberobj.tp_hashkey() == "" {
                return PyHostProxy(t="host", val=raw);
            }
            fs.set_add(memberobj);
        }
        return fs;
    }
    if isinstance(raw, set) {
        ns = PySet(t="set", items={}, frozen=False);
        for member in raw {
            memberobj = from_host(member);
            if memberobj.tp_hashkey() == "" {
                return PyHostProxy(t="host", val=raw);
            }
            ns.set_add(memberobj);
        }
        return ns;
    }
    # A host trampoline coming back home (e.g. a native __new__ that host type()
    # stored, then handed back on class construction) recovers its original
    # native function rather than nesting host->native->host indirection.
    recovered = _jac_recover_native(raw);
    if recovered is not None {
        return recovered as PyObj;
    }
    return PyHostProxy(t="host", val=raw);
}

def to_host(value: PyObj) -> any {
    match value {
        case PyNoneType():
            return None;

        case PyBool():
            return value.val;

        case PyInt():
            return value.val;

        case PyFloat():
            return value.val;

        case PyComplex():
            return complex(value.real, value.imag);

        case PyStr():
            return value.val;

        case PyBytes():
            return bytes(value.val);

        case PyTuple():
            tuple_items: list[any] = [];
            for item in value.items {
                tuple_items.append(to_host(item));
            }
            return tuple(tuple_items);

        case PyList():
            list_items: list[any] = [];
            for item in value.items {
                list_items.append(to_host(item));
            }
            return list_items;

        case PyDict():
            dict_items: dict[any, any] = {};
            for hk in value.items {
                `entry = value.items[hk];
                dict_items[to_host(`entry.key)] = to_host(`entry.value);
            }
            return dict_items;

        case PySet():
            members: list[any] = [];
            for member in value.set_members() {
                members.append(to_host(member));
            }
            if value.frozen {
                return frozenset(members);
            }
            return set(members);

        case PySlice():
            return slice(
                to_host(value.start), to_host(value.stop), to_host(value.step)
            );

        case PyFunction():
            # A native function crossing to the host becomes a trampoline that
            # calls back into ceval (see _jac_make_host_trampoline). This is what
            # lets host type()/classmethod/property/functools wrap and later
            # invoke jacpython functions -- the round-trip that unblocks
            # namedtuple's dynamic class creation and decorator machinery.
            return _jac_make_host_trampoline(value);

        case PyNativeBuiltin():
        case PyBoundMethod():
        case PyGenMethod():
            # Native builtins/bound methods crossing to the host become
            # trampolines too (same round-trip as PyFunction): host code can
            # call them and from_host recovers the native via __jac_native__.
            return _jac_make_host_trampoline(value);

        case PyListMethod():
        case PyDictMethod():
        case PySetMethod():
            return _jac_make_host_trampoline(value);

        case PyNativeNew():
            # object.__new__ / tuple.__new__ crossing to the host (namedtuple binds
            # `_tuple_new = tuple.__new__`) becomes the real host builtin __new__.
            return _jac_builtin_new_slot(value.base_name);

        case PyClassMethod():
            # A native classmethod handed to host type()/a host class becomes a
            # real host classmethod over the wrapped function's trampoline, so
            # `Cls.cmeth(...)` dispatched by the host binds the class correctly.
            return _jac_wrap_classmethod(to_host(value.func));

        case PyStaticMethod():
            return _jac_wrap_staticmethod(to_host(value.func));

        case PyProperty():
            fget = to_host(value.fget as PyObj) if value.fget is not None else None;
            fset = to_host(value.fset as PyObj) if value.fset is not None else None;
            fdel = to_host(value.fdel as PyObj) if value.fdel is not None else None;
            return _jac_wrap_property(fget, fset, fdel);

        case PyIter():
            # A native iterator crossing the host boundary drains into a host
            # list so host consumers (list()/tuple()/sum()/for-in via trampoline)
            # see its remaining items instead of None. Laziness is already lost
            # at this boundary.
            iter_drained: list[any] = [];
            while value.index < len(value.items) {
                iter_drained.append(to_host(value.items[value.index]));
                value.index = value.index + 1;
            }
            return iter_drained;

        case PyHostProxy():
            return value.val;

        case PyException():
            # A caught exception crossing to the host (str(e)/repr(e)/type(e), or
            # handed to host logging/warnings) becomes a REAL host exception
            # instance carrying the same args -- previously this fell through to
            # None, so str(e) was "None" and type(e) was NoneType.
            return host_exception(value);

        case PyUserObj():
            # A builtin subclass reaching the host boundary (len/print/format)
            # presents as its boxed value; a plain user object has no host form.
            if value._has_base() {
                return to_host(value._base_obj());
            }
            return None;

        case PyGenerator():
            # A native genexpr reaching the host boundary (list(gen)/tuple(gen)/
            # sum(gen)/...) is drained through the real suspend/resume machinery
            # into a host list, which every iterable-consuming builtin accepts.
            drained = gen_drain(value);
            return to_host(drained);

        case PyDictView():
            # Rebuild a real host dict and hand back the matching live view, so
            # both iteration (list()/sorted()/set()) AND repr round-trip: repr of
            # the result is `dict_keys([...])`/`dict_values([...])`/`dict_items([
            # ...])`, not a bare list. Order follows the dict's insertion order.
            hd: dict[any, any] = {};
            for hk in value.d.items {
                `entry = value.d.items[hk];
                hd[to_host(`entry.key)] = to_host(`entry.value);
            }
            if value.mode == "values" {
                return hd.values();
            }
            if value.mode == "items" {
                return hd.items();
            }
            return hd.keys();

    }
    return None;
}

def host_builtin(name: str) -> PyObj {
    if name == "Exception"
        or name == "BaseException"
        or name == "ValueError"
        or name == "TypeError"
        or name == "KeyError"
        or name == "IndexError"
        or name == "AttributeError"
        or name == "NameError"
        or name == "ZeroDivisionError"
        or name == "ImportError"
        or name == "StopIteration"
        or name == "StopAsyncIteration"
        or name == "GeneratorExit"
        or name == "RuntimeError" {
        return py_exception_type(name);
    }
    # next()/iter() are handled natively so a native generator or iterator is
    # driven one step in-VM instead of being drained across the host boundary.
    # id() is native so it reports stable object identity (consistent with `is`)
    # rather than the host id of a throwaway to_host value. len() reads a native
    # container's own size (and dispatches __len__) instead of counting a
    # to_host copy, which drops plain user objects held as members/keys.
    # getattr/setattr/hasattr must be native: they route through py_attr so a
    # native object's own attributes (a PyFunction's __module__, a PyModule's
    # members, a user class's descriptors) are seen, instead of host getattr on
    # a lossy to_host copy. This is load-bearing for the import closure, where
    # decorators (functools.wraps, reprlib.recursive_repr) copy dunders via
    # getattr(fn, '__module__').
    if name == "next"
        or name == "iter"
        or name == "id"
        or name == "len"
        or name == "repr"
        or name == "hash"
        or name == "isinstance"
        or name == "issubclass"
        or name == "getattr"
        or name == "setattr"
        or name == "hasattr"
        or name == "delattr"
        or name == "globals" {
        # globals() must be native: it returns a LIVE view of the running frame's
        # module namespace, so `globals().update({...})` / `globals()[k] = v`
        # (module init idioms, e.g. re._constants) bind real module globals that a
        # later LOAD_GLOBAL can see. The call site in run_frame supplies the ns.
        return PyNativeBuiltin(t="native_builtin", name=name);
    }
    # classmethod/staticmethod/property are native descriptors so a method decorated
    # with them is resolved in-VM (bound to the class, unwrapped, or invoked as a
    # getter) instead of being frozen into an uncallable host wrapper. Pervasive in
    # enum/abc/typing/dataclasses.
    if name == "classmethod" {
        return PyClassMethodCtor(t="classmethod_ctor");
    }
    if name == "staticmethod" {
        return PyStaticMethodCtor(t="staticmethod_ctor");
    }
    if name == "property" {
        return PyPropertyCtor(t="property_ctor");
    }
    result = _jac_host_builtin(name);
    if host_result_ok(result) {
        return PyHostProxy(t="host", val=result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_import(name: str, fromlist: PyObj) -> PyObj {
    if name == "weakref" and not ("weakref" in shim_modules) {
        # The host module's ref() sees to_host conversions (plain objects ->
        # None), so serve our identity-faithful shim instead.
        shim_modules["weakref"] = build_weakref_module();
    }
    if name in shim_modules {
        return shim_modules[name];
    }
    result = _jac_host_import(name, to_host(fromlist));
    if host_result_ok(result) {
        return PyHostProxy(t="host", val=result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

# LOAD_GLOBAL/LOAD_NAME fallthrough after locals/globals: builtins resolve
# here. A miss must surface as CPython's NameError, not the AttributeError the
# host getattr inside _jac_host_builtin would raise.
def load_name_fallback(name: str) -> PyObj {
    value = host_builtin(name);
    if is_error(value) {
        return py_error("NameError", "name '" + name + "' is not defined");
    }
    return value;
}

# type(obj): the object's type. A native user instance answers with its own
# PyClass; a class answers with its metaclass (or the host `type` for the default);
# everything else (scalars, proxied host values) round-trips through host type().
def py_type_of(o: PyObj) -> PyObj {
    if isinstance(o, PyUserObj) {
        return (o as PyUserObj).cls as PyObj;
    }
    if isinstance(o, PyClass) {
        m = (o as PyClass).metaclass;
        if m is not None and isinstance(m, PyClass) {
            return m as PyObj;
        }
        return host_builtin("type");
    }
    # Native callable wrappers have no faithful host object (to_host drops
    # them), so answer with the matching HOST callable type instead of NoneType
    # via the to_host fallthrough. CPython distinguishes builtin_function_or_
    # method (builtins/bound builtins), method (bound user functions), and the
    # concrete iterator types.
    if isinstance(o, PyNativeBuiltin) or isinstance(o, PyListMethod)
        or isinstance(o, PyDictMethod) or isinstance(o, PySetMethod) {
        return from_host(_jac_builtin_function_or_method_type());
    }
    if isinstance(o, PyBoundMethod) or isinstance(o, PyGenMethod) {
        return from_host(_jac_bound_method_type());
    }
    if isinstance(o, PyIter) {
        return from_host(_jac_list_iterator_type());
    }
    return from_host(_jac_host_type(to_host(o)));
}

# Build a real host exception instance from a native PyException, so the host's
# own str()/repr()/type()/isinstance machinery drives it. Uses the recorded args
# (falling back to `message` for VM-raised errors, which carry no args tuple). A
# non-builtin type_name (a user Exception subclass) can't be reconstructed as a
# host type, so it degrades to a plain Exception carrying the message -- enough
# for str()/repr(); `except <UserClass>` matching stays native (exception_matches
# uses the raw PyUserObj's MRO, never this host form).
def host_exception(exc: PyException) -> any {
    raw_args: list[any] = [];
    for a in exc.args {
        raw_args.append(to_host(a));
    }
    if len(raw_args) == 0 and exc.message != "" {
        raw_args.append(exc.message);
    }
    built = _jac_construct_builtin(exc.type_name, raw_args);
    if bool(built[0]) {
        return built[1];
    }
    fallback = _jac_construct_builtin("Exception", raw_args);
    return fallback[1];
}

# f-string / format machinery. Formatting is delegated to host CPython's
# format()/repr()/ascii() during bootstrap -- the __format__ / __str__ protocols
# are not natively ported yet, and routing here keeps objects.jac na-clean.
def host_format(value: PyObj, spec: str) -> PyObj {
    result = _jac_host_format(to_host(value), spec);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_convert(value: PyObj, conv: int) -> PyObj {
    result = _jac_host_convert(to_host(value), conv);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_getattr(value: PyObj, name: str) -> PyObj {
    result = _jac_host_getattr(to_host(value), name);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_getitem(value: PyObj, index: PyObj) -> PyObj {
    result = _jac_host_getitem(to_host(value), to_host(index));
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def host_setattr(value: PyObj, name: str, field: PyObj) -> PyObj {
    result = _jac_host_setattr(to_host(value), name, to_host(field));
    if host_result_ok(result) {
        return py_none();
    }
    return py_error(str(result[1]), str(result[2]));
}


# ---------------- ceval ----------------
# Opcode numbers and cache metadata: opcode_meta.jac (PLAN.md P0.1).

# The dispatchers below are thin adapters over the object model's virtual
# slots: they exist only so the ceval reads naturally. Behavior selection is
# the method call (self's vtable), never a tag comparison.
def py_truth(value: PyObj) -> bool {
    return value.tp_bool();
}

# A key/value that is NOT a builtin (a user object or a host proxy) can carry a
# custom __eq__, so the hashkey-bucket match must be confirmed with a real
# comparison. Between two builtins the hashkey protocol already IS value equality
# (numeric collapse included), so the confirming eq is skipped -- the fast path.
def _needs_eq_confirm(o: PyObj) -> bool {
    return isinstance(o, PyUserObj) or isinstance(o, PyHostProxy);
}

# CPython tuple_repr: trailing comma for length-1 tuples.
def tuple_repr(v: PyTuple) -> PyObj {
    if len(v.items) == 0 {
        return PyStr(t="str", val="()");
    }
    out = "(";
    i = 0;
    while i < len(v.items) {
        if i > 0 {
            out = out + ", ";
        }
        piece = py_repr(v.items[i]);
        if is_error(piece) {
            return piece;
        }
        out = out + (piece as PyStr).val;
        i = i + 1;
    }
    if len(v.items) == 1 {
        out = out + ",";
    }
    return PyStr(t="str", val=out + ")");
}

# Native repr(): scalars, containers, class + user __repr__ in-VM; remainder
# falls back to host_convert(..., 2).
def py_obj_is_type(value: PyObj) -> bool {
    if isinstance(value, PyClass) {
        return True;
    }
    if isinstance(value, PyHostProxy) {
        return bool(_jac_host_val_is_type((value as PyHostProxy).val));
    }
    return False;
}

def py_type_same(a: PyObj, b: PyObj) -> bool {
    if a is b {
        return True;
    }
    if isinstance(a, PyHostProxy) and isinstance(b, PyHostProxy) {
        return (a as PyHostProxy).val is (b as PyHostProxy).val;
    }
    return False;
}

def py_repr(value: PyObj) -> PyObj {
    if isinstance(value, PyException) {
        return baseexception_repr(value as PyException, py_repr);
    }
    if isinstance(value, PyTuple) {
        return tuple_repr(value as PyTuple);
    }
    if isinstance(value, PyList) {
        return list_repr(value as PyList, py_repr);
    }
    if isinstance(value, PyBytes) {
        return bytes_repr(value as PyBytes);
    }
    if isinstance(value, PyDict) {
        return dict_repr(value as PyDict, py_repr);
    }
    if isinstance(value, PyClass) {
        c = value as PyClass;
        mod = "";
        if "__module__" in c.attrs {
            m = c.attrs["__module__"];
            if isinstance(m, PyStr) {
                mod = (m as PyStr).val;
            }
        } elif "__name__" in c.attrs {
            m = c.attrs["__name__"];
            if isinstance(m, PyStr) {
                mod = (m as PyStr).val;
            }
        }
        return type_repr(type_tp_name(c.name, mod));
    }
    if isinstance(value, PyStr) {
        return str_repr(value as PyStr);
    }
    if isinstance(value, PyInt) {
        return int_repr(value as PyInt);
    }
    if isinstance(value, PyFloat) {
        return float_repr(value as PyFloat);
    }
    if isinstance(value, PyBool) or isinstance(value, PyNoneType) {
        return PyStr(t="str", val=_pyobj_repr(value));
    }
    if isinstance(value, PyUserObj) {
        method = py_attr(value, "__repr__");
        if not is_error(method) {
            res = py_invoke(method, [], {});
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyStr) {
                return res;
            }
            return py_error("TypeError", "__repr__ returned non-string");
        }
    }
    # Native bound-method/builtin wrappers have no faithful host form (to_host
    # drops them to None, which would repr as 'None'), so synthesize the
    # CPython-style repr minus the embedded address.
    if isinstance(value, PyListMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PyListMethod).name + " of list object>");
    }
    if isinstance(value, PyDictMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PyDictMethod).name + " of dict object>");
    }
    if isinstance(value, PySetMethod) {
        return PyStr(t="str", val="<built-in method " + (value as PySetMethod).name + " of set object>");
    }
    if isinstance(value, PyNativeBuiltin) {
        return PyStr(t="str", val="<built-in function " + (value as PyNativeBuiltin).name + ">");
    }
    if isinstance(value, PyIter) {
        # repr is observational: it must NOT route through to_host, whose drain
        # would exhaust the iterator as a side effect.
        return PyStr(t="str", val="<iterator object>");
    }
    result = host_convert(value, 2);
    if is_error(result) {
        return result;
    }
    return result;
}

def py_compare(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    if isinstance(lhs, PyUserObj) or isinstance(rhs, PyUserObj) {
        return user_compare(kind, lhs, rhs);
    }
    # A dict view on either side compares set-like (keys/items), invoking element
    # __eq__: {1:1}.keys() == {1}, and d1.items() == d2.items() propagating a raise.
    if isinstance(lhs, PyDictView) or isinstance(rhs, PyDictView) {
        return dictview_richcompare(kind, lhs, rhs);
    }
    if isinstance(lhs, PyDict) and isinstance(rhs, PyDict) {
        return dict_richcompare(kind, lhs as PyDict, rhs as PyDict, py_compare);
    }
    if isinstance(lhs, PyList) and isinstance(rhs, PyList) {
        return list_richcompare(kind, lhs as PyList, rhs as PyList, py_compare);
    }
    if isinstance(lhs, PyTuple) and isinstance(rhs, PyTuple) {
        return tuple_richcompare(kind, lhs as PyTuple, rhs as PyTuple);
    }
    if isinstance(lhs, PyBytes) and isinstance(rhs, PyBytes) {
        return bytes_richcompare(kind, lhs as PyBytes, rhs as PyBytes);
    }
    if isinstance(lhs, PySet) and isinstance(rhs, PySet) {
        return set_richcompare(kind, lhs as PySet, rhs as PySet);
    }
    if py_obj_is_type(lhs) and py_obj_is_type(rhs) {
        return type_richcompare_same(kind, py_type_same(lhs, rhs));
    }
    return PyObject_RichCompare(lhs, rhs, kind);
}

# Native nb_binop covers the ported fast paths (int/str Gap #2 %-format, tuple/
# list concat, ...). Operand/format combos not yet ported (str % with %f/%i or
# multiple args, str * int, ...) fall back across the substrate to host CPython
# when both operands are host-backed. Purely additive: only a native error
# triggers the fallback, so ported semantics always win.
def host_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    result = _jac_host_binop(kind, to_host(lhs), to_host(rhs));
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def _host_representable(t: str) -> bool {
    # Native PySet is fully to_host-representable, so a mixed native-set / host
    # operand binop (e.g. dict.keys() | {2}) can still fall back to the host.
    # Native set | set never reaches here -- PySet.nb_binop answers it directly.
    return _is_host_backed(t) or t == "host" or t == "set" or t == "frozenset";
}

# Object identity for `is` / `id()`. None and booleans are true singletons in
# CPython, and small ints [-5, 256] are cached, so for these three identity is
# deterministically value-equality -- we answer them by value and match CPython
# without interning every construction site (which the na-clean leaf can't hold
# a persistent singleton for anyway). Every other object uses real Jac reference
# identity: fresh containers/strings/big-ints are `is`-equal only when aliased.
def _small_int_cached(v: int) -> bool {
    return v >= -5 and v <= 256;
}

def py_identity(a: PyObj, b: PyObj) -> bool {
    if isinstance(a, PyNoneType) or isinstance(b, PyNoneType) {
        return isinstance(a, PyNoneType) and isinstance(b, PyNoneType);
    }
    if isinstance(a, PyBool) and isinstance(b, PyBool) {
        return (a as PyBool).val == (b as PyBool).val;
    }
    if isinstance(a, PyInt) and isinstance(b, PyInt) {
        av = (a as PyInt).val;
        bv = (b as PyInt).val;
        if av == bv and _small_int_cached(av) {
            return True;
        }
        return a is b;
    }
    # Two proxies to the SAME host object are the same object: `type(x) is str`
    # (str being a host-type proxy, type(x) another) must hold, or CPython idioms
    # like namedtuple's `type(name) is not str` field-name check spuriously fail.
    if isinstance(a, PyHostProxy) and isinstance(b, PyHostProxy) {
        return (a as PyHostProxy).val is (b as PyHostProxy).val;
    }
    return a is b;
}

# id(): stable per-object integer. For the cached-immutable classes above, return
# a synthetic id in a reserved low band so `id(x) == id(y)` iff `x is y` stays
# consistent with py_identity; every other object reports its Jac reference id.
def py_id(o: PyObj) -> int {
    if isinstance(o, PyNoneType) {
        return 1;
    }
    if isinstance(o, PyBool) {
        if (o as PyBool).val {
            return 3;
        }
        return 2;
    }
    if isinstance(o, PyInt) {
        v = (o as PyInt).val;
        if _small_int_cached(v) {
            return 1000 + v;
        }
    }
    # A proxy's identity is its underlying host object's identity (consistent
    # with py_identity treating same-host-object proxies as one object).
    if isinstance(o, PyHostProxy) {
        return id((o as PyHostProxy).val);
    }
    return id(o);
}

# A dunder returned NotImplemented (native sentinel or host singleton proxy).
def is_notimplemented(o: PyObj) -> bool {
    if o is PY_NOT_IMPLEMENTED {
        return True;
    }
    if isinstance(o, PyHostProxy) {
        return _jac_is_notimpl((o as PyHostProxy).val) as bool;
    }
    return False;
}

# ---- user-class operator overloading (__add__/__eq__/... dispatch) ---------
# The native nb_binop/tp_richcompare slots only know builtin types; a plain user
# class defines operators as `__add__`/`__eq__`/... methods in its class dict.
# These helpers implement CPython's binary-operator protocol (normal slot, then
# reflected slot, then TypeError) over the MRO for PyUserObj operands.

# NB_ binop kind -> dunder name ("" if the kind has no overload slot).
def binop_dunder(kind: int) -> str {
    names = [
        "__add__",
        "__and__",
        "__floordiv__",
        "__lshift__",
        "__matmul__",
        "__mul__",
        "__mod__",
        "__or__",
        "__pow__",
        "__rshift__",
        "__sub__",
        "__truediv__",
        "__xor__"
    ];
    if kind >= 0 and kind < len(names) {
        return names[kind];
    }
    return "";
}

# Reflected counterpart (__radd__/__rmul__/...) for the same kind.
def binop_rdunder(kind: int) -> str {
    names = [
        "__radd__",
        "__rand__",
        "__rfloordiv__",
        "__rlshift__",
        "__rmatmul__",
        "__rmul__",
        "__rmod__",
        "__ror__",
        "__rpow__",
        "__rrshift__",
        "__rsub__",
        "__rtruediv__",
        "__rxor__"
    ];
    if kind >= 0 and kind < len(names) {
        return names[kind];
    }
    return "";
}

# Rich-compare kind (0<,1<=,2==,3!=,4>,5>=) -> dunder name.
def compare_dunder(kind: int) -> str {
    names = ["__lt__", "__le__", "__eq__", "__ne__", "__gt__", "__ge__"];
    if kind >= 0 and kind < len(names) {
        return names[kind];
    }
    return "";
}

# Reflected comparison kind: < <-> >, <= <-> >=, ==/!= are self-reflected.
def compare_swap(kind: int) -> int {
    swap = [4, 5, 2, 3, 0, 1];
    if kind >= 0 and kind < len(swap) {
        return swap[kind];
    }
    return kind;
}

def user_has_dunder(u: PyUserObj, name: str) -> bool {
    return not is_error(class_lookup_attr(u.cls, name));
}

# CPython operator subclass priority: when `type(rhs)` is a PROPER subclass of
# `type(lhs)` and overrides the reflected slot (`rname`), the reflected call is
# tried BEFORE the left operand's forward slot. True iff that reordering applies.
def rhs_reflected_priority(lhs: PyObj, rhs: PyObj, rname: str) -> bool {
    if rname == "" {
        return False;
    }
    if not (isinstance(lhs, PyUserObj) and isinstance(rhs, PyUserObj)) {
        return False;
    }
    lcls = (lhs as PyUserObj).cls;
    rcls = (rhs as PyUserObj).cls;
    if lcls is rcls {
        return False;
    }
    # rhs's class must be a proper subclass of lhs's class (it already differs).
    if not instance_of_class(rhs as PyUserObj, lcls) {
        return False;
    }
    return user_has_dunder(rhs as PyUserObj, rname);
}

# Bind the MRO-resolved dunder to the receiver and call it with `args`. The
# result -- a value, a raised exception (PyError), or NotImplemented -- is
# returned verbatim for the protocol layer to interpret.
def call_user_dunder(u: PyUserObj, name: str, args: list[PyObj]) -> PyObj {
    method = class_lookup_attr(u.cls, name);
    return bind_attribute(method, u).tp_call(args, {});
}

# CPython binary-operator protocol for PyUserObj operands: try lhs.__op__(rhs),
# then the reflected rhs.__rop__(lhs); a builtin-subclass operand with no user
# override delegates to its boxed value; otherwise TypeError. A raised exception
# from a dunder propagates immediately (it is not NotImplemented).
def user_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    name = binop_dunder(kind);
    rname = binop_rdunder(kind);
    # Subclass reflected priority: A() + B() where B(A) overrides __radd__ runs
    # B.__radd__ first (CPython rule).
    if rhs_reflected_priority(lhs, rhs, rname) {
        res = call_user_dunder(rhs as PyUserObj, rname, [lhs]);
        if not is_notimplemented(res) {
            return res;
        }
    }
    if isinstance(lhs, PyUserObj) {
        lu = lhs as PyUserObj;
        if name != "" and user_has_dunder(lu, name) {
            res = call_user_dunder(lu, name, [rhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    if isinstance(rhs, PyUserObj) {
        ru = rhs as PyUserObj;
        if rname != "" and user_has_dunder(ru, rname) {
            res = call_user_dunder(ru, rname, [lhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    # No user override matched: a builtin subclass acts as its boxed value.
    if isinstance(lhs, PyUserObj) and (lhs as PyUserObj)._has_base() {
        r = (lhs as PyUserObj)._base_obj().nb_binop(kind, unwrap_base(rhs));
        if not is_error(r) {
            return r;
        }
    }
    if isinstance(rhs, PyUserObj) and (rhs as PyUserObj)._has_base() {
        r = unwrap_base(lhs).nb_binop(kind, (rhs as PyUserObj)._base_obj());
        if not is_error(r) {
            return r;
        }
    }
    return py_error("TypeError", "unsupported operand type(s)");
}

# CPython rich-comparison protocol for PyUserObj operands. Same shape as
# user_binop, plus the == / != identity fallback when neither side overrides.
def user_compare(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    name = compare_dunder(kind);
    rname = compare_dunder(compare_swap(kind));
    # Subclass reflected priority: rhs's reflected comparison runs first when
    # type(rhs) is a proper subclass of type(lhs) and overrides it.
    if rhs_reflected_priority(lhs, rhs, rname) {
        res = call_user_dunder(rhs as PyUserObj, rname, [lhs]);
        if not is_notimplemented(res) {
            return res;
        }
    }
    # A builtin subclass's OWN comparison dunder wins (class MyInt(int) that
    # overrides __eq__), mirroring user_binop -- user_has_dunder only finds it
    # when the user class actually defines it, so an unoverridden subclass still
    # falls through to the boxed-value comparison below.
    if isinstance(lhs, PyUserObj) {
        lu = lhs as PyUserObj;
        if name != "" and user_has_dunder(lu, name) {
            res = call_user_dunder(lu, name, [rhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    if isinstance(rhs, PyUserObj) {
        ru = rhs as PyUserObj;
        if rname != "" and user_has_dunder(ru, rname) {
            res = call_user_dunder(ru, rname, [lhs]);
            if not is_notimplemented(res) {
                return res;
            }
        }
    }
    if isinstance(lhs, PyUserObj) and (lhs as PyUserObj)._has_base() {
        res = (lhs as PyUserObj)._base_obj().tp_richcompare(kind, unwrap_base(rhs));
        if not is_notimplemented(res) {
            return res;
        }
    }
    if isinstance(rhs, PyUserObj) and (rhs as PyUserObj)._has_base() {
        res = unwrap_base(lhs).tp_richcompare(kind, (rhs as PyUserObj)._base_obj());
        if not is_notimplemented(res) {
            return res;
        }
    }
    if kind == 2 {
        return PyBool(t="bool", val=lhs is rhs);
    }
    if kind == 3 {
        return PyBool(t="bool", val=lhs is not rhs);
    }
    return py_error("TypeError", "unorderable types");
}

def py_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    # NB_INPLACE_* (13..25) reduce to their base binop (0..12). jacpython values
    # are immutable at this layer, so `x += y` is `x = x + y` -- the trailing
    # STORE rebinds the name, matching CPython's immutable-type fallback.
    if kind >= 13 and kind <= 25 {
        kind = kind - 13;
    }
    # A user-class operand routes through the operator-overload protocol first.
    if isinstance(lhs, PyUserObj) or isinstance(rhs, PyUserObj) {
        return user_binop(kind, lhs, rhs);
    }
    # A dict view on either side does set algebra (| & - ^) yielding a PySet,
    # e.g. {1:1}.keys() | {2} and {2} | {1:1}.items().
    if isinstance(lhs, PyDictView) or isinstance(rhs, PyDictView) {
        return dictview_binop(kind, lhs, rhs);
    }
    result = lhs.nb_binop(kind, rhs);
    if is_error(result) {
        # A builtin-subclass operand the other side's slot didn't recognize
        # (e.g. 1 + MyInt(5), where int.nb_binop rejects the "instance" tag):
        # retry with both operands unwrapped to their boxed values.
        ul = unwrap_base(lhs);
        ur = unwrap_base(rhs);
        if not (ul is lhs) or not (ur is rhs) {
            result = ul.nb_binop(kind, ur);
        }
    }
    if is_error(result) and _host_representable(lhs.t) and _host_representable(rhs.t) {
        # Fall back when native slots are incomplete (TypeError, ValueError from
        # partial str %-format, ...). Operational numeric errors must stay native
        # so exception messages match CPython in-VM (e.g. str(e) after `1 // 0`).
        err = result as PyError;
        tn = err.exception.type_name;
        if tn != "ZeroDivisionError" and tn != "OverflowError" {
            return host_binop(kind, lhs, rhs);
        }
    }
    return result;
}

def py_subscript(container: PyObj, index: PyObj) -> PyObj {
    return container.mp_subscript(index);
}

# Membership test (CONTAINS_OP). Native sets/dicts answer via the hash-key
# protocol; other container shapes route through the host so `in` stays
# consistent for opaque proxies during bootstrap.
def py_contains(container: PyObj, member: PyObj) -> PyObj {
    if isinstance(container, PyDictView) {
        return view_contains(container as PyDictView, member);
    }
    if isinstance(container, PySet) {
        return (container as PySet).set_lookup(member);
    }
    if isinstance(container, PyDict) {
        return PyBool(t="bool", val=(container as PyDict).dict_contains(member));
    }
    # Native tuple/list membership compares elements with a real == in-VM. Routing
    # through the host collapses every native class/instance to None (to_host), so
    # `SomeClass in (OtherClass,)` would wrongly match; keep it native.
    if isinstance(container, PyTuple) or isinstance(container, PyList) {
        elems: list[PyObj] = [];
        if isinstance(container, PyTuple) {
            elems = (container as PyTuple).items;
        } else {
            elems = (container as PyList).items;
        }
        for item in elems {
            cmp = py_compare(2, member, item);
            if is_error(cmp) {
                return cmp;
            }
            if cmp.tp_bool() {
                return PyBool(t="bool", val=True);
            }
        }
        return PyBool(t="bool", val=False);
    }
    result = _jac_host_contains(to_host(member), to_host(container));
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def py_store_subscript(container: PyObj, index: PyObj, value: PyObj) -> PyObj {
    return container.mp_ass_subscript(index, value);
}

def py_delete_subscript(container: PyObj, index: PyObj) -> PyObj {
    return container.mp_del_subscript(index);
}

# DICT_UPDATE/DICT_MERGE source view: yields the str-keyed pairs to merge into
# the target dict. Native PyDict is returned directly; a host-backed mapping
# (PyHostProxy) is converted via from_host, which lands as a PyDict when its
# keys are strings. Non-mapping / non-str-key sources produce an empty view.
def dict_merge_pairs(source: PyObj) -> PyDict {
    if isinstance(source, PyDict) {
        return source as PyDict;
    }
    if isinstance(source, PyHostProxy) {
        converted = from_host((source as PyHostProxy).val);
        if isinstance(converted, PyDict) {
            return converted as PyDict;
        }
    }
    return PyDict(t="dict", items={});
}

# UNARY_NEGATIVE (-x). int/bool negate to int (-True == -1), float to float; any
# other operand is a TypeError, matching CPython's nb_negative == NULL path.
def py_negative(value: PyObj) -> PyObj {
    if isinstance(value, PyBool) {
        v = 0;
        if (value as PyBool).val {
            v = 1;
        }
        return PyInt(t="int", val=-v);
    }
    if isinstance(value, PyInt) {
        return PyInt(t="int", val=-(value as PyInt).val);
    }
    if isinstance(value, PyFloat) {
        return PyFloat(t="float", val=-(value as PyFloat).val);
    }
    return py_error("TypeError", "bad operand type for unary -");
}

# UNARY_INVERT (~x). Defined only for ints/bools: ~x == -x - 1.
def py_invert(value: PyObj) -> PyObj {
    if isinstance(value, PyBool) {
        v = 0;
        if (value as PyBool).val {
            v = 1;
        }
        return PyInt(t="int", val=-v - 1);
    }
    if isinstance(value, PyInt) {
        return PyInt(t="int", val=-(value as PyInt).val - 1);
    }
    return py_error("TypeError", "bad operand type for unary ~");
}

def append_to_list(target: PyObj, iterable: PyObj) {
    target_list = target as PyList;
    if iterable.t == "list" {
        target_list.items.extend(list_value(iterable));
    } elif iterable.t == "tuple" {
        target_list.items.extend(tuple_value(iterable));
    } elif iterable.t == "str" {
        for ch in str_value(iterable) {
            target_list.items.append(PyStr(t="str", val=ch));
        }
    }
}

# Native scalar/container tags whose method surface is not yet ported. During
# bootstrap their attribute lookups fall back across the substrate boundary to
# host CPython (host_getattr returns a bound method, which from_host wraps as a
# callable PyHostProxy). This is the object-core-clean seam: the fallback lives
# here in pyc_first (host-allowed), never in the na-clean objects.jac, so e.g.
# 'abc'.upper() / {}.copy() / dict().keys() work before their native ports land.
def _is_host_backed(t: str) -> bool {
    return t == "str"
        or t == "bytes"
        or t == "int"
        or t == "bool"
        or t == "float"
        or t == "list"
        or t == "tuple"
        or t == "dict"
        or t == "complex";
}

def py_attr(value: PyObj, name: str) -> PyObj {
    result = value.tp_getattro(name);
    # A native dict's keys()/values()/items() are bound zero-arg constructors of
    # a live, set-like PyDictView (not host proxies), so view comparison / set
    # algebra can invoke element __eq__ and iteration carries the mutation guard.
    if is_error(result)
        and isinstance(value, PyDict)
        and (name == "keys" or name == "values" or name == "items") {
        return PyDictViewCtor(t="view_ctor", d=value as PyDict, mode=name);
    }
    # Native mutating/accessor dict methods, so a dict-subclass mutation lands in
    # real storage rather than a to_host copy.
    if is_error(result) and isinstance(value, PyDict) and is_dict_method(name) {
        return PyDictMethod(t="dict_method", target=value as PyDict, name=name);
    }
    # Native list methods, so `lst.append(x)` mutates the real list, not a copy.
    if is_error(result) and isinstance(value, PyList) and is_list_method(name) {
        return PyListMethod(t="list_method", target=value as PyList, name=name);
    }
    if is_error(result)
        and isinstance(value, PySet)
        and is_set_method(name, (value as PySet).frozen) {
        return PySetMethod(t="set_method", target=value as PySet, name=name);
    }
    if is_error(result) and _is_host_backed(value.t) {
        return host_getattr(value, name);
    }
    # `.__new__` on any object with no override is object.__new__ (inherited), so
    # None.__new__ / instance.__new__ resolve instead of raising -- enum compares
    # candidate constructors against object.__new__.
    if is_error(result) and name == "__new__" {
        return PyNativeNew(t="native_new", base_name="object");
    }
    # `.__init__` with no user override is object.__init__ (a no-op accepting any
    # args), so inst.__init__(*args) resolves rather than raising.
    if is_error(result) and name == "__init__" {
        return PyNoOpInit(t="noop_init");
    }
    return result;
}

def bind_attribute(value: PyObj, receiver: PyObj) -> PyObj {
    # Explicit bind (a looked-up __init__/__new__/__prepare__ against a known
    # receiver). Routes through the descriptor protocol so a classmethod binds its
    # class and a staticmethod unwraps, not just a plain function.
    if isinstance(value, PyClassMethod) or isinstance(value, PyStaticMethod) {
        return descriptor_get(value, receiver, receiver);
    }
    if value.t == "function" {
        return PyBoundMethod(t="bound_method", function=value, receiver=receiver);
    }
    return value;
}

def py_set_attr(value: PyObj, name: str, field: PyObj) -> PyObj {
    return value.tp_setattro(name, field);
}

# `del obj.name` / delattr(obj, name). Native objects delete from their own
# writable attribute map; anything else falls back to the host.
def py_del_attr(value: PyObj, name: str) -> PyObj {
    if isinstance(value, PyClass) {
        c = value as PyClass;
        if name in c.attrs {
            _py_container_del(c.attrs, name);
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if name in u.attrs {
            _py_container_del(u.attrs, name);
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    if isinstance(value, PyModule) {
        m = value as PyModule;
        if name in m.attrs {
            _py_container_del(m.attrs, name);
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    if isinstance(value, PyFunction) {
        f = value as PyFunction;
        if name in f.attrs {
            _py_container_del(f.attrs, name);
            return py_none();
        }
        return py_error("AttributeError", name);
    }
    result = _jac_host_delattr(to_host(value), name);
    if host_result_ok(result) {
        return py_none();
    }
    return py_error(str(result[1]), str(result[2]));
}

def py_iter(value: PyObj) -> PyObj {
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if user_has_dunder(u, "__iter__") {
            res = call_user_dunder(u, "__iter__", []);
            if is_error(res) {
                return res;
            }
            if not (res.t == "iter" or res.t == "generator" or res.t == "dictiter") {
                return py_error(
                    "TypeError", "iter() returned non-iterator of type '" + res.t + "'"
                );
            }
            return res;
        }
        if u._has_base() {
            return PyObject_GetIter(u._base_obj());
        }
    }
    return PyObject_GetIter(value);
}

# Native ``hash()`` for ported builtins and user ``__hash__``; no host fallback.
def py_hash(value: PyObj) -> PyObj {
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if user_has_dunder(u, "__hash__") {
            h = call_user_dunder(u, "__hash__", []);
            if is_error(h) {
                return h;
            }
            if isinstance(h, PyInt) {
                return h;
            }
            return py_error("TypeError", "__hash__ should return an integer");
        }
        if u._has_base() {
            return py_hash(u._base_obj());
        }
        return PyObject_HashNotImplemented(value);
    }
    if isinstance(value, PyTuple) {
        return tuple_hash(value as PyTuple);
    }
    if isinstance(value, PyInt) {
        return long_hash_obj(value as PyInt);
    }
    if isinstance(value, PyBytes) {
        return bytes_hash_obj(value as PyBytes);
    }
    if isinstance(value, PySet) {
        return set_hash_obj(value as PySet);
    }
    return hash_element(value);
}

def py_aiter_has_anext(value: PyObj) -> bool {
    if isinstance(value, PyUserObj) {
        return user_has_dunder(value as PyUserObj, "__anext__");
    }
    return not is_error(py_attr(value, "__anext__"));
}

# `async for`: call __aiter__ and verify the result exposes __anext__.
def py_aiter(value: PyObj) -> PyObj {
    if isinstance(value, PyUserObj)
        and user_has_dunder(value as PyUserObj, "__aiter__") {
        result = call_user_dunder(value as PyUserObj, "__aiter__", []);
    } else {
        method = py_attr(value, "__aiter__");
        if is_error(method) {
            return method;
        }
        result = py_invoke(method, [], {});
    }
    if is_error(result) {
        return result;
    }
    if not py_aiter_has_anext(result) {
        type_label = result.t;
        if isinstance(result, PyUserObj) {
            type_label = (result as PyUserObj).cls.name;
        }
        return py_error(
            "TypeError",
            "'async for' received an object from __aiter__ that does not implement __anext__: "
                + type_label
        );
    }
    return result;
}

# Resolve a value to the iterator GET_AWAITABLE / SEND drive (native coroutine or
# generator only for now -- same surface as `await`).
def py_get_awaitable(value: PyObj) -> PyObj {
    if value.t == "coroutine" or value.t == "generator" {
        return value;
    }
    return py_error("TypeError", "object can't be used in 'await' expression");
}

# `async for` loop step: call __anext__ on the async iterator and wrap the result
# as an awaitable for the following SEND loop.
def py_anext(aiter: PyObj) -> PyObj {
    if isinstance(aiter, PyUserObj)
        and user_has_dunder(aiter as PyUserObj, "__anext__") {
        result = call_user_dunder(aiter as PyUserObj, "__anext__", []);
    } else {
        method = py_attr(aiter, "__anext__");
        if is_error(method) {
            return method;
        }
        result = py_invoke(method, [], {});
    }
    if is_error(result) {
        return result;
    }
    return py_get_awaitable(result);
}

def py_len(value: PyObj) -> PyObj {
    if isinstance(value, PyStr) {
        return PyInt(t="int", val=len((value as PyStr).val));
    }
    if isinstance(value, PyBytes) {
        return PyInt(t="int", val=len((value as PyBytes).val));
    }
    if isinstance(value, PyTuple) {
        return PyInt(t="int", val=len((value as PyTuple).items));
    }
    if isinstance(value, PyList) {
        return PyInt(t="int", val=len((value as PyList).items));
    }
    if isinstance(value, PyDict) {
        return PyInt(t="int", val=len((value as PyDict).items));
    }
    if isinstance(value, PySet) {
        return PyInt(t="int", val=len((value as PySet).items));
    }
    if isinstance(value, PyDictView) {
        return PyInt(t="int", val=len((value as PyDictView).d.items));
    }
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if user_has_dunder(u, "__len__") {
            res = call_user_dunder(u, "__len__", []);
            if is_error(res) {
                return res;
            }
            if isinstance(res, PyInt) {
                return res;
            }
            return py_error("TypeError", "'__len__' should return an integer");
        }
        if u._has_base() {
            return py_len(u._base_obj());
        }
    }
    if isinstance(value, PyHostProxy) {
        # A proxied host object (e.g. a namedtuple instance produced by
        # tuple.__new__, or any C-extension container) answers len() on the host.
        result = _jac_host_len(to_host(value));
        if host_result_ok(result) {
            return from_host(result[1]);
        }
        return py_error(str(result[1]), str(result[2]));
    }
    return py_error("TypeError", "object of type '" + value.t + "' has no len()");
}

# CPython tp_flags bits (Include/object.h) used by MATCH_* opcodes.
glob _TPFLAGS_SEQUENCE: int = 32,
     _TPFLAGS_MAPPING: int = 64,
     _TPFLAGS_MATCH_SELF: int = 4194304,
     _match_keys_dummy: PyObj = py_none();

def match_keys_dummy -> PyObj {
    if _match_keys_dummy.t == "none" {
        built = _jac_construct_builtin("object", []);
        if host_result_ok(built) {
            _match_keys_dummy = from_host(built[1]);
        }
    }
    return _match_keys_dummy;
}

def py_type_has_sequence_flag(value: PyObj) -> bool {
    if value.t == "list" or value.t == "tuple" {
        return True;
    }
    if value.t == "str" or value.t == "bytes" {
        return False;
    }
    if isinstance(value, PyUserObj) {
        return obj_is_builtin(value, "list") or obj_is_builtin(value, "tuple");
    }
    if isinstance(value, PyHostProxy) {
        host_val = (value as PyHostProxy).val;
        if _jac_isinstance_of_builtin(host_val, "str")
            or _jac_isinstance_of_builtin(host_val, "bytes") {
            return False;
        }
        if _jac_type_has_flag(host_val, _TPFLAGS_SEQUENCE) {
            return True;
        }
        return (_jac_isinstance_of_builtin(host_val, "list")
            or _jac_isinstance_of_builtin(host_val, "tuple")) as bool;
    }
    return False;
}

def py_type_has_mapping_flag(value: PyObj) -> bool {
    if value.t == "dict" {
        return True;
    }
    if isinstance(value, PyUserObj) {
        return obj_is_builtin(value, "dict");
    }
    if isinstance(value, PyHostProxy) {
        host_val = (value as PyHostProxy).val;
        if _jac_type_has_flag(host_val, _TPFLAGS_MAPPING) {
            return True;
        }
        return _jac_isinstance_of_builtin(host_val, "dict") as bool;
    }
    return False;
}

def py_type_has_match_self_flag(type_obj: PyObj) -> bool {
    if isinstance(type_obj, PyHostProxy) {
        return _jac_type_has_flag((type_obj as PyHostProxy).val, _TPFLAGS_MATCH_SELF) as bool;
    }
    return False;
}

def match_class_type_name(type_obj: PyObj) -> str {
    if isinstance(type_obj, PyClass) {
        return (type_obj as PyClass).name;
    }
    if isinstance(type_obj, PyHostProxy) {
        return str(_jac_host_type_name((type_obj as PyHostProxy).val));
    }
    return "?";
}

def py_match_attr_optional(value: PyObj, name: str) -> PyObj {
    attr = py_attr(value, name);
    if is_error(attr) {
        if isinstance(attr, PyError)
            and (attr as PyError).exception.type_name == "AttributeError" {
            return py_none();
        }
        return attr;
    }
    return attr;
}

def py_match_type_attr_optional(type_obj: PyObj, name: str) -> PyObj {
    if isinstance(type_obj, PyClass) {
        found = class_lookup_attr(type_obj as PyClass, name);
        if not is_error(found) {
            return found;
        }
        if isinstance(found, PyError)
            and (found as PyError).exception.type_name == "AttributeError" {
            return py_none();
        }
        return found;
    }
    return py_match_attr_optional(type_obj, name);
}

def py_match_class_attr(
    subject: PyObj, type_obj: PyObj, name: PyObj, seen: PySet
) -> PyObj {
    if not isinstance(name, PyStr) {
        return py_error(
            "TypeError", "__match_args__ elements must be strings (got " + name.t + ")",
        );
    }
    if seen.set_contains(name) {
        return py_error(
            "TypeError",
            match_class_type_name(type_obj)
                + "() got multiple sub-patterns for attribute "
                + dict_key_repr(name),
        );
    }
    seen.set_add(name);
    attr = py_match_attr_optional(subject, (name as PyStr).val);
    if is_error(attr) {
        return attr;
    }
    if attr.t == "none" {
        return py_none();
    }
    return attr;
}

def py_match_keys(map_obj: PyObj, keys: PyObj) -> PyObj {
    if not isinstance(keys, PyTuple) {
        return py_error("TypeError", "MATCH_KEYS keys must be a tuple");
    }
    key_items = (keys as PyTuple).items;
    nkeys = len(key_items);
    if nkeys == 0 {
        return PyTuple(t="tuple", items=[]);
    }
    get_m = py_attr(map_obj, "get");
    if is_error(get_m) {
        return get_m;
    }
    dummy = match_keys_dummy();
    seen = PySet(t="set", items={}, frozen=False);
    values: list[PyObj] = [];
    ki = 0;
    while ki < nkeys {
        key = key_items[ki];
        if seen.set_contains(key) {
            return py_error(
                "ValueError",
                "mapping pattern checks duplicate key (" + dict_key_repr(key) + ")",
            );
        }
        seen.set_add(key);
        val = py_invoke(get_m, [key, dummy], {});
        if is_error(val) {
            return val;
        }
        if val is dummy {
            return py_none();
        }
        values.append(val);
        ki = ki + 1;
    }
    return PyTuple(t="tuple", items=values);
}

def py_match_class(
    subject: PyObj, type_obj: PyObj, nargs: int, kw_names: PyObj
) -> PyObj {
    if not isinstance(type_obj, PyClass) and not isinstance(type_obj, PyHostProxy) {
        return py_error("TypeError", "called match pattern must be a class");
    }
    if not isinstance(kw_names, PyTuple) {
        return py_error("TypeError", "MATCH_CLASS names must be a tuple");
    }
    if not py_isinstance(subject, type_obj) {
        return py_none();
    }
    seen = PySet(t="set", items={}, frozen=False);
    attrs_list: list[PyObj] = [];
    if nargs > 0 {
        match_args_obj = py_match_type_attr_optional(type_obj, "__match_args__");
        if is_error(match_args_obj) {
            return match_args_obj;
        }
        match_self = 0;
        match_args: PyTuple;
        if match_args_obj.t == "none" {
            match_args = PyTuple(t="tuple", items=[]);
            if py_type_has_match_self_flag(type_obj) {
                match_self = 1;
            }
        } else {
            if not isinstance(match_args_obj, PyTuple) {
                got = match_args_obj.t;
                if isinstance(match_args_obj, PyHostProxy) {
                    got = str(_jac_host_type_name((match_args_obj as PyHostProxy).val));
                }
                return py_error(
                    "TypeError",
                    match_class_type_name(type_obj)
                        + ".__match_args__ must be a tuple (got "
                        + got
                        + ")",
                );
            }
            match_args = match_args_obj as PyTuple;
        }
        allowed = len(match_args.items);
        if match_self {
            allowed = 1;
        }
        if allowed < nargs {
            plural = "s";
            if allowed == 1 {
                plural = "";
            }
            return py_error(
                "TypeError",
                match_class_type_name(type_obj)
                    + "() accepts "
                    + str(allowed)
                    + " positional sub-pattern"
                    + plural
                    + " ("
                    + str(nargs)
                    + " given)",
            );
        }
        if match_self {
            attrs_list.append(subject);
        } else {
            pi = 0;
            while pi < nargs {
                name = match_args.items[pi];
                attr = py_match_class_attr(subject, type_obj, name, seen);
                if is_error(attr) {
                    return attr;
                }
                if attr.t == "none" {
                    return py_none();
                }
                attrs_list.append(attr);
                pi = pi + 1;
            }
        }
    }
    kw_tuple = kw_names as PyTuple;
    ki = 0;
    while ki < len(kw_tuple.items) {
        name = kw_tuple.items[ki];
        attr = py_match_class_attr(subject, type_obj, name, seen);
        if is_error(attr) {
            return attr;
        }
        if attr.t == "none" {
            return py_none();
        }
        attrs_list.append(attr);
        ki = ki + 1;
    }
    return PyTuple(t="tuple", items=attrs_list);
}

# Materialize a host iterable (range, dict-view, map/filter object, ...) into a
# native PyIter so GET_ITER/FOR_ITER drive it without a host round-trip per step.
def host_iter(value: PyHostProxy) -> PyObj {
    result = _jac_host_iter(value.val);
    if host_result_ok(result) {
        items: list[PyObj] = [];
        for item in result[1] {
            items.append(from_host(item));
        }
        return PyIter(t="iter", items=items, index=0);
    }
    return py_error(str(result[1]), str(result[2]));
}

# The PyObj yielded by a dict iterator at its current position: the key (keys),
# the value (values), or a (key, value) PyTuple (items). The caller has already
# confirmed the iterator is not stale, so the hashkey is still present.
def dictiter_yield(di: PyDictIter) -> PyObj {
    hk = di.keys[di.index];
    `entry = di.d.items[hk];
    if di.mode == "values" {
        return `entry.value;
    }
    if di.mode == "items" {
        return PyTuple(t="tuple", items=[`entry.key, `entry.value]);
    }
    return `entry.key;
}

def dictiter_error -> PyObj {
    return py_error("RuntimeError", "dictionary changed size during iteration");
}

def find_cell(cells: list[PyCell], names: list[str], name: str) -> PyCell | None {
    i = find_name(names, name);
    if i >= 0 and i < len(cells) {
        return cells[i];
    }
    return None;
}

# CPython 3.11+ indexes LOAD_FAST / *_DEREF / MAKE_CELL into a single merged
# "localsplus" array laid out as [varnames(nlocals)] [cellvars-not-already-a-var]
# [freevars]. A cell variable that is ALSO an argument keeps its varname slot
# (it is NOT duplicated in the appended region) -- so the appended region holds
# only the non-arg cellvars, then the freevars. resolve_cell maps a merged index
# to its PyCell (or None for a plain local). Getting this layout wrong swaps a
# parameter-cell with a sibling local-cell (breaks every closure/decorator).
def resolve_cell(
    co: PyCode, arg: int, cells: list[PyCell], closure: list[PyCell]
) -> PyCell | None {
    nl = len(co.varnames);
    if arg < nl {
        pos = find_name(co.cellvars, co.varnames[arg]);
        if pos >= 0 and pos < len(cells) {
            return cells[pos];
        }
        return None;
    }
    j = arg - nl;
    # Walk the non-arg cellvars in cellvar order; the j-th is this slot.
    seen = 0;
    ci = 0;
    while ci < len(co.cellvars) {
        if find_name(co.varnames, co.cellvars[ci]) < 0 {
            if seen == j and ci < len(cells) {
                return cells[ci];
            }
            seen = seen + 1;
        }
        ci = ci + 1;
    }
    # Past the non-arg cellvars lies the freevar region (the closure cells).
    free_index = j - seen;
    if free_index >= 0 and free_index < len(closure) {
        return closure[free_index];
    }
    return None;
}

def fast_value(
    co: PyCode, arg: int, fast: list[PyObj], cells: list[PyCell], closure: list[PyCell]
) -> PyObj {
    # A cell slot (an arg-cell in the varname region, or any appended cell/free
    # slot) yields the CELL OBJECT -- that is how LOAD_FAST/LOAD_CLOSURE fetch a
    # cell to seed an inner function's closure. A plain local yields its value.
    cell = resolve_cell(co, arg, cells, closure);
    if cell is not None {
        return cell as PyObj;
    }
    if arg < len(fast) {
        return fast[arg];
    }
    return py_error("UnboundLocalError", "local variable is not set");
}

def fast_value_check(
    co: PyCode,
    arg: int,
    fast: list[PyObj],
    assigned: list[bool],
    cells: list[PyCell],
    closure: list[PyCell],
) -> PyObj {
    # LOAD_FAST_CHECK: like LOAD_FAST but raises UnboundLocalError when the
    # plain-local slot was never STORE_FAST-bound (CPython 3.14+ null check).
    cell = resolve_cell(co, arg, cells, closure);
    if cell is not None {
        return cell as PyObj;
    }
    if arg >= len(fast) {
        return py_error("UnboundLocalError", "local variable is not set");
    }
    if arg < len(assigned) and not assigned[arg] {
        vname = "?";
        if arg < len(co.varnames) {
            vname = co.varnames[arg];
        }
        return py_error(
            "UnboundLocalError",
            "cannot access local variable '"
                + vname
                + "' where it is not associated with a value",
        );
    }
    return fast[arg];
}

def deref_cell(
    co: PyCode, arg: int, fast: list[PyObj], cells: list[PyCell], closure: list[PyCell]
) -> PyCell | None {
    return resolve_cell(co, arg, cells, closure);
}

def read_varint(data: list[int], pos: int) -> tuple[int, int] {
    value = 0;
    current = 0;
    while pos < len(data) {
        current = data[pos] & 0xFF;
        pos = pos + 1;
        value = (value << 6) | (current & 63);
        if (current & 64) == 0 {
            return (value, pos);
        }
    }
    return (value, pos);
}

def find_handler(co: PyCode, offset: int) -> PyHandler | None {
    data = co.exceptiontable;
    pos = 0;
    while pos < len(data) {
        start_read = read_varint(data, pos);
        start = start_read[0] * 2;
        pos = start_read[1];
        length_read = read_varint(data, pos);
        end = start + length_read[0] * 2;
        pos = length_read[1];
        target_read = read_varint(data, pos);
        target = target_read[0] * 2;
        pos = target_read[1];
        depth_read = read_varint(data, pos);
        depth = depth_read[0] >> 1;
        lasti = (depth_read[0] & 1) != 0;
        pos = depth_read[1];
        if offset >= start and offset < end {
            return PyHandler(
                t="handler",
                start=start,
                end=end,
                target=target,
                depth=depth,
                lasti=lasti
            );
        }
    }
    return None;
}

def recover_exception(
    co: PyCode, value: PyObj, offset: int, stack: list[PyObj]
) -> int {
    if value.t != "error" {
        return -1;
    }
    handler = find_handler(co, offset);
    if handler is None {
        return -1;
    }
    error = value as PyError;
    while len(stack) > handler.depth {
        stack.pop();
    }
    if handler.lasti {
        stack.append(PyInt(t="int", val=offset));
    }
    stack.append(error.exception);
    return handler.target;
}

def exception_matches(value: PyObj, target: PyObj) -> bool {
    if value.t != "exception" {
        return False;
    }
    exception = value as PyException;
    # A user exception class target (except Exc): match by the raised instance's
    # MRO if we kept the instance, else by class name.
    if isinstance(target, PyClass) {
        raw = exception.raw;
        if raw is not None and isinstance(raw, PyUserObj) {
            for klass in class_mro((raw as PyUserObj).cls) {
                if klass is (target as PyClass) {
                    return True;
                }
            }
        }
        return (target as PyClass).name == exception.type_name;
    }
    target_name: str = "";
    if target.t == "exception_type" {
        target_name = (target as PyExceptionType).name;
    } elif target.t == "host" {
        # The except-target is a host exception CLASS; read its own __name__, not
        # type(cls).__name__ (which is "type" and never matches).
        target_name = _jac_host_class_name((target as PyHostProxy).val) as str;
    }
    if target_name == "" {
        return False;
    }
    return exc_name_matches(exception.type_name, target_name);
}

# True iff `cls` (a user class) derives from a builtin exception -- i.e. one of
# its MRO classes lists a host BaseException-subclass proxy among its bases.
# `class Exc(Exception)` has native_base "" (Exception is not a subclassable
# builtin layout), so we detect it through the recorded host base, not the layout.
def class_is_exception(cls: PyClass) -> bool {
    for klass in class_mro(cls) {
        for base in klass.bases {
            # Builtin exceptions resolve to a native PyExceptionType (Exception,
            # ValueError, ...); a not-yet-native one arrives as a host proxy.
            if isinstance(base, PyExceptionType) {
                return True;
            }
            if isinstance(base, PyHostProxy)
                and bool(_jac_is_exception_type((base as PyHostProxy).val)) {
                return True;
            }
        }
    }
    return False;
}

def py_raise_value(value: PyObj) -> PyObj {
    if value.t == "exception" {
        return PyError(t="error", exception=value as PyException);
    }
    if value.t == "exception_type" {
        typ = value as PyExceptionType;
        return PyError(
            t="error",
            exception=PyException(t="exception", type_name=typ.name, message="")
        );
    }
    # A raised user exception instance (class Exc(Exception); raise Exc()) surfaces
    # as a PyException tagged with the user class name, keeping the instance in
    # `raw` so `except <UserClass>` can match it by MRO.
    if isinstance(value, PyUserObj) {
        u = value as PyUserObj;
        if class_is_exception(u.cls) {
            return PyError(
                t="error",
                exception=PyException(
                    t="exception", type_name=u.cls.name, message="", raw=value
                )
            );
        }
    }
    # A raised exception CLASS (raise Exc) auto-instantiates, then re-raises.
    if isinstance(value, PyClass) and class_is_exception(value as PyClass) {
        instance = (value as PyClass).tp_call([], {});
        if is_error(instance) {
            return instance;
        }
        return py_raise_value(instance);
    }
    if isinstance(value, PyHostProxy) {
        raw = (value as PyHostProxy).val;
        if bool(_jac_is_exception_type(raw)) {
            return PyError(
                t="error",
                exception=PyException(
                    t="exception", type_name=str(_jac_host_class_name(raw)), message=""
                )
            );
        }
        inst = _jac_host_exception_instance(raw);
        if bool(inst[0]) {
            return PyError(
                t="error",
                exception=PyException(
                    t="exception",
                    type_name=str(inst[1]),
                    message=str(inst[2]),
                    raw=value
                )
            );
        }
    }
    return py_error("TypeError", "exceptions must derive from BaseException");
}

def py_call_host(
    fn: PyHostProxy, args: list[PyObj], kwargs: dict[str, PyObj]
) -> PyObj {
    # An unbound builtin-method descriptor called with a NATIVE container as
    # receiver (list.append(lst, x), dict.get(d, k)) must operate on the real
    # native storage: marshaling through to_host hands the host a COPY, so the
    # call would silently no-op for mutators. Dispatch natively instead.
    info = _jac_host_unbound_method_info(fn.val);
    if bool(info[0]) and len(args) > 0 {
        owner = str(info[1]);
        meth = str(info[2]);
        recv = args[0];
        rest: list[PyObj] = [];
        i = 1;
        while i < len(args) {
            rest.append(args[i]);
            i = i + 1;
        }
        if owner == "list" and isinstance(recv, PyList) and is_list_method(meth) {
            return PyListMethod(t="list_method", target=(recv as PyList), name=meth).tp_call(rest, kwargs);
        }
        if owner == "dict" and isinstance(recv, PyDict) and is_dict_method(meth) {
            return PyDictMethod(t="dict_method", target=(recv as PyDict), name=meth).tp_call(rest, kwargs);
        }
        if owner == "set" and isinstance(recv, PySet) and is_set_method(meth, (recv as PySet).frozen) {
            return PySetMethod(t="set_method", target=(recv as PySet), name=meth).tp_call(rest, kwargs);
        }
    }
    raw_args: list[any] = [];
    for item in args {
        raw_args.append(to_host(item));
    }
    raw_kwargs: dict[str, any] = {};
    for key in kwargs {
        raw_kwargs[key] = to_host(kwargs[key]);
    }
    result = _jac_host_call(fn.val, raw_args, raw_kwargs);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

def py_invoke(fn: PyObj, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    # A pending error flowing into a call site propagates unchanged; every real
    # callable resolves through its tp_call slot (function/class/bound method/
    # exception type/host proxy/build-class), never a tag switch.
    if fn.t == "error" {
        return fn;
    }
    return fn.tp_call(args, kwargs);
}

# ---------------- Track B: builtin subclassing support -----------------------

# C3 linearization: L[C] = C + merge(L[B1], ..., L[Bn], [B1, ..., Bn]). This gives
# the strict CPython MRO -- a diamond D(B, C) with B,C : A resolves [D, B, C, A],
# so an attribute on both A and C picks C, not A. An inconsistent hierarchy (no
# valid linearization) degrades to the partial order computed so far rather than
# looping. Only PyClass bases participate; a native/host base is not a node here.
def class_mro(cls: PyClass) -> list[PyClass] {
    seqs: list[list[PyClass]] = [];
    direct: list[PyClass] = [];
    for base in cls.bases {
        if isinstance(base, PyClass) {
            seqs.append(class_mro(base as PyClass));
            direct.append(base as PyClass);
        }
    }
    if len(direct) > 0 {
        seqs.append(direct);
    }
    result: list[PyClass] = [cls];
    for klass in c3_merge(seqs) {
        result.append(klass);
    }
    return result;
}

# Merge step of C3: repeatedly take the head of some sequence that appears in no
# other sequence's tail, append it, and strip it from every head. Stops when all
# sequences drain (success) or no valid head exists (inconsistent -> partial).
def c3_merge(seqs: list[list[PyClass]]) -> list[PyClass] {
    work: list[list[PyClass]] = [];
    for s in seqs {
        row: list[PyClass] = [];
        for x in s {
            row.append(x);
        }
        work.append(row);
    }
    result: list[PyClass] = [];
    while True {
        live: list[list[PyClass]] = [];
        for s in work {
            if len(s) > 0 {
                live.append(s);
            }
        }
        if len(live) == 0 {
            return result;
        }
        chosen: PyClass | None = None;
        for s in live {
            head = s[0];
            in_tail = False;
            for other in live {
                k = 1;
                while k < len(other) {
                    if other[k] is head {
                        in_tail = True;
                    }
                    k = k + 1;
                }
            }
            if not in_tail {
                chosen = head;
                break;
            }
        }
        if chosen is None {
            return result;
        }
        result.append(chosen);
        for s in live {
            if len(s) > 0 and s[0] is chosen {
                s.pop(0);
            }
        }
        work = live;
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

# super().name lookup: search the instance's MRO starting AFTER the defining
# class (zero-arg super semantics). defining_cls comes from the __class__ cell;
# if it isn't a PyClass, fall back to the instance's own class.
# `builtin.__new__(cls, *box_args)` reached through super() from a subclass's
# own __new__ (e.g. re._constants._NamedIntConstant, IntEnum members). The first
# arg is the class to instantiate; the rest box the builtin base. Returns a
# PyUserObj tagged with that class so the subclass's identity and attributes
# (a .name set right after) survive -- exactly the value/ref line Track B draws.
obj PyNativeNew(PyObj) {
    has base_name: str;

    # Value identity by base_name so every object.__new__ producer compares equal
    # (enum's _find_new_ does `target in {object.__new__, ...}`).
    def tp_hashkey -> str {
        return "nativenew:" + self.base_name;
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        same = isinstance(other, PyNativeNew)
            and self.base_name == (other as PyNativeNew).base_name;
        if kind == 2 {
            return PyBool(t="bool", val=same);
        }
        if kind == 3 {
            return PyBool(t="bool", val=not same);
        }
        return py_error("TypeError", "unsupported comparison");
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) == 0 {
            return py_error("TypeError", "__new__() takes a class argument");
        }
        target_cls = args[0];
        # type.__new__(mcls, name, bases, namespace): the class factory reached by
        # super().__new__ inside a metaclass __new__. Builds a PyClass tagged with
        # mcls as its metaclass so a subclass re-runs the same protocol.
        if self.base_name == "type" {
            return type_new(args);
        }
        # object.__new__(cls): a plain instance, no boxed builtin value. This is
        # the super().__new__(cls) / object.__new__(cls) path of a class whose
        # only base is object (functools._PlaceholderType, most user classes).
        if self.base_name == "object" {
            if isinstance(target_cls, PyClass) {
                return PyUserObj(
                    t="instance", cls=target_cls as PyClass, attrs={}, base=py_none()
                );
            }
            return py_error("TypeError", "object.__new__ requires a class");
        }
        box_args: list[PyObj] = [];
        j = 1;
        while j < len(args) {
            box_args.append(args[j]);
            j = j + 1;
        }
        # builtin.__new__ over a HOST class (namedtuple's dynamic tuple subclass)
        # stays host-side so the host subclass instance is preserved.
        if isinstance(target_cls, PyHostProxy) {
            raw_box: list[any] = [];
            for a in box_args {
                raw_box.append(to_host(a));
            }
            hres = _jac_builtin_new(
                self.base_name, (target_cls as PyHostProxy).val, raw_box
            );
            if host_result_ok(hres) {
                return from_host(hres[1]);
            }
            return py_error(str(hres[1]), str(hres[2]));
        }
        boxed = construct_native_base(self.base_name, box_args);
        if is_error(boxed) {
            return boxed;
        }
        if isinstance(target_cls, PyClass) {
            return PyUserObj(
                t="instance", cls=target_cls as PyClass, attrs={}, base=boxed
            );
        }
        # Called with the exact builtin type (not a user subclass): plain value.
        return boxed;
    }
}

# super().<dunder>(...) inside a builtin-subclass method (dict/list/... subclass)
# resolves to the boxed base's own slot -- e.g. _EnumDict(dict).__setitem__ calling
# super().__setitem__(k, v) mutates the underlying dict. Bound to the instance's
# boxed value at lookup time, so the call site applies only the operands.
obj PyBuiltinSuperMethod(PyObj) {
    has base: PyObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        b = self.base;
        if n == "__init__" {
            # super().__init__(...) on a mutable base. Empty (the common case, e.g.
            # EnumDict) is a no-op; a mapping argument fills the boxed dict.
            if len(args) == 0 {
                return py_none();
            }
            if isinstance(b, PyDict) and isinstance(args[0], PyDict) {
                src = args[0] as PyDict;
                for keyobj in src.dict_keys() {
                    (b as PyDict).dict_set(keyobj, src.mp_subscript(keyobj));
                }
                return py_none();
            }
            return py_none();
        }
        if n == "__setitem__" {
            return b.mp_ass_subscript(args[0], args[1]);
        }
        if n == "__getitem__" {
            return b.mp_subscript(args[0]);
        }
        if n == "__delitem__" {
            return b.mp_del_subscript(args[0]);
        }
        if n == "__len__" {
            return py_len(b);
        }
        if n == "__iter__" {
            return b.tp_iter();
        }
        if n == "__contains__" {
            return py_contains(b, args[0]);
        }
        return py_error("AttributeError", n);
    }
}

# True iff `inst` is an instance of `cls` (walks the instance class's MRO).
def instance_of_class(inst: PyUserObj, cls: PyClass) -> bool {
    for klass in class_mro(inst.cls) {
        if klass is cls {
            return True;
        }
    }
    return False;
}

def super_lookup(defining_cls: PyObj, instance: PyObj, name: str) -> PyObj {
    # `instance` is a real instance for a normal super().method(), but a CLASS
    # for super(Cls, cls).__new__(...) inside a __new__. Resolve which class's
    # MRO to walk from either shape.
    walk_cls = py_none();
    if isinstance(instance, PyUserObj) {
        walk_cls = (instance as PyUserObj).cls;
    } elif isinstance(instance, PyClass) {
        walk_cls = instance;
    } else {
        return py_error("AttributeError", name);
    }
    start: PyClass = walk_cls as PyClass;
    if isinstance(defining_cls, PyClass) {
        start = defining_cls as PyClass;
    }
    mro = class_mro(walk_cls as PyClass);
    past = False;
    for klass in mro {
        if past and name in klass.attrs {
            return klass.attrs[name];
        }
        if klass is start {
            past = True;
        }
    }
    # No python ancestor defines it. A super().<dunder>() on a boxed-builtin
    # subclass (dict/list/... subclass calling super().__setitem__ etc.) delegates
    # to the base value's own slot.
    if name != "__new__" and isinstance(instance, PyUserObj) {
        inst = instance as PyUserObj;
        if inst._has_base() {
            return PyBuiltinSuperMethod(
                t="builtin_super", base=inst._base_obj(), name=name
            );
        }
    }
    # No python ancestor defines it. super().__new__ resolves to the base
    # constructor: a builtin (int.__new__, str.__new__, ...) when the chain boxes
    # one, else object.__new__ (a plain instance of the class).
    if name == "__new__" {
        base = start.native_base;
        for klass in mro {
            if klass.native_base != "" {
                base = klass.native_base;
            }
        }
        if base == "" {
            base = "object";
        }
        return PyNativeNew(t="native_new", base_name=base);
    }
    return py_error("AttributeError", name);
}

# Box a builtin subclass instance by running the builtin constructor over the
# call args (int("5") -> 5, list(x) -> [...]). Errors propagate.
def construct_native_base(name: str, args: list[PyObj]) -> PyObj {
    raw_args: list[any] = [];
    for a in args {
        raw_args.append(to_host(a));
    }
    result = _jac_construct_builtin(name, raw_args);
    if host_result_ok(result) {
        return from_host(result[1]);
    }
    return py_error(str(result[1]), str(result[2]));
}

# For operator delegation: a builtin subclass on either operand acts as its
# boxed value (MyInt(5) + MyInt(1) -> 5 + 1).
def unwrap_base(o: PyObj) -> PyObj {
    if isinstance(o, PyUserObj) {
        u = o as PyUserObj;
        if u._has_base() {
            return u._base_obj();
        }
    }
    return o;
}

# True iff `obj` counts as an instance of the builtin named `name`, honoring
# builtin-subclass boxing and the bool<:int relationship.
def obj_is_builtin(ob: PyObj, name: str) -> bool {
    if name == "object" {
        return True;
    }
    if isinstance(ob, PyUserObj) {
        u = ob as PyUserObj;
        for klass in class_mro(u.cls) {
            if klass.native_base == name {
                return True;
            }
        }
        if u._has_base() {
            return obj_is_builtin(u._base_obj(), name);
        }
        return False;
    }
    if ob.t == name {
        return True;
    }
    if name == "int" and ob.t == "bool" {
        return True;
    }
    return False;
}

def py_isinstance(ob: PyObj, typ: PyObj) -> bool {
    if isinstance(typ, PyTuple) {
        for t in (typ as PyTuple).items {
            if py_isinstance(ob, t) {
                return True;
            }
        }
        return False;
    }
    if isinstance(ob, PyException) {
        if typ.t == "exception_type" {
            return exc_name_matches(
                (ob as PyException).type_name, (typ as PyExceptionType).name
            );
        }
        if isinstance(typ, PyHostProxy) {
            host_type = (typ as PyHostProxy).val;
            if bool(_jac_is_exception_type(host_type)) {
                tname = _jac_host_class_name(host_type) as str;
                return exc_name_matches((ob as PyException).type_name, tname);
            }
        }
        if isinstance(typ, PyClass) {
            return exc_name_matches(
                (ob as PyException).type_name, (typ as PyClass).name
            );
        }
    }
    if isinstance(typ, PyClass) {
        if isinstance(ob, PyUserObj) {
            for klass in class_mro((ob as PyUserObj).cls) {
                if klass is (typ as PyClass) {
                    return True;
                }
            }
        }
        # isinstance(SomeClass, Meta): a class is an instance of its metaclass, so
        # walk the class's metaclass MRO (isinstance(Enum, EnumType) is True).
        if isinstance(ob, PyClass) {
            meta = (ob as PyClass).metaclass;
            if meta is not None and isinstance(meta, PyClass) {
                for klass in class_mro(meta as PyClass) {
                    if klass is (typ as PyClass) {
                        return True;
                    }
                }
            }
        }
        return False;
    }
    if isinstance(typ, PyHostProxy) {
        host_type = (typ as PyHostProxy).val;
        name: str = str(_jac_builtin_base_name(host_type));
        if name != "" {
            return obj_is_builtin(ob, name);
        }
        return bool(_jac_host_isinstance(to_host(ob), host_type));
    }
    return False;
}

def py_issubclass(cls: PyObj, typ: PyObj) -> bool {
    if isinstance(typ, PyTuple) {
        for t in (typ as PyTuple).items {
            if py_issubclass(cls, t) {
                return True;
            }
        }
        return False;
    }
    if isinstance(cls, PyClass) {
        c = cls as PyClass;
        if isinstance(typ, PyClass) {
            for klass in class_mro(c) {
                if klass is (typ as PyClass) {
                    return True;
                }
            }
            return False;
        }
        if isinstance(typ, PyHostProxy) {
            name: str = str(_jac_builtin_base_name((typ as PyHostProxy).val));
            if name == "object" {
                return True;
            }
            if name != "" {
                for klass in class_mro(c) {
                    if klass.native_base == name {
                        return True;
                    }
                }
            }
            return False;
        }
        return False;
    }
    if isinstance(cls, PyHostProxy) and isinstance(typ, PyHostProxy) {
        return bool(
            _jac_host_issubclass((cls as PyHostProxy).val, (typ as PyHostProxy).val)
        );
    }
    return False;
}

# The builtin ancestor (if any) that dictates a class's instance layout, plus the
# `type` marker for a metaclass. Inherited from a user base's own native_base when
# subclassing a subclass; read off a host builtin/`type` base directly.
# The subclassable builtins whose instances are filled by __init__ rather than
# frozen at __new__ time. A user __init__ on such a subclass creates an empty base
# and fills it (usually via super().__init__).
def is_mutable_base(name: str) -> bool {
    return name == "dict" or name == "list" or name == "set";
}

def compute_native_base(bases: list[PyObj]) -> str {
    native_base = "";
    for base in bases {
        if isinstance(base, PyClass) {
            inherited = (base as PyClass).native_base;
            if inherited != "" {
                native_base = inherited;
            }
        } elif isinstance(base, PyHostProxy) {
            hostval = (base as PyHostProxy).val;
            if _jac_is_type_type(hostval) {
                # `class Meta(type)` -- a metaclass. super().__new__ builds classes.
                native_base = "type";
            } else {
                builtin_name: str = str(_jac_builtin_base_name(hostval));
                if builtin_name != "" and builtin_name != "object" {
                    native_base = builtin_name;
                }
            }
        }
    }
    return native_base;
}

# Box a PyClass from a resolved name/bases/namespace. `meta` is the metaclass that
# produced it (None = the default `type`), recorded so a later subclass can
# re-derive and re-run the metaclass protocol.
def make_pyclass_from_map(
    class_name: str, bases: list[PyObj], namespace: dict[str, PyObj], meta: any
) -> PyClass {
    flags = type_ready(0);
    if flags < 0 {
        flags = Py_TPFLAGS_READY;
    }
    return PyClass(
        t="class",
        name=class_name,
        attrs=namespace,
        bases=bases,
        native_base=compute_native_base(bases),
        metaclass=meta,
        tp_flags=flags
    );
}

# type.__new__(mcls, name, bases, namespace): build a class object. Serves both
# the metaclass super().__new__ path and a bare 3-arg type(name, bases, ns) call.
def type_new(args: list[PyObj]) -> PyObj {
    if len(args) < 4 {
        return py_error("TypeError", "type.__new__() takes name, bases, dict");
    }
    mcls = args[0];
    class_name = expect_str(args[1]);
    bases: list[PyObj] = [];
    bases_obj = args[2];
    if isinstance(bases_obj, PyTuple) {
        bases = (bases_obj as PyTuple).items;
    } elif isinstance(bases_obj, PyList) {
        bases = (bases_obj as PyList).items;
    }
    namespace = extract_namespace(args[3]);
    cls = make_pyclass_from_map(class_name, bases, namespace, mcls);
    ordered: list[str] = [];
    for k in namespace {
        ordered.append(k);
    }
    return apply_set_name_hooks(cls, ordered);
}

# After a class is built, type.__new__ calls __set_name__(cls, name) on every
# namespace value that defines it, in definition order (PEP 487). This drives
# enum member creation: each _proto_member's __set_name__ builds the real member
# and registers it on the class. Returns the class, or the first hook's error.
def apply_set_name_hooks(cls: PyClass, ordered_names: list[str]) -> PyObj {
    for name in ordered_names {
        if name in cls.attrs {
            value = cls.attrs[name];
            if isinstance(value, PyUserObj)
                and user_has_dunder(value as PyUserObj, "__set_name__") {
                res = call_user_dunder(
                    value as PyUserObj, "__set_name__", [cls, PyStr(t="str", val=name)]
                );
                if is_error(res) {
                    return res;
                }
            }
        }
    }
    return cls;
}

# PEP 487: after a subclass is built, its nearest base's __init_subclass__ is
# called with the new class (implicit classmethod) plus the class keyword args --
# `class Sub(Base, key=1)` runs Base.__init_subclass__(cls=Sub, key=1). Only a
# user base that actually defines it fires (the object default is a no-op); a
# base that stores it as a plain def takes the new class as its first argument.
def apply_init_subclass(cls: PyClass, kwds: dict[str, PyObj]) -> PyObj {
    for base in cls.bases {
        if isinstance(base, PyClass) {
            found = class_lookup_attr(base as PyClass, "__init_subclass__");
            if not is_error(found) and isinstance(found, PyFunction) {
                res = py_invoke(found, [cls], kwds);
                if is_error(res) {
                    return res;
                }
                return cls;
            }
        }
    }
    return cls;
}

# Read a PyDict whose keys are all strings (a class namespace) into a jac str map.
def pydict_to_str_map(d: PyDict) -> dict[str, PyObj] {
    m: dict[str, PyObj] = {};
    for keyobj in d.dict_keys() {
        val = d.mp_subscript(keyobj);
        m[expect_str(keyobj)] = val;
    }
    return m;
}

# The class namespace as a str map, whether the metaclass __prepare__ returned a
# plain dict or a custom mapping (a dict-subclass like enum's _EnumDict, which
# boxes a real dict). A mapping's own tracking attributes stay on the object; the
# stored member/method entries live in the boxed dict.
def extract_namespace(ns_obj: PyObj) -> dict[str, PyObj] {
    if isinstance(ns_obj, PyDict) {
        return pydict_to_str_map(ns_obj as PyDict);
    }
    if isinstance(ns_obj, PyUserObj) {
        u = ns_obj as PyUserObj;
        if u._has_base() and isinstance(u._base_obj(), PyDict) {
            return pydict_to_str_map(u._base_obj() as PyDict);
        }
    }
    return {};
}

# The metaclass of a base object (its `type`), or None. Only PyClass bases carry a
# recorded metaclass; a host base (object/type/builtins) resolves to the default.
def metaclass_of(base: PyObj) -> any {
    if isinstance(base, PyClass) {
        m = (base as PyClass).metaclass;
        if m is not None and isinstance(m, PyClass) {
            return m;
        }
    }
    return None;
}

# Pick the class's metaclass: the most-derived of an explicit `metaclass=` kwarg
# and every base's own metaclass (CPython's winner rule). Returns None for the
# default `type` path. An explicit `metaclass=type` (host proxy) stays default.
def resolve_metaclass(kwargs: dict[str, PyObj], bases: list[PyObj]) -> any {
    winner: any = None;
    if "metaclass" in kwargs {
        m = kwargs["metaclass"];
        if isinstance(m, PyClass) {
            winner = m;
        }
    }
    for base in bases {
        bm = metaclass_of(base);
        if isinstance(bm, PyClass) {
            if winner is None {
                winner = bm;
            } elif py_issubclass(bm as PyObj, winner as PyObj) {
                winner = bm;
            }
        }
    }
    return winner;
}

def py_build_class(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    if len(args) < 2 {
        return py_error("TypeError", "__build_class__ needs a body and name");
    }
    body = args[0] as PyFunction;
    class_name = expect_str(args[1]);
    # args[2:] are the base objects.
    bases: list[PyObj] = [];
    j = 2;
    while j < len(args) {
        bases.append(args[j]);
        j = j + 1;
    }
    # Class keyword args other than `metaclass` are forwarded to __prepare__ and
    # the metaclass call (e.g. __init_subclass__ kwargs).
    class_kwds: dict[str, PyObj] = {};
    for k in kwargs {
        if k != "metaclass" {
            class_kwds[k] = kwargs[k];
        }
    }
    metaclass = resolve_metaclass(kwargs, bases);
    # A user metaclass (EnumType, ABCMeta): run the full protocol -- __prepare__
    # for the body namespace, then call the metaclass as the class factory.
    if isinstance(metaclass, PyClass) {
        return build_class_via_metaclass(
            metaclass as PyClass, class_name, bases, body, class_kwds
        );
    }
    # Default `type`: execute the body into a plain namespace and box a PyClass.
    namespace: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    body_result = exec_code_frame(
        body.code, [], {}, body.globals, namespace, body.closure, [], {}
    );
    if body_result.t == "error" {
        return body_result;
    }
    cls = make_pyclass_from_map(class_name, bases, namespace, None);
    ordered: list[str] = [];
    for k in namespace {
        ordered.append(k);
    }
    hooked = apply_set_name_hooks(cls, ordered);
    if is_error(hooked) {
        return hooked;
    }
    return apply_init_subclass(cls, class_kwds);
}

# The custom-metaclass class-creation protocol: metaclass.__prepare__ produces the
# body namespace, the body runs into it, then the metaclass is called as
# (name, bases, namespace, **kwds) -- its __new__/__init__ build and finish the
# class. Only a plain-dict namespace is supported; a custom mapping (enum's
# _EnumDict) as a live body namespace is a later refinement.
def build_class_via_metaclass(
    metaclass: PyClass,
    class_name: str,
    bases: list[PyObj],
    body: PyFunction,
    class_kwds: dict[str, PyObj]
) -> PyObj {
    bases_tuple = PyTuple(t="tuple", items=bases);
    prepared: PyObj = py_none();
    prep = class_lookup_attr(metaclass, "__prepare__");
    if not is_error(prep) {
        prep_args: list[PyObj] = [PyStr(t="str", val=class_name), bases_tuple];
        prepared = py_invoke(bind_attribute(prep, metaclass), prep_args, class_kwds);
        if is_error(prepared) {
            return prepared;
        }
    }
    # A custom mapping namespace (enum's _EnumDict, a dict subclass): run the body
    # into a plain ordered map, then replay each binding through the mapping's
    # __setitem__ so its member-tracking side effects fire in source order. The
    # mapping itself is handed to the metaclass as the classdict.
    if isinstance(prepared, PyUserObj) {
        namespace: dict[str, PyObj] = {};
        body_result = exec_code_frame(
            body.code, [], {}, body.globals, namespace, body.closure, [], {}
        );
        if body_result.t == "error" {
            return body_result;
        }
        mapping = prepared as PyUserObj;
        if user_has_dunder(mapping, "__setitem__") {
            for k in namespace {
                res = call_user_dunder(
                    mapping, "__setitem__", [PyStr(t="str", val=k), namespace[k]]
                );
                if is_error(res) {
                    return res;
                }
            }
        }
        call_args: list[PyObj] = [
            PyStr(t="str", val=class_name),
            bases_tuple,
            prepared
        ];
        return py_invoke(metaclass, call_args, class_kwds);
    }
    # A plain-dict (or absent) namespace: seed, run the body, box a real dict.
    namespace2: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    if isinstance(prepared, PyDict) {
        prep_map = pydict_to_str_map(prepared as PyDict);
        for pk in prep_map {
            namespace2[pk] = prep_map[pk];
        }
    }
    body_result2 = exec_code_frame(
        body.code, [], {}, body.globals, namespace2, body.closure, [], {}
    );
    if body_result2.t == "error" {
        return body_result2;
    }
    ns_dict = dict_from_str_map(namespace2);
    call_args2: list[PyObj] = [PyStr(t="str", val=class_name), bases_tuple, ns_dict];
    return py_invoke(metaclass, call_args2, class_kwds);
}

def make_function_from_stack(stack: list[PyObj], globals: dict[str, PyObj]) -> PyObj {
    if len(stack) == 0 {
        return py_error("RuntimeError", "MAKE_FUNCTION stack underflow");
    }
    code_obj = stack.pop();
    if code_obj.t != "code" {
        return py_error("TypeError", "MAKE_FUNCTION needs code");
    }
    code = code_obj as PyCode;
    return PyFunction(t="function", code=code, globals=globals, name=code.name);
}

# ---------------- generator frame machinery (PLAN.md §5, P5) ----------------
# CPython implements a generator as a suspended frame; jacpython mirrors that.
# PyFrame captures the resumable eval state (stack/fast/cells/ip). YIELD_VALUE
# saves it and hands a PyYield up to run_frame's caller; PyGenerator drives the
# frame forward one yield at a time. PyGenStop is the "frame returned normally"
# (StopIteration) sentinel that distinguishes exhaustion from a real raise.
obj PyFrame(PyObj) {
    has co: PyCode,
        fast: list[PyObj],
        assigned: list[bool],
        cells: list[PyCell],
        closure: list[PyCell],
        stack: list[PyObj],
        globals: dict[str, PyObj],
        locals: dict[str, PyObj],
        ip: int = 0,
        # True when suspended inside `yield from` (YIELD_VALUE oparg 1). A throw
        # is then delegated into the sub-iterator via the SEND loop rather than
        # injected at the outer suspend point.
        yf: bool = False,
        # A pending exception to throw into the current yield-from sub-iterator,
        # consumed by the next SEND instead of a normal send.
        pending_throw: any = None,
        # True once the frame's locals/stack have been released (gen.close() or
        # gi_frame.clear()); guards against running __del__ finalizers twice.
        cleared: bool = False;
}

obj PyYield(PyObj) {
    has val: PyObj;
}

# next()/iter() as native callables (host_builtin routes these here) so they
# drive a native generator/iterator in-VM rather than draining it to a host list.
obj PyNativeBuiltin(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.name == "id" {
            if len(args) == 0 {
                return py_error("TypeError", "id expected 1 argument");
            }
            return PyInt(t="int", val=py_id(args[0]));
        }
        if self.name == "len" {
            if len(args) != 1 {
                return py_error("TypeError", "len() takes exactly one argument");
            }
            return py_len(args[0]);
        }
        if self.name == "hash" {
            if len(args) != 1 {
                return py_error("TypeError", "hash() takes exactly one argument");
            }
            return py_hash(args[0]);
        }
        if self.name == "repr" {
            if len(args) != 1 {
                return py_error("TypeError", "repr() takes exactly one argument");
            }
            return py_repr(args[0]);
        }
        if self.name == "isinstance" {
            if len(args) < 2 {
                return py_error("TypeError", "isinstance expected 2 arguments");
            }
            return PyBool(t="bool", val=py_isinstance(args[0], args[1]));
        }
        if self.name == "issubclass" {
            if len(args) < 2 {
                return py_error("TypeError", "issubclass expected 2 arguments");
            }
            return PyBool(t="bool", val=py_issubclass(args[0], args[1]));
        }
        if self.name == "getattr" {
            # getattr(obj, name[, default]): native attribute access, honoring a
            # 3rd-arg default on AttributeError (CPython only swallows that one).
            if len(args) < 2 {
                return py_error("TypeError", "getattr expected at least 2 arguments");
            }
            attr = py_attr(args[0], expect_str(args[1]));
            if is_error(attr)
                and len(args) >= 3
                and (attr as PyError).exception.type_name == "AttributeError" {
                return args[2];
            }
            return attr;
        }
        if self.name == "hasattr" {
            if len(args) < 2 {
                return py_error("TypeError", "hasattr expected 2 arguments");
            }
            probe = py_attr(args[0], expect_str(args[1]));
            return PyBool(t="bool", val=not is_error(probe));
        }
        if self.name == "setattr" {
            if len(args) < 3 {
                return py_error("TypeError", "setattr expected 3 arguments");
            }
            return py_set_attr(args[0], expect_str(args[1]), args[2]);
        }
        if self.name == "delattr" {
            if len(args) < 2 {
                return py_error("TypeError", "delattr expected 2 arguments");
            }
            return py_del_attr(args[0], expect_str(args[1]));
        }
        if self.name == "iter" {
            if len(args) == 0 {
                return py_error("TypeError", "iter expected at least 1 argument");
            }
            result = py_iter(args[0]);
            if is_error(result) and isinstance(args[0], PyHostProxy) {
                # Dict views and other host-only iterables still materialize once.
                return host_iter(args[0] as PyHostProxy);
            }
            return result;
        }
        # next(iterator[, default])
        if len(args) == 0 {
            return py_error("TypeError", "next expected at least 1 argument");
        }
        step = send_into(args[0], py_none());
        if step.t == "genstop" {
            if len(args) > 1 {
                return args[1];
            }
            return stop_iteration(py_none());
        }
        return step;
    }
}

# A live view of a running frame's globals (`dict[str, PyObj]`, held by
# reference). globals() returns one so module init idioms that MUTATE the module
# namespace -- globals().update({...}), globals()[name] = value -- bind real
# globals a later LOAD_GLOBAL/LOAD_NAME resolves. A snapshot dict would silently
# drop those writes (re._constants._makecodes builds its OPCODES this way).
obj PyGlobalsProxy(PyObj) {
    has ns: dict[str, PyObj];

    def mp_subscript(index: PyObj) -> PyObj {
        key = expect_str(index);
        if key in self.ns {
            return self.ns[key];
        }
        return py_error("KeyError", key);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        self.ns[expect_str(index)] = value;
        return py_none();
    }

    # Iterating globals() yields its keys (module code does
    # `[n for n in globals() if ...]` to compute __all__).
    def tp_iter -> PyObj {
        keys: list[PyObj] = [];
        for k in self.ns {
            keys.append(PyStr(t="str", val=k));
        }
        return PyIter(t="iter", items=keys, index=0);
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "update" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="update");
        }
        if name == "get" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="get");
        }
        if name == "keys" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="keys");
        }
        if name == "values" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="values");
        }
        if name == "items" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="items");
        }
        if name == "setdefault" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="setdefault");
        }
        return py_error("AttributeError", name);
    }
}

# The bound dict-method objects a PyGlobalsProxy hands out. Kept minimal to the
# surface module-init code exercises; each mutates/reads the shared ns directly.
obj PyNsMethod(PyObj) {
    has ns: dict[str, PyObj],
        op: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.op == "update" {
            if len(args) > 0 {
                src = args[0];
                pairs: PyObj = py_none();
                if isinstance(src, PyDict) {
                    pairs = src;
                } else {
                    pairs = from_host(to_host(src));
                }
                if isinstance(pairs, PyDict) {
                    smap = (pairs as PyDict).dict_str_map();
                    for k in smap {
                        self.ns[k] = smap[k];
                    }
                }
            }
            for kw in kwargs {
                self.ns[kw] = kwargs[kw];
            }
            return py_none();
        }
        if self.op == "get" {
            if len(args) > 0 {
                key = expect_str(args[0]);
                if key in self.ns {
                    return self.ns[key];
                }
            }
            if len(args) > 1 {
                return args[1];
            }
            return py_none();
        }
        if self.op == "setdefault" {
            if len(args) > 0 {
                key = expect_str(args[0]);
                if key in self.ns {
                    return self.ns[key];
                }
                fallback = py_none();
                if len(args) > 1 {
                    fallback = args[1];
                }
                self.ns[key] = fallback;
                return fallback;
            }
            return py_none();
        }
        if self.op == "keys" {
            out: list[PyObj] = [];
            for k in self.ns {
                out.append(PyStr(t="str", val=k));
            }
            return PyList(t="list", items=out);
        }
        if self.op == "values" {
            vout: list[PyObj] = [];
            for k in self.ns {
                vout.append(self.ns[k]);
            }
            return PyList(t="list", items=vout);
        }
        if self.op == "items" {
            iout: list[PyObj] = [];
            for k in self.ns {
                pair: list[PyObj] = [PyStr(t="str", val=k), self.ns[k]];
                iout.append(PyTuple(t="tuple", items=pair));
            }
            return PyList(t="list", items=iout);
        }
        return py_error("TypeError", "unsupported namespace op");
    }
}

# ---- native set methods (.pop/.difference/.union/... ) --------------------
# PySet is a native (na-clean leaf) container, so its methods can't route to the
# host the way str/list/dict do -- to_host would round-trip and lose identity.
# The method surface lives here (host-adjacent: arbitrary-iterable args are
# drained through py_iter/host_iter), wrapping the leaf's value-based set algebra.

# Materialize any iterable arg into a PyList of its members, or return a PyError
# if it is not iterable (this is the TypeError set().difference(123) must raise).
def members_of(arg: PyObj) -> PyObj {
    if isinstance(arg, PySet) {
        return PyList(t="list", items=(arg as PySet).set_members());
    }
    if isinstance(arg, PyList) {
        return arg;
    }
    it = py_iter(arg);
    if is_error(it) {
        it = host_iter(PyHostProxy(t="host", val=to_host(arg)));
        if is_error(it) {
            return it;
        }
    }
    out: list[PyObj] = [];
    while True {
        step = send_into(it, py_none());
        if step.t == "genstop" {
            break;
        }
        if is_error(step) {
            return step;
        }
        out.append(step);
    }
    return PyList(t="list", items=out);
}

def set_from_members(members: list[PyObj], frozen: bool) -> PyObj {
    tag = "set";
    if frozen {
        tag = "frozenset";
    }
    s = PySet(t=tag, items={}, frozen=frozen);
    for m in members {
        r = s.set_add(m);
        if is_error(r) {
            return r;
        }
    }
    return s;
}

# Build a fresh PySet from one iterable arg (used to coerce a .difference([...])
# operand into set algebra). Propagates the not-iterable TypeError.
def coerce_set(arg: PyObj) -> PyObj {
    om = members_of(arg);
    if is_error(om) {
        return om;
    }
    return set_from_members((om as PyList).items, False);
}

def is_set_method(name: str, frozen: bool) -> bool {
    shared = name == "copy"
        or name == "union"
        or name == "intersection"
        or name == "difference"
        or name == "symmetric_difference"
        or name == "issubset"
        or name == "issuperset"
        or name == "isdisjoint"
        or name == "__contains__";
    if shared {
        return True;
    }
    if frozen {
        return False;
    }
    return name == "add"
        or name == "discard"
        or name == "remove"
        or name == "pop"
        or name == "clear"
        or name == "update"
        or name == "difference_update"
        or name == "intersection_update"
        or name == "symmetric_difference_update";
}

obj PySetMethod(PyObj) {
    has target: PySet,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        s = self.target;
        if n == "__contains__" {
            if len(args) < 1 {
                return py_error("TypeError", "__contains__ expected 1 argument");
            }
            return s.set_lookup(args[0]);
        }
        # --- no-arg mutating / accessor methods ---
        if n == "pop" {
            return s.set_pop();
        }
        if n == "copy" {
            return s.set_copy();
        }
        if n == "clear" {
            return s.set_clear();
        }
        if n == "add" {
            if len(args) < 1 {
                return py_error("TypeError", "add expected 1 argument");
            }
            return s.set_add(args[0]);
        }
        if n == "discard" {
            if len(args) < 1 {
                return py_error("TypeError", "discard expected 1 argument");
            }
            return s.set_discard(args[0]);
        }
        if n == "remove" {
            if len(args) < 1 {
                return py_error("TypeError", "remove expected 1 argument");
            }
            if not s.set_contains(args[0]) {
                return py_error("KeyError", dict_key_repr(args[0]));
            }
            return s.set_discard(args[0]);
        }
        # --- single-iterable-arg predicates ---
        if n == "issubset" or n == "issuperset" or n == "isdisjoint" {
            if len(args) < 1 {
                return py_error("TypeError", n + " expected 1 argument");
            }
            other = coerce_set(args[0]);
            if is_error(other) {
                return other;
            }
            os = other as PySet;
            if n == "issubset" {
                return set_richcompare(Py_LE, s, os);
            }
            if n == "issuperset" {
                return set_richcompare(Py_GE, s, os);
            }
            # isdisjoint: no shared member (element ``==``, not hashkey only).
            for hk in s.items {
                elem = s.items[hk];
                found = os.set_lookup(elem);
                if is_error(found) {
                    return found;
                }
                if (found as PyBool).val {
                    return PyBool(t="bool", val=False);
                }
            }
            return PyBool(t="bool", val=True);
        }
        # --- *others set-algebra (non-mutating) ---
        if n == "union"
            or n == "intersection"
            or n == "difference"
            or n == "symmetric_difference" {
            kind = 7;
            if n == "intersection" {
                kind = 1;
            } elif n == "difference" {
                kind = 10;
            } elif n == "symmetric_difference" {
                kind = 12;
            }
            acc = s.set_copy();
            for a in args {
                other = coerce_set(a);
                if is_error(other) {
                    return other;
                }
                acc = acc.nb_binop(kind, other as PySet);
                if is_error(acc) {
                    return acc;
                }
            }
            return acc;
        }
        # --- *others mutating updates ---
        if n == "update"
            or n == "difference_update"
            or n == "intersection_update"
            or n == "symmetric_difference_update" {
            kind = 7;
            if n == "difference_update" {
                kind = 10;
            } elif n == "intersection_update" {
                kind = 1;
            } elif n == "symmetric_difference_update" {
                kind = 12;
            }
            acc = s.set_copy();
            for a in args {
                other = coerce_set(a);
                if is_error(other) {
                    return other;
                }
                acc = acc.nb_binop(kind, other as PySet);
                if is_error(acc) {
                    return acc;
                }
            }
            # Write the result back into the receiver's storage in place.
            s.items = (acc as PySet).items;
            return py_none();
        }
        return py_error("AttributeError", n);
    }
}

# Native mutating/accessor list methods. Without these, `lst.append(x)` routes to
# host_getattr on a to_host COPY of the list -- the mutation is lost. Load-bearing
# for any code that builds a list by `.append` (enum's EnumDict._member_names
# tracking, most stdlib), not just comprehensions (which use LIST_APPEND).
def is_list_method(name: str) -> bool {
    return name == "append"
        or name == "extend"
        or name == "insert"
        or name == "pop"
        or name == "remove"
        or name == "clear"
        or name == "index"
        or name == "count"
        or name == "reverse"
        or name == "sort"
        or name == "copy";
}

# Materialize the elements of a native iterable argument (list/tuple/set/iter).
def iterable_items(src: PyObj) -> list[PyObj] {
    if isinstance(src, PyList) {
        return (src as PyList).items;
    }
    if isinstance(src, PyTuple) {
        return (src as PyTuple).items;
    }
    if isinstance(src, PySet) {
        return (src as PySet).set_members();
    }
    if isinstance(src, PyIter) {
        return (src as PyIter).items;
    }
    it = py_iter(src);
    if isinstance(it, PyIter) {
        return (it as PyIter).items;
    }
    return [];
}

# CPython list.sort(): stable merge sort driven by py_compare(<). key= uses
# decorate-sort-undecorate; reverse= flips the comparison (NOT the tie-break),
# so equal elements keep insertion order in both directions. Mutates lst in
# place; returns an error from a failing comparison, else None.
def list_sort_inplace(lst: PyList, key_fn: PyObj, do_reverse: bool) -> PyObj {
    n_count = len(lst.items);
    if n_count <= 1 {
        return py_none();
    }
    pairs: list[PyObj] = [];
    idx = 0;
    while idx < n_count {
        v = lst.items[idx];
        k = v;
        if not (key_fn.t == "none") {
            res = key_fn.tp_call([v], {});
            if is_error(res) {
                return res;
            }
            k = res;
        }
        pairs.append(PyTuple(t="tuple", items=[k, v]));
        idx = idx + 1;
    }
    width = 1;
    while width < n_count {
        merged: list[PyObj] = [];
        i = 0;
        while i < n_count {
            mid = i + width;
            hi = i + 2 * width;
            if mid > n_count {
                mid = n_count;
            }
            if hi > n_count {
                hi = n_count;
            }
            a = i;
            b = mid;
            while a < mid and b < hi {
                ka = ((pairs[a] as PyTuple).items[0]);
                kb = ((pairs[b] as PyTuple).items[0]);
                # Normal order takes b when kb < ka; reverse takes b when
                # ka < kb. Ties always take a, which is what keeps the sort
                # stable in both directions.
                if do_reverse {
                    lt = py_compare(0, ka, kb);
                } else {
                    lt = py_compare(0, kb, ka);
                }
                if is_error(lt) {
                    return lt;
                }
                if (lt as PyBool).val {
                    merged.append(pairs[b]);
                    b = b + 1;
                } else {
                    merged.append(pairs[a]);
                    a = a + 1;
                }
            }
            while a < mid {
                merged.append(pairs[a]);
                a = a + 1;
            }
            while b < hi {
                merged.append(pairs[b]);
                b = b + 1;
            }
            i = i + 2 * width;
        }
        pairs = merged;
        width = width * 2;
    }
    sorted_items: list[PyObj] = [];
    for p in pairs {
        sorted_items.append((p as PyTuple).items[1]);
    }
    lst.items = sorted_items;
    return py_none();
}

obj PyListMethod(PyObj) {
    has target: PyList,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        lst = self.target;
        if n == "append" {
            lst.items.append(args[0]);
            return py_none();
        }
        if n == "extend" {
            for x in iterable_items(args[0]) {
                lst.items.append(x);
            }
            return py_none();
        }
        if n == "insert" {
            i = (args[0].to_index() as PyInt).val;
            if i < 0 {
                i = len(lst.items) + i;
            }
            if i < 0 {
                i = 0;
            }
            if i > len(lst.items) {
                i = len(lst.items);
            }
            rebuilt: list[PyObj] = [];
            j = 0;
            while j < len(lst.items) {
                if j == i {
                    rebuilt.append(args[1]);
                }
                rebuilt.append(lst.items[j]);
                j = j + 1;
            }
            if i >= len(lst.items) {
                rebuilt.append(args[1]);
            }
            lst.items = rebuilt;
            return py_none();
        }
        if n == "pop" {
            if len(lst.items) == 0 {
                return py_error("IndexError", "pop from empty list");
            }
            i = len(lst.items) - 1;
            if len(args) >= 1 {
                i = (args[0].to_index() as PyInt).val;
                if i < 0 {
                    i = len(lst.items) + i;
                }
            }
            if i < 0 or i >= len(lst.items) {
                return py_error("IndexError", "pop index out of range");
            }
            v = lst.items[i];
            kept: list[PyObj] = [];
            j = 0;
            while j < len(lst.items) {
                if j != i {
                    kept.append(lst.items[j]);
                }
                j = j + 1;
            }
            lst.items = kept;
            return v;
        }
        if n == "remove" {
            j = 0;
            while j < len(lst.items) {
                if list_elem_eq(lst.items[j], args[0]) {
                    kept2: list[PyObj] = [];
                    k = 0;
                    while k < len(lst.items) {
                        if k != j {
                            kept2.append(lst.items[k]);
                        }
                        k = k + 1;
                    }
                    lst.items = kept2;
                    return py_none();
                }
                j = j + 1;
            }
            return py_error("ValueError", "list.remove(x): x not in list");
        }
        if n == "clear" {
            lst.items = [];
            return py_none();
        }
        if n == "index" {
            j = 0;
            while j < len(lst.items) {
                if list_elem_eq(lst.items[j], args[0]) {
                    return PyInt(t="int", val=j);
                }
                j = j + 1;
            }
            return py_error("ValueError", "not in list");
        }
        if n == "count" {
            c = 0;
            for x in lst.items {
                if list_elem_eq(x, args[0]) {
                    c = c + 1;
                }
            }
            return PyInt(t="int", val=c);
        }
        if n == "reverse" {
            rev: list[PyObj] = [];
            j = len(lst.items) - 1;
            while j >= 0 {
                rev.append(lst.items[j]);
                j = j - 1;
            }
            lst.items = rev;
            return py_none();
        }
        if n == "sort" {
            if len(args) != 0 {
                return py_error("TypeError", "sort() takes no positional arguments");
            }
            key_fn = py_none();
            do_reverse = False;
            for kw in kwargs {
                if kw == "key" {
                    key_fn = kwargs[kw];
                } elif kw == "reverse" {
                    do_reverse = py_truth(kwargs[kw]);
                } else {
                    return py_error("TypeError", "'" + kw + "' is an invalid keyword argument for sort()");
                }
            }
            return list_sort_inplace(lst, key_fn, do_reverse);
        }
        if n == "copy" {
            dup: list[PyObj] = [];
            for x in lst.items {
                dup.append(x);
            }
            return PyList(t="list", items=dup);
        }
        return py_error("AttributeError", n);
    }
}

# Element equality for list membership (remove/index/count): a real __eq__ so a
# user object or boxed value compares by value, not identity.
def list_elem_eq(a: PyObj, b: PyObj) -> bool {
    res = py_compare(2, a, b);
    if isinstance(res, PyBool) {
        return (res as PyBool).val;
    }
    return False;
}

# The native mutating/accessor dict methods. keys()/values()/items() are served
# separately by PyDictViewCtor; these must be native too so that a mutation on a
# dict subclass instance (enum's EnumDict.setdefault/pop) hits the real storage
# instead of a throwaway to_host copy.
def is_dict_method(name: str) -> bool {
    return name == "get"
        or name == "setdefault"
        or name == "pop"
        or name == "popitem"
        or name == "update"
        or name == "clear"
        or name == "copy"
        or name == "__contains__"
        or name == "__getitem__"
        or name == "__setitem__"
        or name == "__delitem__";
}

obj PyDictMethod(PyObj) {
    has target: PyDict,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        n = self.name;
        d = self.target;
        if n == "get" {
            if d.dict_contains(args[0]) {
                return d.mp_subscript(args[0]);
            }
            return args[1] if len(args) >= 2 else py_none();
        }
        if n == "setdefault" {
            if d.dict_contains(args[0]) {
                return d.mp_subscript(args[0]);
            }
            default_val = args[1] if len(args) >= 2 else py_none();
            r = d.mp_ass_subscript(args[0], default_val);
            if is_error(r) {
                return r;
            }
            return default_val;
        }
        if n == "pop" {
            if d.dict_contains(args[0]) {
                v = d.mp_subscript(args[0]);
                d.mp_del_subscript(args[0]);
                return v;
            }
            if len(args) >= 2 {
                return args[1];
            }
            return py_error("KeyError", dict_key_repr(args[0]));
        }
        if n == "popitem" {
            # LIFO: dict.popitem() returns the LAST inserted (key, value) pair,
            # not the first. dict_keys() yields insertion order, so take the tail.
            last_key: PyObj = py_none();
            has_key = False;
            for keyobj in d.dict_keys() {
                last_key = keyobj;
                has_key = True;
            }
            if has_key {
                v = d.mp_subscript(last_key);
                d.mp_del_subscript(last_key);
                return PyTuple(t="tuple", items=[last_key, v]);
            }
            return py_error("KeyError", "popitem(): dictionary is empty");
        }
        if n == "clear" {
            for keyobj in d.dict_keys() {
                d.mp_del_subscript(keyobj);
            }
            return py_none();
        }
        if n == "copy" {
            nd = PyDict(t="dict", items={});
            for keyobj in d.dict_keys() {
                nd.dict_set(keyobj, d.mp_subscript(keyobj));
            }
            return nd;
        }
        if n == "update" {
            if len(args) >= 1 {
                src = args[0];
                if isinstance(src, PyDict) {
                    sd = src as PyDict;
                    for keyobj in sd.dict_keys() {
                        d.dict_set(keyobj, sd.mp_subscript(keyobj));
                    }
                } elif isinstance(src, PyUserObj)
                    and (src as PyUserObj)._has_base()
                    and isinstance((src as PyUserObj)._base_obj(), PyDict) {
                    sd = (src as PyUserObj)._base_obj() as PyDict;
                    for keyobj in sd.dict_keys() {
                        d.dict_set(keyobj, sd.mp_subscript(keyobj));
                    }
                } else {
                    # An iterable of (key, value) pairs.
                    pairs: list[PyObj] = [];
                    if isinstance(src, PyList) {
                        pairs = (src as PyList).items;
                    } elif isinstance(src, PyTuple) {
                        pairs = (src as PyTuple).items;
                    } else {
                        seq = py_iter(src);
                        if is_error(seq) {
                            return seq;
                        }
                        if isinstance(seq, PyIter) {
                            pairs = (seq as PyIter).items;
                        }
                    }
                    for pair in pairs {
                        if isinstance(pair, PyTuple) {
                            pt = (pair as PyTuple).items;
                            if len(pt) == 2 {
                                d.dict_set(pt[0], pt[1]);
                            }
                        }
                    }
                }
            }
            for k in kwargs {
                d.dict_set(PyStr(t="str", val=k), kwargs[k]);
            }
            return py_none();
        }
        if n == "__contains__" {
            return PyBool(t="bool", val=d.dict_contains(args[0]));
        }
        if n == "__getitem__" {
            return d.mp_subscript(args[0]);
        }
        if n == "__setitem__" {
            return d.mp_ass_subscript(args[0], args[1]);
        }
        if n == "__delitem__" {
            return d.mp_del_subscript(args[0]);
        }
        return py_error("AttributeError", n);
    }
}

# ---- native dict views (.keys()/.values()/.items()) -----------------------
# CPython dict views are lazy, set-like windows on a live dict. Native ones let
# view comparison / set operations invoke element __eq__ (so a raising element
# comparison propagates, unlike the by-hashkey set model) and let view iteration
# carry the dict's mutation guard. keys/items are set-like; values is not.

# Sentinel returned by dict_lookup_value when a key is absent (None is a valid
# stored value, so it can't double as the not-found marker).
obj PyAbsent(PyObj) {}

# Membership test for a key, confirming a hashkey-bucket hit with a real eq when
# either side carries a custom __eq__. Returns PyBool or a PyError (raising eq).
def dict_haskey(d: PyDict, key: PyObj) -> PyObj {
    hk = key.tp_hashkey();
    if hk == "" {
        return py_error("TypeError", "unhashable type");
    }
    if not (hk in d.items) {
        return PyBool(t="bool", val=False);
    }
    stored = d.items[hk].key;
    if _needs_eq_confirm(stored) or _needs_eq_confirm(key) {
        keq = py_compare(2, stored, key);
        if is_error(keq) {
            return keq;
        }
        return PyBool(t="bool", val=py_truth(keq));
    }
    return PyBool(t="bool", val=True);
}

# The stored value for a key, a PyAbsent sentinel if not present, or a PyError.
def dict_lookup_value(d: PyDict, key: PyObj) -> PyObj {
    hk = key.tp_hashkey();
    if hk == "" {
        return py_error("TypeError", "unhashable type");
    }
    if not (hk in d.items) {
        return PyAbsent(t="absent");
    }
    stored = d.items[hk].key;
    if _needs_eq_confirm(stored) or _needs_eq_confirm(key) {
        keq = py_compare(2, stored, key);
        if is_error(keq) {
            return keq;
        }
        if not py_truth(keq) {
            return PyAbsent(t="absent");
        }
    }
    return d.items[hk].value;
}

# The bound method object d.keys / d.values / d.items resolves to; calling it
# builds the view (matching CPython, where `d.keys` is a builtin method and
# `d.keys()` is the view).
obj PyDictViewCtor(PyObj) {
    has d: PyDict,
        mode: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyDictView(t="dictview_obj", d=self.d, mode=self.mode);
    }
}

obj PyDictView(PyObj) {
    has d: PyDict,
        mode: str;

    def tp_iter -> PyObj {
        return self.d.dict_iter(self.mode);
    }

    def tp_bool -> bool {
        return len(self.d.items) != 0;
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        return dictview_richcompare(kind, self, other);
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        return dictview_binop(kind, self, other);
    }
}

# The view's elements as PyObjs: keys, values, or (key, value) tuples.
def dictview_elements(view: PyDictView) -> list[PyObj] {
    out: list[PyObj] = [];
    for hk in view.d.items {
        `entry = view.d.items[hk];
        if view.mode == "values" {
            out.append(`entry.value);
        } elif view.mode == "items" {
            out.append(PyTuple(t="tuple", items=[`entry.key, `entry.value]));
        } else {
            out.append(`entry.key);
        }
    }
    return out;
}

# Element-wise containment that invokes __eq__ where CPython does: a keys/values
# element by comparison, an items (k, v) pair by key lookup + value compare.
def view_contains(view: PyDictView, elem: PyObj) -> PyObj {
    if view.mode == "keys" {
        return dict_haskey(view.d, elem);
    }
    if view.mode == "items" {
        if not isinstance(elem, PyTuple) {
            return PyBool(t="bool", val=False);
        }
        pair = elem as PyTuple;
        if len(pair.items) != 2 {
            return PyBool(t="bool", val=False);
        }
        look = dict_lookup_value(view.d, pair.items[0]);
        if is_error(look) {
            return look;
        }
        if look.t == "absent" {
            return PyBool(t="bool", val=False);
        }
        return py_compare(2, pair.items[1], look);
    }
    # values view: linear scan, comparing each stored value.
    for hk in view.d.items {
        c = py_compare(2, view.d.items[hk].value, elem);
        if is_error(c) {
            return c;
        }
        if py_truth(c) {
            return PyBool(t="bool", val=True);
        }
    }
    return PyBool(t="bool", val=False);
}

# Elements of any set-like operand (view / native set / dict[keys]).
def setlike_elements(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyDictView) {
        return dictview_elements(o as PyDictView);
    }
    if isinstance(o, PySet) {
        return (o as PySet).set_members();
    }
    if isinstance(o, PyDict) {
        return (o as PyDict).dict_keys();
    }
    return [];
}

def setlike_count(o: PyObj) -> int {
    if isinstance(o, PyDictView) {
        return len((o as PyDictView).d.items);
    }
    if isinstance(o, PySet) {
        return len((o as PySet).items);
    }
    if isinstance(o, PyDict) {
        return len((o as PyDict).items);
    }
    return len(setlike_elements(o));
}

# elem in a set-like container, routing to the eq-invoking path per container.
def setlike_contains(container: PyObj, elem: PyObj) -> PyObj {
    if isinstance(container, PyDictView) {
        return view_contains(container as PyDictView, elem);
    }
    if isinstance(container, PySet) {
        return (container as PySet).set_lookup(elem);
    }
    if isinstance(container, PyDict) {
        return dict_haskey(container as PyDict, elem);
    }
    return py_contains(container, elem);
}

# True iff every element of x is contained in y (PyBool), or a PyError if an
# element comparison raised. The subset primitive under set-like comparison.
def all_contained(x: PyObj, y: PyObj) -> PyObj {
    for e in setlike_elements(x) {
        c = setlike_contains(y, e);
        if is_error(c) {
            return c;
        }
        if not py_truth(c) {
            return PyBool(t="bool", val=False);
        }
    }
    return PyBool(t="bool", val=True);
}

# CPython dict-view set comparison (==, !=, <, <=, >, >=). Both operands are
# treated as sets; an element __eq__ raised mid-comparison propagates.
def dictview_richcompare(kind: int, a: PyObj, b: PyObj) -> PyObj {
    la = setlike_count(a);
    lb = setlike_count(b);
    if kind == 2 {
        if la != lb {
            return PyBool(t="bool", val=False);
        }
        return all_contained(a, b);
    }
    if kind == 3 {
        if la != lb {
            return PyBool(t="bool", val=True);
        }
        r = all_contained(a, b);
        if is_error(r) {
            return r;
        }
        return PyBool(t="bool", val=not py_truth(r));
    }
    if kind == 1 {
        return all_contained(a, b);
    }
    if kind == 5 {
        return all_contained(b, a);
    }
    if kind == 0 {
        if not (la < lb) {
            return PyBool(t="bool", val=False);
        }
        return all_contained(a, b);
    }
    if kind == 4 {
        if not (la > lb) {
            return PyBool(t="bool", val=False);
        }
        return all_contained(b, a);
    }
    return py_error("TypeError", "unorderable types");
}

# Coerce a set-op operand to a PySet: a view materializes its elements, a set
# passes through, anything else is drained as an iterable (propagating the
# not-iterable TypeError).
def to_set_like(o: PyObj) -> PyObj {
    if isinstance(o, PySet) {
        return o;
    }
    if isinstance(o, PyDictView) {
        return set_from_members(dictview_elements(o as PyDictView), False);
    }
    return coerce_set(o);
}

# Dict-view set algebra (| & - ^) with a view on either side, producing a PySet.
def dictview_binop(kind: int, lhs: PyObj, rhs: PyObj) -> PyObj {
    ls = to_set_like(lhs);
    if is_error(ls) {
        return ls;
    }
    rs = to_set_like(rhs);
    if is_error(rs) {
        return rs;
    }
    return (ls as PySet).nb_binop(kind, rs as PySet);
}

# A frame that ran to RETURN_VALUE. `val` is the generator's return value, which
# `yield from` yields as the sub-expression result and .send()/next() surface as
# StopIteration(val).
obj PyGenStop(PyObj) {
    has val: PyObj;
}

obj PyGenerator(PyObj) {
    has frame: PyFrame,
        started: bool = False,
        finished: bool = False,
        running: bool = False;

    def tp_iter -> PyObj {
        return self;
    }

    # gen.send / gen.throw / gen.close / gen.__next__ resolve to native bound
    # driver methods; every other attribute is a real AttributeError.
    def tp_getattro(name: str) -> PyObj {
        if name == "send" or name == "throw" or name == "close" or name == "__next__" {
            return PyGenMethod(t="gen_method", gen=self, kind=name);
        }
        if name == "gi_frame" {
            return PyGenFrame(t="genframe", gen=self);
        }
        if name == "gi_running" {
            # True only while the generator's frame is actively executing;
            # observable from re-entrant access (the generator inspecting
            # itself through a callback), False while suspended/finished.
            return PyBool(t="bool", val=self.running);
        }
        return py_error("AttributeError", name);
    }
}

# A bound generator driver (gen.send/throw/close/__next__). Calling it drives the
# suspended frame and raises StopIteration on exhaustion, matching CPython's
# generator method surface (unlike FOR_ITER, which swallows the StopIteration).
obj PyGenMethod(PyObj) {
    has gen: PyGenerator,
        kind: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.kind == "throw" {
            thrown = py_none();
            if len(args) > 0 {
                thrown = args[0];
            }
            return gen_throw(self.gen, thrown);
        }
        if self.kind == "close" {
            return gen_close(self.gen);
        }
        sent = py_none();
        if self.kind == "send" and len(args) > 0 {
            sent = args[0];
        }
        return gen_send(self.gen, sent);
    }
}

# Resume `gen` with `sent` (the value YIELD_VALUE produces on wake; None for
# plain iteration). Returns the yielded PyObj on a yield, a PyGenStop on normal
# return (exhaustion), or a propagating error object on a raise.
def gen_resume(gen: PyGenerator, sent: PyObj) -> PyObj {
    if gen.running {
        # CPython: resuming a generator whose frame is already executing
        # (self-resume via a callback/trampoline) raises ValueError.
        return py_error("ValueError", "generator already executing");
    }
    if gen.finished {
        return PyGenStop(t="genstop", val=py_none());
    }
    if gen.started {
        # YIELD_VALUE popped its operand when it suspended; the resume value
        # takes its place on the stack (the trailing POP_TOP discards it in a
        # genexpr; `x = yield` would bind it in a full generator).
        gen.frame.stack.append(sent);
    }
    gen.started = True;
    gen.running = True;
    result = run_frame(gen.frame);
    return finish_gen_result(gen, result);
}

# Common tail for every generator re-entry (resume/send/throw): translate the
# raw run_frame outcome into the yielded value | PyGenStop(return value) | error
# shape that all generator drivers speak.
def finish_gen_result(gen: PyGenerator, result: PyObj) -> PyObj {
    gen.running = False;
    if is_error(result) {
        gen.finished = True;
        return result;
    }
    if result.t == "yield" {
        return (result as PyYield).val;
    }
    gen.finished = True;
    return PyGenStop(t="genstop", val=result);
}

# gen.send(v): resume with v, returning the next yielded value or raising
# StopIteration(return_value) on exhaustion. A just-started generator only
# accepts None (CPython raises TypeError otherwise).
def gen_send(gen: PyGenerator, sent: PyObj) -> PyObj {
    if not gen.started and not gen.finished and sent.t != "none" {
        return py_error(
            "TypeError", "can't send non-None value to a just-started generator"
        );
    }
    result = gen_resume(gen, sent);
    if result.t == "genstop" {
        return stop_iteration((result as PyGenStop).val);
    }
    return result;
}

# StopIteration carrying the generator's return value as its .value payload.
def stop_iteration(value: PyObj) -> PyObj {
    return PyError(
        t="error",
        exception=PyException(
            t="exception", type_name="StopIteration", message="", value=value
        ),
    );
}

# Coerce a thrown operand (exception instance, exception type, or already-raised
# error) into a PyError for injection at the suspend point.
def as_error(value: PyObj) -> PyObj {
    if value.t == "error" {
        return value;
    }
    return py_raise_value(value);
}

# gen.throw(exc): resume the generator as though `exc` were raised at the point
# where it last suspended, so a try/except surrounding the yield can catch it.
def gen_throw(gen: PyGenerator, thrown: PyObj) -> PyObj {
    if gen.running {
        return py_error("ValueError", "generator already executing");
    }
    err = as_error(thrown);
    if err.t != "error" {
        return err;
    }
    if not gen.started or gen.finished {
        # Nothing suspended to resume into: the exception propagates directly.
        gen.finished = True;
        return err;
    }
    frame = gen.frame;
    if frame.yf {
        # Suspended inside `yield from`: delegate the throw into the sub-iterator
        # by re-running the SEND loop in throw mode. SEND's existing yield /
        # exhaustion / error handling then completes or unwinds the yield-from.
        frame.pending_throw = err;
        frame.stack.append(py_none());  # sent-value placeholder SEND reads below
        gen.running = True;
        return finish_gen_result(gen, run_frame(frame));
    }
    # frame.ip sits one instruction past YIELD_VALUE; the handler lookup wants
    # the yield's own offset (YIELD_VALUE has no inline cache, so -2 bytes).
    offset = frame.ip - 2;
    target = recover_exception(frame.co, err, offset, frame.stack);
    if target < 0 {
        gen.finished = True;
        return err;
    }
    frame.ip = target;
    gen.running = True;
    result = run_frame(frame);
    return finish_gen_result(gen, result);
}

# Throw `err` into a yield-from sub-iterator (the SEND-in-throw-mode step).
# Returns the same yielded-value | PyGenStop | error shape as send_into.
def send_throw_into(receiver: PyObj, err: PyObj) -> PyObj {
    if receiver.t == "generator" or receiver.t == "coroutine" {
        return gen_throw(receiver as PyGenerator, err);
    }
    # A non-generator sub-iterator with a .throw() gets it; otherwise the
    # exception simply propagates at the delegation point.
    thrower = py_attr(receiver, "throw");
    if is_error(thrower) {
        return err;
    }
    result = py_invoke(thrower, [(err as PyError).exception], {});
    if is_error(result) {
        exc = (result as PyError).exception;
        if exc.type_name == "StopIteration" {
            payload = py_none();
            if exc.value is not None {
                payload = exc.value as PyObj;
            }
            return PyGenStop(t="genstop", val=payload);
        }
        return result;
    }
    return result;
}

# Release a frame's held references (fast locals, evaluation stack, cell
# contents) and run __del__ finalizers on any user object thereby dropped. This
# models CPython's frame teardown on gen.close()/gi_frame.clear(): a local whose
# last reference lived in the frame is finalized. We approximate "last reference"
# by the common case the generator machinery guarantees -- an argument passed
# straight into the generator call is reachable only through its frame -- since
# jacpython does not carry Python-level refcounts. Idempotent via frame.cleared.
def frame_clear(frame: PyFrame) -> None {
    if frame.cleared {
        return;
    }
    frame.cleared = True;
    held: list[PyObj] = [];
    idx = 0;
    while idx < len(frame.fast) {
        if idx < len(frame.assigned) and frame.assigned[idx] {
            held.append(frame.fast[idx]);
        }
        idx = idx + 1;
    }
    for item in frame.stack {
        held.append(item);
    }
    for cell in frame.cells {
        held.append(cell.val);
    }
    for name in frame.locals {
        held.append(frame.locals[name]);
    }
    frame.fast = [];
    frame.stack = [];
    frame.locals = {};
    for obj in held {
        if isinstance(obj, PyUserObj)
            and user_has_dunder(obj as PyUserObj, "__del__") {
            _ = call_user_dunder(obj as PyUserObj, "__del__", []);
        }
    }
}

# A generator's gi_frame surface: only .clear() is modeled (the frame-teardown
# entry point CPython exposes), which releases the suspended frame's locals and
# finalizes any user object dropped -- then marks the generator exhausted.
obj PyGenFrame(PyObj) {
    has gen: PyGenerator;

    def tp_getattro(name: str) -> PyObj {
        if name == "clear" {
            return PyGenFrameClear(t="genframe_clear", gen=self.gen);
        }
        return py_error("AttributeError", name);
    }
}

obj PyGenFrameClear(PyObj) {
    has gen: PyGenerator;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        frame_clear(self.gen.frame);
        self.gen.finished = True;
        return py_none();
    }
}

# Native copy.copy / copy.deepcopy. Generators (and coroutines) are uncopyable in
# CPython -- no __copy__/__reduce_ex__ support, so copy raises TypeError -- and a
# native generator can't cross to_host as a live generator anyway (it would drain
# to a list, spuriously succeeding). Every other value delegates to host copy.
obj PyCopyFn(PyObj) {
    has deep: bool;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "copy expected at least 1 argument");
        }
        if isinstance(args[0], PyGenerator) {
            return py_error("TypeError", "cannot pickle 'generator' object");
        }
        mod = host_import("copy", py_none());
        if is_error(mod) {
            return mod;
        }
        fnname = "copy";
        if self.deep {
            fnname = "deepcopy";
        }
        fn = mod.tp_getattro(fnname);
        if is_error(fn) {
            return fn;
        }
        return py_invoke(fn, args, kwargs);
    }
}

# The native `copy` module, seeded into a Layer-1 namespace so a test that does
# copy.copy(gen) sees CPython's TypeError natively (the host proxy would drain).
# Native weakref module surface (shimmed over host weakref). CPython-faithful
# for objects whose RAW Python identity is the object itself (PyUserObj,
# PyClass, functions, generators): deref hands back the identical object, and
# death follows refcounting exactly. Boxed value types (int/str/list/...) are
# rejected up front because CPython makes them un-weakreferenceable, and host
# proxies are rejected because deref would mint a fresh proxy and break
# `r() is o` identity.
obj PyWeakRefFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            # callback= / weakref.ref(cls) forms unsupported by this surface.
            return py_error("TypeError", "weakref.ref expected 1 argument");
        }
        target = args[0];
        if isinstance(target, PyHostProxy) or isinstance(target, PyInt)
            or isinstance(target, PyFloat) or isinstance(target, PyBool)
            or isinstance(target, PyStr) or isinstance(target, PyBytes)
            or isinstance(target, PyTuple) or isinstance(target, PyList)
            or isinstance(target, PyDict) or isinstance(target, PySet)
            or isinstance(target, PyNoneType) {
            tname = "object";
            tn = py_type_of(target);
            if isinstance(tn, PyClass) {
                tname = (tn as PyClass).name;
            }
            return py_error("TypeError", "cannot create weak reference to '" + tname + "' object");
        }
        wr = _jac_make_weakref(target);
        if wr is None {
            return py_error("TypeError", "cannot create weak reference to 'object' object");
        }
        return PyWeakRef(t="weakref", wr=wr);
    }
}

obj PyWeakRef(PyObj) {
    has wr: any;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        raw = _jac_weakref_deref(self.wr);
        if raw is None {
            return py_none();
        }
        # The raw value IS the original PyObj: identity (`r() is o`) holds.
        return raw as PyObj;
    }
}

def build_weakref_module -> PyObj {
    return PyModule(
        t="module",
        name="weakref",
        attrs={
            "ref": PyWeakRefFn(t="weakref_fn"),
        },
    );
}

def build_copy_module -> PyObj {
    return PyModule(
        t="module",
        name="copy",
        attrs={
            "copy": PyCopyFn(t="copy_fn", deep=False),
            "deepcopy": PyCopyFn(t="copy_fn", deep=True),

        },
    );
}

# gen.close(): throw GeneratorExit in. Swallowing it (StopIteration or letting
# GeneratorExit propagate) is a clean close; yielding again is a RuntimeError.
def gen_close(gen: PyGenerator) -> PyObj {
    if gen.finished or not gen.started {
        gen.finished = True;
        frame_clear(gen.frame);
        return py_none();
    }
    gen_exit = PyException(t="exception", type_name="GeneratorExit", message="");
    result = gen_throw(gen, gen_exit);
    gen.finished = True;
    frame_clear(gen.frame);
    if result.t == "genstop" {
        # The generator caught GeneratorExit and returned; close() surfaces that
        # return value (None if it just fell off the end). (CPython 3.13+.)
        return (result as PyGenStop).val;
    }
    if is_error(result) {
        if (result as PyError).exception.type_name == "GeneratorExit" {
            return py_none();
        }
        return result;
    }
    return py_error("RuntimeError", "generator ignored GeneratorExit");
}

# Drive one step of a yield-from sub-iterator (SEND). Returns the yielded value,
# a PyGenStop(return value) on exhaustion, or a propagating error.
def send_into(receiver: PyObj, sent: PyObj) -> PyObj {
    # A native coroutine drives through the identical suspend/resume machinery as
    # a generator -- `await` lowers to the same SEND loop `yield from` uses.
    if receiver.t == "generator" or receiver.t == "coroutine" {
        return gen_resume(receiver as PyGenerator, sent);
    }
    if receiver.t == "iter" {
        it = receiver as PyIter;
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        if it.index < len(it.items) {
            item = it.items[it.index];
            it.index = it.index + 1;
            return item;
        }
        return PyGenStop(t="genstop", val=py_none());
    }
    if receiver.t == "dictiter" {
        di = receiver as PyDictIter;
        if sent.t != "none" {
            return py_error("AttributeError", "send");
        }
        if di.dictiter_stale() {
            return dictiter_error();
        }
        if di.index < len(di.keys) {
            item = dictiter_yield(di);
            di.index = di.index + 1;
            return item;
        }
        return PyGenStop(t="genstop", val=py_none());
    }
    # Any other iterator: drive it through its own send/__next__ surface.
    method_name = "send";
    if sent.t == "none" {
        method_name = "__next__";
    }
    driver = py_attr(receiver, method_name);
    if is_error(driver) {
        return driver;
    }
    call_args: list[PyObj] = [];
    if method_name == "send" {
        call_args.append(sent);
    }
    result = py_invoke(driver, call_args, {});
    if is_error(result) {
        exc = (result as PyError).exception;
        if exc.type_name == "StopIteration" {
            payload = py_none();
            if exc.value is not None {
                payload = exc.value as PyObj;
            }
            return PyGenStop(t="genstop", val=payload);
        }
        return result;
    }
    return result;
}

# Drain a generator to exhaustion through the real suspend/resume machinery and
# return the yielded PyObjs as a list. Used at the host boundary (to_host) so
# list()/tuple()/sum()/... consume a native genexpr without an eager-eval shim.
def gen_drain(gen: PyGenerator) -> PyObj {
    items: list[PyObj] = [];
    while True {
        nxt = gen_resume(gen, py_none());
        if nxt.t == "genstop" {
            return PyList(t="list", items=items);
        }
        if is_error(nxt) {
            return nxt;
        }
        items.append(nxt);
    }
    return PyList(t="list", items=items);
}

def exec_code_frame(
    co: PyCode,
    args: list[PyObj],
    kwargs: dict[str, PyObj],
    globals: dict[str, PyObj],
    locals: dict[str, PyObj],
    closure: list[PyCell],
    defaults: list[PyObj],
    kwdefaults: dict[str, PyObj],
) -> PyObj {
    fast: list[PyObj] = [];
    assigned: list[bool] = [];
    i = 0;
    while i < len(co.varnames) {
        fast.append(py_none());
        assigned.append(False);
        i = i + 1;
    }
    positional_count = co.argcount;
    has_varargs = (co.flags & 4) != 0;
    has_varkw = (co.flags & 8) != 0;
    # Named-parameter slots occupy [0 .. argcount + kwonlyargcount); the *args and
    # **kwargs slots (when present) follow, in that order (CPython's localsplus
    # layout). Keywords that don't name a parameter belong in **kwargs.
    param_slots = positional_count + co.kwonlyargcount;
    i = 0;
    while i < len(args) and i < positional_count {
        fast[i] = args[i];
        assigned[i] = True;
        i = i + 1;
    }
    if has_varargs {
        # Surplus positionals gather into the *args tuple slot.
        extra: list[PyObj] = [];
        j = positional_count;
        while j < len(args) {
            extra.append(args[j]);
            j = j + 1;
        }
        fast[param_slots] = PyTuple(t="tuple", items=extra);
        assigned[param_slots] = True;
    } elif len(args) > positional_count {
        return py_error("TypeError", "too many positional arguments");
    }
    varkw_slot = -1;
    if has_varkw {
        varkw_slot = param_slots;
        if has_varargs {
            varkw_slot = varkw_slot + 1;
        }
        fast[varkw_slot] = PyDict(t="dict", items={});
        assigned[varkw_slot] = True;
    }
    for key in kwargs {
        index = find_name(co.varnames, key);
        # A keyword binds a named parameter only if it lands in the parameter
        # region and isn't positional-only; otherwise it flows into **kwargs (or
        # is an error when the function has none).
        is_param = index >= 0 and index < param_slots and index >= co.posonlyargcount;
        if is_param and assigned[index] {
            return py_error("TypeError", "multiple values for argument " + key);
        }
        if is_param {
            fast[index] = kwargs[key];
            assigned[index] = True;
        } elif has_varkw {
            (fast[varkw_slot] as PyDict).dict_set(PyStr(t="str", val=key), kwargs[key]);
        } elif index >= 0 and index < co.posonlyargcount {
            return py_error("TypeError", "positional-only argument passed by name");
        } else {
            return py_error("TypeError", "unexpected keyword argument " + key);
        }
    }
    i = 0;
    while i < positional_count {
        if not assigned[i] {
            default_index = i - (positional_count - len(defaults));
            if default_index >= 0 and default_index < len(defaults) {
                fast[i] = defaults[default_index];
                assigned[i] = True;
            }
        }
        if not assigned[i] {
            return py_error("TypeError", "missing required argument");
        }
        i = i + 1;
    }
    i = 0;
    while i < co.kwonlyargcount {
        index = positional_count + i;
        if not assigned[index] {
            key = co.varnames[index];
            if key in kwdefaults {
                fast[index] = kwdefaults[key];
                assigned[index] = True;
            }
        }
        if not assigned[index] {
            return py_error("TypeError", "missing required keyword argument");
        }
        i = i + 1;
    }

    cells: list[PyCell] = [];
    for name in co.cellvars {
        fast_index = find_name(co.varnames, name);
        value = py_none();
        if fast_index >= 0 {
            value = fast[fast_index];
        }
        cells.append(PyCell(t="cell", val=value));
    }
    frame = PyFrame(
        t="frame",
        co=co,
        fast=fast,
        assigned=assigned,
        cells=cells,
        closure=closure,
        stack=[],
        globals=globals,
        locals=locals,
        ip=0,
    );
    # A generator-flagged code object does not run on call: it returns a
    # generator wrapping the (unstarted) frame; execution begins on first resume.
    # CO_COROUTINE (0x80) is the async-def analogue -- the same suspendable frame,
    # tagged "coroutine" so type(coro).__name__ and the await/SEND driver treat it
    # as an awaitable (not a for-iterable) while reusing gen_resume/send_into.
    if (co.flags & 128) != 0 {
        return PyGenerator(t="coroutine", frame=frame, started=False, finished=False);
    }
    if (co.flags & 32) != 0 {
        return PyGenerator(t="generator", frame=frame, started=False, finished=False);
    }
    return run_frame(frame);
}

def run_frame(frame: PyFrame) -> PyObj {
    co = frame.co;
    fast = frame.fast;
    assigned = frame.assigned;
    cells = frame.cells;
    closure = frame.closure;
    stack = frame.stack;
    globals = frame.globals;
    locals = frame.locals;
    code = co.co_code;
    ip = frame.ip;
    ext_arg = 0;
    # The stack of exceptions currently being handled (one entry per active except
    # block). A bare `raise` re-raises the top; PUSH_EXC_INFO pushes on handler
    # entry, POP_EXCEPT pops on handler exit. Frame-local: a bare raise across a
    # generator yield boundary is not modeled (vanishingly rare).
    exc_handling: list[PyObj] = [];
    # Polymorphic opcode scratch slots: handlers below store PyObj values (and
    # occasionally the narrower PyStr/PyException subtypes) here, so they are
    # declared once up front instead of being pinned to a first-use type.
    result: PyObj = py_none();
    exc: PyObj = py_none();
    while ip < len(code) {
        offset = ip;
        op = code[ip];
        arg = code[ip + 1];
        ip = ip + 2 + 2 * opcode_cache_count(op);
        # EXTENDED_ARG carries the high bits of the FOLLOWING instruction's oparg
        # (up to four may chain). Fold any accumulated prefix into this arg, then
        # either stash it (this op IS the prefix) or clear it for the real op.
        arg = arg | (ext_arg << 8);
        ext_arg = 0;
        if op == OP_EXTENDED_ARG {
            ext_arg = arg;
            continue;
        }
        if op == OP_CACHE or op == OP_NOT_TAKEN or op == OP_NOP or op == OP_RESUME {
            continue;
        }
        if op == OP_LOAD_CONST {
            stack.append(co.consts[arg]);
            continue;
        }
        if op == OP_LOAD_SMALL_INT {
            # oparg is an unsigned int in [0, 256); it is ALWAYS non-negative
            # (CPython emits LOAD_CONST for negative literals). Do NOT sign-extend
            # -- doing so mis-decoded 128..255 as negatives.
            stack.append(PyInt(t="int", val=arg));
            continue;
        }
        if op == OP_LOAD_FAST or op == OP_LOAD_FAST_BORROW {
            fast_result = fast_value(co, arg, fast, cells, closure);
            if is_error(fast_result) {
                return fast_result;
            }
            stack.append(fast_result);
            continue;
        }
        if op == OP_LOAD_FAST_CHECK {
            fast_result = fast_value_check(co, arg, fast, assigned, cells, closure);
            if is_error(fast_result) {
                return fast_result;
            }
            stack.append(fast_result);
            continue;
        }
        if op == OP_STORE_FAST {
            if arg < len(fast) {
                fast[arg] = stack.pop();
                assigned[arg] = True;
                continue;
            }
            return py_error("UnboundLocalError", "invalid local variable");
        }
        if op == OP_DELETE_FAST {
            # `del local`: unbind the fast slot. A later LOAD_FAST raises
            # UnboundLocalError (the assigned flag gates that).
            if arg < len(fast) {
                fast[arg] = py_none();
                assigned[arg] = False;
                continue;
            }
            return py_error("UnboundLocalError", "invalid local variable");
        }
        if op == OP_LOAD_FAST_AND_CLEAR {
            # Inlined comprehensions save the loop var's outer binding here and
            # clear the slot; a STORE_FAST at the tail restores it. NULL (an
            # unbound slot) is modeled with the None placeholder.
            if arg < len(fast) and assigned[arg] {
                stack.append(fast[arg]);
            } else {
                stack.append(py_none());
            }
            if arg < len(fast) {
                fast[arg] = py_none();
                assigned[arg] = False;
            }
            continue;
        }
        if op == OP_STORE_FAST_LOAD_FAST {
            store_index = arg // 16;
            load_index = arg % 16;
            if store_index >= len(fast) {
                return py_error("UnboundLocalError", "invalid local variable");
            }
            fast[store_index] = stack.pop();
            assigned[store_index] = True;
            load_result = fast_value(co, load_index, fast, cells, closure);
            if is_error(load_result) {
                return load_result;
            }
            stack.append(load_result);
            continue;
        }
        if op == OP_STORE_FAST_STORE_FAST {
            # Packed two-register store: TOS -> reg(arg>>4), TOS1 -> reg(arg&15).
            first_index = arg // 16;
            second_index = arg % 16;
            if first_index >= len(fast) or second_index >= len(fast) {
                return py_error("UnboundLocalError", "invalid local variable");
            }
            fast[first_index] = stack.pop();
            assigned[first_index] = True;
            fast[second_index] = stack.pop();
            assigned[second_index] = True;
            continue;
        }
        if op == OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW or op == OP_LOAD_FAST_LOAD_FAST {
            first = arg // 16;
            second = arg % 16;
            first_result = fast_value(co, first, fast, cells, closure);
            second_result = fast_value(co, second, fast, cells, closure);
            if is_error(first_result) {
                return first_result;
            }
            if is_error(second_result) {
                return second_result;
            }
            stack.append(first_result);
            stack.append(second_result);
            continue;
        }
        if op == OP_LOAD_GLOBAL {
            name_index = arg // 2;
            if name_index >= len(co.names) {
                return py_error("NameError", "invalid global name");
            }
            name = co.names[name_index];
            value = py_none();
            if name in globals {
                value = globals[name];
            } else {
                value = load_name_fallback(name);
            }
            if is_error(value) {
                target = recover_exception(co, value, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return value;
            }
            stack.append(value);
            if (arg & 1) != 0 {
                stack.append(py_none());
            }
            continue;
        }
        if op == OP_LOAD_NAME {
            name = co.names[arg];
            value = py_none();
            if name in locals {
                value = locals[name];
            } elif name in globals {
                value = globals[name];
            } else {
                value = load_name_fallback(name);
            }
            if is_error(value) {
                target = recover_exception(co, value, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return value;
            }
            stack.append(value);
            continue;
        }
        if op == OP_LOAD_DEREF {
            cell = deref_cell(co, arg, fast, cells, closure);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            stack.append(cell.val);
            continue;
        }
        if op == OP_LOAD_CLOSURE {
            cell = deref_cell(co, arg, fast, cells, closure);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            stack.append(cell);
            continue;
        }
        if op == OP_STORE_DEREF {
            value = stack.pop();
            cell = deref_cell(co, arg, fast, cells, closure);
            if cell is None {
                return py_error("NameError", "free variable is not set");
            }
            cell.val = value;
            continue;
        }
        if op == OP_MAKE_CELL {
            continue;
        }
        if op == OP_COPY_FREE_VARS {
            continue;
        }
        if op == OP_LOAD_LOCALS {
            stack.append(dict_from_str_map(locals));
            continue;
        }
        if op == OP_STORE_NAME {
            locals[co.names[arg]] = stack.pop();
            continue;
        }
        if op == OP_STORE_GLOBAL {
            # `global x; x = ...` inside a function -- write straight to the
            # module globals, bypassing the frame's fast/locals.
            globals[co.names[arg]] = stack.pop();
            continue;
        }
        if op == OP_DELETE_GLOBAL {
            gdel_name = co.names[arg];
            if gdel_name in globals {
                _py_container_del(globals, gdel_name);
                continue;
            }
            gdeleted = py_error("NameError", "name '" + gdel_name + "' is not defined");
            target = recover_exception(co, gdeleted, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return gdeleted;
        }
        if op == OP_DELETE_NAME {
            del_name = co.names[arg];
            if del_name in locals {
                _py_dict_del(locals, del_name);
                continue;
            }
            deleted = py_error("NameError", "name '" + del_name + "' is not defined");
            target = recover_exception(co, deleted, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return deleted;
        }
        if op == OP_LOAD_BUILD_CLASS {
            stack.append(PyBuildClass(t="build_class"));
            continue;
        }
        if op == OP_MAKE_FUNCTION {
            function = make_function_from_stack(stack, globals);
            if is_error(function) {
                return function;
            }
            stack.append(function);
            continue;
        }
        if op == OP_SET_FUNCTION_ATTRIBUTE {
            function = stack.pop() as PyFunction;
            attribute = stack.pop();
            if arg == 1 and attribute.t == "tuple" {
                function.defaults = tuple_value(attribute);
            } elif arg == 2 and attribute.t == "dict" {
                function.kwdefaults = (attribute as PyDict).dict_str_map();
            } elif arg == 8 and attribute.t == "tuple" {
                function.closure = [];
                closure_index = 0;
                for item in tuple_value(attribute) {
                    if item.t == "cell" {
                        function.closure.append(item as PyCell);
                    } elif closure_index < len(function.code.freevars) {
                        outer_cell = find_cell(
                            cells, co.cellvars, function.code.freevars[closure_index]
                        );
                        if outer_cell is not None {
                            function.closure.append(outer_cell);
                        } else {
                            function.closure.append(PyCell(t="cell", val=item));
                        }
                    } else {
                        function.closure.append(PyCell(t="cell", val=item));
                    }
                    closure_index = closure_index + 1;
                }
            }
            stack.append(function);
            continue;
        }
        if op == OP_BUILD_LIST {
            values: list[PyObj] = [];
            while len(values) < arg {
                values.insert(0, stack.pop());
            }
            stack.append(PyList(t="list", items=values));
            continue;
        }
        if op == OP_BUILD_TUPLE {
            values: list[PyObj] = [];
            while len(values) < arg {
                values.insert(0, stack.pop());
            }
            stack.append(PyTuple(t="tuple", items=values));
            continue;
        }
        if op == OP_BUILD_MAP {
            # key0,val0,key1,val1,... are pushed in source order; popping walks
            # them backwards, so buffer and replay forward to preserve insertion
            # order (dict iteration / .values() / .items() are order-sensitive).
            popped: list[PyObj] = [];
            j = 0;
            while j < arg * 2 {
                popped.insert(0, stack.pop());
                j = j + 1;
            }
            # Any hashable key lands in the native PyDict (hash-key protocol).
            # An unhashable key would raise TypeError in real Python; keep the
            # literal opaque on the host rather than raising during bootstrap.
            any_unhashable = False;
            j = 0;
            while j < arg {
                if popped[j * 2].tp_hashkey() == "" {
                    any_unhashable = True;
                }
                j = j + 1;
            }
            if any_unhashable {
                host_map: dict[any, any] = {};
                j = 0;
                while j < arg {
                    host_map[to_host(popped[j * 2])] = to_host(popped[j * 2 + 1]);
                    j = j + 1;
                }
                stack.append(PyHostProxy(t="host", val=host_map));
                continue;
            }
            native_map = PyDict(t="dict", items={});
            j = 0;
            while j < arg {
                native_map.dict_set(popped[j * 2], popped[j * 2 + 1]);
                j = j + 1;
            }
            stack.append(native_map);
            continue;
        }
        if op == OP_BUILD_SET {
            # Native PySet via the hash-key protocol; set algebra (|, &, -, ^) and
            # membership then run natively (PySet.nb_binop / set_contains).
            members: list[PyObj] = [];
            while len(members) < arg {
                members.insert(0, stack.pop());
            }
            native_set = PySet(t="set", items={}, frozen=False);
            set_err: PyObj = py_none();
            had_set_err = False;
            for member in members {
                set_err = native_set.set_add(member);
                if is_error(set_err) {
                    had_set_err = True;
                    break;
                }
            }
            if had_set_err {
                target = recover_exception(co, set_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return set_err;
            }
            stack.append(native_set);
            continue;
        }
        if op == OP_SET_UPDATE {
            iterable = stack.pop();
            target_index = len(stack) - arg;
            target_set: PySet = stack[target_index] as PySet;
            for hostel in to_host(iterable) {
                target_set.set_add(from_host(hostel));
            }
            continue;
        }
        if op == OP_CONVERT_VALUE {
            value = stack.pop();
            if isinstance(value, PyException) {
                exc = value as PyException;
                if arg == 2 {
                    result = baseexception_repr(exc, py_repr);
                } elif arg == 3 {
                    result = host_convert(value, arg);
                } else {
                    result = baseexception_str(exc);
                }
            } else {
                result = host_convert(value, arg);
            }
            if is_error(result) {
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_FORMAT_SIMPLE {
            value = stack.pop();
            result = host_format(value, "");
            if is_error(result) {
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_FORMAT_WITH_SPEC {
            spec = stack.pop();
            value = stack.pop();
            result = host_format(value, expect_str(spec));
            if is_error(result) {
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BUILD_STRING {
            parts: list[PyObj] = [];
            while len(parts) < arg {
                parts.insert(0, stack.pop());
            }
            joined = "";
            for part in parts {
                joined = joined + expect_str(part);
            }
            stack.append(PyStr(t="str", val=joined));
            continue;
        }
        if op == OP_LIST_EXTEND {
            # After popping the iterable, the target list sits at STACK[-arg]
            # (CPython extends STACK[-arg-1] pre-pop). The prior `-1-arg` form
            # only worked for a bare list literal, where a negative index still
            # landed on the list; with a callable+NULL below (e.g. len([...]))
            # it addressed the NULL instead.
            iterable = stack.pop();
            target_index = len(stack) - arg;
            append_to_list(stack[target_index], iterable);
            continue;
        }
        if op == OP_LIST_APPEND {
            value = stack.pop();
            target_index = len(stack) - arg;
            (stack[target_index] as PyList).items.append(value);
            continue;
        }
        if op == OP_SET_ADD {
            # set comprehension step: value=TOS, target set at STACK[-arg].
            set_member: PyObj = stack.pop();
            target_index = len(stack) - arg;
            (stack[target_index] as PySet).set_add(set_member);
            continue;
        }
        if op == OP_MAP_ADD {
            # dict comprehension step: value=TOS, key=TOS1, target dict at
            # STACK[-arg] after the two pops (mirrors LIST_APPEND's addressing).
            map_value: PyObj = stack.pop();
            map_key: PyObj = stack.pop();
            target_index = len(stack) - arg;
            (stack[target_index] as PyDict).dict_set(map_key, map_value);
            continue;
        }
        if op == OP_DICT_UPDATE {
            # {**a, **b}: merge source (TOS) into the dict at STACK[-arg-1];
            # duplicate keys are overwritten (last wins), no error.
            update_source: PyObj = stack.pop();
            target_index = len(stack) - arg;
            update_target = stack[target_index] as PyDict;
            update_pairs = dict_merge_pairs(update_source);
            ukeys = update_pairs.dict_keys();
            uvals = update_pairs.dict_values();
            uj = 0;
            while uj < len(ukeys) {
                update_target.dict_set(ukeys[uj], uvals[uj]);
                uj = uj + 1;
            }
            continue;
        }
        if op == OP_DICT_MERGE {
            # f(**kw): merge source (TOS) into the kwargs dict at STACK[-arg-1].
            # Unlike DICT_UPDATE, a duplicate key is a TypeError (a keyword passed
            # more than once). Keyword keys are always strings.
            merge_source: PyObj = stack.pop();
            # Stack effect (CPython): (callable, unused, unused, dict,
            # unused[oparg-1], update). After popping `update`, the target dict
            # sits `oparg` slots below the top.
            target_index = len(stack) - arg;
            merge_target = stack[target_index] as PyDict;
            merge_pairs = dict_merge_pairs(merge_source);
            mkeys = merge_pairs.dict_keys();
            mvals = merge_pairs.dict_values();
            dup_key = "";
            has_dup = False;
            mj = 0;
            while mj < len(mkeys) {
                if merge_target.dict_contains(mkeys[mj]) {
                    dup_key = expect_str(mkeys[mj]);
                    has_dup = True;
                } else {
                    merge_target.dict_set(mkeys[mj], mvals[mj]);
                }
                mj = mj + 1;
            }
            if has_dup {
                merge_err = py_error(
                    "TypeError",
                    "got multiple values for keyword argument '" + dup_key + "'",
                );
                target = recover_exception(co, merge_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return merge_err;
            }
            continue;
        }
        if op == OP_UNPACK_SEQUENCE {
            seq = stack.pop();
            it = py_iter(seq);
            if is_error(it) {
                target = recover_exception(co, it, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return it;
            }
            unpacked: list[PyObj] = [];
            if isinstance(it, PyIter) {
                unpacked = (it as PyIter).items;
            } elif it.t == "generator" {
                while True {
                    nxt = gen_resume(it as PyGenerator, py_none());
                    if is_error(nxt) {
                        return nxt;
                    }
                    if nxt.t == "genstop" {
                        break;
                    }
                    unpacked.append(nxt);
                }
            }
            unpack_err: PyObj = py_none();
            if len(unpacked) < arg {
                unpack_err = py_error(
                    "ValueError",
                    "not enough values to unpack (expected "
                        + str(arg)
                        + ", got "
                        + str(len(unpacked))
                        + ")",
                );
            } elif len(unpacked) > arg {
                unpack_err = py_error(
                    "ValueError",
                    "too many values to unpack (expected " + str(arg) + ")",
                );
            }
            if is_error(unpack_err) {
                target = recover_exception(co, unpack_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return unpack_err;
            }
            # Push in reverse so the first element lands on top of the stack for
            # the successive STORE ops (CPython's UNPACK_SEQUENCE ordering).
            k = arg - 1;
            while k >= 0 {
                stack.append(unpacked[k]);
                k = k - 1;
            }
            continue;
        }
        if op == OP_UNPACK_EX {
            # oparg = before | (after << 8); a starred target captures the middle.
            before = arg % 256;
            after = arg // 256;
            seq = stack.pop();
            it = py_iter(seq);
            if is_error(it) {
                target = recover_exception(co, it, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return it;
            }
            unpacked = [];
            if isinstance(it, PyIter) {
                unpacked = (it as PyIter).items;
            } elif it.t == "generator" {
                while True {
                    nxt = gen_resume(it as PyGenerator, py_none());
                    if is_error(nxt) {
                        return nxt;
                    }
                    if nxt.t == "genstop" {
                        break;
                    }
                    unpacked.append(nxt);
                }
            }
            m = len(unpacked);
            if m < before + after {
                ex_err = py_error(
                    "ValueError",
                    "not enough values to unpack (expected at least "
                        + str(before + after)
                        + ", got "
                        + str(m)
                        + ")",
                );
                target = recover_exception(co, ex_err, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return ex_err;
            }
            # Stack top->bottom must be: head[0..before-1], middle-list,
            # tail[m-after..m-1]. Push tail deepest-first, then middle, then head.
            j = m - 1;
            while j >= m - after {
                stack.append(unpacked[j]);
                j = j - 1;
            }
            middle_items: list[PyObj] = [];
            mk = before;
            while mk < m - after {
                middle_items.append(unpacked[mk]);
                mk = mk + 1;
            }
            stack.append(PyList(t="list", items=middle_items));
            b = before - 1;
            while b >= 0 {
                stack.append(unpacked[b]);
                b = b - 1;
            }
            continue;
        }
        if op == OP_GET_LEN {
            len_obj = stack[len(stack) - 1];
            len_res = py_len(len_obj);
            if is_error(len_res) {
                target = recover_exception(co, len_res, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return len_res;
            }
            stack.append(len_res);
            continue;
        }
        if op == OP_MATCH_SEQUENCE {
            seq_subject = stack[len(stack) - 1];
            stack.append(PyBool(t="bool", val=py_type_has_sequence_flag(seq_subject)));
            continue;
        }
        if op == OP_MATCH_MAPPING {
            map_subject = stack[len(stack) - 1];
            stack.append(PyBool(t="bool", val=py_type_has_mapping_flag(map_subject)));
            continue;
        }
        if op == OP_MATCH_KEYS {
            mk_keys = stack[len(stack) - 1];
            mk_subject = stack[len(stack) - 2];
            mk_res = py_match_keys(mk_subject, mk_keys);
            if is_error(mk_res) {
                target = recover_exception(co, mk_res, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return mk_res;
            }
            stack.append(mk_res);
            continue;
        }
        if op == OP_MATCH_CLASS {
            mc_names = stack.pop();
            mc_type = stack.pop();
            mc_subject = stack.pop();
            mc_res = py_match_class(mc_subject, mc_type, arg, mc_names);
            if is_error(mc_res) {
                target = recover_exception(co, mc_res, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return mc_res;
            }
            stack.append(mc_res);
            continue;
        }
        if op == OP_GET_ITER {
            iterable = py_iter(stack.pop());
            if is_error(iterable) {
                target = recover_exception(co, iterable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return iterable;
            }
            stack.append(iterable);
            continue;
        }
        if op == OP_GET_YIELD_FROM_ITER {
            # `yield from`: a generator (or coroutine) is already its own
            # iterator and is left in place so send()/throw() reach it directly;
            # anything else is turned into an iterator like GET_ITER.
            top = stack[len(stack) - 1];
            if top.t == "generator" {
                continue;
            }
            iterable = py_iter(stack.pop());
            if is_error(iterable) {
                target = recover_exception(co, iterable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return iterable;
            }
            stack.append(iterable);
            continue;
        }
        if op == OP_GET_AWAITABLE {
            # `await x`: resolve x to the iterator the following SEND loop drives.
            top = stack[len(stack) - 1];
            awaitable = py_get_awaitable(top);
            if is_error(awaitable) {
                target = recover_exception(co, awaitable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return awaitable;
            }
            stack[len(stack) - 1] = awaitable;
            continue;
        }
        if op == OP_GET_AITER {
            iterable = stack.pop();
            aiter = py_aiter(iterable);
            if is_error(aiter) {
                target = recover_exception(co, aiter, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return aiter;
            }
            stack.append(aiter);
            continue;
        }
        if op == OP_GET_ANEXT {
            aiter = stack[len(stack) - 1];
            awaitable = py_anext(aiter);
            if is_error(awaitable) {
                target = recover_exception(co, awaitable, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return awaitable;
            }
            stack.append(awaitable);
            continue;
        }
        if op == OP_END_ASYNC_FOR {
            # Async-for cleanup: [..., aiter, exc]. StopAsyncIteration ends the
            # loop (pop both, jump past the body); anything else re-raises.
            exc = stack.pop();
            stack.pop();
            exc_name = "";
            if exc.t == "exception" {
                exc_name = (exc as PyException).type_name;
            }
            if exc_name == "StopAsyncIteration" {
                continue;
            }
            reraised = py_raise_value(exc);
            target = recover_exception(co, reraised, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return reraised;
        }
        if op == OP_SEND {
            # yield-from step. Stack: [..., receiver, sent]. Drive the receiver
            # one step; on a yield replace `sent` with the yielded value and fall
            # through to YIELD_VALUE (re-suspending the outer generator); on
            # exhaustion replace `sent` with the sub-iterator's return value and
            # jump past the loop to END_SEND.
            sent = stack[len(stack) - 1];
            receiver = stack[len(stack) - 2];
            if frame.pending_throw is not None {
                thrown_err = frame.pending_throw as PyObj;
                frame.pending_throw = None;
                step = send_throw_into(receiver, thrown_err);
            } else {
                step = send_into(receiver, sent);
            }
            if is_error(step) {
                target = recover_exception(co, step, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return step;
            }
            if step.t == "genstop" {
                stack[len(stack) - 1] = (step as PyGenStop).val;
                ip = ip + 2 * arg;
            } else {
                stack[len(stack) - 1] = step;
            }
            continue;
        }
        if op == OP_END_SEND {
            # (receiver, value -- value): drop the exhausted sub-iterator, keep
            # its return value as the yield-from expression result.
            value = stack.pop();
            stack.pop();
            stack.append(value);
            continue;
        }
        if op == OP_CLEANUP_THROW {
            # Reached when an exception thrown into a yield-from lands here. Stack:
            # [sub_iter, last_sent, exc]. A StopIteration means the sub-iterator
            # finished handling the throw: unwind to (None, value) and loop to
            # END_SEND. Any other exception re-raises out of the outer generator.
            exc = stack.pop();
            stack.pop();
            stack.pop();
            exc_name = "";
            if exc.t == "exception" {
                exc_name = (exc as PyException).type_name;
            }
            if exc_name == "StopIteration" {
                payload = py_none();
                if (exc as PyException).value is not None {
                    payload = (exc as PyException).value as PyObj;
                }
                stack.append(py_none());
                stack.append(payload);
                continue;
            }
            reraised = py_raise_value(exc);
            target = recover_exception(co, reraised, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return reraised;
        }
        if op == OP_FOR_ITER {
            top = stack[len(stack) - 1];
            if top.t == "dictiter" {
                di = top as PyDictIter;
                if di.dictiter_stale() {
                    nxt = dictiter_error();
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                    } else {
                        return nxt;
                    }
                } elif di.index < len(di.keys) {
                    stack.append(dictiter_yield(di));
                    di.index = di.index + 1;
                } else {
                    stack.pop();
                    ip = ip + 2 * arg;
                }
                continue;
            }
            if top.t == "generator" {
                nxt = gen_resume(top as PyGenerator, py_none());
                if nxt.t == "genstop" {
                    stack.pop();
                    ip = ip + 2 * arg;
                } elif is_error(nxt) {
                    target = recover_exception(co, nxt, offset, stack);
                    if target >= 0 {
                        ip = target;
                    } else {
                        return nxt;
                    }
                } else {
                    stack.append(nxt);
                }
                continue;
            }
            iterator = top as PyIter;
            if iterator.index < len(iterator.items) {
                stack.append(iterator.items[iterator.index]);
                iterator.index = iterator.index + 1;
            } else {
                stack.pop();
                ip = ip + 2 * arg;
            }
            continue;
        }
        if op == OP_END_FOR or op == OP_POP_ITER {
            continue;
        }
        if op == OP_JUMP_FORWARD {
            ip = ip + 2 * arg;
            continue;
        }
        if op == OP_JUMP_BACKWARD or op == OP_JUMP_BACKWARD_NO_INTERRUPT {
            ip = ip - 2 * arg;
            continue;
        }
        if op == OP_POP_JUMP_IF_FALSE
            or op == OP_POP_JUMP_IF_TRUE
            or op == OP_POP_JUMP_IF_NONE
            or op == OP_POP_JUMP_IF_NOT_NONE {
            condition = stack.pop();
            jump = False;
            if op == OP_POP_JUMP_IF_FALSE {
                jump = not py_truth(condition);
            } elif op == OP_POP_JUMP_IF_TRUE {
                jump = py_truth(condition);
            } elif op == OP_POP_JUMP_IF_NONE {
                jump = condition.t == "none";
            } else {
                jump = condition.t != "none";
            }
            if jump {
                ip = ip + 2 * arg;
            }
            continue;
        }
        if op == OP_COMPARE_OP {
            rhs = stack.pop();
            lhs = stack.pop();
            result = py_compare(arg >> 5, lhs, rhs);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_IS_OP {
            rhs = stack.pop();
            lhs = stack.pop();
            same = py_identity(lhs, rhs);
            if arg == 1 {
                same = not same;
            }
            stack.append(PyBool(t="bool", val=same));
            continue;
        }
        if op == OP_UNARY_NOT {
            stack.append(PyBool(t="bool", val=not py_truth(stack.pop())));
            continue;
        }
        if op == OP_UNARY_NEGATIVE {
            result = py_negative(stack.pop());
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_UNARY_INVERT {
            result = py_invert(stack.pop());
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BINARY_OP {
            rhs = stack.pop();
            lhs = stack.pop();
            result = py_subscript(lhs, rhs) if arg == 26 else py_binop(arg, lhs, rhs);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BINARY_SLICE {
            # container[start:stop] -- step is always None for this opcode.
            stop = stack.pop();
            start = stack.pop();
            container = stack.pop();
            result = py_subscript(
                container, PySlice(t="slice", start=start, stop=stop, step=py_none())
            );
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_BUILD_SLICE {
            # oparg is 2 (start:stop) or 3 (start:stop:step); operands on stack.
            slice_step: PyObj = py_none();
            if arg == 3 {
                slice_step = stack.pop();
            }
            slice_stop = stack.pop();
            slice_start = stack.pop();
            stack.append(
                PySlice(t="slice", start=slice_start, stop=slice_stop, step=slice_step)
            );
            continue;
        }
        if op == OP_LOAD_ATTR {
            owner = stack.pop();
            name = co.names[arg // 2];
            result = py_attr(owner, name);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            if (arg & 1) != 0 {
                stack.append(result);
                stack.append(py_none());
            } else {
                stack.append(result);
            }
            continue;
        }
        if op == OP_LOAD_SUPER_ATTR {
            # Stack (top-down): self, class(__class__ cell), global super. arg
            # encodes name>>2, bit0 = method-call form, bit1 = two-arg super.
            super_self = stack.pop();
            super_class = stack.pop();
            super_global = stack.pop();
            super_name = co.names[arg >> 2];
            result = super_lookup(super_class, super_self, super_name);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            bound = bind_attribute(result, super_self);
            if (arg & 1) != 0 {
                stack.append(bound);
                stack.append(py_none());
            } else {
                stack.append(bound);
            }
            continue;
        }
        if op == OP_STORE_ATTR {
            owner = stack.pop();
            field = stack.pop();
            result = py_set_attr(owner, co.names[arg], field);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            continue;
        }
        if op == OP_DELETE_ATTR {
            owner = stack.pop();
            result = py_del_attr(owner, co.names[arg]);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            continue;
        }
        if op == OP_STORE_SUBSCR {
            stored_index: PyObj = stack.pop();
            owner = stack.pop();
            stored_value: PyObj = stack.pop();
            result = py_store_subscript(owner, stored_index, stored_value);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            continue;
        }
        if op == OP_DELETE_SUBSCR {
            deleted_index: PyObj = stack.pop();
            owner = stack.pop();
            result = py_delete_subscript(owner, deleted_index);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            continue;
        }
        if op == OP_IMPORT_NAME {
            fromlist = stack.pop();
            level_obj = stack.pop();
            result = py_none();
            if layer3_is_active() {
                import_level = 0;
                if isinstance(level_obj, PyInt) {
                    import_level = (level_obj as PyInt).val;
                }
                result = py_import_name(co.names[arg], fromlist, import_level, globals);
            } else {
                result = host_import(co.names[arg], fromlist);
            }
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_IMPORT_FROM {
            module = stack[len(stack) - 1];
            result = py_attr(module, co.names[arg]);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_PUSH_NULL {
            stack.append(py_none());
            continue;
        }
        if op == OP_CALL or op == OP_CALL_KW {
            keyword_names: list[str] = [];
            call_count = arg;
            if op == OP_CALL_KW {
                names_obj = stack.pop();
                keyword_names = str_values(names_obj);
            }
            call_args: list[PyObj] = [];
            while len(call_args) < call_count {
                call_args.insert(0, stack.pop());
            }
            kwargs_for_call: dict[str, PyObj] = {};
            positional_count_for_call = call_count - len(keyword_names);
            while len(keyword_names) > 0 {
                key = keyword_names.pop();
                kwargs_for_call[key] = call_args.pop();
            }
            if len(stack) == 0 {
                return py_error("RuntimeError", "CALL stack underflow");
            }
            self_or_null = stack.pop();
            if len(stack) == 0 {
                return py_error("RuntimeError", "CALL stack underflow");
            }
            fn = stack.pop();
            # globals() binds to THIS frame's namespace (a live view), which only
            # the ceval holds -- resolve it here rather than in PyNativeBuiltin.
            if fn.t == "native_builtin" and (fn as PyNativeBuiltin).name == "globals" {
                stack.append(PyGlobalsProxy(t="globals", ns=globals));
                continue;
            }
            # CPython's CALL convention carries a `self_or_null` slot below the
            # args. NULL (a plain call after PUSH_NULL, modeled here as None) is
            # dropped; a real value (a bound self, or a genexpr's `.0` iterator
            # under `CALL 0`) is prepended as the first positional argument.
            if self_or_null.t != "none" {
                call_args.insert(0, self_or_null);
            }
            result = py_invoke(fn, call_args, kwargs_for_call);
            if is_error(result) {
                target = recover_exception(co, result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return result;
            }
            stack.append(result);
            continue;
        }
        if op == OP_CALL_FUNCTION_EX {
            # f(*args, **kwargs). Stack (bottom->top): func, self_or_null,
            # callargs (a materialized iterable), kwargs (a mapping or NULL). The
            # oparg is unused in 3.14: a NULL kwargs slot (PUSH_NULL) means no
            # keywords.
            kwargs_obj = stack.pop();
            callargs_obj = stack.pop();
            self_or_null_ex = stack.pop();
            fn_ex = stack.pop();
            ex_args_list = members_of(callargs_obj);
            if is_error(ex_args_list) {
                return ex_args_list;
            }
            ex_call_args: list[PyObj] = (ex_args_list as PyList).items;
            if self_or_null_ex.t != "none" {
                ex_call_args.insert(0, self_or_null_ex);
            }
            ex_kwargs: dict[str, PyObj] = {};
            if isinstance(kwargs_obj, PyDict) {
                ex_kwargs = (kwargs_obj as PyDict).dict_str_map();
            } elif kwargs_obj.t != "none" {
                # A non-dict, non-NULL mapping (e.g. a proxied host mapping):
                # normalize through from_host(to_host(...)) into a PyDict.
                coerced = from_host(to_host(kwargs_obj));
                if isinstance(coerced, PyDict) {
                    ex_kwargs = (coerced as PyDict).dict_str_map();
                }
            }
            ex_result = py_invoke(fn_ex, ex_call_args, ex_kwargs);
            if is_error(ex_result) {
                target = recover_exception(co, ex_result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return ex_result;
            }
            stack.append(ex_result);
            continue;
        }
        if op == OP_PUSH_EXC_INFO {
            if len(stack) > 0 {
                exception = stack.pop();
                stack.append(py_none());
                stack.append(exception);
                # Mark this exception as the one being handled (for bare `raise`).
                exc_handling.append(exception);
            }
            continue;
        }
        if op == OP_CHECK_EXC_MATCH {
            match_type: PyObj = stack.pop();
            exception = stack[len(stack) - 1];
            stack.append(
                PyBool(t="bool", val=exception_matches(exception, match_type))
            );
            continue;
        }
        if op == OP_POP_EXCEPT {
            if len(stack) > 0 {
                stack.pop();
            }
            if len(exc_handling) > 0 {
                exc_handling.pop();
            }
            continue;
        }
        if op == OP_RAISE_VARARGS {
            # arg: 0 = re-raise, 1 = raise exc, 2 = raise exc from cause. For the
            # `from` form the cause is on top, the exception below it.
            raised = py_none();
            raise_cause: PyObj = py_none();
            if arg == 2 {
                raise_cause = stack.pop();
                raised = stack.pop();
            } elif arg == 1 {
                raised = stack.pop();
            } elif len(exc_handling) > 0 {
                # Bare `raise`: re-raise the exception currently being handled.
                raised = exc_handling[len(exc_handling) - 1];
            }
            result = py_raise_value(raised);
            # `raise X from Y`: record Y on the raised exception so e.__cause__
            # reads it back (skip `from None`, which carries no cause object).
            if arg == 2 and isinstance(result, PyError) and raise_cause.t != "none" {
                cause_err = py_raise_value(raise_cause);
                if isinstance(cause_err, PyError) {
                    (result as PyError).exception.cause = (
                        cause_err as PyError
                    ).exception;
                }
            }
            target = recover_exception(co, result, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return result;
        }
        if op == OP_RERAISE {
            raised = stack[len(stack) - 1];
            result = py_raise_value(raised);
            target = recover_exception(co, result, offset, stack);
            if target >= 0 {
                ip = target;
                continue;
            }
            return result;
        }
        if op == OP_COPY {
            stack.append(stack[len(stack) - arg]);
            continue;
        }
        if op == OP_SWAP {
            # SWAP(i) exchanges TOS with the item i positions down (stack[-i],
            # index len-i). TOS itself is position 1.
            swap_top = len(stack) - 1;
            swap_other = len(stack) - arg;
            swapped: PyObj = stack[swap_top];
            stack[swap_top] = stack[swap_other];
            stack[swap_other] = swapped;
            continue;
        }
        if op == OP_LOAD_SPECIAL {
            # LOAD_SPECIAL macro (_INSERT_NULL + _LOAD_SPECIAL): pop the context
            # manager, look up __enter__/__exit__, push [func, self_or_null] for
            # the CALL convention (method descriptors keep the owner as self).
            if len(stack) < 1 {
                return py_error("RuntimeError", "LOAD_SPECIAL stack underflow");
            }
            owner = stack.pop();
            spec_name = "__enter__";
            if arg == 1 {
                spec_name = "__exit__";
            } elif arg == 2 {
                spec_name = "__aenter__";
            } elif arg == 3 {
                spec_name = "__aexit__";
            }
            method = py_attr(owner, spec_name);
            if is_error(method) {
                target = recover_exception(co, method, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return method;
            }
            if isinstance(method, PyBoundMethod) {
                bm = method as PyBoundMethod;
                stack.append(bm.function);
                stack.append(bm.receiver);
            } else {
                stack.append(method);
                stack.append(owner);
            }
            continue;
        }
        if op == OP_WITH_EXCEPT_START {
            # WITH_EXCEPT_START: call the context manager's __exit__ with the
            # active exception info and push its truthy suppress flag.
            if len(stack) < 5 {
                return py_error("RuntimeError", "WITH_EXCEPT_START stack underflow");
            }
            val = stack[len(stack) - 1];
            exit_self = stack[len(stack) - 4];
            exit_func = stack[len(stack) - 5];
            exc_type: PyObj = py_none();
            if val.t == "exception" {
                exc_type = py_exception_type((val as PyException).type_name);
            }
            exit_args: list[PyObj] = [exc_type, val, py_none()];
            exit_result: PyObj = py_none();
            if exit_self.t != "none" {
                exit_result = bind_attribute(exit_func, exit_self).tp_call(
                    exit_args, {}
                );
            } else {
                exit_result = py_invoke(exit_func, exit_args, {});
            }
            if is_error(exit_result) {
                target = recover_exception(co, exit_result, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return exit_result;
            }
            stack.append(exit_result);
            continue;
        }
        if op == OP_RETURN_GENERATOR {
            # The generator object already exists (created at call time). Push a
            # placeholder standing in for it; the following POP_TOP discards it.
            stack.append(py_none());
            continue;
        }
        if op == OP_YIELD_VALUE {
            # Suspend: pop the yielded value, freeze the resume point, and hand
            # the value up to gen_resume. run_frame re-enters here from ip.
            # oparg 1 marks a yield-from delegation, so a later throw knows to
            # route into the sub-iterator rather than inject at this point.
            value = stack.pop();
            frame.ip = ip;
            frame.yf = arg == 1;
            return PyYield(t="yield", val=value);
        }
        if op == OP_TO_BOOL {
            condition = stack.pop();
            stack.append(PyBool(t="bool", val=py_truth(condition)));
            continue;
        }
        if op == OP_CONTAINS_OP {
            container = stack.pop();
            member = stack.pop();
            contained = py_contains(container, member);
            if is_error(contained) {
                target = recover_exception(co, contained, offset, stack);
                if target >= 0 {
                    ip = target;
                    continue;
                }
                return contained;
            }
            present = py_truth(contained);
            if arg == 1 {
                present = not present;
            }
            stack.append(PyBool(t="bool", val=present));
            continue;
        }
        if op == OP_LOAD_COMMON_CONSTANT {
            # _common_constants: [AssertionError, NotImplementedError, tuple,
            # all, any]. Resolved through host_builtin so an identity check like
            # `tuple is <common tuple>` (the tuple()/frozenset() genexpr fast
            # path) sees the same host-proxy tag on both sides.
            common_name = "tuple";
            if arg == 0 {
                common_name = "AssertionError";
            } elif arg == 1 {
                common_name = "NotImplementedError";
            } elif arg == 3 {
                common_name = "all";
            } elif arg == 4 {
                common_name = "any";
            }
            stack.append(host_builtin(common_name));
            continue;
        }
        if op == OP_CALL_INTRINSIC_1 {
            operand = stack.pop();
            if arg == 6 {
                # INTRINSIC_LIST_TO_TUPLE: the tuple()-of-genexpr fast path
                # builds a list, then converts it in place.
                stack.append(PyTuple(t="tuple", items=(operand as PyList).items));
                continue;
            }
            if arg == 3 {
                # INTRINSIC_STOPITERATION_ERROR (PEP 479): the pending exception
                # is on the stack. A StopIteration escaping a generator body is
                # converted to RuntimeError; everything else passes through. The
                # following RERAISE propagates whatever we push back.
                exc_name = "";
                if operand.t == "exception" {
                    exc_name = (operand as PyException).type_name;
                }
                if exc_name == "StopIteration" {
                    stack.append(
                        PyException(
                            t="exception",
                            type_name="RuntimeError",
                            message="generator raised StopIteration",
                        )
                    );
                } else {
                    stack.append(operand);
                }
                continue;
            }
            if arg == 5 {
                # INTRINSIC_UNARY_POSITIVE
                stack.append(operand);
                continue;
            }
            if arg == 2 {
                # INTRINSIC_IMPORT_STAR: `from module import *` binds the module's
                # exported names into the current globals. (Layer 3 only.)
                star_out = import_star_into(operand, globals);
                if is_error(star_out) {
                    target = recover_exception(co, star_out, offset, stack);
                    if target >= 0 {
                        ip = target;
                        continue;
                    }
                    return star_out;
                }
                # CPython pushes None for the following POP_TOP.
                stack.append(py_none());
                continue;
            }
            return py_error("SystemError", "unsupported CALL_INTRINSIC_1 " + str(arg));
        }
        if op == OP_RETURN_VALUE {
            if len(stack) == 0 {
                return py_none();
            }
            return stack.pop();
        }
        if op == OP_POP_TOP {
            if len(stack) > 0 {
                stack.pop();
            }
            continue;
        }
        return py_error("SystemError", "unsupported opcode " + str(op));
    }
    return py_none();
}

def exec_code(co: PyObj, args: list[PyObj], globals: dict[str, PyObj]) -> PyObj {
    match co {
        case PyCode():
            return exec_code_frame(co, args, {}, globals, globals, [], [], {});

    }
    return py_error("TypeError", "expected code object");
}

def exec_module(co: PyObj) -> dict[str, PyObj] {
    globals: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    exec_code(co, [], globals);
    return globals;
}
