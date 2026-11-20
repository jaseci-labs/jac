---
description: The native math and cmath modules, as CPython's, and where 64-bit ints and static types make them differ.
keywords: math, cmath, math.integer, math.fmax, math.fmin, math.signbit, math.isnormal, math.issubnormal, math.sqrt, math.floor, math.ceil, math.trunc, math.gcd, math.lcm, math.factorial, math.comb, math.perm, math.isqrt, math.fsum, math.prod, math.sumprod, math.hypot, math.dist, math.log, math.exp, math.isclose, math.pi, math.e, math.tau, math.inf, math.nan, cmath.sqrt, cmath.phase, cmath.polar, cmath.rect
---
# math and cmath

`math` holds the floating-point and integer functions of CPython's `math`, and `cmath` the
complex ones of CPython's `cmath`, with CPython's results, correctly rounded where CPython's are,
and its exceptions and messages. Both are native (see [The library](index.md),
`jac docs library`). In a kernel, `math` is the kernel's own: see
[Kernel math](../accel/kernel-math.md) (`jac docs kernel math`).

```jac
import math;
import cmath;

with entry {
    print(math.sqrt(2.0), math.floor(-2.5), math.ceil(2.1), math.trunc(-3.7));
    print(math.gcd(12, 18, 27), math.lcm(4, 6), math.comb(5, 2), math.perm(4), math.isqrt(17));
    print(math.fsum([0.1] * 10), math.prod([1.5, 2.0], start=2), math.hypot(3.0, 4.0));
    print(math.log(8.0, 2.0), math.isclose(0.1 + 0.2, 0.3), math.factorial(20));
    print(cmath.sqrt(complex(-1, 0)), cmath.polar(complex(0, 1)), abs(complex(3, 4)));
    try {
        math.sqrt(-1.0);
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
1.4142135623730951 -3 3 -3
3 12 10 24 4
1.0 6.0 5.0
3.0 True 2432902008176640000
1j (1.0, 1.5707963267948966) 5.0
ValueError: expected a nonnegative input, got -1.0
```

## What is there

**math:**

| Group | Names |
|---|---|
| Constants | `pi`, `e`, `tau`, `inf`, `nan` |
| To an int | `floor`, `ceil`, `trunc` (each returns an `int`; `floor(7)` is `7`) |
| Integers | `factorial`, `isqrt`, `gcd`, `lcm` (any number of arguments), `comb`, `perm` |
| Sums and products | `fsum`, `prod` (`start=`), `sumprod`, `hypot` (any number of coordinates), `dist` |
| Powers and logarithms | `sqrt`, `cbrt`, `exp`, `exp2`, `expm1`, `log` (`base` optional), `log2`, `log10`, `log1p`, `pow` |
| Trigonometry | `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sinh`, `cosh`, `tanh`, `asinh`, `acosh`, `atanh`, `degrees`, `radians` |
| Special | `erf`, `erfc`, `gamma`, `lgamma` |
| Floating point | `fabs`, `copysign`, `fmod`, `remainder`, `fma`, `frexp`, `ldexp`, `modf`, `nextafter` (`steps=`), `ulp`, `isclose`, `isfinite`, `isinf`, `isnan`, and Python 3.15's `fmax`, `fmin`, `signbit`, `isnormal`, `issubnormal` |

`fsum([0.1] * 10)` is exactly `1.0`. Functions that take `float` accept an `int` argument.

**math.integer**, Python 3.15's module of the integer functions: `factorial`, `isqrt`, `gcd`,
`lcm`, `comb`, `perm`.

**cmath:** `pi`, `e`, `tau`, `inf`, `nan`, `infj`, `nanj`, `sqrt`, `exp`, `log`, `log10`,
`phase`, `polar`, `rect`, the trigonometric and hyperbolic functions and their inverses,
`isclose`, `isfinite`, `isinf`, `isnan`.

`complex` itself is a builtin type: see [Numbers](number-methods.md) (`jac docs complex
methods`). Jac has no imaginary literal (`1j`): write `complex(0, 1)`.

## Errors

As CPython's: a domain error is `ValueError` (`math.log(0.0)` raises `expected a positive input,
got 0.0`), a result too large is `OverflowError` (`math.exp(1000.0)` raises `math range error`),
and `factorial(-1)` raises `ValueError: factorial() not defined for negative values`.

## Differences from CPython

- **Integers are 64-bit.** An integer result past the range raises `OverflowError`:
  `math.factorial(25)` raises `OverflowError: factorial() result too large`, as do `comb`, `perm`
  and `lcm` past it. CPython returns a larger int.
- **`cmath`'s functions take an int or a float too**, converted to `complex` as in CPython:
  `cmath.sqrt(-1.0)` is `1j`.
