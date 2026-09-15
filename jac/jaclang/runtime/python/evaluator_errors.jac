"""Evaluator diagnostics from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. The C adapters expose object fields and
fixed-arity formatting calls. Branching and reference cleanup remain here.
"""

import from jaclang.runtime.python.references {
    JacPyThreadState, PyObjectRef, jacpy_ref_null, jacpy_ref_is_null, jacpy_ref_close
}
import from jaclang.runtime.python.evaluator_support {
    jacpy_eval_tuple_check, jacpy_eval_tuple_size, jacpy_eval_tuple_item,
    jacpy_eval_error_pending
}
import from jaclang.runtime.python.evaluator_monitoring {
    PyThreadState_Get, PyErr_GetRaisedException, PyErr_SetRaisedException
}

import from c {
    # A borrowed C string is an opaque address, not a Jac string descriptor.
    obj JacPyCString;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_object_has_iter(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def PySequence_Check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def PyErr_Clear;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyObject_FunctionStr(function: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_exception_type(tstate: &JacPyThreadState, kind: i32) -> &PyObjectRef from tstate;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_format_function_type_error(tstate: &JacPyThreadState, format: str,
        function: &PyObjectRef, operand: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_format_objects_error(tstate: &JacPyThreadState, exception: &PyObjectRef,
        format: str, first: &PyObjectRef, second: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def PyErr_ExceptionMatches(exception: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def PyErr_GivenExceptionMatches(exception: &PyObjectRef, expected: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def PyException_GetArgs(exception: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=False)
    def PyUnicode_AsUTF8(value: &PyObjectRef) -> &JacPyCString from value;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_cstring_is_null(value: &JacPyCString) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_format_cstring_error(tstate: &JacPyThreadState, exception: &PyObjectRef,
        format: &JacPyCString, value: &JacPyCString);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_object_is(left: &PyObjectRef, right: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_name_error_has_name(exception: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_identifier(tstate: &JacPyThreadState, identifier: i32) -> &PyObjectRef from tstate;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyObject_SetAttr(value: &PyObjectRef, name: &PyObjectRef, attribute: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_code_local_name(code: &PyObjectRef, index: i64) -> &PyObjectRef from code;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_code_first_free(code: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_error_format(kind: i32) -> &JacPyCString;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_type_has_await(type: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_format_type_error(tstate: &JacPyThreadState, format: str, type: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_method_check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_function_check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_cfunction_check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_method_function(method: &PyObjectRef) -> &PyObjectRef from method;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_function_name(function: &PyObjectRef) -> &PyObjectRef from function;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_cfunction_name(function: &PyObjectRef) -> &JacPyCString from function;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_object_type_name(value: &PyObjectRef) -> &JacPyCString from value;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_function_description(callable: i32) -> &JacPyCString;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_object_type(value: &PyObjectRef) -> &PyObjectRef from value;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_type_lookup(type: &PyObjectRef, name: &PyObjectRef) -> &PyObjectRef from type;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_object_has_descr_get(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_fatal(message: str);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _Py_Check_ArgsIterable(tstate: &JacPyThreadState,
    function: &PyObjectRef, arguments: &PyObjectRef) -> i32 {
    if jacpy_object_has_iter(arguments) == 0 and PySequence_Check(arguments) == 0 {
        PyErr_Clear();
        description: own PyObjectRef = _PyObject_FunctionStr(function);
        if jacpy_ref_is_null(&description) == 0 {
            jacpy_format_function_type_error(tstate,
                "%U argument after * must be an iterable, not %.200s", &description, arguments);
            jacpy_ref_close(description);
        }
        return -1;
    }
    return 0;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_FormatKwargsError(tstate: &JacPyThreadState,
    function: &PyObjectRef, keywords: &PyObjectRef) {
    if PyErr_ExceptionMatches(jacpy_exception_type(tstate, 1)) != 0 {
        PyErr_Clear();
        description: own PyObjectRef = _PyObject_FunctionStr(function);
        if jacpy_ref_is_null(&description) == 0 {
            jacpy_format_function_type_error(tstate,
                "%U argument after ** must be a mapping, not %.200s", &description, keywords);
            jacpy_ref_close(description);
        }
    } elif PyErr_ExceptionMatches(jacpy_exception_type(tstate, 2)) != 0 {
        exception: own PyObjectRef = PyErr_GetRaisedException();
        arguments: own PyObjectRef = PyException_GetArgs(&exception);
        if jacpy_ref_is_null(&exception) == 0 and jacpy_eval_tuple_check(&arguments) != 0
            and jacpy_eval_tuple_size(&arguments) == 1 {
            PyErr_Clear();
            description: own PyObjectRef = _PyObject_FunctionStr(function);
            if jacpy_ref_is_null(&description) == 0 {
                key: &PyObjectRef from arguments = jacpy_eval_tuple_item(&arguments, 0);
                jacpy_format_objects_error(tstate, jacpy_exception_type(tstate, 0),
                    "%U got multiple values for keyword argument '%S'", &description, key);
                jacpy_ref_close(description);
            }
            jacpy_ref_close(exception);
        } else {
            PyErr_SetRaisedException(exception);
        }
        jacpy_ref_close(arguments);
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_FormatExcCheckArg(tstate: &JacPyThreadState, exception_type: &PyObjectRef,
    format: &JacPyCString, value: &PyObjectRef) {
    if jacpy_ref_is_null(value) != 0 { return; }
    characters: &JacPyCString from value = PyUnicode_AsUTF8(value);
    if jacpy_cstring_is_null(characters) != 0 { return; }
    jacpy_format_cstring_error(tstate, exception_type, format, characters);
    name_error: &PyObjectRef from tstate = jacpy_exception_type(tstate, 3);
    if jacpy_object_is(exception_type, name_error) != 0 {
        exception: own PyObjectRef = PyErr_GetRaisedException();
        if PyErr_GivenExceptionMatches(&exception, name_error) != 0 {
            if jacpy_name_error_has_name(&exception) == 0 {
                # Attribute assignment can fail; restore the original NameError
                # after the attempt, including any name needed for suggestions.
                PyObject_SetAttr(&exception, jacpy_eval_identifier(tstate, 0), value);
            }
        }
        PyErr_SetRaisedException(exception);
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_FormatExcUnbound(tstate: &JacPyThreadState, code: &PyObjectRef, oparg: i32) {
    if jacpy_eval_error_pending() != 0 { return; }
    name: &PyObjectRef from code = jacpy_code_local_name(code, oparg);
    if oparg < jacpy_code_first_free(code) {
        _PyEval_FormatExcCheckArg(tstate, jacpy_exception_type(tstate, 4),
            jacpy_eval_error_format(1), name);
    } else {
        _PyEval_FormatExcCheckArg(tstate, jacpy_exception_type(tstate, 3),
            jacpy_eval_error_format(2), name);
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_FormatAwaitableError(tstate: &JacPyThreadState, type: &PyObjectRef, oparg: i32) {
    if jacpy_type_has_await(type) == 0 {
        if oparg == 1 {
            jacpy_format_type_error(tstate,
                "'async with' received an object from __aenter__ that does not implement __await__: %.100s", type);
        } elif oparg == 2 {
            jacpy_format_type_error(tstate,
                "'async with' received an object from __aexit__ that does not implement __await__: %.100s", type);
        }
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=False)
def PyEval_GetFuncName(function: &PyObjectRef) -> &JacPyCString from function {
    if jacpy_method_check(function) != 0 {
        method_function: &PyObjectRef from function = jacpy_method_function(function);
        return PyEval_GetFuncName(method_function);
    } elif jacpy_function_check(function) != 0 {
        name: &PyObjectRef from function = jacpy_function_name(function);
        return PyUnicode_AsUTF8(name);
    } elif jacpy_cfunction_check(function) != 0 {
        return jacpy_cfunction_name(function);
    }
    return jacpy_object_type_name(function);
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def PyEval_GetFuncDesc(function: &PyObjectRef) -> &JacPyCString from function {
    if jacpy_method_check(function) != 0 or jacpy_function_check(function) != 0
        or jacpy_cfunction_check(function) != 0 {
        return jacpy_function_description(1);
    }
    return jacpy_function_description(0);
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_type_has_special_method(type: &PyObjectRef, name: &PyObjectRef) -> i32 {
    descriptor: &PyObjectRef from type = jacpy_type_lookup(type, name);
    if jacpy_ref_is_null(descriptor) != 0 { return 0; }
    return jacpy_object_has_descr_get(descriptor);
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def _PyEval_SpecialMethodCanSuggest(value: &PyObjectRef, oparg: i32) -> i32 {
    tstate: &JacPyThreadState = PyThreadState_Get();
    type: &PyObjectRef from value = jacpy_object_type(value);
    if oparg == 0 or oparg == 1 {
        if jacpy_type_has_special_method(type, jacpy_eval_identifier(tstate, 1)) != 0
            and jacpy_type_has_special_method(type, jacpy_eval_identifier(tstate, 2)) != 0 {
            return 1;
        }
        return 0;
    } elif oparg == 2 or oparg == 3 {
        if jacpy_type_has_special_method(type, jacpy_eval_identifier(tstate, 3)) != 0
            and jacpy_type_has_special_method(type, jacpy_eval_identifier(tstate, 4)) != 0 {
            return 1;
        }
        return 0;
    }
    jacpy_eval_fatal("unsupported special method");
    return -1;
}
