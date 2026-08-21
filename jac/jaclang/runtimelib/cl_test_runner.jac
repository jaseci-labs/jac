import re;
import from contextlib { contextmanager }

glob _COLOR_CACHE: dict[(str, bool)] = {};

glob _RESULT_SENTINEL: str = "__JAC_CL_TEST_RESULTS__",
     _NPM_STUB_FILE: str = "__jac_npm_stub.js",
     _TSCONFIG_FILE: str = "tsconfig.json",
     _MOCKS_DIR: str = "__mocks__",
     _MOCK_SEARCH_DIR: tuple = ("tests", "__mocks__"),
     _VIRTUAL_PREFIX: str = "@jac/",
     _RUNTIME_SPEC: str = "@jac/runtime",
     _SERVER_ENTRY_NAMES: tuple = ("server.jac", "main.jac"),
     _IMPORT_LINE = re.compile(r"^\s*import\b.*?;?\s*$", re.MULTILINE),
     _IMPORT_FROM = re.compile(
         r"import\s+(?P<clause>[^;]*?)\s+from\s+[\"'](?P<spec>[^\"']+)[\"']\s*;?"
     ),
     _EXPORT_FROM = re.compile(
         r"export\s+(?P<clause>\*(?:\s+as\s+[A-Za-z_$][\w$]*)?|\{[^}]*\})"
         r"\s*from\s*[\"'](?P<spec>[^\"']+)[\"']\s*;?"
     ),
     _BARE_IMPORT = re.compile(r"import\s+[\"'](?P<spec>[^\"']+)[\"']\s*;?"),
     _DYNAMIC_IMPORT = re.compile(r"\bimport\s*\(\s*[\"'](?P<spec>[^\"']+)[\"']\s*\)"),
     _REQUIRE_CALL = re.compile(r"\brequire\s*\(\s*[\"'](?P<spec>[^\"']+)[\"']\s*\)"),
     _NATIVE_PREFIXES: tuple[str, ...] = ("node:", "bun:"),
     _REL_EXTS: tuple[str, ...] = (".js", ".mjs", ".cjs"),
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

obj ClImportPlan {
    has paths: dict[str, str] = {},
        staged: dict[str, str] = {},
        stubbed: list[str] = [],
        star_stubbed: list[str] = [],
        uses_runtime: bool = False;
}

def _scan_all_specs(js: str) -> dict[str, dict];

def _scan_import_specs(js: str) -> dict[str, dict];

def _scan_relative_specs(js: str) -> list[str];

def _resolve_relative_source(base_dir: str, spec: str) -> (str | None);

def _mock_target(spec: str) -> str;

def _client_test_settings(source_path: (str | None)) -> tuple[str, dict, (str | None)];

def _mock_sources_for(source_path: (str | None)) -> dict[str, str];

def _render_tsconfig(paths: dict[str, str]) -> str;

def _render_npm_stub(named: set, needs_default: bool) -> str;

def _resolve_client_imports(
    source_path: (str | None), entry_js: str, dep_files: dict[str, str]
) -> ClImportPlan;

def _report_stubbed(source_path: (str | None), plan: ClImportPlan) -> None;

def _build_harness(
    module_js: str, tests: list, api_base_url: str = "", storage: (dict | None) = None
) -> str;

def _collect_local_imports(
    module_js: str, source_dir: str, entry_path: str
) -> dict[str, str];

def _exported_names(js: str) -> set;

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
    api_base_url: str,
    storage: (dict | None),
    timeout: float,
    source_path: (str | None) = None
) -> list[ClTestResult];

def _parse_results(stdout: str, tests: list) -> (list[ClTestResult] | None);

def module_is_client(filepath: str) -> bool;
def is_cl_test_file(filepath: str) -> bool;

def is_cl_test_file_for_discovery(filepath: str) -> bool;

def register_results_into_jactestcheck(filepath: str, results: list) -> None;
