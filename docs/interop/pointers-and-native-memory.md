---
description: ptr[T], a pointer into C memory - indexing, arithmetic, bounds-checked views, pin and Pinned for addresses C keeps, addressof, and load, store and vector for packed, aligned, volatile and streaming accesses.
keywords: ptr, ptr[T], pointer, null pointer, is_null, PtrView, pin, Pinned, addressof, C plain data, native memory, volatile, nontemporal, unaligned access
---
# Pointers and native memory

`ptr[T]` is a pointer into memory that C laid out: what a C function returns, what `malloc`
gives, a field of a C record, a device's registers. It is the type C's `T *` has in a
[C library](c-libraries.md) declaration, and `ptr` alone is C's `void *`.

A pointer is an address and nothing more. It does not own what it points to, the collector does
not follow it, and indexing it is unchecked, as in C. Memory a C function allocated is freed by
the C function that frees it.

```jac
import from c {
    def calloc(n: int, size: int) -> ptr[u8];
    def free(p: ptr[u8]) -> None;
}

with entry {
    raw = calloc(64, 1);
    nums = ptr[i32](raw);
    nums[0] = 10;
    nums[1] = 20;
    nums[2] = nums[0] + nums[1];
    print(nums[2], raw[0], raw[4]);
    q = nums + 2;
    print(q[0], q[-1], q - nums, q == nums + 2);
    print(nums.is_null(), ptr[i32]().is_null(), int(nums) == int(raw));
    free(raw);
}
```

```output
30 10 20
30 20 2 True
False True True
```

## What a pointer does

`T`, the item, is C plain data: a number of any sized type, a `bool`, another pointer, a C
record, or a plain [struct](../language/structs.md) (one holding no reference). A pointer to
anything else is refused where it is indexed (E1152).

| Expression | Meaning |
|---|---|
| `ptr[T](x)` | `x` as a `ptr[T]`: `x` is an `int` address, another pointer (a cast), or a `str` (the address of its UTF-8 bytes, for as long as the program holds the str) |
| `ptr[T]()`, `ptr()` | The null pointer |
| `p[i]` | The `T` at `p + i`. `i` may be negative. Unchecked |
| `p[i] = v`, `p[i] += v` | Writes the `T` at `p + i`. The index is evaluated once |
| `p + n`, `p - n` | The pointer `n` items on: the address moves by `n` times the size of `T` |
| `p - q` | How many items apart two pointers of one type are, an `int` |
| `p == q`, `p != q`, `p < q`, `p <= q`, `p > q`, `p >= q` | Comparison of the addresses |
| `p.is_null()` | Whether the address is zero |
| `int(p)` | The address |
| `p.view(n)` | A bounds-checked view of the first `n` items (below) |
| `p.load(i, ...)`, `p.store(i, v, ...)`, `p.vector(i, N)` | An access that says more than `p[i]` (below) |

A value of type `ptr[T]` fits where a bare `ptr` is wanted. A bare `ptr` has no item type, so it
is not indexed or viewed (E1040, E1191, E1199): cast it first, `ptr[u8](p)`.

Reading through a null, freed or out-of-range pointer is undefined, as in C. Nothing checks it.

### Records in place

Where `T` is a C record or a plain struct, `p[i]` is the record there, in place: `p[i].x = 1.0`
writes C's memory. Reading `p[i]` into a variable copies the record; `p[i] = r` copies `r` in.

```jac
import from c {
    obj Pair {
        has a: i32,
            b: f32;
    }

    def calloc(n: int, size: int) -> ptr[Pair];
    def free(p: ptr[Pair]) -> None;
}

with entry {
    pairs = calloc(2, 8);
    pairs[1].a = 9;
    pairs[1].b = 2.5;
    kept = pairs[1];
    pairs[1].a = 10;
    pairs[0] = pairs[1];
    print(kept.a, pairs[1].a, pairs[0].a, pairs.view(2)[0].b);
    free(pairs);
}
```

```output
9 10 10 2.5
```

## Views

`p.view(n)` is the `n` items at `p` with their length known: `v[i]` and `v[i] = x` are
bounds-checked (`IndexError`), a negative index counts from the end, and `len(v)` is `n`. The
view reads and writes the same memory the pointer does; it copies nothing.

