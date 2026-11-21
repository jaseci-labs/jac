---
description: The importable modules that are jac's own rather than Python's - jaclang.comptime, atomics, dl, accel and stdjac - and where each is documented.
keywords: jaclang, Jac's own modules, jac's own modules
---
# Jac's own modules

A few importable modules have no Python counterpart: they belong to the language and its
toolchain. They resolve like the standard library's (see [The library](index.md),
`jac docs library`): a program imports them by name, and a module of the project with the same
name would shadow them.

| Module | What it is | Page |
|---|---|---|
| `jaclang.comptime` | Functions the compiler evaluates itself: reflection on types and functions (`fields`, `params`, `kind`, `type_args`, `members`, `args_type`), fields by a name known at compile time (`get_field`, `set_field`, `restore`, `apply`), facts of the build (`target`, `bits`, `signed`, `sendable`), and what decorators record (`inline`, `noinline`, `cold`, `align`, `fast_math`) | [Reflection](../language/reflection.md) (`jac docs reflection`), [Compile-time values](../language/compile-time-values.md) (`jac docs target`), [Decorators](../language/decorators.md) (`jac docs decorator`) |
| `atomics` | `Atomic[T]`, an integer that threads change in one step | [Atomics](../language/numbers-atomics.md) (`jac docs atomics`) |
| `dl` | C libraries opened as the program runs | [dl](../interop/dl.md) (`jac docs dl`) |
| `accel` | Devices, tensors and kernels | [accel](../accel/index.md) (`jac docs accel`) |
| `stdjac` and its modules | The app runtime: servers, remote calls, the codec, UI | [stdjac](../apps/stdjac.md) (`jac docs stdjac`) |

`jaclang.comptime`'s functions run as the program compiles: code written with them is unrolled for
each type into straight-line code, and nothing is reflected on as the program runs.

```jac
import from jaclang.comptime { fields, kind, members, bits, target }

enum Color {
    RED,
    GREEN,
}

obj Point {
    has x: int,
        y: float = 0.0,
        label: str = "p";
}

def describe[T] -> str {
    parts: list[str] = [];
    comptime for f in fields(T) {
        parts.append(f"{f.name}: {kind(f.type).name.lower()}");
    }
    return ", ".join(parts);
}

with entry {
    print(describe[Point](), [c.name for c in members(Color)], bits(i16));
    comptime if target().os == "windows" {
        print("built for Windows");
    } else {
        print("built for", target().os);
    }
}
```

The last line names the operating system the program was built for; on Linux:

```text
x: int, y: float, label: str ['RED', 'GREEN'] 16
built for linux
```

## Where it differs from Python

Python has no `jaclang` package: `jaclang.comptime` exists only for Jac programs.
