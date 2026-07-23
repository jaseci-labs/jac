import re;
import from contextlib { contextmanager }
import from typing { Iterator }

glob _COLOR_CACHE: dict[(str, bool)] = {};

glob _RESULT_SENTINEL: str = "__JAC_CL_TEST_RESULTS__",
     _NPM_STUB_FILE: str = "__jac_npm_stub.js",
     _SERVER_ENTRY_NAMES: tuple = ("server.jac", "main.jac"),
     _IMPORT_LINE = re.compile(r"^\s*import\b.*?;?\s*$", re.MULTILINE),
     _IMPORT_FROM = re.compile(
         r"import\s+(?P<clause>[^;]*?)\s+from\s+[\"'](?P<spec>[^\"']+)[\"']\s*;?"
     ),
     _NAMED_BINDING = re.compile(r"([A-Za-z_$][\w$]*)\s*(?:as\s+[A-Za-z_$][\w$]*)?"),
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
     _SERVER_LAUNCHER: str = """
import sys
import jaclang
from jaclang.cli.commands import execution
execution.start(
    filename=sys.argv[1], port=int(sys.argv[2]), main=True, no_client=True
)
""";

obj ClTestResult {
    has name: str,
        description: str,
        ok: bool,
        error: (str | None) = None;
}

def compile_cl_module(filepath: str) -> tuple[str, list, dict, list];

def _compile_runtime_js -> str;

def _compile_runtime_core_js -> str;

def _stub_npm_imports(js_sources: list[str]) -> tuple[list, str, bool];

def _build_harness(
    module_js: str, tests: list, api_base_url: str = "", storage: (dict | None) = None
) -> str;

def find_server_entry(
    test_filepath: str, server_imports: (list[str] | None) = None
) -> (str | None);

@contextmanager
def _serve_in_background(server_entry: str, base_path: str) -> Iterator[int];

def run_cl_test_file(
    filepath: str,
    api_base_url: (str | None) = None,
    test_name: (str | None) = None,
    storage: (dict | None) = None,
    serve: bool = True,
    timeout: float = 120.0
) -> list[ClTestResult];

def _run_harness(
    module_js: str,
    tests: list,
    imports: dict,
    api_base_url: str,
    storage: (dict | None),
    timeout: float
) -> list[ClTestResult];

def _parse_results(stdout: str, tests: list) -> (list[ClTestResult] | None);

def module_is_client(filepath: str) -> bool;
def is_cl_test_file(filepath: str) -> bool;

def is_cl_test_file_for_discovery(filepath: str) -> bool;

def register_results_into_jactestcheck(filepath: str, results: list) -> None;
