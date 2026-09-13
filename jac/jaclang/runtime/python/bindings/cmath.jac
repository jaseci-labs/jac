"""Python complex-math signatures, constants, and native initialization."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    ModuleHooks,
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
                 "acos", 0, "acos($module, z, /)\n--\n\nComplex acos.", acos_call, 8
             ),
             MethodDefinition(
                 "acosh", 0, "acosh($module, z, /)\n--\n\nComplex acosh.", acosh_call, 8
             ),
             MethodDefinition(
                 "asin", 0, "asin($module, z, /)\n--\n\nComplex asin.", asin_call, 8
             ),
             MethodDefinition(
                 "asinh", 0, "asinh($module, z, /)\n--\n\nComplex asinh.", asinh_call, 8
             ),
             MethodDefinition(
                 "atan", 0, "atan($module, z, /)\n--\n\nComplex atan.", atan_call, 8
             ),
             MethodDefinition(
                 "atanh", 0, "atanh($module, z, /)\n--\n\nComplex atanh.", atanh_call, 8
             ),
             MethodDefinition(
                 "cos", 0, "cos($module, z, /)\n--\n\nComplex cos.", cos_call, 8
             ),
             MethodDefinition(
                 "cosh", 0, "cosh($module, z, /)\n--\n\nComplex cosh.", cosh_call, 8
             ),
             MethodDefinition(
                 "exp", 0, "exp($module, z, /)\n--\n\nComplex exp.", exp_call, 8
             ),
             MethodDefinition(
                 "sin", 0, "sin($module, z, /)\n--\n\nComplex sin.", sin_call, 8
             ),
             MethodDefinition(
                 "sinh", 0, "sinh($module, z, /)\n--\n\nComplex sinh.", sinh_call, 8
             ),
             MethodDefinition(
                 "sqrt", 0, "sqrt($module, z, /)\n--\n\nComplex sqrt.", sqrt_call, 8
             ),
             MethodDefinition(
                 "tan", 0, "tan($module, z, /)\n--\n\nComplex tan.", tan_call, 8
             ),
             MethodDefinition(
                 "tanh", 0, "tanh($module, z, /)\n--\n\nComplex tanh.", tanh_call, 8
             ),
             MethodDefinition(
                 "log10", 0, "log10($module, z, /)\n--\n\nComplex log10.", log10_call, 8
             ),
             MethodDefinition(
                 "phase", 0, "phase($module, z, /)\n--\n\nComplex phase.", phase_call, 8
             ),
             MethodDefinition(
                 "polar", 0, "polar($module, z, /)\n--\n\nComplex polar.", polar_call, 8
             ),
             MethodDefinition(
                 "isfinite",
                 0,
                 "isfinite($module, z, /)\n--\n\nComplex isfinite.",
                 isfinite_call,
                 8
             ),
             MethodDefinition(
                 "isinf", 0, "isinf($module, z, /)\n--\n\nComplex isinf.", isinf_call, 8
             ),
             MethodDefinition(
                 "isnan", 0, "isnan($module, z, /)\n--\n\nComplex isnan.", isnan_call, 8
             ),
             MethodDefinition(
                 "log",
                 0,
                 "log($module, z, base=None, /)\n--\n\nComplex logarithm.",
                 log_call,
                 1
             ),
             MethodDefinition(
                 "rect",
                 0,
                 "rect($module, r, phi, /)\n--\n\nConvert polar to rectangular coordinates.",
                 rect_call,
                 1
             ),
             MethodDefinition(
                 "isclose",
                 close_call,
                 "isclose($module, /, a, b, *, rel_tol=1e-09, abs_tol=0.0)\n--\n\nCompare complex values with tolerances."
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit_cmath -> u64 {
    return definition.initialize();
}
