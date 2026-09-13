"""Python math signatures, constants, and native initialization."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_owned
}
import from jaclang.runtime.python.bindings.arguments {
    CallSignature,
    BoundArguments,
    invoke
}
import from jaclang.runtime.python.capi { jacpy_float }
import from jaclang.runtime.python.modules.math {
    jacpy_math_binary,
    jacpy_math_comb,
    jacpy_math_dist,
    jacpy_math_factorial,
    jacpy_math_fma,
    jacpy_math_fsum,
    jacpy_math_gcd,
    jacpy_math_hypot,
    jacpy_math_isclose,
    jacpy_math_isqrt,
    jacpy_math_ldexp,
    jacpy_math_log,
    jacpy_math_nextafter,
    jacpy_math_parts,
    jacpy_math_prod,
    jacpy_math_sumprod,
    jacpy_math_unary
}

def:priv factorial_call(module: u64, value: u64) -> u64 {
    return jacpy_math_factorial(value);
}

def:priv isqrt_call(module: u64, value: u64) -> u64 {
    return jacpy_math_isqrt(value);
}

def:priv gcd_call(module: u64, args: u64) -> u64 {
    return jacpy_math_gcd(args, 0);
}

def:priv lcm_call(module: u64, args: u64) -> u64 {
    return jacpy_math_gcd(args, 1);
}

glob:priv comb_signature = CallSignature("comb", ["n", "k"], 2, 2, 2);
def:priv comb_bound(args: BoundArguments) -> u64 {
    return jacpy_math_comb(args.values[0], args.values[1], 1);
}

def:priv comb_call(module: u64, args: u64) -> u64 {
    return invoke(comb_signature, args, 0, comb_bound);
}

glob:priv perm_signature = CallSignature("perm", ["n", "k"], 1, 2, 2);
def:priv perm_bound(args: BoundArguments) -> u64 {
    return jacpy_math_comb(args.values[0], args.values[1], 0);
}

def:priv perm_call(module: u64, args: u64) -> u64 {
    return invoke(perm_signature, args, 0, perm_bound);
}

def:priv acos_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(0, value);
}

def:priv acosh_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(1, value);
}

def:priv asin_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(2, value);
}

def:priv asinh_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(3, value);
}

def:priv atan_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(4, value);
}

def:priv atanh_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(5, value);
}

def:priv cbrt_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(6, value);
}

def:priv cos_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(7, value);
}

def:priv cosh_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(8, value);
}

def:priv erf_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(9, value);
}

def:priv erfc_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(10, value);
}

def:priv exp_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(11, value);
}

def:priv exp2_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(12, value);
}

def:priv expm1_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(13, value);
}

def:priv fabs_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(14, value);
}

def:priv gamma_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(15, value);
}

def:priv lgamma_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(16, value);
}

def:priv log1p_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(17, value);
}

def:priv sin_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(18, value);
}

def:priv sinh_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(19, value);
}

def:priv sqrt_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(20, value);
}

def:priv tan_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(21, value);
}

def:priv tanh_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(22, value);
}

def:priv degrees_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(23, value);
}

def:priv radians_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(24, value);
}

def:priv isfinite_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(25, value);
}

def:priv isinf_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(26, value);
}

def:priv isnan_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(27, value);
}

def:priv ceil_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(28, value);
}

def:priv floor_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(29, value);
}

def:priv trunc_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(30, value);
}

def:priv log10_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(31, value);
}

def:priv log2_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(32, value);
}

def:priv ulp_call(module: u64, value: u64) -> u64 {
    return jacpy_math_unary(33, value);
}

glob:priv atan2_signature = CallSignature("atan2", ["x", "y"], 2, 2, 2);
def:priv atan2_bound(args: BoundArguments) -> u64 {
    return jacpy_math_binary(0, args.values[0], args.values[1]);
}

def:priv atan2_call(module: u64, args: u64) -> u64 {
    return invoke(atan2_signature, args, 0, atan2_bound);
}

glob:priv copysign_signature = CallSignature("copysign", ["x", "y"], 2, 2, 2);
def:priv copysign_bound(args: BoundArguments) -> u64 {
    return jacpy_math_binary(1, args.values[0], args.values[1]);
}

def:priv copysign_call(module: u64, args: u64) -> u64 {
    return invoke(copysign_signature, args, 0, copysign_bound);
}

glob:priv fmod_signature = CallSignature("fmod", ["x", "y"], 2, 2, 2);
def:priv fmod_bound(args: BoundArguments) -> u64 {
    return jacpy_math_binary(2, args.values[0], args.values[1]);
}

def:priv fmod_call(module: u64, args: u64) -> u64 {
    return invoke(fmod_signature, args, 0, fmod_bound);
}

glob:priv remainder_signature = CallSignature("remainder", ["x", "y"], 2, 2, 2);
def:priv remainder_bound(args: BoundArguments) -> u64 {
    return jacpy_math_binary(3, args.values[0], args.values[1]);
}

def:priv remainder_call(module: u64, args: u64) -> u64 {
    return invoke(remainder_signature, args, 0, remainder_bound);
}

glob:priv pow_signature = CallSignature("pow", ["x", "y"], 2, 2, 2);
def:priv pow_bound(args: BoundArguments) -> u64 {
    return jacpy_math_binary(4, args.values[0], args.values[1]);
}

def:priv pow_call(module: u64, args: u64) -> u64 {
    return invoke(pow_signature, args, 0, pow_bound);
}

glob:priv log_signature = CallSignature("log", ["x", "base"], 1, 2, 2);
def:priv log_bound(args: BoundArguments) -> u64 {
    return jacpy_math_log(args.values[0], args.values[1]);
}

def:priv log_call(module: u64, args: u64) -> u64 {
    return invoke(log_signature, args, 0, log_bound);
}

glob:priv ldexp_signature = CallSignature("ldexp", ["x", "i"], 2, 2, 2);
def:priv ldexp_bound(args: BoundArguments) -> u64 {
    return jacpy_math_ldexp(args.values[0], args.values[1]);
}

def:priv ldexp_call(module: u64, args: u64) -> u64 {
    return invoke(ldexp_signature, args, 0, ldexp_bound);
}

glob:priv fma_signature = CallSignature("fma", ["x", "y", "z"], 3, 3, 3);
def:priv fma_bound(args: BoundArguments) -> u64 {
    return jacpy_math_fma(args.values[0], args.values[1], args.values[2]);
}

def:priv fma_call(module: u64, args: u64) -> u64 {
    return invoke(fma_signature, args, 0, fma_bound);
}

def:priv frexp_call(module: u64, value: u64) -> u64 {
    return jacpy_math_parts(0, value);
}

def:priv modf_call(module: u64, value: u64) -> u64 {
    return jacpy_math_parts(1, value);
}

glob:priv isclose_signature = CallSignature(
         "isclose", ["a", "b", "rel_tol", "abs_tol"], 2, 2, 0
     );

def:priv isclose_bound(args: BoundArguments) -> u64 {
    return jacpy_math_isclose(
        args.values[0], args.values[1], args.values[2], args.values[3]
    );
}

def:priv isclose_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(isclose_signature, args, kwargs, isclose_bound);
}

glob:priv nextafter_signature = CallSignature(
         "nextafter", ["x", "y", "steps"], 2, 2, 2
     );

def:priv nextafter_bound(args: BoundArguments) -> u64 {
    return jacpy_math_nextafter(args.values[0], args.values[1], args.values[2]);
}

def:priv nextafter_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(nextafter_signature, args, kwargs, nextafter_bound);
}

def:priv fsum_call(module: u64, value: u64) -> u64 {
    return jacpy_math_fsum(value);
}

def:priv hypot_call(module: u64, args: u64) -> u64 {
    return jacpy_math_hypot(args);
}

glob:priv dist_signature = CallSignature("dist", ["p", "q"], 2, 2, 2);
def:priv dist_bound(args: BoundArguments) -> u64 {
    return jacpy_math_dist(args.values[0], args.values[1]);
}

def:priv dist_call(module: u64, args: u64) -> u64 {
    return invoke(dist_signature, args, 0, dist_bound);
}

glob:priv sumprod_signature = CallSignature("sumprod", ["p", "q"], 2, 2, 2);
def:priv sumprod_bound(args: BoundArguments) -> u64 {
    return jacpy_math_sumprod(args.values[0], args.values[1]);
}

def:priv sumprod_call(module: u64, args: u64) -> u64 {
    return invoke(sumprod_signature, args, 0, sumprod_bound);
}

glob:priv prod_signature = CallSignature("prod", ["iterable", "start"], 1, 1, 1);
def:priv prod_bound(args: BoundArguments) -> u64 {
    return jacpy_math_prod(args.values[0], args.values[1]);
}

def:priv prod_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(prod_signature, args, kwargs, prod_bound);
}

def:priv execute(module: u64) -> i32 {
    names = ["pi", "e", "tau", "inf", "nan"];
    values = [
        3.14159265358979323846,
        2.71828182845904523536,
        6.28318530717958647692,
        float("inf"),
        float("nan")
    ];
    for i in range(len(names)) {
        if not add_owned(module, names[i], jacpy_float(values[i])) {
            return i32(-1);
        }
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "math",
         "Native Jac mathematics.",
         [
             MethodDefinition(
                 "factorial",
                 MethodCallbacks(positional=factorial_call),
                 "factorial($module, n, /)\n--\n\nReturn n factorial.",
                 flags=8
             ),
             MethodDefinition(
                 "isqrt",
                 MethodCallbacks(positional=isqrt_call),
                 "isqrt($module, n, /)\n--\n\nReturn the integer part of the square root of n.",
                 flags=8
             ),
             MethodDefinition(
                 "gcd",
                 MethodCallbacks(positional=gcd_call),
                 "gcd($module, *integers)\n--\n\nGreatest common divisor.",
                 flags=1
             ),
             MethodDefinition(
                 "lcm",
                 MethodCallbacks(positional=lcm_call),
                 "lcm($module, *integers)\n--\n\nLeast common multiple.",
                 flags=1
             ),
             MethodDefinition(
                 "comb",
                 MethodCallbacks(positional=comb_call),
                 "comb($module, n, k, /)\n--\n\nNumber of unordered selections without repetition.",
                 flags=1
             ),
             MethodDefinition(
                 "perm",
                 MethodCallbacks(positional=perm_call),
                 "perm($module, n, k=None, /)\n--\n\nNumber of ordered selections without repetition.",
                 flags=1
             ),
             MethodDefinition(
                 "acos",
                 MethodCallbacks(positional=acos_call),
                 "Return the arc cosine (measured in radians) of x.\n\nThe result is between 0 and pi.",
                 flags=8
             ),
             MethodDefinition(
                 "acosh",
                 MethodCallbacks(positional=acosh_call),
                 "Return the inverse hyperbolic cosine of x.",
                 flags=8
             ),
             MethodDefinition(
                 "asin",
                 MethodCallbacks(positional=asin_call),
                 "Return the arc sine (measured in radians) of x.\n\nThe result is between -pi/2 and pi/2.",
                 flags=8
             ),
             MethodDefinition(
                 "asinh",
                 MethodCallbacks(positional=asinh_call),
                 "Return the inverse hyperbolic sine of x.",
                 flags=8
             ),
             MethodDefinition(
                 "atan",
                 MethodCallbacks(positional=atan_call),
                 "Return the arc tangent (measured in radians) of x.\n\nThe result is between -pi/2 and pi/2.",
                 flags=8
             ),
             MethodDefinition(
                 "atanh",
                 MethodCallbacks(positional=atanh_call),
                 "Return the inverse hyperbolic tangent of x.",
                 flags=8
             ),
             MethodDefinition(
                 "cbrt",
                 MethodCallbacks(positional=cbrt_call),
                 "Return the cube root of x.",
                 flags=8
             ),
             MethodDefinition(
                 "cos",
                 MethodCallbacks(positional=cos_call),
                 "Return the cosine of x (measured in radians).",
                 flags=8
             ),
             MethodDefinition(
                 "cosh",
                 MethodCallbacks(positional=cosh_call),
                 "Return the hyperbolic cosine of x.",
                 flags=8
             ),
             MethodDefinition(
                 "erf",
                 MethodCallbacks(positional=erf_call),
                 "Error function at x.",
                 flags=8
             ),
             MethodDefinition(
                 "erfc",
                 MethodCallbacks(positional=erfc_call),
                 "Complementary error function at x.",
                 flags=8
             ),
             MethodDefinition(
                 "exp",
                 MethodCallbacks(positional=exp_call),
                 "Return e raised to the power of x.",
                 flags=8
             ),
             MethodDefinition(
                 "exp2",
                 MethodCallbacks(positional=exp2_call),
                 "Return 2 raised to the power of x.",
                 flags=8
             ),
             MethodDefinition(
                 "expm1",
                 MethodCallbacks(positional=expm1_call),
                 "Return exp(x)-1.\n\nThis function avoids the loss of precision involved in the direct evaluation of exp(x)-1 for small x.",
                 flags=8
             ),
             MethodDefinition(
                 "fabs",
                 MethodCallbacks(positional=fabs_call),
                 "Return the absolute value of the float x.",
                 flags=8
             ),
             MethodDefinition(
                 "gamma",
                 MethodCallbacks(positional=gamma_call),
                 "Gamma function at x.",
                 flags=8
             ),
             MethodDefinition(
                 "lgamma",
                 MethodCallbacks(positional=lgamma_call),
                 "Natural logarithm of absolute value of Gamma function at x.",
                 flags=8
             ),
             MethodDefinition(
                 "log1p",
                 MethodCallbacks(positional=log1p_call),
                 "Return the natural logarithm of 1+x (base e).\n\nThe result is computed in a way which is accurate for x near zero.",
                 flags=8
             ),
             MethodDefinition(
                 "sin",
                 MethodCallbacks(positional=sin_call),
                 "Return the sine of x (measured in radians).",
                 flags=8
             ),
             MethodDefinition(
                 "sinh",
                 MethodCallbacks(positional=sinh_call),
                 "Return the hyperbolic sine of x.",
                 flags=8
             ),
             MethodDefinition(
                 "sqrt",
                 MethodCallbacks(positional=sqrt_call),
                 "Return the square root of x.",
                 flags=8
             ),
             MethodDefinition(
                 "tan",
                 MethodCallbacks(positional=tan_call),
                 "Return the tangent of x (measured in radians).",
                 flags=8
             ),
             MethodDefinition(
                 "tanh",
                 MethodCallbacks(positional=tanh_call),
                 "Return the hyperbolic tangent of x.",
                 flags=8
             ),
             MethodDefinition(
                 "degrees",
                 MethodCallbacks(positional=degrees_call),
                 "Convert angle x from radians to degrees.",
                 flags=8
             ),
             MethodDefinition(
                 "radians",
                 MethodCallbacks(positional=radians_call),
                 "Convert angle x from degrees to radians.",
                 flags=8
             ),
             MethodDefinition(
                 "isfinite",
                 MethodCallbacks(positional=isfinite_call),
                 "Return True if x is neither an infinity nor a NaN, and False otherwise.",
                 flags=8
             ),
             MethodDefinition(
                 "isinf",
                 MethodCallbacks(positional=isinf_call),
                 "Return True if x is a positive or negative infinity, and False otherwise.",
                 flags=8
             ),
             MethodDefinition(
                 "isnan",
                 MethodCallbacks(positional=isnan_call),
                 "Return True if x is a NaN (not a number), and False otherwise.",
                 flags=8
             ),
             MethodDefinition(
                 "ceil",
                 MethodCallbacks(positional=ceil_call),
                 "Return the ceiling of x as an Integral.\n\nThis is the smallest integer >= x.",
                 flags=8
             ),
             MethodDefinition(
                 "floor",
                 MethodCallbacks(positional=floor_call),
                 "Return the floor of x as an Integral.\n\nThis is the largest integer <= x.",
                 flags=8
             ),
             MethodDefinition(
                 "trunc",
                 MethodCallbacks(positional=trunc_call),
                 "Truncates the Real x to the nearest Integral toward 0.\n\nUses the __trunc__ magic method.",
                 flags=8
             ),
             MethodDefinition(
                 "log10",
                 MethodCallbacks(positional=log10_call),
                 "Return the base 10 logarithm of x.",
                 flags=8
             ),
             MethodDefinition(
                 "log2",
                 MethodCallbacks(positional=log2_call),
                 "Return the base 2 logarithm of x.",
                 flags=8
             ),
             MethodDefinition(
                 "ulp",
                 MethodCallbacks(positional=ulp_call),
                 "Return the value of the least significant bit of the float x.",
                 flags=8
             ),
             MethodDefinition(
                 "atan2",
                 MethodCallbacks(positional=atan2_call),
                 "Return the arc tangent (measured in radians) of y/x.\n\nUnlike atan(y/x), the signs of both x and y are considered.",
                 flags=1
             ),
             MethodDefinition(
                 "copysign",
                 MethodCallbacks(positional=copysign_call),
                 "Return a float with the magnitude (absolute value) of x but the sign of y.\n\nOn platforms that support signed zeros, copysign(1.0, -0.0)\nreturns -1.0.\n",
                 flags=1
             ),
             MethodDefinition(
                 "fmod",
                 MethodCallbacks(positional=fmod_call),
                 "Return fmod(x, y), according to platform C.\n\nx % y may differ.",
                 flags=1
             ),
             MethodDefinition(
                 "remainder",
                 MethodCallbacks(positional=remainder_call),
                 "Difference between x and the closest integer multiple of y.\n\nReturn x - n*y where n*y is the closest integer multiple of y.\nIn the case where x is exactly halfway between two multiples of\ny, the nearest even value of n is used. The result is always exact.",
                 flags=1
             ),
             MethodDefinition(
                 "pow",
                 MethodCallbacks(positional=pow_call),
                 "Return x**y (x to the power of y).",
                 flags=1
             ),
             MethodDefinition(
                 "log",
                 MethodCallbacks(positional=log_call),
                 "log(x, [base=math.e])\nReturn the logarithm of x to the given base.\n\nIf the base is not specified, returns the natural logarithm (base e) of x.",
                 flags=1
             ),
             MethodDefinition(
                 "ldexp",
                 MethodCallbacks(positional=ldexp_call),
                 "Return x * (2**i).\n\nThis is essentially the inverse of frexp().",
                 flags=1
             ),
             MethodDefinition(
                 "fma",
                 MethodCallbacks(positional=fma_call),
                 "Fused multiply-add operation.\n\nCompute (x * y) + z with a single round.",
                 flags=1
             ),
             MethodDefinition(
                 "frexp",
                 MethodCallbacks(positional=frexp_call),
                 "Return the mantissa and exponent of x, as pair (m, e).\n\nIf x is a finite nonzero number, then m is a float with\n0.5 <= abs(m) < 1.0 and an integer e is such that\nx == m * 2**e exactly.  Else, return (x, 0).",
                 flags=8
             ),
             MethodDefinition(
                 "modf",
                 MethodCallbacks(positional=modf_call),
                 "Return the fractional and integer parts of x.\n\nBoth results carry the sign of x and are floats.",
                 flags=8
             ),
             MethodDefinition(
                 "isclose",
                 MethodCallbacks(keywords=isclose_call),
                 "Determine whether two floating-point numbers are close in value.\n\n  rel_tol\n    maximum difference for being considered \"close\", relative to the\n    magnitude of the input values\n  abs_tol\n    maximum difference for being considered \"close\", regardless of the\n    magnitude of the input values\n\nReturn True if a is close in value to b, and False otherwise.\n\nFor the values to be considered close, the difference between them\nmust be smaller than at least one of the tolerances.\n\n-inf, inf and NaN behave similarly to the IEEE 754 Standard.  That\nis, NaN is not close to anything, even itself.  inf and -inf are\nonly close to themselves."
             ),
             MethodDefinition(
                 "nextafter",
                 MethodCallbacks(keywords=nextafter_call),
                 "Return the floating-point value the given number of steps after x towards y.\n\nIf steps is not specified or is None, it defaults to 1.\n\nRaises a TypeError, if x or y is not a double, or if steps is not\nan integer.  Raises ValueError if steps is negative."
             ),
             MethodDefinition(
                 "fsum",
                 MethodCallbacks(positional=fsum_call),
                 "Return an accurate floating-point sum of values in the iterable seq.\n\nAssumes IEEE-754 floating-point arithmetic.",
                 flags=8
             ),
             MethodDefinition(
                 "hypot",
                 MethodCallbacks(positional=hypot_call),
                 "Multidimensional Euclidean distance from the origin to a point.\n\nRoughly equivalent to:\n    sqrt(sum(x**2 for x in coordinates))\n\nFor a two dimensional point (x, y), gives the hypotenuse\nusing the Pythagorean theorem:  sqrt(x*x + y*y).\n\nFor example, the hypotenuse of a 3/4/5 right triangle is:\n\n    >>> hypot(3.0, 4.0)\n    5.0",
                 flags=1
             ),
             MethodDefinition(
                 "dist",
                 MethodCallbacks(positional=dist_call),
                 "Return the Euclidean distance between two points p and q.\n\nThe points should be specified as sequences (or iterables) of\ncoordinates.  Both inputs must have the same dimension.\n\nRoughly equivalent to:\n    sqrt(sum((px - qx) ** 2.0 for px, qx in zip(p, q)))",
                 flags=1
             ),
             MethodDefinition(
                 "sumprod",
                 MethodCallbacks(positional=sumprod_call),
                 "Return the sum of products of values from two iterables p and q.\n\nRoughly equivalent to:\n\n    sum(map(operator.mul, p, q, strict=True))\n\nFor float and mixed int/float inputs, the intermediate products\nand sums are computed with extended precision.",
                 flags=1
             ),
             MethodDefinition(
                 "prod",
                 MethodCallbacks(keywords=prod_call),
                 "Calculate the product of all the elements in the input iterable.\n\nThe default start value for the product is 1.\n\nWhen the iterable is empty, return the start value.  This function is\nintended specifically for use with numeric values and may reject\nnon-numeric types."
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit_math -> u64 {
    return definition.initialize();
}
