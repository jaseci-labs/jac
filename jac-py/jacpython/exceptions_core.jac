# P3.2a — exception matching + BaseException str/repr.
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/exceptions_core.c``
# (lift: ``jac-py/Objects/_lifted/exceptions_core.jac``).
import from objects {
    PyObj,
    PyException,
    PyExceptionType,
    PyStr,
    PyInt,
    PyBool,
    PyTuple,
    expect_str,
    is_error,
}

# Direct parent links from CPython ``Lib/test/exception_hierarchy.txt``.
glob _EXC_PARENT: dict[str, str] = {
         "BaseExceptionGroup": "BaseException",
         "GeneratorExit": "BaseException",
         "KeyboardInterrupt": "BaseException",
         "SystemExit": "BaseException",
         "Exception": "BaseException",
         "ArithmeticError": "Exception",
         "FloatingPointError": "ArithmeticError",
         "OverflowError": "ArithmeticError",
         "ZeroDivisionError": "ArithmeticError",
         "AssertionError": "Exception",
         "AttributeError": "Exception",
         "BufferError": "Exception",
         "EOFError": "Exception",
         "ExceptionGroup": "Exception",
         "ImportError": "Exception",
         "ModuleNotFoundError": "ImportError",
         "LookupError": "Exception",
         "IndexError": "LookupError",
         "KeyError": "LookupError",
         "MemoryError": "Exception",
         "NameError": "Exception",
         "UnboundLocalError": "NameError",
         "OSError": "Exception",
         "BlockingIOError": "OSError",
         "ChildProcessError": "OSError",
         "ConnectionError": "OSError",
         "BrokenPipeError": "ConnectionError",
         "ConnectionAbortedError": "ConnectionError",
         "ConnectionRefusedError": "ConnectionError",
         "ConnectionResetError": "ConnectionError",
         "FileExistsError": "OSError",
         "FileNotFoundError": "OSError",
         "InterruptedError": "OSError",
         "IsADirectoryError": "OSError",
         "NotADirectoryError": "OSError",
         "PermissionError": "OSError",
         "ProcessLookupError": "OSError",
         "TimeoutError": "OSError",
         "ReferenceError": "Exception",
         "RuntimeError": "Exception",
         "NotImplementedError": "RuntimeError",
         "PythonFinalizationError": "RuntimeError",
         "RecursionError": "RuntimeError",
         "StopAsyncIteration": "Exception",
         "StopIteration": "Exception",
         "SyntaxError": "Exception",
         "IndentationError": "SyntaxError",
         "TabError": "IndentationError",
         "SystemError": "Exception",
         "TypeError": "Exception",
         "ValueError": "Exception",
         "UnicodeError": "ValueError",
         "UnicodeDecodeError": "UnicodeError",
         "UnicodeEncodeError": "UnicodeError",
         "UnicodeTranslateError": "UnicodeError",
         "Warning": "Exception",
         "BytesWarning": "Warning",
         "DeprecationWarning": "Warning",
         "EncodingWarning": "Warning",
         "FutureWarning": "Warning",
         "ImportWarning": "Warning",
         "PendingDeprecationWarning": "Warning",
         "ResourceWarning": "Warning",
         "RuntimeWarning": "Warning",
         "SyntaxWarning": "Warning",
         "UnicodeWarning": "Warning",
         "UserWarning": "Warning",

     };


def _exc_is_subclass(exc_name: str, base_name: str) -> bool {
    if exc_name == base_name {
        return True;
    }
    cur = exc_name;
    while cur in _EXC_PARENT {
        cur = _EXC_PARENT[cur];
        if cur == base_name {
            return True;
        }
    }
    return False;
}

# CPython ``PyErr_GivenExceptionMatches`` name-level matching with
# BaseException / Exception special cases from ceval.
def exc_name_matches(err_name: str, target_name: str) -> bool {
    if target_name == "BaseException" {
        return True;
    }
    if target_name == "Exception" {
        if err_name == "GeneratorExit"
            or err_name == "KeyboardInterrupt"
            or err_name == "SystemExit" {
            return False;
        }
        return True;
    }
    if _exc_is_subclass(err_name, target_name) {
        return True;
    }
    return err_name == target_name;
}

def _obj_to_str(value: PyObj) -> str {
    if isinstance(value, PyStr) {
        return (value as PyStr).val;
    }
    if isinstance(value, PyInt) {
        return str((value as PyInt).val);
    }
    if isinstance(value, PyBool) {
        if (value as PyBool).val {
            return "True";
        }
        return "False";
    }
    return expect_str(value);
}

def _repr_obj(value: PyObj, repr_fn: any) -> str {
    res = repr_fn(value);
    if is_error(res) {
        return "<unrepresentable>";
    }
    return expect_str(res);
}

# CPython ``BaseException_str`` (+ VM ``message`` fallback for ``py_error``).
def baseexception_str(exc: PyException) -> PyStr {
    if len(exc.args) == 0 {
        if exc.message != "" {
            return PyStr(t="str", val=exc.message);
        }
        return PyStr(t="str", val="");
    }
    if len(exc.args) == 1 {
        return PyStr(t="str", val=_obj_to_str(exc.args[0]));
    }
    parts: list[str] = [];
    for item in exc.args {
        parts.append(_obj_to_str(item));
    }
    inner = ", ".join(parts);
    return PyStr(t="str", val="(" + inner + ")");
}

# CPython ``BaseException_repr`` (single-arg ``%R`` uses ``repr`` of the arg).
# ``repr_fn`` is ``py_repr`` from ceval (full native/host repr dispatch).
def baseexception_repr(exc: PyException, repr_fn: any) -> PyStr {
    name = exc.type_name;
    if len(exc.args) == 0 {
        return PyStr(t="str", val=name + "()");
    }
    if len(exc.args) == 1 {
        return PyStr(t="str", val=name + "(" + _repr_obj(exc.args[0], repr_fn) + ")",);
    }
    parts: list[str] = [];
    for item in exc.args {
        parts.append(_repr_obj(item, repr_fn));
    }
    inner = ", ".join(parts);
    return PyStr(t="str", val=name + "(" + inner + ")");
}

# ``PyErr_GivenExceptionMatches`` for native ``PyException`` vs exception types.
def py_err_given_exception_matches(err: PyException, exc: PyObj) -> bool {
    if isinstance(exc, PyTuple) {
        for item in (exc as PyTuple).items {
            if py_err_given_exception_matches(err, item) {
                return True;
            }
        }
        return False;
    }
    if exc.t == "exception_type" {
        return exc_name_matches(err.type_name, (exc as PyExceptionType).name);
    }
    return False;
}
