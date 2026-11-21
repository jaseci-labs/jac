---
description: Views of a tensor - slices, transpose, reshape, ravel, split, blocks and zipped - which share the tensor's memory, and the layouts (strides, row-major, column-major, contiguous) behind them.
keywords: tensor view, transpose, reshape, ravel, split, blocks, zipped, strides, is_contiguous, contiguous, tensor layout, column-major
---
# Views and layouts

A view is a tensor that shares another tensor's memory under another shape. It
is made with no copy, where the tensor lives, and a store through it is seen in
the tensor, from ordinary code and from a [kernel](kernels.md) alike. The
operations have NumPy's names and meanings.

```jac
import from accel { tensor }

with entry {
    m = tensor[i32, 4, 6]([[r * 10 + c for c in range(6)] for r in range(4)]);
    s = m[1:4:2, ::-2];
    print(s.shape, s.tolist());
    print(m[..., 3].tolist(), m[2].tolist());
    t = m.transpose();
    print(t.shape, t[5, 3]);
    s[0, 0] = -1;
    t[0, 3] = -2;
    print(m[1, 5], m[3, 0]);
}
```

```output
(2, 3) [15, 13, 11, 35, 33, 31]
[3, 13, 23, 33] [20, 21, 22, 23, 24, 25]
(6, 4) 35
-1 -2
```

## How a view works: strides

A tensor's item `(i0, i1, ...)` is at its address plus
`i0 * s0 + i1 * s1 + ...` elements, where `t.strides` is `(s0, s1, ...)`. A view
is another shape and other strides over the same memory. `t.strides` counts
elements, not bytes: it is what a kernel indexes by.

```jac
import from accel { tensor }

with entry {
    m = tensor[i32, 4, 6]([[r * 10 + c for c in range(6)] for r in range(4)]);
    print(m.strides, m.is_contiguous);
    print(m[1:4:2, ::-2].strides, m[1:4:2, ::-2].is_contiguous);
    print(m.transpose().strides, m.blocks(2, 3).strides);
}
```

```output
(6, 1) True
(12, -2) False
(1, 6) (12, 3, 6, 1)
```

## The operations

| Operation | Gives |
|---|---|
| `m[1:4:2, ::-2]` | the items the subscript names. Of a `tensor[i32, 4, 6]`: a `tensor[i32, 2, 3]`, rows 1 and 3, columns 5, 3, 1 |
| `m[..., 3]` | a `tensor[i32, 4]`: column 3 |
| `m[2]` | a `tensor[i32, 6]`: row 2 |
| `m.transpose()` | the dimensions reversed: a `tensor[i32, 6, 4]` with strides `(1, 6)` |
| `m.transpose(1, 0)` | dimension `k` of the view is dimension `axes[k]` of `m`. Here the same as `m.transpose()` |
| `m.reshape(3, -1)` | the same items in another shape, row-major: a `tensor[i32, 3, 8]`. One dimension may be -1, for what the rest leave |
| `m.ravel()` | the items as one dimension: `m.reshape(-1)` |
| `m.split(2, axis=1)` | a list of `n` views of equal parts of a dimension, in order: two `tensor[i32, 4, 3]`, columns 0 to 2 and 3 to 5. `axis` is 0 unless given |
| `m.blocks(2, 3)` | the tensor in blocks of that shape: a view of twice the dimensions, `tensor[i32, 2, 2, 2, 3]`, where `b[i, j]` is the 2 by 3 block at row `i` and column `j` of blocks |
| `zipped(a, b, 2, 3)` | a list of pairs: the corresponding blocks of `a` and `b` (each `t.blocks(2, 3)`), in row-major order of the blocks' places |

`zipped` is a function imported from `accel`; the rest are a tensor's own.

```jac
import from accel { tensor, zipped }

with entry {
    m = tensor[i32, 4, 6]([[r * 10 + c for c in range(6)] for r in range(4)]);
    r = m.reshape(3, -1);
    print(r.shape, r[2].tolist(), m.ravel()[13]);
    halves = m.split(2, axis=1);
    print(len(halves), halves[1].shape, halves[1][0].tolist());
    b = m.blocks(2, 3);
    print(b.shape, b[1, 1].tolist());
    sums: list[int] = [];
    for (x, y) in zipped(m, m.copy(), 2, 3) {
        sums.append(x[0, 0] + y[1, 2]);
    }
    print(sums);
}
```

