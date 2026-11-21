---
description: The intrinsics native code calls by name for memory a pointer does not describe - loads and stores at an int address, stack memory, the address of a value or of its data, thread-local storage, and a float's bits.
keywords: intrinsic, raw memory, __mem_load_i64, __mem_store_i64, __alloca, __ref_addr, __str_data, __bytes_data, __bytearray_data, __list_data_ptr, __thread_local, __thread_local_block, __c_thread_local, thread-local, __float_bits, __bits_float, __f32_bits, __bits_f32
---
# Raw memory intrinsics

An intrinsic is a builtin the compiler turns into the machine operation itself. A native program
calls these by name, with no import. They work on addresses held as `int`s, below what a
[`ptr[T]`](pointers-and-native-memory.md) says about memory (`jac docs ptr`), and are for code
that needs exactly that operation: memory a C library hands over as a plain address, a lock-free
structure shared with C, a value's bits.

Nothing checks an address. Reading or writing memory the program does not own, or a value's data
after the program lets the value go, is undefined, as in C.

The atomic intrinsics, `__atomic_load_i64` and the rest, are with `Atomic` in
[Atomic integers](../language/numbers-atomics.md) (`jac docs __atomic_fence`). The memory
profile's `__rc_*` functions are in [Memory](../language/memory.md) (`jac docs memory`). Other
names of the form `__name` a program can reach are the runtime's own, not part of the language.

## Memory at an address

| Call | What it is |
|---|---|
| `__mem_load_i8(a)`, `__mem_load_i16(a)`, `__mem_load_i32(a)`, `__mem_load_i64(a)` | The `i8`, `i16`, `i32` or `int` at address `a`, read as a signed number of that width |
| `__mem_store_i8(a, v)` ... `__mem_store_i64(a, v)` | Writes `v`, of that type, at `a` |
| `__alloca(n)` | The address of `n` bytes of the calling function's stack frame, which last until it returns |
| `__ref_addr(x)` | The address of the heap value `x`: the same for one object, different for two equal ones |
| `__str_data(s)` | The address of a `str`'s UTF-8 bytes |
| `__bytes_data(b)`, `__bytearray_data(b)` | The address of a `bytes`'s or `bytearray`'s first byte. A `bytearray` that grows may move |
| `__list_data_ptr(xs)` | The address of a `list[int]`'s first item; the items follow 8 bytes apart |

The addresses are little-endian memory on every target jac builds for, so a narrow load of a
wider value reads its low bytes.

```jac
import from c {
    def calloc(n: int, size: int) -> ptr[u8];
    def free(p: ptr[u8]) -> None;
}

with entry {
    raw = calloc(2, 8);
    p = int(raw);
    __mem_store_i64(p, 99);
    __mem_store_i32(p + 8, i32(-5));
    print(__mem_load_i64(p), __mem_load_i32(p + 8), __mem_load_i8(p + 8), raw[8]);
    free(raw);
    frame = __alloca(16);
    __mem_store_i64(frame + 8, 4);
    print(__mem_load_i64(frame + 8));
    xs = [10, 20, 30];
    print(__ref_addr(xs) == __ref_addr(xs), __ref_addr(xs) == __ref_addr([10, 20, 30]));
    print(__mem_load_i64(__list_data_ptr(xs) + 8), __mem_load_i8(__str_data("héllo") + 1));
}
```

```output
99 -5 -5 251
4
True False
20 -61
```

## Thread-local storage

| Call | What it is |
|---|---|
| `__thread_local("name")` | The address of an 8-byte cell the calling thread has of its own, zero at first: the same on every call from one thread, another in each thread |
| `__thread_local_block("name", n)` | The same for a block of `n` bytes |
| `__c_thread_local("name")` | The address of C's thread-local variable of that name, a `_Thread_local` of a [C module](c-modules.md) |

The name is a string literal, and a block's size a positive constant (E5095). Calls naming one
name, in any module of the program, reach the one cell.

```jac
import threading;

glob seen: list[int] = [];

def note {
    cell = __thread_local("calls");
    __mem_store_i64(cell, __mem_load_i64(cell) + 1);
    seen.append(cell);
}

with entry {
    note();
    note();
    t = threading.Thread(target=note);
    t.start();
    t.join();
    print(__mem_load_i64(__thread_local("calls")), seen[0] == seen[1], seen[0] != seen[2]);
}
```

```output
2 True True
```

## A float's bits

| Call | What it is |
|---|---|
| `__float_bits(x)` | A `float`'s 64 IEEE 754 bits, as an `int` |
| `__bits_float(n)` | The `float` whose bits are `n` |
| `__f32_bits(x)` | An `f32`'s 32 bits, as an `int` |
| `__bits_f32(n)` | The `f32` whose bits are `n` |

```jac
with entry {
    print(__float_bits(1.0), __bits_float(4611686018427387904), __f32_bits(f32(-2.0)));
    print(__bits_f32(1069547520), __float_bits(-0.0) < 0);
}
```

```output
4607182418800017408 2.0 3221225472
1.5 True
```

They are a kernel's too: see [Kernels](../accel/kernels.md) (`jac docs kernel`).

## What is rejected

```jac
# expect: E5095 x3, E1051, E1001 x2
with entry {
    name = "slot";
    size = 8;
    print(__thread_local(name));
    print(__thread_local_block("block", 0));
    print(__thread_local_block("block", size));
    print(__alloca(1, 2));
    print(__mem_load_i8([1, 2]));
    print(__mem_load_i64("x"));
}
```

| Code | Condition |
|---|---|
| E5095 | A thread-local's name that is not a string literal, or a block's size that is not a positive constant |
| E1050, E1051 | Too few or too many arguments |
| E1001 | An address that is not an `int`, or a value of another type than the store's |
| E1540 | Any of these intrinsics in a `cpython` or JS space: `__alloca`, `__ref_addr`, a load or store, an atomic on an address and a thread-local's address need native memory, and `__float_bits` and its kin a float's bits, which those spaces do not provide |

## Differences from Python and from the reference design

- Python has no raw addresses; `ctypes` reads memory through objects that check and convert. Here
  `__mem_load_i64(a)` compiles to one load.
