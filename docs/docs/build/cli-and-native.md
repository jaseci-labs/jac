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

A `.na.jac` file compiles through LLVM to a **standalone, zero-dependency executable** you can ship to machines that have neither Jac nor Python -- like a `curl`-style single-binary tool:

```jac
# sum.na.jac
def compute_sum(n: int) -> int {
    total: int = 0; i: int = 1;
    while i <= n { total = total + i; i = i + 1; }
    return total;
}

with entry { print(f"Sum of 1 to 10: {compute_sum(10)}"); }
```

```bash
jac nacompile sum.na.jac -o sum
./sum
```

Jac ships its own native linker, so there's no `gcc`/`ld` in the loop. The native subset requires a `with entry` block and allows no walkers/nodes/async or Python imports.

!!! tip "Shipping a full app instead?"
    The native subset is the price of the smallest possible artifact. To ship *any* Jac program (walkers, Python imports, even a web client) as one executable, use `jac build --as binary` -- it fuses your app's sealed `.jab` onto the `jac` launcher so the file carries the full runtime. A plain `jac build` emits the sealed `.jab` bundle itself, which any Jac install runs with zero live compilation. See [Ship it](../quick-guide/project-kinds.md#ship-it-one-file-or-one-executable) and [`jac build`](../reference/cli/index.md#jac-build).

## Run natively in place {#cli-native}

Set `kind = "cli-native"` in `jac.toml` when you want the *program* to execute through the native pathway rather than producing a distributable artifact -- the same `.na.jac` subset, run as a command. A bare `jac run` then compiles-and-executes it. (`cli` runs on the Python VM; `cli-native` runs the native build; `native-binary` ships the executable.)

## Your learning path

- **Concepts you need** → [Core Concepts](../quick-guide/what-makes-jac-different.md) -- codespaces & object-spatial programming
- **Learn the language** → [Jac Fundamentals](../tutorials/language/basics.md) · [Graphs & Walkers](../tutorials/language/osp.md)
- **Build it for real** → [Build a Chess Engine](../tutorials/native/chess.md) -- a complete native project · [WebAssembly in the Browser](../tutorials/native/wasm.md) -- the same `na` code compiled to wasm
- **Look it up** → [Native pathway reference](../reference/language/native-pathway.md) · [CLI commands](../reference/cli/index.md)

## Going further

- Add AI to a CLI tool → [AI agents & LLM apps](ai-agents.md)
- Ship a C-callable library instead of an executable → [Reusable libraries & packages](libraries.md#native-lib)
- Need a server, not a script → [Backend APIs & services](backend-apis.md)
