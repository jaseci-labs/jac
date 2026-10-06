"""The math module: its clinic-generated functions, the FUNC1/FUNC2 ones
mathmodule.c writes by hand, and the constants."""

import from jaclang.runtime.python.cpython_api { NULL, PyFloat_FromDouble, PyObject }
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_owned
}
import from jaclang.runtime.python.bindings.arguments { check_positional }
import from jaclang.runtime.python.bindings.clinic.math {
    math_acos_doc,
    math_acosh_doc,
    math_asin_doc,
    math_asinh_doc,
    math_atan_doc,
    math_atan2_doc,
    math_atanh_doc,
    math_cbrt_doc,
    math_copysign_doc,
    math_cos_doc,
    math_cosh_doc,
    math_erf_doc,
    math_erfc_doc,
    math_exp_doc,
    math_exp2_doc,
    math_expm1_doc,
    math_fabs_doc,
    math_gamma_doc,
    math_lgamma_doc,
    math_log_doc,
    math_log1p_doc,
    math_remainder_doc,
    math_sin_doc,
    math_sinh_doc,
    math_sqrt_doc,
    math_tan_doc,
    math_tanh_doc,
    module_doc,
    module_methods
}
import from jaclang.runtime.python.modules.math {
    jacpy_math_binary,
    jacpy_math_log,
    jacpy_math_unary
}

# FUNC1/FUNC1A/FUNC1D/FUNC1AD: METH_O over math_1().
def:priv acos_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(0, value);
}

def:priv acosh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(1, value);
}

def:priv asin_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(2, value);
}

def:priv asinh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(3, value);
}

def:priv atan_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(4, value);
}

def:priv atanh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(5, value);
}

def:priv cbrt_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(6, value);
}

def:priv cos_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(7, value);
}

def:priv cosh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(8, value);
}

def:priv erf_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(9, value);
}

def:priv erfc_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(10, value);
}

def:priv exp_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(11, value);
}

def:priv exp2_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(12, value);
}

def:priv expm1_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(13, value);
}

def:priv fabs_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(14, value);
}

def:priv gamma_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(15, value);
}

def:priv lgamma_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(16, value);
}

def:priv log1p_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(17, value);
}

def:priv sin_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(18, value);
}

def:priv sinh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(19, value);
}

def:priv sqrt_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(20, value);
}

def:priv tan_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(21, value);
}

def:priv tanh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_math_unary(22, value);
}

# FUNC2: METH_FASTCALL over math_2(), which checks for exactly two arguments.
def:priv binary(
    args: ptr[ptr[PyObject]], nargs: i64, name: str, operation: int
) -> ptr[PyObject] {
    if not check_positional(name, int(nargs), 2, 2) {
        return NULL;
    }
    stack = args.view(2);
    return jacpy_math_binary(i64(operation), stack[0], stack[1]);
}

def:priv atan2_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return binary(args, nargs, "atan2", 0);
}

def:priv copysign_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return binary(args, nargs, "copysign", 1);
}

def:priv remainder_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return binary(args, nargs, "remainder", 3);
}

# math_log(): METH_FASTCALL, "log" with one or two arguments.
def:priv log_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if not check_positional("log", int(nargs), 1, 2) {
        return NULL;
    }
    stack = args.view(int(nargs));
    return jacpy_math_log(stack[0], stack[1] if nargs == 2 else NULL);
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    names = ["pi", "e", "tau", "inf", "nan"];
    values = [
        3.14159265358979323846,
        2.71828182845904523536,
        6.28318530717958647692,
        float("inf"),
        float("nan")
    ];
    for i in range(len(names)) {
        if not add_owned(module, names[i], PyFloat_FromDouble(values[i])) {
            return i32(-1);
        }
    }
    return i32(0);
}

