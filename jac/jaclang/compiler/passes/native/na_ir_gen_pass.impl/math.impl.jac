"""math module codegen: lower `math.<fn>(...)` and `math.<const>` to libm.

Mechanism A (issue #6404): `import math;` is allowlisted in
NATIVE_SUPPORTED_STDLIB and every member access is intercepted here and
lowered to a libm call (resolved from the host process at JIT time / linked
against libm for AOT). CPython also calls libm, so results are ULP-level
congruent — `math` is 🟢 in the roadmap. Integer-only helpers
(factorial/gcd/isqrt) are out of the v1 subset and documented as unsupported.
"""

# Constants exposed as math.<name>. Values match CPython's math module.
glob _MATH_CONSTS: dict[str, float] = {
         "pi": 3.141592653589793,
         "e": 2.718281828459045,
         "tau": 6.283185307179586,
         "inf": float("inf"),
         "nan": float("nan"),

     },
     # Unary double->double functions. Maps the Python name to the libm symbol
     # (identical except where noted, e.g. gamma -> tgamma).
     _MATH_UNARY: dict[str, str] = {
         "sqrt": "sqrt",
         "sin": "sin",
         "cos": "cos",
         "tan": "tan",
         "asin": "asin",
         "acos": "acos",
         "atan": "atan",
         "sinh": "sinh",
         "cosh": "cosh",
         "tanh": "tanh",
         "asinh": "asinh",
         "acosh": "acosh",
         "atanh": "atanh",
         "exp": "exp",
         "expm1": "expm1",
         "log2": "log2",
         "log10": "log10",
         "log1p": "log1p",
         "fabs": "fabs",
         "cbrt": "cbrt",
         "erf": "erf",
         "erfc": "erfc",
         "gamma": "tgamma",
         "lgamma": "lgamma",

     },
     # Binary (double, double)->double functions, mapped to libm symbols.
     _MATH_BINARY: dict[str, str] = {
         "pow": "pow",
         "atan2": "atan2",
         "hypot": "hypot",
         "fmod": "fmod",
         "copysign": "copysign",
         "remainder": "remainder",

     },
     # Unary double->int functions (Python returns int): call libm then fptosi.
     _MATH_TO_INT: set[str] = {"floor", "ceil", "trunc"};

"""Lower a `math.<const>` attribute access (math.pi/e/tau/inf/nan)."""
impl NaIRGenPass._emit_math_const(name: str) -> (ir.Value | None) {
    if name in _MATH_CONSTS {
        return ir.Constant(ir.DoubleType(), _MATH_CONSTS[name]);
    }
    return None;
}

"""Lower a `math.<fn>(args)` call to libm. Returns None if unsupported
(caller falls through to E5090 so the failure is loud, not silent)."""
impl NaIRGenPass._emit_math_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) {
    f64 = ir.DoubleType();
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    params = nd.params or [];
    # Evaluate args and coerce each to double (libm's calling type).
    args: list[ir.Value] = [];
    for p in params {
        v = self._codegen_expr(p);
        if v is None {
            return None;
        }
        args.append(self._coerce_type(v, f64));
    }

    # --- Unary double->double via libm ---
    if name in _MATH_UNARY and len(args) == 1 {
        fn = self._get_or_declare_extern(_MATH_UNARY[name], f64, [f64]);
        return self.builder.call(fn, [args[0]], name=f"math.{name}");
    }

    # --- Unary double->int (floor/ceil/trunc) ---
    if name in _MATH_TO_INT and len(args) == 1 {
        fn = self._get_or_declare_extern(name, f64, [f64]);
        d = self.builder.call(fn, [args[0]], name=f"math.{name}.d");
        return self.builder.fptosi(d, i64, name=f"math.{name}");
    }

    # --- Binary double,double->double via libm ---
    if name in _MATH_BINARY and len(args) == 2 {
        fn = self._get_or_declare_extern(_MATH_BINARY[name], f64, [f64, f64]);
        return self.builder.call(fn, [args[0], args[1]], name=f"math.{name}");
    }

    # --- log(x) or log(x, base) ---
    if name == "log" and len(args) >= 1 {
        logfn = self._get_or_declare_extern("log", f64, [f64]);
        lx = self.builder.call(logfn, [args[0]], name="math.log.x");
        if len(args) == 1 {
            return lx;
        }
        lb = self.builder.call(logfn, [args[1]], name="math.log.base");
        return self.builder.fdiv(lx, lb, name="math.log");
    }

    # --- degrees/radians (computed; not libm symbols) ---
    if name == "degrees" and len(args) == 1 {
        k = ir.Constant(f64, 180.0 / 3.141592653589793);
        return self.builder.fmul(args[0], k, name="math.degrees");
    }
    if name == "radians" and len(args) == 1 {
        k = ir.Constant(f64, 3.141592653589793 / 180.0);
        return self.builder.fmul(args[0], k, name="math.radians");
    }

    # --- Predicates -> bool (i1) ---
    if name == "isnan" and len(args) == 1 {
        # `x != x` lowers to `fcmp une` which is true iff x is NaN (an ordered
        # value always equals itself; only NaN compares unordered/not-equal).
        return self.builder.fcmp_unordered("!=", args[0], args[0], name="math.isnan");
    }
    if name == "isinf" and len(args) == 1 {
        fabsfn = self._get_or_declare_extern("fabs", f64, [f64]);
        a = self.builder.call(fabsfn, [args[0]], name="math.isinf.abs");
        inf = ir.Constant(f64, float("inf"));
        return self.builder.fcmp_ordered("==", a, inf, name="math.isinf");
    }
    if name == "isfinite" and len(args) == 1 {
        # finite iff (x == x) and (|x| != inf): ordered, non-infinite.
        ord_eq = self.builder.fcmp_ordered("==", args[0], args[0], name="math.fin.ord");
        fabsfn = self._get_or_declare_extern("fabs", f64, [f64]);
        a = self.builder.call(fabsfn, [args[0]], name="math.fin.abs");
        inf = ir.Constant(f64, float("inf"));
        not_inf = self.builder.fcmp_ordered("!=", a, inf, name="math.fin.noinf");
        return self.builder.and_(ord_eq, not_inf, name="math.isfinite");
    }

    return None;
}