```jac
import from c {
    def calloc(n: int, size: int) -> ptr[f32];
    def free(p: ptr[f32]) -> None;
}

def total(p: ptr[f32], n: int) -> float {
    v = p.view(n);
    acc = 0.0;
    for i in range(len(v)) {
        acc += float(v[i]);
    }
    return acc;
}

with entry {
    p = calloc(4, 4);
    v = p.view(4);
    v[0] = 1.5;
    v[-1] = 2.5;
    print(len(v), p[3], total(p, 4));
    try {
        print(v[4]);
    } except IndexError as e {
        print("IndexError:", e);
    }
    print(bytes(ptr[u8](p).view(4)));
    free(p);
}
```

```output
4 2.5 4.0
IndexError: PtrView index out of range
b'\x00\x00\xc0?'
```

- `bytes(v)` and `bytearray(v)` copy a view of `u8` out of C memory.
- A view is indexed, not iterated: loop over `range(len(v))`.
- A negative length is a `ValueError`, and so is a view of one or more items of a null pointer.
  `ptr[T]().view(0)` is an empty view.
- A view held in a local variable that its function only indexes and measures (`v[i]`,
  `v[i] = x`, `len(v)`) is kept as its pointer and length and allocates nothing. A view passed
  on, returned or stored is an object.

## Addresses C keeps: `pin`