# math_methods[]: the hand-written entries with their mathmodule.c docs, and
# the clinic-generated ones.
glob:priv definition = ModuleDefinition(
         "math",
         module_doc,
         [
             MethodDefinition(
                 "acos", MethodCallbacks(positional=acos_call), math_acos_doc, flags=8
             ),
             MethodDefinition(
                 "acosh",
                 MethodCallbacks(positional=acosh_call),
                 math_acosh_doc,
                 flags=8
             ),
             MethodDefinition(
                 "asin", MethodCallbacks(positional=asin_call), math_asin_doc, flags=8
             ),
             MethodDefinition(
                 "asinh",
                 MethodCallbacks(positional=asinh_call),
                 math_asinh_doc,
                 flags=8
             ),
             MethodDefinition(
                 "atan", MethodCallbacks(positional=atan_call), math_atan_doc, flags=8
             ),
             MethodDefinition(
                 "atan2", MethodCallbacks(fast=atan2_call), math_atan2_doc, flags=128
             ),
             MethodDefinition(
                 "atanh",
                 MethodCallbacks(positional=atanh_call),
                 math_atanh_doc,
                 flags=8
             ),
             MethodDefinition(
                 "cbrt", MethodCallbacks(positional=cbrt_call), math_cbrt_doc, flags=8
             ),
             MethodDefinition(
                 "copysign",
                 MethodCallbacks(fast=copysign_call),
                 math_copysign_doc,
                 flags=128
             ),
             MethodDefinition(
                 "cos", MethodCallbacks(positional=cos_call), math_cos_doc, flags=8
             ),
             MethodDefinition(
                 "cosh", MethodCallbacks(positional=cosh_call), math_cosh_doc, flags=8
             ),
             MethodDefinition(
                 "erf", MethodCallbacks(positional=erf_call), math_erf_doc, flags=8
             ),
             MethodDefinition(
                 "erfc", MethodCallbacks(positional=erfc_call), math_erfc_doc, flags=8
             ),
             MethodDefinition(
                 "exp", MethodCallbacks(positional=exp_call), math_exp_doc, flags=8
             ),
             MethodDefinition(
                 "exp2", MethodCallbacks(positional=exp2_call), math_exp2_doc, flags=8
             ),
             MethodDefinition(
                 "expm1",
                 MethodCallbacks(positional=expm1_call),
                 math_expm1_doc,
                 flags=8
             ),
             MethodDefinition(
                 "fabs", MethodCallbacks(positional=fabs_call), math_fabs_doc, flags=8
             ),
             MethodDefinition(
                 "gamma",
                 MethodCallbacks(positional=gamma_call),
                 math_gamma_doc,
                 flags=8
             ),
             MethodDefinition(
                 "lgamma",
                 MethodCallbacks(positional=lgamma_call),
                 math_lgamma_doc,
                 flags=8
             ),
             MethodDefinition(
                 "log", MethodCallbacks(fast=log_call), math_log_doc, flags=128
             ),
             MethodDefinition(
                 "log1p",
                 MethodCallbacks(positional=log1p_call),
                 math_log1p_doc,
                 flags=8
             ),
             MethodDefinition(
                 "remainder",
                 MethodCallbacks(fast=remainder_call),
                 math_remainder_doc,
                 flags=128
             ),
             MethodDefinition(
                 "sin", MethodCallbacks(positional=sin_call), math_sin_doc, flags=8
             ),
             MethodDefinition(
                 "sinh", MethodCallbacks(positional=sinh_call), math_sinh_doc, flags=8
             ),
             MethodDefinition(
                 "sqrt", MethodCallbacks(positional=sqrt_call), math_sqrt_doc, flags=8
             ),
             MethodDefinition(
                 "tan", MethodCallbacks(positional=tan_call), math_tan_doc, flags=8
             ),
             MethodDefinition(
                 "tanh", MethodCallbacks(positional=tanh_call), math_tanh_doc, flags=8
             )
         ]
             + module_methods,
         ModuleHooks(execute=execute)
     );

def:pub PyInit_math -> ptr[PyObject] {
    return definition.initialize();
}
