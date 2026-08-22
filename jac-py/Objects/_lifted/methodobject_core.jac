# c2jac: hand-staged from ``jac-py/tools/p3_object_core/corpus/methodobject_core.c``
# (PyCFunction_GetFlags / vectorcall dispatch; runtime truth in ``methodobject.jac``).

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


@__jac_value__
obj PyMethodDef {
    has ml_name: str = str(),
        ml_meth: object = object(),
        ml_flags: int = 0,
        ml_doc: str = str();
}

@__jac_value__
obj PyCFunctionObject {
    has m_ml: PyMethodDef = PyMethodDef(),
        m_self: object = object(),
        m_module: object = object(),
        m_weakreflist: object = object(),
        vectorcall: object = object();
}

@__jac_value__
obj PyCMethodObject {
    has func: PyCFunctionObject = PyCFunctionObject(),
        mm_class: object = object();
}


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

def PyCFunction_GET_FLAGS(func: PyCFunctionObject) -> int {
    return func.m_ml.ml_flags;
}

def PyCFunction_GET_SELF(func: PyCFunctionObject) -> object {
    if (func.m_ml.ml_flags & METH_STATIC) != 0 {
        return 0;
    }
    return func.m_self;
}

def PyCFunction_GET_CLASS(func: PyCFunctionObject) -> object {
    if (func.m_ml.ml_flags & METH_METHOD) != 0 {
        om: PyCMethodObject = func;
        return om.mm_class;
    }
    return 0;
}

def PyCFunction_GetFlags(op: PyCFunctionObject) -> int {
    return PyCFunction_GET_FLAGS(op);
}

def meth_repr(m: PyCFunctionObject, tp_name: str, is_module_self: bool) -> str {
    if m.m_self == 0 or is_module_self {
        return "<built-in function " + m.m_ml.ml_name + ">";
    }
    return (
        "<built-in method "
        + m.m_ml.ml_name
        + " of "
        + tp_name
        + " object at 0x0>"
    );
}
