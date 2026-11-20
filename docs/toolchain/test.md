---
description: jac test, how it finds test modules, the [test] table of jac.toml, -k, -j and -o, the runners it builds in .jac/test, its output and exit statuses, and running tests as WebAssembly.
keywords: test runner, runner, deselected
---
# test

`jac test` builds and runs the `test` blocks of a project. Each module that has tests is built into one program, its test runner, and the runners are built and run in parallel: a module's tests start when its own runner is built, while others are still building.

This page is the command. The `test` block itself is in [Tests](../language/tests.md) (`jac docs language/tests`).

## The shortest example

A module holds its tests beside the code they test:

```jac
obj Cart {
    has items: dict[str, int] = {};

    def add(name: str, count: int = 1) {
        self.items[name] = self.items.get(name, 0) + count;
    }

    def total -> int {
        return sum(self.items.values());
    }
}

test "an empty cart holds nothing" {
    assert Cart().total() == 0;
}

test "adding twice adds up" {
    c = Cart();
    c.add("pen");
    c.add("pen", 2);
    assert c.total() == 3;
}
```

```sh
jac test cart.jac
```

```text
jac test: 1 module with tests, 1 to build, on macos-aarch64
cart.jac: 2 passed

2 passed; 1 of 1 module passed in 1.22s
```

## Forms and options

```sh
jac test [<path>...] [<option>...]
jac test <file.jac> -o <runner> [<option>...]
```

