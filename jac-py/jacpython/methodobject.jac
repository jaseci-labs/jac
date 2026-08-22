# P3.2b — bound method / C function flag helpers.
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/methodobject_core.c``
# (lift: ``jac-py/Objects/_lifted/methodobject_core.jac``).
#
# Vectorcall dispatch and full PyCMethod_New remain future work; this module
# exposes flag classification and repr helpers used by runtime probes.
import from objects { PyObj, }

glob METH_VARARGS: int = 1,
     METH_KEYWORDS: int = 2,
     METH_NOARGS: int = 4,
     METH_O: int = 8,
     METH_STATIC: int = 32,
     METH_FASTCALL: int = 128,
     METH_METHOD: int = 512,
     CF_VECTORCALL_NONE: int = 0,
     CF_VECTORCALL_FASTCALL: int = 1,
     CF_VECTORCALL_FASTCALL_KEYWORDS: int = 2,
     CF_VECTORCALL_NOARGS: int = 3,
     CF_VECTORCALL_O: int = 4,
     CF_VECTORCALL_FASTCALL_KEYWORDS_METHOD: int = 5,
     CF_VECTORCALL_BAD: int = 6;


# ``cfunction_select_vectorcall`` — dispatch kind from ``PyCMethod_New`` switch.
def cfunction_select_vectorcall(ml_flags: int) -> int {
    masked = ml_flags & (
        METH_VARARGS | METH_FASTCALL | METH_NOARGS | METH_O | METH_KEYWORDS | METH_METHOD
    );
    if masked == METH_VARARGS or masked == (METH_VARARGS | METH_KEYWORDS) {
        return CF_VECTORCALL_NONE;
    }
    if masked == METH_FASTCALL {
        return CF_VECTORCALL_FASTCALL;
    }
    if masked == (METH_FASTCALL | METH_KEYWORDS) {
        return CF_VECTORCALL_FASTCALL_KEYWORDS;
    }
    if masked == METH_NOARGS {
        return CF_VECTORCALL_NOARGS;
    }
    if masked == METH_O {
        return CF_VECTORCALL_O;
    }
    if masked == (METH_METHOD | METH_FASTCALL | METH_KEYWORDS) {
        return CF_VECTORCALL_FASTCALL_KEYWORDS_METHOD;
    }
    return CF_VECTORCALL_BAD;
}

def cfunction_uses_vectorcall(ml_flags: int) -> bool {
    kind = cfunction_select_vectorcall(ml_flags);
    return kind != CF_VECTORCALL_NONE and kind != CF_VECTORCALL_BAD;
}

# True when ``obj`` is a bound instance method (has ``__self__`` not None).
def method_is_bound(meth: PyObj) -> bool {
    if not hasattr(meth, "__self__") {
        return False;
    }
    self = getattr(meth, "__self__");
    return self is not None;
}

# True for unbound built-in methods accessed on the type (``list.append``).
def method_is_unbound_builtin(meth: PyObj) -> bool {
    if not hasattr(meth, "__self__") {
        return False;
    }
    return getattr(meth, "__self__") is None;
}

# ``meth_repr`` pattern for built-in function vs bound method strings.
def builtin_method_repr(name: str, tp_name: str, bound: bool) -> str {
    if not bound {
        return "<built-in function " + name + ">";
    }
    return "<built-in method " + name + " of " + tp_name + " object at 0x0>";
}
