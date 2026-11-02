"""The cmath module: its clinic-generated functions and constants."""

# cmath_exec(): pi, e, tau, inf, infj, nan and nanj.
def:priv execute(module: ptr[PyObject]) -> i32 {
    names = ["pi", "e", "tau", "inf", "nan"];
    values = [
        3.14159265358979323846,
        2.71828182845904523536,
        6.28318530717958647693,
        float("inf"),
        float("nan")
    ];
    for i in range(len(names)) {
        if not add_owned(module, names[i], PyFloat_FromDouble(values[i])) {
            return i32(-1);
        }
    }
    if not add_owned(module, "infj", PyComplex_FromDoubles(0.0, float("inf"))) {
        return i32(-1);
    }
    if not add_owned(module, "nanj", PyComplex_FromDoubles(0.0, float("nan"))) {
        return i32(-1);
    }
    return i32(0);
}

def:priv acos_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(0, value);
}

def:priv acosh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(1, value);
}

def:priv asin_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(2, value);
}

def:priv asinh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(3, value);
}

def:priv atan_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(4, value);
}

def:priv atanh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(5, value);
}

def:priv cos_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(6, value);
}

def:priv cosh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(7, value);
}

def:priv exp_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(8, value);
}

def:priv sin_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(9, value);
}

def:priv sinh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(10, value);
}

def:priv sqrt_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(11, value);
}

def:priv tan_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(12, value);
}

def:priv tanh_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(13, value);
}

def:priv log10_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(14, value);
}

def:priv phase_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_cmath_call(15, value);
}

def:priv fast_methods -> list[MethodDefinition] {
    methods: list[MethodDefinition] = [];
    for method in module_methods {
        name = method.name;
        if name == "acos" {
            method.callbacks = MethodCallbacks(positional=acos_call);
        } elif name == "acosh" {
            method.callbacks = MethodCallbacks(positional=acosh_call);
        } elif name == "asin" {
            method.callbacks = MethodCallbacks(positional=asin_call);
        } elif name == "asinh" {
            method.callbacks = MethodCallbacks(positional=asinh_call);
        } elif name == "atan" {
            method.callbacks = MethodCallbacks(positional=atan_call);
        } elif name == "atanh" {
            method.callbacks = MethodCallbacks(positional=atanh_call);
        } elif name == "cos" {
            method.callbacks = MethodCallbacks(positional=cos_call);
        } elif name == "cosh" {
            method.callbacks = MethodCallbacks(positional=cosh_call);
        } elif name == "exp" {
            method.callbacks = MethodCallbacks(positional=exp_call);
        } elif name == "sin" {
            method.callbacks = MethodCallbacks(positional=sin_call);
        } elif name == "sinh" {
            method.callbacks = MethodCallbacks(positional=sinh_call);
        } elif name == "sqrt" {
            method.callbacks = MethodCallbacks(positional=sqrt_call);
        } elif name == "tan" {
            method.callbacks = MethodCallbacks(positional=tan_call);
        } elif name == "tanh" {
            method.callbacks = MethodCallbacks(positional=tanh_call);
        } elif name == "log10" {
            method.callbacks = MethodCallbacks(positional=log10_call);
        } elif name == "phase" {
            method.callbacks = MethodCallbacks(positional=phase_call);
        }
        methods.append(method);
    }
    return methods;
}

glob:priv definition = ModuleDefinition(
         "cmath", module_doc, fast_methods(), ModuleHooks(execute=execute)
     );

def:pub PyInit_cmath -> ptr[PyObject] {
    return definition.initialize();
}
