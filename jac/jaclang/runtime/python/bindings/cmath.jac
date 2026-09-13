"""Python complex-math signatures, constants, and native initialization."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
    MethodCallbacks,
    MethodDefinition,
    add_owned
}
import from jaclang.runtime.python.bindings.arguments {
    CallSignature,
    BoundArguments,
    invoke
}
import from jaclang.runtime.python.modules.cmath {
    jacpy_cmath_unary,
    jacpy_cmath_log,
    jacpy_cmath_rect,
    jacpy_cmath_isclose
}
import from jaclang.runtime.python.capi { jacpy_float, jacpy_complex }

def:priv acos_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(0, value);
}

def:priv acosh_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(1, value);
}

def:priv asin_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(2, value);
}

def:priv asinh_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(3, value);
}

def:priv atan_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(4, value);
}

def:priv atanh_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(5, value);
}

def:priv cos_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(6, value);
}

def:priv cosh_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(7, value);
}

def:priv exp_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(8, value);
}

def:priv sin_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(9, value);
}

def:priv sinh_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(10, value);
}

def:priv sqrt_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(11, value);
}

def:priv tan_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(12, value);
}

def:priv tanh_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(13, value);
}

def:priv log10_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(14, value);
}

def:priv phase_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(15, value);
}

def:priv polar_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(16, value);
}

def:priv isfinite_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(17, value);
}

def:priv isinf_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(18, value);
}

def:priv isnan_call(module: u64, value: u64) -> u64 {
    return jacpy_cmath_unary(19, value);
}

glob:priv log_signature = CallSignature("log", ["z", "base"], 1, 2, 2),
     rect_signature = CallSignature("rect", ["r", "phi"], 2, 2, 2),
     close_signature = CallSignature("isclose", ["a", "b", "rel_tol", "abs_tol"], 2, 2);

def:priv log_bound(args: BoundArguments) -> u64 {
    return jacpy_cmath_log(args.values[0], args.values[1]);
}

def:priv rect_bound(args: BoundArguments) -> u64 {
    return jacpy_cmath_rect(args.values[0], args.values[1]);
}

def:priv close_bound(args: BoundArguments) -> u64 {
    return jacpy_cmath_isclose(
        args.values[0], args.values[1], args.values[2], args.values[3]
    );
}

def:priv log_call(module: u64, args: u64) -> u64 {
    return invoke(log_signature, args, 0, log_bound);
}

def:priv rect_call(module: u64, args: u64) -> u64 {
    return invoke(rect_signature, args, 0, rect_bound);
}

def:priv close_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(close_signature, args, kwargs, close_bound);
}

def:priv execute(module: u64) -> i32 {
    names = ["pi", "e", "tau", "inf", "nan"];
    values = [
        3.14159265358979323846,
        2.71828182845904523536,
        6.28318530717958647693,
        float("inf"),
        float("nan")
    ];
    for i in range(len(names)) {
        if not add_owned(module, names[i], jacpy_float(values[i])) {
            return i32(-1);
        }
    }
    if not add_owned(module, "infj", jacpy_complex(0.0, float("inf"))) {
        return i32(-1);
    }
    if not add_owned(module, "nanj", jacpy_complex(0.0, float("nan"))) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "cmath",
         "Native Jac complex mathematics.",
         [
             MethodDefinition(
                 "acos",
                 MethodCallbacks(positional=acos_call),
                 "acos($module, z, /)\n--\n\nComplex acos.",
                 flags=8
             ),
             MethodDefinition(
                 "acosh",
                 MethodCallbacks(positional=acosh_call),
                 "acosh($module, z, /)\n--\n\nComplex acosh.",
                 flags=8
             ),
             MethodDefinition(
                 "asin",
                 MethodCallbacks(positional=asin_call),
                 "asin($module, z, /)\n--\n\nComplex asin.",
                 flags=8
             ),
             MethodDefinition(
                 "asinh",
                 MethodCallbacks(positional=asinh_call),
                 "asinh($module, z, /)\n--\n\nComplex asinh.",
                 flags=8
             ),
             MethodDefinition(
                 "atan",
                 MethodCallbacks(positional=atan_call),
                 "atan($module, z, /)\n--\n\nComplex atan.",
                 flags=8
             ),
             MethodDefinition(
                 "atanh",
                 MethodCallbacks(positional=atanh_call),
                 "atanh($module, z, /)\n--\n\nComplex atanh.",
                 flags=8
             ),
             MethodDefinition(
                 "cos",
                 MethodCallbacks(positional=cos_call),
                 "cos($module, z, /)\n--\n\nComplex cos.",
                 flags=8
             ),
             MethodDefinition(
                 "cosh",
                 MethodCallbacks(positional=cosh_call),
                 "cosh($module, z, /)\n--\n\nComplex cosh.",
                 flags=8
             ),
             MethodDefinition(
                 "exp",
                 MethodCallbacks(positional=exp_call),
                 "exp($module, z, /)\n--\n\nComplex exp.",
                 flags=8
             ),
             MethodDefinition(
                 "sin",
                 MethodCallbacks(positional=sin_call),
                 "sin($module, z, /)\n--\n\nComplex sin.",
                 flags=8
             ),
             MethodDefinition(
                 "sinh",
                 MethodCallbacks(positional=sinh_call),
                 "sinh($module, z, /)\n--\n\nComplex sinh.",
                 flags=8
             ),
             MethodDefinition(
                 "sqrt",
                 MethodCallbacks(positional=sqrt_call),
                 "sqrt($module, z, /)\n--\n\nComplex sqrt.",
                 flags=8
             ),
             MethodDefinition(
                 "tan",
                 MethodCallbacks(positional=tan_call),
                 "tan($module, z, /)\n--\n\nComplex tan.",
                 flags=8
             ),
             MethodDefinition(
                 "tanh",
                 MethodCallbacks(positional=tanh_call),
                 "tanh($module, z, /)\n--\n\nComplex tanh.",
                 flags=8
             ),
             MethodDefinition(
                 "log10",
                 MethodCallbacks(positional=log10_call),
                 "log10($module, z, /)\n--\n\nComplex log10.",
                 flags=8
             ),
             MethodDefinition(
                 "phase",
                 MethodCallbacks(positional=phase_call),
                 "phase($module, z, /)\n--\n\nComplex phase.",
                 flags=8
             ),
             MethodDefinition(
                 "polar",
                 MethodCallbacks(positional=polar_call),
                 "polar($module, z, /)\n--\n\nComplex polar.",
                 flags=8
             ),
             MethodDefinition(
                 "isfinite",
                 MethodCallbacks(positional=isfinite_call),
                 "isfinite($module, z, /)\n--\n\nComplex isfinite.",
                 flags=8
             ),
             MethodDefinition(
                 "isinf",
                 MethodCallbacks(positional=isinf_call),
                 "isinf($module, z, /)\n--\n\nComplex isinf.",
                 flags=8
             ),
             MethodDefinition(
                 "isnan",
                 MethodCallbacks(positional=isnan_call),
                 "isnan($module, z, /)\n--\n\nComplex isnan.",
                 flags=8
             ),
             MethodDefinition(
                 "log",
                 MethodCallbacks(positional=log_call),
                 "log($module, z, base=None, /)\n--\n\nComplex logarithm.",
                 flags=1
             ),
             MethodDefinition(
                 "rect",
                 MethodCallbacks(positional=rect_call),
                 "rect($module, r, phi, /)\n--\n\nConvert polar to rectangular coordinates.",
                 flags=1
             ),
             MethodDefinition(
                 "isclose",
                 MethodCallbacks(keywords=close_call),
                 "isclose($module, /, a, b, *, rel_tol=1e-09, abs_tol=0.0)\n--\n\nCompare complex values with tolerances."
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit_cmath -> u64 {
    return definition.initialize();
}