```output
(3, 8) [24, 25, 30, 31, 32, 33, 34, 35] 21
2 (4, 3) [3, 4, 5]
(2, 2, 2, 3) [23, 24, 25, 33, 34, 35]
[12, 18, 52, 58]
```

## Subscripts

A subscript takes ints and slices in any mix.

- An int takes one item of its dimension and drops the dimension. It is checked
  (`IndexError`) and is never negative.
- A slice takes the items it names, as a dimension of their count. Its bounds
  are Python's, negative ones counted from the end, and its step is any but 0:
  a negative step runs backward. A step of 0 is `E1451`, or `ValueError` where
  it is known only as the program runs.
- `...` may appear once. It stands for the full slices that make the subscript
  one item for each dimension.
- The dimensions after the subscript's last item are all taken: `m[2]` is
  `m[2, :]`.

A subscript of as many ints as dimensions is an item, not a view (see
[Tensors](tensors.md)).

## What the type of a view says

A view's type keeps the element type and states each dimension the compiler can
know:

- a slice with known bounds and step, of a known dimension,
- a transpose's dimensions, in its order,
- a reshape's sizes and a block's sizes.

Every other dimension is `_`. So the views above can be declared with their
shapes, and a wrong one is a type error:

```jac
# expect: E1001
import from accel { tensor }

with entry {
    m = tensor[i32, 4, 6]();
    s: tensor[i32, 2, 3] = m[1:4:2, ::-2];
    b: tensor[i32, 2, 2, 2, 3] = m.blocks(2, 3);
    wrong: tensor[i32, 4, 6] = m.transpose();
}
```

```text
main.jac:8:32: error[E1001]: expected tensor[i32, 4, 6], found tensor[i32, 6, 4]
```

## Layouts

A tensor made from data or a shape is contiguous: its items are next to each
other in memory. It is row-major, unless `order="F"` makes it column-major. With
`order="F"` the data is still given row by row; only the memory is laid out by
columns.

`t.is_contiguous` says whether a tensor's items are row-major and next to each
other. It is NumPy's `C_CONTIGUOUS`: a dimension of size 1 may have any stride,
and a tensor of no items is contiguous.

Every operation honors the strides, on the processor and on an accelerator:
`t.tolist()`, printing, `t.fill(v)`, item reads and stores.

| Operation | Gives |
|---|---|
| `t.copy()` | a contiguous row-major copy of `t`'s items alone, where `t` lives |
| `t.to(dev)` | the same, on `dev` |
| `t.contiguous()` | `t` itself when it is contiguous, else its copy |

```jac
import from accel { tensor }

with entry {
    f = tensor[f32, 2, 3]([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], order="F");
    print(f.strides, f.is_contiguous, f.tolist());
    print(f.transpose().is_contiguous, f.reshape(3, 2, order="F").tolist());
    m = tensor[i32, 2, 3]([[1, 2, 3], [4, 5, 6]]);
    t = m.transpose();
    c = t.copy();
    print(c.strides, c.is_contiguous, m.contiguous() is m, t.contiguous() is t);
    m[::2, ::2].fill(0);
    print(m.tolist());
}
```

```output
(1, 2) False [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
True [1.0, 5.0, 4.0, 3.0, 2.0, 6.0]
(2, 1) True True False
[0, 2, 0, 4, 5, 6]
```

## What is checked, and when

The compiler checks what it knows; what is known only as the program runs
raises `ValueError` then.

| Rule | Compile time | Run time |
|---|---|---|
| a subscript has no more items than dimensions, and one `...` at most | `E1235` | |
| an index is an int | `E1053` | |
| a slice's step is not 0 | `E1451` | `ValueError` |
| the axes of `transpose` and `split` are compile-time ints | `E0033` | |
| an axis is in range (from minus the rank to the rank less one) | `E1446` | |
| a transpose names each axis once | `E1447` | |
| a transpose names all the axes or none | `E1235` | |
| a reshape has one -1 at most | `E1449` | |
| a reshape keeps the count of items | `E1448` | `ValueError` |
| `split`'s parts, and the extents of `blocks` and `zipped`, divide what they part | `E1450` | `ValueError` |
| `blocks` and `zipped` take an extent for each dimension | `E1235` | |
| a reshape is of a tensor contiguous in its order | | `ValueError` |
| `zipped`'s two tensors have the same places | | `ValueError` |

