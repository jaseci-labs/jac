"""Run Jac client (`cl`) `test` blocks under bun.

A `test` block in client codespace compiles to a plain top-level JS function
whose `assert` statements lower to `throw new Error(...)`. Nothing in the core
runtime invoked those functions, so client tests were dead code.

This module closes that gap. Given a `.cl.jac` file it:

1. compiles it and reads the cl tests recorded in `mod.gen.client_manifest`,
2. emits a single-file harness (the emitted module JS + a runner epilogue that
   calls each test, catching the thrown `Error` as a failure),
3. resolves `@jac/runtime` and injects the API base URL / a `localStorage`
   shim when the tests exercise the cl->sv fetch bridge,
4. runs the harness under `bun` and parses a JSON result line.

The structured results are marshalled into `JacTestCheck` by the caller so
`jac test` and the pytest plugin report client and server tests uniformly.
"""

import re;
import from contextlib { contextmanager }
import from typing { Iterator }

# Sentinel the harness prints so we can pluck the result JSON out of stdout
# regardless of any other console output the module produced.
glob _RESULT_SENTINEL: str = "__JAC_CL_TEST_RESULTS__",
     # Generated stub module that npm specifiers are redirected to (see below).
     _NPM_STUB_FILE: str = "__jac_npm_stub.js",
     # Fallback backend filenames, in priority order, used only when a full-stack
     # cl test declares no `sv import` backend and sets no JAC_CL_TEST_SERVER. The
     # preferred path is an explicit `sv import` of the backend module.
     _SERVER_ENTRY_NAMES: tuple = ("server.jac", "main.jac"),
     # Matches top-level `import ... ;` / `import ... from "..."` statements that an
     # ES module requires at the top of the file. We hoist these above the prelude.
     _IMPORT_LINE = re.compile(r"^\s*import\b.*?;?\s*$", re.MULTILINE),
     # Captures the clause + specifier of an `import <clause> from "<spec>"` statement.
     _IMPORT_FROM = re.compile(
         r"import\s+(?P<clause>[^;]*?)\s+from\s+[\"'](?P<spec>[^\"']+)[\"']\s*;?"
     ),
     # Named bindings inside a `{ ... }` import clause (the imported name, pre-`as`).
     _NAMED_BINDING = re.compile(r"([A-Za-z_$][\w$]*)\s*(?:as\s+[A-Za-z_$][\w$]*)?"),
     # Harness templates. Plain strings with %%TOKEN%% placeholders (not f-strings)
     # so the JS braces need no escaping.
     _PRELUDE_TEMPLATE: str = """
// --- jac cl test prelude (injected by cl_test_runner) ---
globalThis.__JAC_API_BASE_URL__ = %%BASE_URL%%;
if (typeof globalThis.localStorage === "undefined") {
  const __store = %%STORAGE%%;
  globalThis.localStorage = {
    getItem: (k) => (k in __store ? __store[k] : null),
    setItem: (k, v) => { __store[k] = String(v); },
    removeItem: (k) => { delete __store[k]; },
    clear: () => { for (const k of Object.keys(__store)) delete __store[k]; },
  };
}
// Minimal browser shims so runtime branches (e.g. 401 -> reload) don't crash
// the harness with a ReferenceError; tests should not hit these paths.
if (typeof globalThis.window === "undefined") {
  globalThis.window = globalThis;
}
if (typeof globalThis.location === "undefined") {
  globalThis.location = { href: "http://localhost/", reload: () => {} };
}
""",
     _EPILOGUE_TEMPLATE: str = """
// --- jac cl test runner epilogue (injected by cl_test_runner) ---
const __JAC_TEST_FNS__ = [
%%FN_ENTRIES%%
];
const __jac_results = [];
for (const [name, description, fn] of __JAC_TEST_FNS__) {
  try {
    await fn();
    __jac_results.push({ name, description, ok: true, error: null });
  } catch (e) {
    __jac_results.push({
      name, description, ok: false,
      error: String((e && e.stack) || e),
    });
  }
}
console.log("%%SENTINEL%%" + JSON.stringify(__jac_results));
""",
     # Server-boot launcher run via `python -c` in a child process. We go through
     # the real `jac start` entrypoint so the *active plugin's* server class is
     # resolved (e.g. jac-scale's uvicorn server) and driven on its own main
     # thread -- the only place its signal-based lifecycle works. `--no-client`
     # skips the client bundle; the parent isolates storage via cwd / env.
     _SERVER_LAUNCHER: str = """
import sys
import jaclang
from jaclang.cli.commands import execution
execution.start(
    filename=sys.argv[1], port=int(sys.argv[2]), main=True, no_client=True
)
""";

"""Outcome of a single client `test` block."""
obj ClTestResult {
    has name: str,
        description: str,
        ok: bool,
        error: (str | None) = None;
}

