---
description: The dl module, which opens a C library as the program runs, finds its symbols, and calls a C function at an address through a Callable type that states its signature.
keywords: dl, dl.open, dl.Library, Library.symbol, Library.close, dlopen, dynamic loading, C function pointer
---
# Opening a C library as the program runs

A library bound with `import from` ([C libraries](c-libraries.md)) must be present for the
program to start. A program that calls a library only where it is installed, such as a GPU's
driver, opens it as it runs instead, with the `dl` module, and starts and runs without it.

```jac
import dl;
import sys;

def libm -> str {
    if sys.platform == "darwin" {
        return "/usr/lib/libSystem.B.dylib";
    }
    if sys.platform == "win32" {
        return "ucrtbase.dll";
    }
    return "libm.so.6";
}

with entry {
    m = dl.open(libm());
    cos = Callable[[f64], f64](m.symbol("cos"));
    ldexp = Callable[[f64, i32], f64](m.symbol("ldexp"));
    print(cos(0.0), ldexp(1.5, 4));
    m.close();
}
```

```output
1.0 24.0
```

`dl` is jac's own module; Python has none of that name. What it raises is what CPython's
`ctypes.CDLL` raises for the same failures.

## The module

| Name | Meaning |
|---|---|
| `dl.open(name: str) -> Library` | Opens the library `name`: a file name the system's loader searches for as it searches for the libraries a program links (`libm.so.6`, `libcuda.so.1`, `nvcuda.dll`), or a path. Raises `OSError` with the loader's message when it cannot be opened |
| `lib.symbol(name: str) -> ptr` | The address of the symbol `name`. Raises `AttributeError` with the loader's message when the library has none, and `ValueError` once the library is closed |
| `lib.close()` | Closes the library. The loader may unload it, and every address it gave becomes invalid. Closing a closed library does nothing |
| `lib.name` | The name `open` was given |

The library's symbols are bound when it is opened and stay its own: opening a library adds
nothing to the names other libraries resolve.

## Calling an address

A symbol is an address, a `ptr`. `Callable[[P, ...], R](p)` makes the address `p` a function of
that type. Calling it calls the C function there with the platform's C ABI.

- The parameters and the result are the C types an `import from` declaration takes: sized
  integers and `int`, `f32` and `f64`, `str` as `const char *`, `ptr` and `ptr[T]`
  ([the table](c-libraries.md#types-in-a-declaration)).
- A signature naming what a C function pointer cannot pass is refused (E5090): a list, a C
  record by value, a callback. So is one that leaves its parameters unstated,
  `Callable[..., R]`.
- The argument is a pointer (E1053).
- Calling it allocates nothing.
- One made from a null address raises `TypeError` when called, as calling `None` does.

The result is a function value like any other. A field, global or parameter of its `Callable`
type takes it or a Jac function alike, so code can fall back to its own implementation where the
library is missing:

```jac
import dl;
import sys;

obj Driver {
    has scale: Callable[[f64], f64];
}

def halved(x: f64) -> f64 {
    return x / 2.0;
}

def load -> Driver {
    name = "/usr/lib/libSystem.B.dylib" if sys.platform == "darwin" else "libm.so.6";
    try {
        lib = dl.open(name);
        return Driver(scale=Callable[[f64], f64](lib.symbol("sqrt")));
    } except OSError {
        return Driver(scale=halved);
    }
}

with entry {
    d = load();
    print(d.scale(16.0));
    d.scale = halved;
    print(d.scale(16.0));
}
```

```output
4.0
8.0
```

## What goes wrong

```jac
import dl;

with entry {
    try {
        dl.open("libjac-no-such-library.so.1");
    } except OSError as e {
        print("OSError");
    }
    absent = Callable[[f64], f64](ptr());
    try {
        absent(1.0);
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
OSError
TypeError: 'NoneType' object is not callable
```

```jac
# expect: E1053, E5090 x4
import from c {
    obj Pair {
        has a: i32,
            b: i32;
    }
}

with entry {
    p = ptr();
    f = Callable[[f64], f64](3);
    g = Callable[[list[int]], int](p);
    h = Callable[[Callable[[int], int]], int](p);
    k = Callable[..., int](p);
    r = Callable[[Pair], int](p);
}
```

| What | Result |
|---|---|
| The library cannot be opened | `OSError`, as the program runs |
| The library has no such symbol | `AttributeError` |
| A symbol is asked of a closed library | `ValueError` |
| A function made from a null address is called | `TypeError` |
| `Callable[...](x)` where `x` is no pointer | E1053 |
| A signature C cannot pass, or with unstated parameters | E5090 |
| The signature disagrees with the C function | Undefined behavior, as a wrong prototype is in C |

The file name differs by platform (`libm.so.6`, `/usr/lib/libSystem.B.dylib`, `ucrtbase.dll`).
Choose it from `sys.platform`, as above, or put each platform's names in a variant of one module
(`names.linux.jac`, `names.darwin.jac`, `names.windows.jac`; `jac docs variant`).