```jac
# expect: E1235, E1451, E0033, E1446, E1447, E1448, E1449, E1450
import from accel { tensor }

with entry {
    m = tensor[f32, 2, 3](fill=1.0);
    n = 1;
    print(m[0:1, 0, 0]);
    print(m[::0]);
    print(m.transpose(n, 0));
    print(m.transpose(0, 2));
    print(m.transpose(1, 1));
    print(m.reshape(4, 2));
    print(m.reshape(-1, -1));
    print(m.split(4));
}
```

The same rules, where the compiler cannot know:

```jac
import from accel { tensor }

with entry {
    m = tensor[i32, _, _](shape=(4, 6));
    n = len(m);
    try {
        m.reshape(n, 5);
    } except ValueError as e {
        print("ValueError:", e);
    }
    try {
        m.split(n + 1);
    } except ValueError as e {
        print("ValueError:", e);
    }
    try {
        m.transpose().reshape(-1);
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
ValueError: cannot reshape a tensor of 24 elements into shape (4, 5)
ValueError: split: dimension 0 of 4 does not divide by 5
ValueError: a reshape of a tensor that is not contiguous would copy its elements: t.contiguous().reshape(...) makes the copy
```

A view's layout is made by these operations alone. The constructor takes no
argument for it: `tensor[f32, 6](of=m)` is `E1052`. A tensor's elements in
another shape are its `reshape`.

## Views in a kernel

A kernel takes a tensor of any layout, and makes views of the tensors it holds:
a subscript with slices, `transpose`, `blocks`, `reshape` and `ravel`, bound to
a local or used in place. `reshape` and `ravel` are of a contiguous tensor, in
row-major order; a view a kernel cannot make is recorded as a fault and raises
`ValueError` when the launch is done. `split` and `zipped` make lists, which a
device has no heap for: they are ordinary code's (`E1540`).

```jac
import from accel { tensor, kernel }

def turned(i: int, m: tensor[f32, _, _], out: tensor[f32, _, _]) {
    t = m.transpose();
    row = out[i];
    back = m[i, ::-1];
    for j in range(len(row)) {
        row[j] = t[j, i] * 10.0 + back[j];
    }
}

with entry {
    m = tensor[f32, 3, 3]([[float(r * 10 + c) for c in range(3)] for r in range(3)]);
    out = tensor[f32, 3, 3]();
    kernel(turned).run(3, m, out);
    print(out.tolist());
    kernel(turned).run(3, m.transpose(), out[::-1]);
    print(out.tolist());
}
```

```output
[2.0, 11.0, 20.0, 112.0, 121.0, 130.0, 222.0, 231.0, 240.0]
[42.0, 132.0, 222.0, 31.0, 121.0, 211.0, 20.0, 110.0, 200.0]
```

Every kernel is compiled twice: once for tensors of any strides, which it takes
with their dimensions, and once for contiguous tensors, whose strides it
computes from their dimensions. The second is the code a kernel written for
contiguous tensors alone would be, and a launch runs it when every tensor it is
given is contiguous. The first launch above runs the contiguous form, the
second the other; nothing in the program chooses.

A kernel's vector loads and stores (`t.vector(i, N)`, `t.store(i, v)`, the
masked and compressed forms; see [Tensor elements as vectors](vector-memory.md))
are one access where the items of the last dimension are next to each other,
and each lane's own element where they are not.

## Differences from NumPy

Where jac differs from NumPy, it is so that a view never copies.

- **`reshape` and `ravel` never copy.** Of a tensor that is not contiguous in
  the order asked for, NumPy's `reshape` copies; here it raises `ValueError`. A
  view that sometimes copies hides a cost and stops writing through.
  `t.contiguous().reshape(...)` makes the copy when it is wanted.
  `reshape(..., order="F")` reads column-major, and needs a column-major
  tensor.
- **`split(n)` is `np.split(t, n)`** as a method: `n` is the number of parts.
  It is not PyTorch's `split`, whose argument is a part's size.
- **`blocks` is a tiling**, as Mojo's `tile` is. It is not NumPy's `tile`,
  which repeats data.
- **`t.strides` counts elements**, not bytes.
- **An index is never negative** (`IndexError`), as everywhere in a tensor. A
  slice's bounds may be.
- **There is no `t.T`.** Jac has no properties to make one; `t.transpose()` is
  it.