A `&x` or `&mut x` argument lends C the address of a variable for one call. Where C keeps the
address after the call returns (a callback's context, a buffer a library fills later), the
storage must stay where it is. `pin(x)` makes that storage: a cell holding `x` at a stable
address, of type `Pinned[T]`. `T` is C plain data (E1152).

```jac
import from c {
    def time(t: &mut Pinned[int]) -> int;
}

obj Clock {
    has cell: Pinned[int];
}

with entry {
    cell = pin(5);
    print(cell.value);
    cell.value = 9;
    c = Clock(cell=cell);
    now = time(&mut c.cell);
    print(cell.value == now, c.cell.value == now);
}
```

```output
5
True True
```

- `cell.value` reads and assigns what the cell holds.
- A `Pinned[T]` is a reference: `c.cell` and `cell` above are one cell.
- A C declaration takes a pinned cell's address with a `&Pinned[T]` or `&mut Pinned[T]`
  parameter, and the call site passes `&cell` or `&mut cell`.
- The cell lives as long as the program holds it. Keep it in a field or a global for as long as C
  uses the address.

## `addressof`

`addressof(x)` is the address of a C global or of a C record value, as a `ptr[T]`. For a C array
defined in an import block it points at the first element. It takes nothing else (E1154).
[C libraries](c-libraries.md) shows it with a global.

## Accesses that say more: `load`, `store`, `vector`

`p.load(i, ...)` and `p.store(i, v, ...)` reach the `T` at `p + i` as `p[i]` does, and state more
about the access in keywords, each known at compile time.

| Keyword | Meaning |
|---|---|
| `align=n` | The address is a multiple of `n`, a power of two up to 2**32. `p[i]` assumes `T`'s natural alignment. `align=1` reads and writes packed data at any byte. A larger value promises more, which the optimizer may use for wider moves; an address that is not so aligned is undefined, as in C |
| `volatile=True` | The access is performed exactly as written, in order with the other volatile accesses: for memory-mapped I/O |
| `nontemporal=True` | `store` only: the store streams past the caches, for data the program will not read again soon |

`T` is a number, a bool or a pointer; a C record or a struct is reached through `p[i]` (E1467).
A `load` or `store` with none of the keywords is `p[i]`, and is refused in its favor (E1466).

`p.vector(i, N)` reads the `N` items from `p + i` as a `simd[T, N]`, and `p.store(i, v)` of a
vector `v` writes its lanes there. They are what a tensor's `t.vector` and `t.store` are, but
unchecked, as `p[i]` is. Each is one access of the whole vector, aligned as one `T` is (so a
`ptr[u8]`'s vector may be at any byte) unless `align=` says more, and takes the same keywords.
`T` is a vector's lane type, an int or float type (E1410), and `N` a power of two from 2 to 64
(E1411). Vectors are described in the accelerated-computing pages: `jac docs simd`.

```jac
import from c {
    def calloc(n: int, size: int) -> ptr[u8];
    def aligned_alloc(align: int, size: int) -> ptr[u8];
    def free(p: ptr[u8]) -> None;
}

with entry {
    # Packed data: a u16 and a u32 at odd bytes.
    pk = calloc(16, 1);
    ptr[u16](pk + 1).store(0, u16(0x1234), align=1);
    ptr[u32](pk + 3).store(0, u32(0x12345678), align=1);
    print(ptr[u16](pk + 1).load(0, align=1), ptr[u32](pk + 3).load(0, align=1), pk[1], pk[2]);
    # Vectors: four bytes at an odd address, and two u32s.
    for k in range(16) {
        pk[k] = u8(k);
    }
    print(pk.vector(3, 4), ptr[u32](pk + 1).vector(0, 2));
    pk.store(0, pk.vector(8, 4));
    print(pk[0], pk[3]);
    free(pk);
    # Over-aligned memory, a streaming store and a volatile access.
    al = aligned_alloc(64, 128);
    d = ptr[f64](al);
    d.store(0, 0.25, align=64, nontemporal=True);
    reg = ptr[u32](al + 64);
    reg.store(0, u32(1), volatile=True);
    print(d.load(0, align=64), reg.load(0, volatile=True));
    free(al);
}
```

```output
4660 305419896 52 18
[3, 4, 5, 6] [67305985, 134678021]
8 11
0.25 1
```

Typical uses:

| Access | For |
|---|---|
| `ptr[u32](frame + 3).load(0, align=1)` | A `u32` at an odd byte of a packet |
| `out.store(i, v, align=64, nontemporal=True)` | A streaming store into a large output buffer |
| `ptr[u32](mmio).load(0, volatile=True)` | A device register |
| `ptr[u8](data).vector(i, 16)` | 16 bytes at any address |

## Below pointers: the raw memory intrinsics

Native code also has intrinsics that work on an address held as an `int`: loads and stores of
each width, stack memory (`__alloca`), the address of a value or of its data, thread-local cells
and a float's bits. They are for an address a C library hands over as a plain integer, and for
code that needs exactly one machine operation. See
[Raw memory intrinsics](pointers-and-native-memory-intrinsics.md) (`jac docs intrinsic`); the
atomic ones are in [Atomic integers](../language/numbers-atomics.md).

## What is rejected

```jac
# expect: E1040, E1191, E1199, E1152 x2, E1001, E1465, E1052, E1466, E1467, E1410, E1411
import from c {
    obj Pair {
        has a: i32,
            b: f32;
    }

    def calloc(n: int, size: int) -> ptr[u8];
    def malloc(n: int) -> ptr;
}

obj Box {
    has v: int = 0;
}

with entry {
    bare = malloc(8);
    print(bare[0]);
    bare[0] = 1;
    print(len(bare.view(1)));
    boxes = ptr[Box](calloc(1, 8));
    print(boxes[0]);
    boxes[0] = Box();
    f = ptr[f32](calloc(4, 4));
    f[0] = "x";
    print(f.load(0, align=3));
    print(f.load(0, nontemporal=True));
    f.store(0, 1.0);
    pairs = ptr[Pair](calloc(2, 8));
    print(pairs.load(0, align=4));
    print(ptr[bool](calloc(4, 1)).vector(0, 4));
    print(f.vector(0, 3));
}
```

| Code | Condition |
|---|---|
| E1040, E1191 | Indexing or assigning through a bare `ptr` |
| E1199 | A view of a bare `ptr` |
| E1152 | An item that is not C plain data: `ptr[Box]` of a Jac object, `pin()` of a list |
| E1001 | A value of another type than the item's stored through the pointer |
| E1465 | An alignment that is not a compile-time power of two, at most 2**32 |
| E1052 | A keyword the access does not take: `nontemporal=` on a `load` |
| E1466 | `load` or `store` with no keyword |
| E1467 | `load` or `store` of a C record or a struct |
| E1410, E1411 | A vector of something that is no int or float type, or of a length that is not a power of two from 2 to 64 |
| E1154 | `addressof()` of anything but a C record or a C global |

## Differences from Python and from the reference design

- Python has no pointer type; `ctypes` pointers are objects that check and convert on every
  access. A `ptr[T]` is a machine address, and `p[i]` compiles to one load.
- A `ptr[T]` is not a reference the language tracks: the ownership rules (`jac docs
  ownership`) do not apply to what it points at, and nothing frees it for the program.