| Option | What it does |
|---|---|
| `-k <text>` | Run only the tests whose names contain `<text>`; a module with none is not built |
| `-j <jobs>` | Build and run this many modules at once, each told it has this many processors (default: one for each core). A build or a runner sizes what it runs at once by its processors, so a test that runs commands of its own runs no more than `<jobs>` of them at once ([`PYTHON_CPU_COUNT`](../reference/environment.md#set-by-jac-for-what-it-runs)) |
| `-o <runner>` | Build the one module's test runner, and do not run it |
| `--target <platform>` | Build the runners for another platform ([build](build.md#--target-building-for-another-platform)) |
| `--rt <dir>` | The runtime to build against (default: the `rt/` beside jac) |
| `--diagnostics <form>` | How diagnostics and test results are written on stderr: `human` (the default), or `json`, one record a line ([check](check.md#diagnostics-as-json)) |

## Which modules are tested

**With paths**, the modules there:

- A `.jac` file names its module. A test annex names the module it belongs to, so `jac test src/cart.test.jac` tests `src/cart.jac`.
- A directory means every module under it that has at least one `test` block.

**With no paths**, the directories `jac.toml` lists, relative to the project's root (the nearest directory at or above the current one that holds a `jac.toml`):

```toml
[test]
directories = ["src", "tests"]
exclude = ["tests/reject/*"]
```

| Key | Meaning | Default |
|---|---|---|
| `directories` | The directories `jac test` searches when it is given no paths | The project's root |
| `directory` | One directory, read when `directories` is absent or empty | |
| `exclude` | fnmatch patterns of paths, relative to the project's root, that a directory search leaves out | Nothing |

A directory search looks at every `.jac` file under the directory, in sorted order, and leaves out:

- files and directories whose names start with `.`;
- directories named `__pycache__`, `node_modules` or `fixtures`;
- impl annexes (`*.impl.jac`), which are part of their modules;
- what `[test] exclude` matches. `exclude` applies to directory searches only: a file named on the command line is tested whatever `exclude` says.

A module's tests are the `test` blocks in the module itself and in its test annexes, `<name>.test.jac` beside it and `test/<name>.test.jac`. A test annex is part of its module: it sees the module's names without importing them.

<!-- example: not checked: a test annex of cart.jac, which is compiled with that module -->
```jac
test "a cart counts each name" {
    c = Cart();
    c.add("pen");
    c.add("ink");
    assert len(c.items) == 2;
}
```

## What a run does

1. Finds the modules, and with `-k` keeps those with a matching test.
2. Builds each module's runner into `.jac/test/<platform>/` under the project's root, at the module's path: `src/cart.jac` becomes `.jac/test/macos-aarch64/src/cart`. A runner is rebuilt only when something its last build read has changed; the header line says how many are built this time.
3. Runs every runner that built, from the project's root, with the environment variable `JAC` set to the jac that is running. A test that builds programs of its own runs that compiler.
4. Shows each module's result, in the order the modules were found, then the summary.

Inside a runner, the module's own code (its globals and plain `with entry` blocks, its test annexes' included) runs first, then each test in source order. Everything a test prints is captured; it is shown only for a test that fails, under the failure. What the module's code prints is not shown.

`with entry:__main__` does not run in a runner, so a module that is a program keeps its main code there: what it does when it is run, as opposed to the setup its tests rely on.

```jac
def greeting(name: str) -> str {
    return f"hello, {name}";
}

with entry:__main__ {
    print(greeting("world"));
}

test "greets by name" {
    assert greeting("ann") == "hello, ann";
}
```

```output
hello, world
```

`jac build` makes the program, which prints its greeting; `jac test` runs only the test. See [Tests](../language/tests.md#a-programs-main-code-and-its-tests) for which entry blocks run when.

Beside each runner are two logs: `<runner>.build.log`, what its build printed, and `<runner>.log`, what its last run printed.

## Reading the output

```text
jac test: 4 modules with tests, 4 to build, on macos-aarch64
tests/reject/broken.jac:2:12: error[E1110]: '+' is not supported between int and str
 2 |     assert 1 + "a" == 2;
   |            ^^^^^^^
    in module 'tests/reject/broken.jac'

tests/reject/broken.jac: the test runner failed to build
src/cart.jac: 3 passed
tests/names.jac: 1 passed

tests/prices.jac:10:5: FAILED[rt AssertionError]: cents of nothing: expected no cents
 10 |     assert cents(0.0) == 0, "expected no cents";
    |     ^
    in module 'tests/prices.jac'
    Traceback (most recent call last):
      File "tests/prices.jac", line 10, in test cents of nothing
        assert cents(0.0) == 0, "expected no cents";
tests/prices.jac: 1 passed, 1 failed

5 passed, 1 failed; 2 of 4 modules passed in 1.19s
FAILED tests/reject/broken.jac (did not build)
FAILED tests/prices.jac::cents of nothing
```

- The first line: how many modules have tests, how many runners have to be built, and the platform.
- A runner that does not build is shown with its diagnostics, each noted `in module '<module>'`, then `<module>: the test runner failed to build`. It counts as a failed module.
- Each module that ran has one line, `<module>: N passed`, with `, N failed` when any did.
- Each failure is shown above its module's line as a diagnostic ([check](check.md#the-format-of-a-diagnostic)) at the line the test stopped at: `FAILED[rt <exception>]` for an assertion that failed and `ERRORED[rt <exception>]` for any other exception, then the test's name and the exception's message. Under it are the source line, the module, the traceback, and after `output:` what the test printed.
- The last lines: the tests' totals (`N passed`, with `, N failed` and `, N deselected` when there are any), how many modules passed, how long the run took, and each failure by name: `FAILED <module>::<test name>` for a test, `FAILED <module> (did not build)` for a runner that did not build, `FAILED <module> (its runner failed)` for one that stopped before its tests were done ([below](#a-runner-that-dies)), and `FAILED <module> (its runner reported no test)` for one that ended with status 0 and sent no result of the module's tests, so nothing says they passed.

With `--diagnostics json` each test's result, passed or failed, is a record a line on stderr instead, with the test's name and outcome in its `result`; the modules' lines and the last lines are still printed.

### A runner that dies

A runner that stops before its tests are done, killed by a signal or ended by a crash, reports no
failure of a test. Its module's line counts the tests that finished; then comes the status the
runner ended with, minus a signal's number when a signal killed it, and what the runner had
printed, a mark for each test that finished. The summary counts the module as failed:

```text
jac test: 1 module with tests, 1 to build, on macos-aarch64
dies.jac: 1 passed

dies.jac: its runner exited with status -6
.

1 passed; 0 of 1 module passed in 1.22s
FAILED dies.jac (its runner failed)
```

Here the second of three tests raised `SIGABRT` (`signal.raise_signal(signal.SIGABRT)`), signal 6. An
exception, `SystemExit` from `sys.exit` among them, is not this case: it fails its test with an
`E` mark and the run goes on.

To find out why the runner stopped, build it with `-o` and run it by hand, where its exit status
shows:

```sh
jac test dies.jac -o dies-tests
./dies-tests; echo $?
```

```text
.134
```

In the shell, a status above 128 is a signal, numbered the status minus 128: 134 is signal 6, `SIGABRT`, and 139
is signal 11, `SIGSEGV`, a crash. Run the runner under a debugger (`lldb ./dies-tests` on macOS,
`gdb ./dies-tests` on Linux) to see where it stopped; `./dies-tests -k <text>` runs one test alone.
What the runner printed before it stopped, as `jac test` ran it, is in its log, `<runner>.log`
beside the runner in `.jac/test/`.

## -k: some of the tests

`-k <text>` runs the tests whose names contain the text, exactly as written. A module with no such test is neither built nor run.

```sh
jac test -k rounds
```

```text
jac test: 1 module with a test whose name contains 'rounds', 1 to build, on macos-aarch64
tests/prices.jac: 1 passed

1 passed, 6 deselected; 1 of 1 module passed in 1.18s
```

The last line counts the tests left out across the whole project.

## -o: one runner, not run

```sh
jac test tests/prices.jac -o prices-tests
./prices-tests
./prices-tests -k rounds
```

`-o` builds one module's runner to the file named and does not run it. The runner is an ordinary program: it runs the module's tests, prints a mark for each (`.` passed, `F` an assertion failed, `E` any other exception was raised), then the failures and the totals, and exits with status 1 when a test failed. Its only option is `-k <text>`. Run it from the project's root when its tests open files by relative path.

```text
.F.                                                                      [100%]

FAILED tests/prices.jac::cents of nothing
E   AssertionError: expected no cents

2 passed, 1 failed
```

This is how to build runners for a platform the tests cannot run on here, and to run a test under a debugger.

## Exit statuses

| Status | Meaning |
|---|---|
| 0 | Every module's tests passed |
| 1 | A test failed, a runner did not build, or the command line was wrong |
| 5 | No tests: nothing under the paths has a `test` block, or `-k` matches no test's name |

```text
jac test: no tests found
jac test: no test's name contains 'multiplies'
```

## --target wasm32-wasi

Runners for another platform cannot run here, with one exception. `jac test --target wasm32-wasi` builds each runner as a WebAssembly module and runs it on jac's own Node, which is a WASI runtime (`rt/node/wasi.mjs`), as `jac node <rt>/node/wasi.mjs --env JAC_DIAGNOSTICS_TO=<file> <runner>.wasm` from the project's root (`<rt>` is jac's runtime directory). The project's files are therefore the runner's, and the file its tests' results are sent to is named to it: a program run that way has only the environment it is told to be given.

Nothing else needs installing. jac has no Node for Windows yet, so there it stops:

```text
jac: test: wasm32-wasi test runners run on jac's Node, which Windows has none of; build one with `jac test <module> -o <runner> --target wasm32-wasi`
```

For any other platform that is not this machine's, `jac test` stops and says how to build a runner instead:

```text
jac: test: linux-x86_64 test runners don't run on macos-aarch64; build one with `jac test <module> -o <runner> --target linux-x86_64`
```

## What goes wrong

| Message | Cause |
|---|---|
| `test: no such test module or directory: <path>` | A path that is neither a `.jac` file nor a directory |
| `[test] directory 'x' (resolved to '...') does not exist` | `jac.toml` lists a directory that is not there |
| `[test] directories must be a list of strings` | `directories` is not a list of strings |
| `[test] directory must be a string` | `directory` is not a string |
| `[test] is not a table` | `test` is a key with a value, not a table |
| `[test] exclude must be a list of strings` | `exclude` is not a list of strings |
| `-j takes how many modules to build and run at once: -j 4` | `-j` without a positive number |
| `<module>: the test runner failed to build` | The module, or its tests, has errors. They are shown above the line; `jac check <module>` reports the same |
