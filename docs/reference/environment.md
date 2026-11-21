---
description: Every environment variable jac reads, sets for the programs it runs, or that a program it built reads - JAC_*, the names an app may not take, color and terminal variables, SDKROOT and the installer's - with what reads each and what it does.
keywords: environment variables, JAC_LIB_DIR, JAC_CACHE_DIR, JAC_CACHE_SIZE, JAC_PROGRESS_TO, JAC, JAC_DIAGNOSTICS_TO, JAC_EXE, JAC_RUST_SYSROOT, NEOJAC_PORT_TO, NEOJAC_DEPENDENCY_DIGEST, JAC_HOME, JAC_BIN_DIR, JAC_BROWSE_SESSION, GITHUB_TOKEN, GH_TOKEN, NO_COLOR, FORCE_COLOR, CLICOLOR_FORCE, TERM, XDG_CACHE_HOME, LOCALAPPDATA, SDKROOT, JAC_GC, JAC_THREADS, JAC_APP
---
# Environment variables

jac needs no environment variable: an installed release finds its runtime, its toolchain and its documentation from where its own executable is. The variables below change what it does, are set by jac for the programs it runs, or are read by the programs it builds.

## Read by jac

| Variable | Read by | What it does |
|---|---|---|
| `JAC_LIB_DIR` | Every command that compiles or runs a tool | The toolchain's `lib/` (Clang's headers, each target's C library and runtime, the C libraries, CPython, Node) instead of the `lib/` beside jac's `bin/`. A compiler built in a checkout outside `build/bin/` needs `JAC_LIB_DIR=build/lib`. It never moves jac's Rust toolchain, which is always the `lib/rust/` of the jac that runs ([build](../toolchain/build.md#how-the-runtime-is-found)) |
| `JAC_CACHE_DIR` | `build`, `check`, `test`, `run`, `emit-js`, `emit-py`, `browse` | The build cache's directory, instead of the per-user cache directory. The cache is its `2/` ([The build cache](../toolchain/cache.md)); what jac fetched is its `fetched/`, and a browser session's directory is under its `browse/` |
| `JAC_CACHE_SIZE` | The same | The size the build cache is kept to: a number of bytes, or one followed by `K`, `M` or `G` (`20G`). Unset, 10G. Over it, a build that finishes alone deletes the entries used longest ago ([The build cache](../toolchain/cache.md#its-size-and-what-is-deleted)) |
| `XDG_CACHE_HOME` | The same, on Linux | Where the per-user cache directory is, when `JAC_CACHE_DIR` is unset (else `~/.cache`) |
| `LOCALAPPDATA` | The same, on Windows | Where the per-user cache directory is, when `JAC_CACHE_DIR` is unset |
| `JAC_PROGRESS_TO` | Every command that shows a status line | A file to append each step to, one line each (`<step>` or `<step> · <detail>`), instead of drawing a status line ([Projects](../toolchain/projects.md#jac_progress_to)) |
| `NO_COLOR` | Every command | Set to anything but empty: no color, wherever the output goes. It wins over `FORCE_COLOR` |
| `FORCE_COLOR`, `CLICOLOR_FORCE` | Every command | Set to anything but empty or `0`: color even where the output is not a terminal |
| `TERM` | Every command | `dumb`: no status line, no outcome line, and no color unless forced |
| `LC_ALL`, `LC_CTYPE`, `LANG` | Every command that shows a status line | The first that is set decides whether the terminal takes UTF-8: without it, the status line is drawn in ASCII and the outcome has no `✓` |
| `JAC_BROWSE_SESSION` | `browse` | The session a command is for, when it has no `--session` (else `default`) ([browse](../toolchain/browse.md#a-session)) |
| `SDKROOT` | `cc`, `c++` for a macOS target | A macOS SDK whose headers, frameworks and libraries a compile and link use, instead of the macOS stubs jac carries. `-isysroot` on the command line does the same |
| `PATH` | The tools | `jac node` and the Rust tools put their own directories first on it for the programs they start |

A build records the state of each variable it read. A change to one, or setting one that was unset (even to an empty value), makes the next build run instead of finding itself up to date ([The build cache](../toolchain/cache.md#when-a-build-has-nothing-to-do)).

The tools jac carries read their own variables as they always do: `jac python` reads CPython's (`PYTHONPATH`, `PYTHONMALLOC`, ...), `jac install` passes pip's (`PIP_INDEX_URL`, `PIP_NO_INDEX`, ...) to pip, and `jac node`, `npm` and `cargo` read theirs.

## Set by jac for what it runs

| Variable | Set by | What it is |
|---|---|---|
| `JAC` | `jac test`, an app's build | The path of the jac that is running, for a test or a build step that runs the compiler itself |
| `PYTHON_CPU_COUNT` | `jac test -j <jobs>` | `<jobs>`: the processors each build and runner is told it has (`os.cpu_count()` and `os.process_cpu_count()`), so a test that runs commands of its own runs as many at once as `-j` allows |
| `JAC_PROGRESS_TO` | An app's build | The file the build steps of each program it runs are reported to, which the app's build shows as `<step> · <inner step>` |
| `JAC_DIAGNOSTICS_TO` | A jac running another | The file the inner one appends its diagnostics to, for the outer one to show. A program removes it from its environment as it starts, so programs it runs report for themselves |
| `JAC_EXE` | `jac cargo`, `jac rustc` on Windows | The jac the toolchain's launchers (`lib/bin/*.exe`, and `rustc`, `rustdoc` and `cargo` in `lib/rust/bin/`) run. A launcher started without it stops with `JAC_EXE is unset: run it through jac cargo or jac rustc` |
| `JAC_RUST_SYSROOT` | The build of a Rust standard library | The sysroot `jac rustc` gives a compile that names none |
| `NEOJAC_PORT_TO` | rustc, under `jac port` | The file rustc writes a crate's typed trees to, instead of compiling it: how `jac port` reads Rust ([port](../toolchain/port.md)) |
| `NEOJAC_DEPENDENCY_DIGEST` | A build of Rust crates | A digest of a crate's dependencies, which the crate can read with `env!` |
| `JAC_APP` | An app's launcher, for a node space | The app's name, which picks its `JAC_<APP>_*` variables. Set it to run the launcher as another app's |
| `JAC_DEV_LISTEN`, `JAC_DEV_SERVED`, `JAC_DEV_PAGE` | `jac dev` | Where the app's program listens, the page space a dev server serves in its place, and the page a window opens ([Building apps](../apps/building.md#a-page-from-its-bundlers-dev-server)) |

These are jac's own plumbing: a program you run under jac sees them, and you rarely set one yourself. The two that pass between jac and its own rustc, `NEOJAC_PORT_TO` and `NEOJAC_DEPENDENCY_DIGEST`, keep the prefix they had before 0.70.0.

## Names an app may not take

`JAC_<NAME>` is also how an app's own settings are given where it runs: `JAC_<APP>_LISTEN`, `JAC_<APP>_DATA` and `JAC_<APP>_ARRANGEMENT` for an app, `JAC_REMOTE_<SPACE>` and `JAC_<SPACE>_CODE` for a space, `JAC_<ABSTRACTION>` and `JAC_<SPACE>_<ABSTRACTION>` for the plugin picked, and `JAC_<ABSTRACTION>_<FIELD>` for a plugin's setting ([Plugins](../apps/plugins.md)). So the variables jac and a program's runtime read for themselves are reserved, and an app or a space whose name would form one of them is refused where it is declared (E2231):

`JAC`, `JAC_HOME`, `JAC_BIN_DIR`, `JAC_LIB_DIR`, `JAC_CACHE_DIR`, `JAC_CACHE_SIZE`, `JAC_EXE`, `JAC_PROGRESS_TO`, `JAC_DIAGNOSTICS_TO`, `JAC_BROWSE_SESSION`, `JAC_RUST_SYSROOT`, `JAC_PYTHON_PREFIX`, `JAC_THREADS`, `JAC_GC`, `JAC_CUDA`, `JAC_FRESH`, `JAC_APP`, `JAC_BUNDLE_JOB`, `JAC_DEV_PAGE`, `JAC_DEV_SERVED`, `JAC_DEV_LISTEN`, `JAC_DEPLOY_KEY`, `JAC_TICKS_OFF`, `JAC_REMOTE_TOKEN`.

An app named `dev` would be given its address by `JAC_DEV_LISTEN`, which `jac dev` sets for itself, and a space named `token` its remote by `JAC_REMOTE_TOKEN`: each is E2231. No abstraction has a name that one of these starts with, so no plugin's setting can form one.

## Read by a program jac built

| Variable | What it does |
|---|---|
| `JAC_GC` | `JAC_GC=off`: under the `managed` memory profile, the cycle collector never runs on its own (an explicit `__rc_collect_cycles()` still does). For finding leaks. See [Memory](../language/memory.md) |
| `JAC_THREADS` | How many threads a `flow for` loop runs on, 4 when it is unset. The program reads the digits the value starts with (`8x` is 8); a value that starts with none, or `0`, is 1. `JAC_THREADS=1` runs every loop in order, with a sequential run's results |

A program reads `JAC_GC` and `JAC_THREADS` from the environment it was started with. Other pages own the rest:

| Variables | Page |
|---|---|
| `JAC_CUDA` | [Devices](../accel/devices.md) |
| `JAC_LLM_MODEL` (the model `by llm(...)` asks), `ANTHROPIC_API_KEY` (the key the `anthropic` plugin sends), `JAC_LLM_ADDRESS` (a gateway to the API, in place of `https://api.anthropic.com`) | [by and sem](../language/by-and-sem.md) |
| `JAC_<ABSTRACTION>` (which of the plugins it was built with a program runs with: `JAC_STORE`), `JAC_<ABSTRACTION>_<FIELD>` (a setting of that plugin: `JAC_STORE_PATH`), and `JAC_<SPACE>_<ABSTRACTION>` with `JAC_<SPACE>_<ABSTRACTION>_<FIELD>` for a space bound on its own. `ui` and `bundler` have none: they are picked as a space is built | [Plugins](../apps/plugins.md#picking-a-plugin-where-the-program-runs) |
| `SSO_GITHUB_CLIENT_ID`, `SSO_GITHUB_CLIENT_SECRET` (a GitHub OAuth app's, with which the `accounts` plugin offers signing in through GitHub) | [Servers](../apps/server.md#signing-in-through-github) |
| `JAC_<APP>_LISTEN`, `JAC_TICKS_OFF` | [Servers](../apps/server.md) |
| `JAC_<APP>_DATA`, `JAC_FRESH` | [An app's data](../apps/data.md) |
| `JAC_<APP>_ARRANGEMENT` (which arrangement an app is, of those its artifact holds) | [Building apps](../apps/building.md#several-arrangements-in-one-artifact) |
| `JAC_REMOTE_<SPACE>`, `JAC_REMOTE_TOKEN`, `JAC_DEPLOY_KEY` | [Crossings](../apps/crossings.md) |

The standard library reads the variables Python's does, with Python's meaning: `HOME`, `TMPDIR` (for `tempfile`), `PYTHONTZPATH` (for `zoneinfo`), `PYTHON_CPU_COUNT` (for `os.cpu_count`), `COMSPEC` (for `subprocess` on Windows), and the rest, through `os.environ`.

## Read by the installer

`install.sh` reads these; jac itself does not ([Install](../start/install.md)):

| Variable | What it changes | Default |
|---|---|---|
| `JAC_HOME` | Where releases are unpacked | `~/.jac` |
| `JAC_BIN_DIR` | Where the `jac` link goes | `~/.local/bin` |
| `GITHUB_TOKEN`, `GH_TOKEN` | Sent with the request for the releases, so it is not held to GitHub's rate limit for unauthenticated requests | none |
| `JAC_RELEASES_API`, `JAC_RELEASES_DOWNLOAD` | Where the releases are listed and downloaded from, for a mirror | `jaseci-labs/jac` on GitHub |