"""Compile a `.cl.jac` file and return `(js, tests, imports, server_imports)`.

`server_imports` are the absolute paths of the backend modules the file binds
to via `sv import` -- a full-stack test boots these directly.

Raises `RuntimeError` if compilation fails."""
def compile_cl_module(filepath: str) -> tuple[str, list, dict, list];

"""Compile core's `client_runtime.cl.jac` (the `@jac/runtime` source) to JS.

Only invoked when a test imports `@jac/runtime`. Resolves the runtime through
`@jac/runtime` -- the same source the bundler and type checker use -- so no
jac-client plugin is required."""
def _compile_runtime_js -> str;

"""Compile the framework-agnostic runtime core sibling to JS.

The `@jac/runtime` shim re-exports `client_runtime_core.cl.jac` and its compiled
form imports the core by dotted module path. We compile that sibling so the
harness can emit it flat alongside `jac_runtime.js` (mirroring the Vite bundler)."""
def _compile_runtime_core_js -> str;

"""Plan stubs for npm imports across *js_sources*.

The compiled `@jac/runtime` pulls in React and friends for its JSX/forms
helpers, none of which the cl->sv fetch/auth path executes. Rather than a real
`bun install`, we redirect every npm specifier to one generated stub that
exports each imported name as an inert callable. bun statically checks named
exports, so the stub must declare exactly the names that are imported.

Returns `(rewritten_sources, stub_js, changed)`."""
def _stub_npm_imports(js_sources: list[str]) -> tuple[list, str, bool];

"""Assemble the single-file bun harness.

ES modules require `import` statements at the top of the file, so we hoist any
imports the emitted module declared, then a prelude (API base URL + a
`localStorage` shim), the rest of the module body, and finally the runner
epilogue that invokes every test and prints a JSON result line."""
def _build_harness(
    module_js: str, tests: list, api_base_url: str = "", storage: (dict | None) = None
) -> str;

"""Locate the backend a full-stack cl test should boot.

Resolution order: `JAC_CL_TEST_SERVER` (absolute or relative to the test dir);
then the module(s) the test binds via `sv import` (`server_imports`); then a
sibling `server.jac` / `main.jac` by filename convention -- the last is a
fallback and announces itself so a rename can't silently change the backend.
Returns `None` when no backend is found (the test runs without a server)."""
def find_server_entry(
    test_filepath: str, server_imports: (list[str] | None) = None
) -> (str | None);

"""Boot `server_entry` on an ephemeral port in a child process.

Launches the real `jac start` entrypoint via `python -c` so the active plugin's
server class is resolved and driven on the subprocess main thread (where
jac-scale's uvicorn + signal-drain lifecycle works); a real socket lets the bun
process reach it over HTTP. Yields the chosen port once the socket accepts
connections. Storage is isolated to `base_path` (cwd + `JAC_DATA_PATH`) and the
process is terminated on exit."""
@contextmanager
def _serve_in_background(server_entry: str, base_path: str) -> Iterator[int];

"""Compile, run, and collect results for the cl tests in *filepath*.

*test_name* (if given) filters to a single test function name. When *serve* is
true and the test imports `@jac/runtime` (i.e. exercises the cl->sv bridge), a
sibling backend is booted on an ephemeral port and its URL is injected unless
*api_base_url* is supplied explicitly. Returns an empty list when the file
declares no cl tests."""
def run_cl_test_file(
    filepath: str,
    api_base_url: (str | None) = None,
    test_name: (str | None) = None,
    storage: (dict | None) = None,
    serve: bool = True,
    timeout: float = 120.0
) -> list[ClTestResult];

"""Emit the harness, run it under bun, and parse the results."""
def _run_harness(
    module_js: str,
    tests: list,
    imports: dict,
    api_base_url: str,
    storage: (dict | None),
    timeout: float
) -> list[ClTestResult];

"""Extract the JSON result line emitted by the harness."""
def _parse_results(stdout: str, tests: list) -> (list[ClTestResult] | None);

"""True if *filepath* is a client-codespace file (`.cl.jac`).

Used when a file is named explicitly (`jac test app.cl.jac`): any client file
the user points at is run."""
def is_cl_test_file(filepath: str) -> bool;

"""True if *filepath* is a client file following test-naming conventions.

Used during directory discovery so app modules like `frontend.cl.jac` are not
compiled/run as suites -- only `test_*.cl.jac` and `*.test.cl.jac`."""
def is_cl_test_file_for_discovery(filepath: str) -> bool;

"""Marshal cl results into `JacTestCheck` so reporting is unified.

Each result becomes a synthetic unittest case: a no-op on success, or one that
raises `AssertionError` carrying the JS error on failure. This lets the
standard `jac test` summary and the pytest plugin treat client tests exactly
like server tests."""
def register_results_into_jactestcheck(filepath: str, results: list) -> None;
