---
description: The small float storage formats f8e4m3fn, f8e5m2 and f4e2m1fn, which are elements of tensors and C memory only, read as f32 and stored by a conversion named for the format.
keywords: f8e4m3fn, f8e5m2, f4e2m1fn, float8, FP8, FP4, storage format
---
# Small float formats

`f8e4m3fn`, `f8e5m2` and `f4e2m1fn` are the small float formats of ML
quantization. They are storage formats, not number types: a value of one
exists only as an element of a [tensor](../accel/tensors.md) or of C memory,
and a program computes with the `f32` an element reads as.

| Format | Also known as | Largest finite value | Infinity | NaN |
|---|---|---|---|---|
| `f8e4m3fn` | ml_dtypes' and ONNX's `float8_e4m3fn`, an OCP FP8 format | 448 | no | yes |
| `f8e5m2` | ml_dtypes' and ONNX's `float8_e5m2`, an OCP FP8 format | 57344 | yes | yes |
| `f4e2m1fn` | ml_dtypes' and ONNX's `float4_e2m1fn`, MX FP4 | 6 | no | no |

Each element takes one byte.

## Reading and storing

- **The type is written only as an element type**: `tensor[f8e4m3fn, n]`,
  `ptr[f8e5m2]`. Any other use (a local, a field, a `list`, a vector's
  lanes) is an error (E1475).
- **An element reads as the `f32` equal to it.** `q[0] * 2.0` is `f32`
  arithmetic.
- **An element is stored by the conversion named for its format**:
  `q[1] = f8e4m3fn(x)`. Storing a float directly, another element, or
  another format's conversion is an error (E1477).
- **The conversion's value is stored and used no other way** (E1476): it
  is not bound to a local, passed, printed or computed with. The formats
  have no arithmetic of their own.

```jac
import from accel { tensor }

with entry {
    q = tensor[f8e4m3fn, _]([0.1, 3.3, 500.0]);
    print(q.tolist());
    y = q[0] * 2.0;
    print(y, type(y));
    q[1] = f8e4m3fn(y + q[1]);
    print(q);
}
```

```output
[0.1015625, 3.25, 448.0]
0.203125 <class 'f32'>
tensor([0.1015625, 3.5, 448.0], shape=(3,))
```

Building the tensor converted each number: 0.1 to 0.1015625, 3.3 to 3.25,
and 500.0 to the format's largest value. `y + q[1]` is 3.453125, stored as
the nearest value the format has, 3.5. `t.tolist()` and printing give the
floats the elements are.

## How the conversion rounds

The conversion takes any number and rounds once, to nearest even.

| Input | `f8e4m3fn` | `f8e5m2` | `f4e2m1fn` |
|---|---|---|---|
| Past the largest finite value | saturates at ±448 | ±infinity | saturates at ±6 |
| An infinity | ±448 | ±infinity | ±6 |
| A NaN | the format's NaN | the format's NaN | raises `ValueError` |

The saturation is what ONNX's saturating cast and the accelerators'
conversions do. In a [kernel](../accel/kernels.md), a NaN converted to
`f4e2m1fn` is recorded and raised as `ValueError` when the kernel is done.

```jac
import from accel { tensor }

with entry {
    e = tensor[f8e5m2, _]([0.1, 57344.0, 61440.0, -1e9]);
    print(e.tolist());
    w = tensor[f4e2m1fn, _]([0.1, 0.75, 3.3, 7.0, float("inf"), 0.25 + 2.0 ** -40]);
    print(w.tolist());
    n = tensor[f8e4m3fn, _]([float("inf"), float("nan")]);
    print(n.tolist());
    try {
        w[0] = f4e2m1fn(float("nan"));
    } except ValueError as err {
        print("no NaN:", err);
    }
}
```

```output
[0.09375, 57344.0, inf, -inf]
[0.0, 1.0, 3.0, 6.0, 6.0, 0.5]
[448.0, nan]
no NaN: cannot convert float NaN to f4e2m1fn
```

The conversions are the runtime's own, in integer arithmetic, and a kernel
runs the same code, so a format's bits are the same on every device.

ml_dtypes rounds a float64 to float32 before rounding to the format, and so
differs where that first rounding makes a tie: `0.25 + 2**-40` is 0.5 as an
`f4e2m1fn` here and 0.0 there.

## Where they are available

The formats are native code's. A cpython or JavaScript space has none of
them (E1540).

## What is rejected

```jac
# expect: E1475 x2, E1476 x2, E1477 x3, E1001
import from accel { tensor }

with entry {
    xs: list[f8e5m2] = [];
    w: f4e2m1fn = 0.5;
    t = tensor[f8e4m3fn, _]([0.5, 1.0, 3.0]);
    q = f8e4m3fn(0.5);
    t[0] = f8e4m3fn(0.5) * 2.0;
    t[0] = 0.5;
    t[1] = t[0];
    t[2] = f8e5m2(0.5);
    y: float = t[0];
}
```

| Code | Meaning |
|---|---|
| E1475 | A format is used as the type of something other than a tensor's or a `ptr`'s element. |
| E1476 | A conversion's value is used other than by storing it as an element. |
| E1477 | An element is given something other than its own format's conversion. |
| E1001 | An element, which reads as an `f32`, is given where a `float` is wanted. Write `float(t[0])`. |
| E1540 | A format is used in a space whose host does not have it. |
