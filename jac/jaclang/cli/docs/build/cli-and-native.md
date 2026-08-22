# I like to build … CLI tools & native binaries

Command-line programs and self-contained native executables -- anything you run straight from a terminal, from quick scripts to ship-anywhere binaries. These map to the `cli`, `cli-native`, and `native-binary` [project kinds](../quick-guide/project-kinds.md).

## Your 5-minute quick win {#cli}

The simplest Jac project is a `.jac` file you run directly. Jac is graph-native, so even a one-off script can model data as nodes and walk them:

```jac
# hello.jac
node Person { has name: str; }

walker Greeter {
    can start with Root entry { visit [-->]; }
    can greet with Person entry {
        print(f"Hello, {here.name}!");
        visit [-->];
    }
}

with entry {
    root ++> Person(name="Ada");
    root ++> Person(name="Alan");
    root spawn Greeter();
}
```

```bash
jac run hello.jac
```

The graph hanging off `root` is saved between runs automatically -- the same persistence that backs Jac servers, with no database to set up.

## Ship it as a native binary {#native-binary}

`jac nacompile` compiles a `.jac` file through LLVM to a **standalone, zero-dependency executable** you can ship to machines that have neither Jac nor Python -- like a `curl`-style single-binary tool:

```jac
# sum.jac
def compute_sum(n: int) -> int {
    total: int = 0; i: int = 1;
    while i <= n { total = total + i; i = i + 1; }
    return total;
}

with entry { print(f"Sum of 1 to 10: {compute_sum(10)}"); }
```

```bash
jac nacompile sum.jac -o sum
./sum
```

Jac ships its own native linker, so there's no `gcc`/`ld` in the loop. The native subset requires a `with entry` block and allows no walkers/nodes/async or Python imports. Memory is reference-counted by default, and modules written with [ownership annotations](../reference/language/ownership-borrowing.md) can compile with `--gc none --enforce-nogc` to Rust-style static allocation and free -- no refcounting or collector in the binary, verifiable with `--assert-no-rc` (see [zero-RC compilation](../reference/language/native-pathway.md#zero-rc-ownership-compilation)).

!!! tip "Shipping a full app instead?"
    The native subset is the price of the smallest possible artifact. To ship *any* Jac program (walkers, Python imports, even a web client) as one executable, use `jac build --as binary` -- it fuses your app's sealed `.jab` onto the `jac` launcher so the file carries the full runtime. A plain `jac build` emits the sealed `.jab` bundle itself, which any Jac install runs with zero live compilation. Add `--fat` to either to vendor the Python dependency closure into the bundle so it materializes offline, with no PyPI (see [fat jab](../reference/cli/index.md#jac-build)). See [Ship it](../quick-guide/project-kinds.md#ship-it-one-file-or-one-executable) and [`jac build`](../reference/cli/index.md#jac-build).

## How a sealed jab boots natively {#sealed-native-boot}

When a `cli`, `cli-native`, or `native-binary` app is sealed with native artifacts, `jac build` writes two files per target triple under the bundle's native directory: the standalone executable and an **entry library** (`lib<stem>.so` / `.dylib` / `.dll`) built with `--entry-lib`, which exports the host-protocol symbols `jac_entry`, `__jac_argc`, `__jac_argv`, and `__jac_shared_init` (see [entry libraries](../reference/language/native-pathway.md#entry-libraries)).

At run time, `jac run app.jab` picks the fastest lane that works, falling back in order:

1. **Standalone executable** -- if a native binary for this platform was sealed, the runner replaces itself with it via `execv`. No interpreter is involved.
2. **Entry library, loaded in-process** -- otherwise the runner `dlopen`s the entry library into its own address space, fills in `__jac_argv`/`__jac_argc`, calls `__jac_shared_init` to run global initializers, then invokes `jac_entry`. Sharing the address space with the Jac runtime keeps the door open for native-to-Python callbacks across the interop bridge.
3. **JIT interpreter** -- if neither artifact exists or loads, the entry runs through the ordinary JIT pathway.

The fallback stops at a boundary: once `jac_entry` has started executing, a failure aborts the run instead of falling back -- replaying the entry through another lane would run its side effects twice.

!!! note "Apps that call back into Python"
    An app whose native code imports Python symbols (`native_imports`) cannot be self-contained, so sealing drops the standalone executable and records the fact in a `<lib>.interop.json` sidecar next to the entry library (naming the unresolved symbols). The jab manifest carries its `native.interop` flag from that record -- never inferred from which artifacts happen to be present. Such apps seal as host-driven entry-library only; there is no standalone exe to exec.

## Run natively in place {#cli-native}

Set `kind = "cli-native"` in `jac.toml` when you want the *program* to execute through the native pathway rather than producing a distributable artifact -- the same native subset, run as a command. A bare `jac run` then compiles-and-executes it. (`cli` runs on the Python VM; `cli-native` runs the native build; `native-binary` ships the executable.)

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- codespaces & object-spatial programming
- **Learn the language** → [Jac Fundamentals](../tutorials/language/basics.md) · [Object-Spatial Programming](../tutorials/language/osp.md)
- **Build it for real** → [Build a Chess Engine](../tutorials/native/chess.md) -- a complete native project · [WebAssembly in the Browser](../tutorials/native/wasm.md) -- the same `na` code compiled to wasm
- **Look it up** → [Native pathway reference](../reference/language/native-pathway.md) · [CLI commands](../reference/cli/index.md)

## Going further

- Add AI to a CLI tool → [AI agents & LLM apps](ai-agents.md)
- Ship a C-callable library instead of an executable → [Reusable libraries & packages](libraries.md#native-lib)
- Need a server, not a script → [Backend APIs & services](backend-apis.md)
