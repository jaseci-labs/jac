---
description: The math module's functions inside a kernel - which ones a kernel computes, their f32 forms, how they follow IEEE instead of raising, and how their results compare with ordinary code's.
keywords: kernel math, f32 math, math in a kernel
---
# A kernel's math

A [kernel](kernels.md) calls `math`'s functions, and computes them itself: no
library is there to call on a device. Each one gives the same bits on the
processor and on an accelerator.

```jac
import math;
import from accel { tensor, kernel }

def soft(i: int, x: tensor[f32, _], y: tensor[f32, _]) {
    y[i] = math.tanh(x[i]) * math.exp(-x[i]);
}

with entry {
    x = tensor[f32, _]([0.5, 1.0]);
    y = tensor[f32, _](shape=2);
    kernel(soft).run(2, x, y);
    print(y.tolist());
}
```

```output
[0.2802882194519043, 0.2801748514175415]
```

Here `x[i]` is an `f32`, so `tanh` and `exp` are computed in binary32 all
through.

## The functions

| Functions | How a kernel computes them |
|---|---|
| `sqrt`, `fabs`, `copysign`, `fma`, and `floor`, `ceil`, `trunc` (each giving an int, as Python's do) | as an instruction, which every device has |
| `exp`, `expm1`, `log` (of one argument), `log1p`, `log2`, `log10`, `pow`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sinh`, `cosh`, `tanh`, `hypot` (of two arguments) | by the runtime's own code, compiled into the kernel |

The second group is ports of musl's libm. Because the same code is compiled for
every device, the processor and an accelerator give the same bits for them. The
code never fuses a multiply and an add on its own.

Any other function of `math` is not a kernel's:

- `math.log(x, base)` is not built yet (`E5090`),
- a function that is the runtime's code needing what a device lacks is refused
  for that need (`E1540`): `math.gamma` reads a table that can change.

## f32 forms

In a kernel these names are generic over the float type. Of a `float` argument
a function is computed in binary64. Of an `f32` it is computed in binary32, by
musl's single-precision routine (some of which use a double inside, as
musl's do).

| Has an `f32` form | No `f32` form (`E1431`) |
|---|---|
| the instructions: `sqrt`, `fabs`, `copysign`, `fma`, `floor`, `ceil`, `trunc` | |
| `exp`, `expm1`, `log`, `pow`, `sin`, `cos`, `tanh` | `log1p`, `log2`, `log10`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sinh`, `cosh`, `hypot` |

Where a function has no `f32` form, convert: `f32(math.tan(float(x)))`. The two
float types do not mix in one call: `math.pow(x, d)` of an `f32` and a `float`
is `E1128`.

```jac
# expect: E1431, E1128, E5090, E1540
import math;
import from accel { tensor, kernel }

def narrow(i: int, out: tensor[f32, _], d: float, wide: tensor[float, _]) {
    out[i] = math.log1p(out[i]);
    out[i] = math.pow(out[i], d);
    wide[i] = math.log(wide[i], 2.0);
    wide[i] = math.gamma(wide[i]);
}

with entry {
    kernel(narrow).run(2, tensor[f32, _](shape=2), 1.5, tensor[float, _](shape=2));
}
```

```text
main.jac:6:14: error[E1431]: math.log1p() has no form for f32: math's functions take floats, and f32s where they have an f32 form (float(x) converts)
main.jac:7:31: error[E1128]: 'math.pow()' mixes f32 and float; convert one side
main.jac:8:15: error[E5090]: jac does not support a kernel calling math.log() of these arguments yet
main.jac:9:15: error[E1540]: gamma() needs module state that can change, which a kernel run for each index does not provide (in narrow)
```

## IEEE results, not exceptions

A kernel's math follows IEEE where ordinary code's raises. `math.log(-1.0)` is a
NaN and `math.log(0.0)` is -inf, and no fault is recorded. In ordinary code the
same calls raise `ValueError`.

```jac
import math;
import from accel { tensor, kernel }

def logs(i: int, x: tensor[float, _], y: tensor[float, _]) {
    y[i] = math.log(x[i]);
}

with entry {
    x = tensor[float, _]([-1.0, 0.0, 1.0]);
    y = tensor[float, _](shape=3);
    kernel(logs).run(3, x, y);
    print(y.tolist());
    try {
        print(math.log(x[0]));
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
[nan, -inf, 0.0]
ValueError: expected a positive input, got -1.0
```

## Compared with ordinary code

Of a `float`, ordinary code's `math.exp` and the rest call the platform's
library. A kernel computes its own. So for one input a kernel's result may
differ from ordinary code's in the last place.

Of an `f32`, the functions are generic over floats everywhere, not only in a
kernel. Ordinary code's `math.exp(x)` of an `f32` is an `f32`, computed by the
same routine (or instruction) a kernel uses, so the two agree bit for bit:

```jac
import math;
import from accel { tensor, kernel }

def curve(i: int, x: tensor[f32, _], y: tensor[f32, _]) {
    y[i] = math.exp(x[i]) + math.sin(x[i]);
}

with entry {
    x = tensor[f32, _]([1.5, 0.25]);
    y = tensor[f32, _](shape=2);
    kernel(curve).run(2, x, y);
    v = f32(1.5);
    host = math.exp(v) + math.sin(v);
    print(host, y[0] == host);
}
```

```output
5.479184 True
```

A function with no `f32` form is refused of an `f32` in ordinary code too
(`E1431`).

## Accuracy

Over a million random arguments each, every result is within 1 ulp of the exact
value, and `exp`, `log`, `log2` and `pow` are within 0.55. The exceptions are
musl's own `tanh`, `sinh` and `atan2`, and the `f32` `tanh`, which reach 2.08,
1.77, 1.44 and 2.01 ulps.

## In vectors

A float vector's math methods (`v.exp()`, `v.log()`, `v.atan2(w)` and the rest)
compute each lane by the routine above for the lane's type, so each lane is bit
for bit what the scalar call gives in a kernel. They have the same `f32` forms
and follow IEEE the same way. See
[Vector methods](vector-methods.md).
