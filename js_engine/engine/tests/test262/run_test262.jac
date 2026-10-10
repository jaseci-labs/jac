"""
run_test262.jac — Test262 conformance runner for js_engine.

Usage (from js_engine/ repo root):
    jac run engine/tests/test262/run_test262.jac [options]
    (pass `--` before `--help`/`-h`: jac run engine/tests/test262/run_test262.jac -- --help)

See README.md for full documentation.
"""
import argparse;
import atexit;
import fnmatch;
import json;
import os;
import re;
import resource;
import shutil;
import signal;
import subprocess;
import sys;
import tempfile;
import time;
import from concurrent.futures { ThreadPoolExecutor, as_completed }
import from datetime { datetime, timezone }
import from pathlib { Path }

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
# This script lives at engine/tests/test262/run_test262.jac inside js_engine/;
# JS_ENGINE_ROOT is the js_engine/ repo root (three levels up from this file).
glob SCRIPT_DIR = Path(__file__).resolve().parent,
     JS_ENGINE_ROOT = SCRIPT_DIR.parent.parent.parent,
     TEST262_ROOT = SCRIPT_DIR / "vendor",
     HARNESS_DIR = TEST262_ROOT / "harness",
     TEST_DIR = TEST262_ROOT / "test",
     LOG_ROOT = JS_ENGINE_ROOT / "regression_logs" / "test262",
     DEFAULT_ENGINE = JS_ENGINE_ROOT / "bin" / "js_engine",
     SKIP_MANIFEST_PATH = SCRIPT_DIR / "skip_manifest.json",
     PIN_PATH = SCRIPT_DIR / "test262.sha";

# ---------------------------------------------------------------------------
# YAML front-matter parser
# ---------------------------------------------------------------------------
"""Minimal YAML scalar / list parser (no external deps)."""
def _parse_yaml_value(value: str) -> any {
    value = value.strip();
    # Inline list: [a, b, c]
    if value.startswith("[") and value.endswith("]") {
        inner = value[1:-1];
        return [
            item.strip().strip('"').strip("'")
            for item in inner.split(",")
            if item.strip()
        ];
    }
    # Block list
    if "\n" in value and value.lstrip().startswith("-") {
        items = [];
        for line in value.splitlines() {
            line = line.strip();
            if line.startswith("- ") {
                items.append(line[2:].strip().strip('"').strip("'"));
            }
        }
        return items;
    }
    # Quoted scalar
    if (value.startswith('"') and value.endswith('"'))
        or (value.startswith("'") and value.endswith("'")) {
        return value[1:-1];
    }
    return value;
}

glob _FRONTMATTER_RE = re.compile(r"/\*---\s*(.*?)\s*---\*/", re.DOTALL);

"""Extract metadata from a test262 front-matter block."""
def parse_frontmatter(source: str) -> dict[str, any] {
    m = _FRONTMATTER_RE.search(source);
    if not m {
        return {};
    }

    raw = m.group(1);
    meta: dict[str, any] = {};
    current_key: str | None = None;
    current_val_lines: list[str] = [];

    def _flush {
        if current_key is not None {
            meta[current_key] = _parse_yaml_value("\n".join(current_val_lines));
        }
    }

    for line in raw.splitlines() {
        # Top-level key: starts at column 0, no leading spaces
        key_match: any = re.`match(r"^([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.*)", line);
        if key_match and not line.startswith(" ") and not line.startswith("\t") {
            _flush();
            current_key = key_match.group(1);
            current_val_lines = [key_match.group(2)] if key_match.group(2) else [];
        } elif current_key is not None {
            current_val_lines.append(line);
        }
    }

    _flush();

    # Normalise negative: it's a mapping { type, phase }
    if "negative" in meta and isinstance(meta["negative"], str) {
        neg_raw = meta["negative"].strip();
        neg_obj: dict[str, any] = {};
        for nline in neg_raw.splitlines() {
            nm = re.`match(r"\s*([a-zA-Z]+):\s*(.*)", nline);
            if nm {
                neg_obj[nm.group(1)] = nm.group(2).strip();
            }
        }
        if neg_obj {
            meta["negative"] = neg_obj;
        } else {
            # fallback: plain string means the error type
            meta["negative"] = {"type": neg_raw, "phase": "runtime"};
        }
    }

    # Normalise flags / features / includes to lists
    for key in ("flags", "features", "includes") {
        if key in meta and isinstance(meta[key], str) {
            val = meta[key].strip();
            if val.startswith("[") and val.endswith("]") {
                meta[key] = _parse_yaml_value(val);
            } elif val {
                meta[key] = [val];
            } else {
                meta[key] = [];
            }
        }
    }

    return meta;
}

# ---------------------------------------------------------------------------
# Skip manifest
# ---------------------------------------------------------------------------
"""Load skip_manifest.json; return empty structure if missing."""
def load_skip_manifest(path: Path) -> dict[str, any] {
    if not path.exists() {
        return {"version": 1, "bulk_skips": [], "tests": []};
    }
    with open(path) as f {
        return json.load(f);
    }
}

"""
Returns:
    skipped_flags   — set of flag strings to bulk-skip
    skipped_features — set of feature strings to bulk-skip
    skipped_paths   — set of exact test paths (relative to test262 root) to skip
    skipped_prefixes — list of (prefix, skip_type) for directory-prefix skips
                       (a `tests` entry whose `path` ends with `/` skips the
                       whole subtree, e.g. an entire generated-test directory)
    path_skip_type  — {path: skip_type} for individually listed tests
"""
def build_skip_lookup(manifest: dict[str, any]) -> tuple[set[str], set[str], set[str], list[tuple[str, str]], dict[str, str]] {
    skipped_flags: set[str] = set();
    skipped_features: set[str] = set();
    skipped_paths: set[str] = set();
    skipped_prefixes: list[tuple[str, str]] = [];
    path_skip_type: dict[str, str] = {};

    for item in manifest.get("bulk_skips", []) {
        if "flag" in item {
            skipped_flags.add(item["flag"]);
        }
        if "feature" in item {
            skipped_features.add(item["feature"]);
        }
    }

    for item in manifest.get("tests", []) {
        rel = item.get("path", "");
        if not rel {
            continue;
        }
        skip_type = item.get("skip_type", "skip");
        if rel.endswith("/") {
            # Directory-prefix skip: matches every test under this subtree.
            skipped_prefixes.append((rel, skip_type));
        } else {
            skipped_paths.add(rel);
            path_skip_type[rel] = skip_type;
        }
    }

    return (
        skipped_flags,
        skipped_features,
        skipped_paths,
        skipped_prefixes,
        path_skip_type
    );
}

# ---------------------------------------------------------------------------
# Test discovery
# ---------------------------------------------------------------------------
glob _FRONTMATTER_MARK = re.compile(rb"/\*---");

"""
True if `p` is an actual test262 test (has a `/*--- … ---*/` metadata block).

Files without front-matter are **not** tests — they are module fixtures /
includes imported by real tests (all `*_FIXTURE.js`, plus a few `*.js` helpers).
test262 tooling never executes them directly; running them standalone is
meaningless (they reference `assert`/globals provided only when they are
*imported* by their owning test, and they may exercise unimplemented features
of the test they support).  Excluding them from discovery keeps them out of
`--check-baseline`'s scope entirely, so an engine fix that makes a fixture's
imported logic actually run cannot show up as a spurious regression.
"""
def _is_test_file(p: Path) -> bool {
    try {
        with open(p, "rb") as fh {
            head = fh.read(4096);
        }
    } except OSError {
        return False;
    }
    return _FRONTMATTER_MARK.search(head) is not None;
}

"""Recursively find all *.js test files under test_dir (fixtures excluded)."""
def discover_tests(test_dir: Path, filter_glob: str | None = None) -> list[Path] {
    tests = [];
    is_glob = filter_glob and any(c in filter_glob for c in ("*", "?", "["));
    # A filter without glob chars and not ending in .js is a directory prefix —
    # anchor it so "language" matches only test/language/... not annexB/language/...
    is_prefix = filter_glob and not is_glob and not filter_glob.endswith(".js");
    for p in sorted(test_dir.rglob("*.js")) {
        # Never discover our own temp artifacts (sandbox dirs / temp files a
        # concurrent worker may have transiently created).
        if any(part.startswith(".t262_") for part in p.parts) {
            continue;
        }
        if filter_glob {
            rel = str(p.relative_to(test_dir));
            if is_glob {
                if not fnmatch.fnmatch(rel, filter_glob)
                    and not fnmatch.fnmatch(str(p), filter_glob) {
                    continue;
                }
            } elif is_prefix {
                prefix = filter_glob.rstrip("/");
                if not (
                    rel == prefix
                    or rel.startswith(prefix + "/")
                    or rel.startswith(prefix + os.sep)
                ) {
                    continue;
                }
            } else {
                if filter_glob not in rel {
                    continue;
                }
            }
        }
        # Skip fixtures / includes (no front-matter) — they are dependencies, not
        # tests.  This is standard test262 behaviour and keeps them out of the
        # baseline-comparison scope.
        if not _is_test_file(p) {
            continue;
        }
        tests.append(p);
    }
    return tests;
}

# ---------------------------------------------------------------------------
# Harness injection
# ---------------------------------------------------------------------------
glob _harness_cache: dict[str, str] = {};

def _read_harness(name: str) -> str {
    if name not in _harness_cache {
        p = HARNESS_DIR / name;
        if p.exists() {
            _harness_cache[name] = p.read_text(encoding="utf-8", errors="replace");
        } else {
            _harness_cache[name] = f"// harness/{name} not found\n";
        }
    }
    return _harness_cache[name];
}

glob _HOST_262_SHIM = (
         # AUGMENT the engine's own $262 rather than replacing it. The engine supplies
         # a working $262.createRealm (gated on JAC_ENGINE_ENABLE_262_HOST); assigning
         # a fresh object here discarded it, so every `features: [cross-realm]` test
         # failed with "$262.createRealm is not a function" even though the
         # implementation exists and works. Do NOT overwrite createRealm here.
         "if (typeof globalThis.$262 !== 'object' || globalThis.$262 === null) {\n"
         "  globalThis.$262 = {};\n"
         "}\n"
         "var $262 = globalThis.$262;\n"
         "if ($262.global === undefined) { $262.global = globalThis; }\n"
         "if (typeof $262.evalScript !== 'function') {\n"
         "  $262.evalScript = function (src) { return (0, eval)(src); };\n"
         "}\n"
         "if (typeof $262.gc !== 'function') { $262.gc = function () {}; }\n"
         # binary_types.js installs detachArrayBuffer when native $262 already exists.
         "if (typeof $262.detachArrayBuffer !== 'function') {\n"
         "  $262.detachArrayBuffer = function () {};\n"
         "}\n"
         # The real host exotic intentionally has typeof === "undefined", so presence
         # must be checked by own-property identity rather than a typeof probe.
         "if (!Object.prototype.hasOwnProperty.call($262, 'IsHTMLDDA')) { $262.IsHTMLDDA = undefined; }\n"
         # Do NOT overwrite createRealm if the engine native host already provided it.
         # Single-process $262.agent shim (builtins_stubs.js) — install if missing so
         # the Atomics harness (getReport/start/broadcast) works without workers.
         "if (typeof globalThis.__jacInstall262Agent === 'function') {\n"
         "  globalThis.__jacInstall262Agent($262);\n"
         "}\n"
         # test262 host `print` (INTERPRETING.md): the async harness (doneprintHandle.js)
         # calls print() to emit `Test262:AsyncTestComplete`/`...Failure`. The engine has
         # no global `print`, so provide one backed by console.log.
         "if (typeof globalThis.print !== 'function') {\n"
         "  globalThis.print = function () { console.log.apply(console, arguments); };\n"
         "}\n"
     );

def build_injected_source(
    test_path: Path, meta: dict[str, any], strict_prefix: bool = False
) -> str {
    # `raw`-flagged tests (test262 INTERPRETING.md) must run the source EXACTLY as
    # written — no harness, no $262 shim, no strict prefix. They are self-contained
    # (usually parse-phase negatives) and injecting anything changes what is parsed.
    raw_flags = meta.get("flags", []);
    if isinstance(raw_flags, str) {
        raw_flags = [raw_flags];
    }
    if "raw" in raw_flags {
        return test_path.read_text(encoding="utf-8", errors="replace");
    }

    parts = [];
    if strict_prefix {
        parts.append('"use strict";\n');
    }

    # Host-provided $262 object (test262 INTERPRETING.md). evalScript runs source
    # in the current realm's global scope via indirect eval.
    parts.append(_HOST_262_SHIM);

    # Always inject sta.js and assert.js
    parts.append(_read_harness("sta.js"));
    parts.append(_read_harness("assert.js"));

    # Async tests (flag `async`) use the $DONE completion protocol. $DONE is a
    # host-provided harness (doneprintHandle.js) — NOT listed in the test's
    # `includes` — so inject it here. It prints `Test262:AsyncTestComplete` on
    # success / `Test262:AsyncTestFailure:...` on failure; the runner decides
    # PASS/FAIL from that marker (see run_single_test). asyncHelpers.js (which
    # defines asyncTest) DOES arrive via `includes`.
    flags_bi = meta.get("flags", []);
    if isinstance(flags_bi, str) {
        flags_bi = [flags_bi];
    }
    if "async" in flags_bi {
        parts.append(_read_harness("doneprintHandle.js"));
        # asyncHelpers.js's asyncTest() gates on
        # `Object.prototype.hasOwnProperty.call(globalThis, "$DONE")`. A top-level
        # `function $DONE` from doneprintHandle.js is not (yet) reflected as a
        # globalThis OWN property by the engine, so publish it explicitly.
        parts.append("globalThis.$DONE = $DONE;\n");
    }

    # Additional includes from front-matter
    for inc_name in meta.get("includes", []) {
        parts.append(_read_harness(inc_name));
    }

    # The test body itself
    parts.append(test_path.read_text(encoding="utf-8", errors="replace"));
    return "\n".join(parts);
}

# ---------------------------------------------------------------------------
# Single test execution
# ---------------------------------------------------------------------------
# Result constants (PASS/FAIL/HANG/SKIP).
# _TIME_BIN: /usr/bin/time -f '%M' reports peak RSS in KB; use it when available.
glob PASS = "PASS",
     FAIL = "FAIL",
     HANG = "HANG",
     SKIP = "SKIP",
     _TIME_BIN = "/usr/bin/time" if os.path.isfile("/usr/bin/time") else None,
     _DEFAULT_MEM_LIMIT_GB = 1;

"""Return a preexec_fn that sets RLIMIT_AS on the child process."""
def _make_mem_limiter(limit_bytes: int) -> Callable[[], None] {
    def _limit {
        resource.setrlimit(resource.RLIMIT_AS, (limit_bytes, limit_bytes));
    }
    return _limit;
}

"""Minimal stand-in for subprocess.CompletedProcess (returncode/stdout/stderr)."""
class _ProcResult {
    with entry {
        __slots__ = ("returncode", "stdout", "stderr");
    }

    def init(self: _ProcResult, returncode: int, stdout: str, stderr: str) {
        self.returncode = returncode;
        self.stdout = stdout;
        self.stderr = stderr;
    }
}

"""
Reap a timed-out child *and its whole process tree*.

The child was started with os.setsid(), so it is the leader of a new process
group whose id equals its pid.  A plain proc.kill() only signals the direct
child (often a /usr/bin/time or `bash -c "ulimit; exec engine"` wrapper),
leaving the real js_engine it exec'd/forked orphaned and spinning.  Signalling
the *group* (killpg) takes down the wrapper and the engine together.
"""
def _kill_process_group(proc: subprocess.Popen) {
    try {
        pgid: int | None = os.getpgid(proc.pid);
    } except (ProcessLookupError, OSError) {
        pgid = None;
    }

    if pgid is not None {
        try {
            # `signal.Signals.SIGKILL` is the same object as `signal.SIGKILL`; the
            # qualified form is what Jac's type checker can resolve.
            os.killpg(pgid, signal.Signals.SIGKILL);
        } except (ProcessLookupError, OSError) {}
    }
    # Belt-and-suspenders: also kill the direct handle in case setsid did not run
    # (e.g. preexec failed) so the group id never got established.
    try {
        proc.kill();
    } except (ProcessLookupError, OSError) {}
    # Reap so we don't leak zombies; the group is already dead.
    try {
        proc.`wait(timeout=5);
    } except (subprocess.TimeoutExpired, OSError) {}
}

"""Return the basenames of all relative (`./x.js`, `./x.json`) module specifiers
in `source`. `.json` is included so an import-attributes test's `_FIXTURE.json`
is staged into the sandbox alongside its `.js` fixtures (otherwise isolating the
test for the `.js` fixture leaves the `.json` fixture behind → "Cannot find
module")."""
def _relative_specifiers(source: str) -> list[str] {
    out = [];
    for m in re.finditer(r"""['"](\.{1,2}/[^'"]+\.(?:js|json))['"]""", source) {
        out.append(os.path.basename(m.group(1)));
    }
    return out;
}

"""
All `.js` files (excluding the test) transitively imported by the test via
relative specifiers, within the test's directory.  Bounded BFS.  Used to
populate the isolated sandbox with real copies so their own relative imports
resolve inside the sandbox (a symlink would resolve relative specifiers against
the link's *target* directory — i.e. back into vendor — reintroducing the
pristine, harness-less instance we are trying to avoid).
"""
def _import_closure_files(test_path: Path, source: str) -> list[Path] {
    seen = {test_path.resolve()};
    out: list[Path] = [];
    frontier = [(test_path, source)];
    while frontier {
        (cur_path, cur_src) = frontier.pop();
        for spec in _relative_specifiers(cur_src) {
            dep = (cur_path.parent / spec).resolve();
            if dep in seen or not dep.exists() {
                continue;
            }
            seen.add(dep);
            try {
                dep_src = dep.read_text(encoding="utf-8", errors="replace");
            } except OSError {
                continue;
            }
            out.append(dep);
            frontier.append((dep, dep_src));
        }
    }
    return out;
}

"""True if `source` has a relative ESM specifier resolving to `basename`."""
def _imports_name(source: str, basename: str) -> bool {
    stem = re.escape(basename);
    return re.search(r"""['"]\.{0,2}/?""" + stem + r"""['"]""", source) is not None;
}

"""
Decide whether the injected test must be served *under its own name* (an
in-place swap) rather than as a race-free sibling temp file.

Required when the test participates in a **by-name import cycle back to
itself** — because both the self-import case and the mutual A↔B case depend on
the importer and importee being the *same* module instance:

  * direct self-import: `import * as ns from './this-test.js'`
  * mutual cycle: this test imports `./dep.js`, and `dep.js` re-imports this
    test's own basename (`export {A as B} from './this-test.js'`).  Served as
    a sibling temp, dep would import the *pristine* on-disk test — a second,
    harness-less instance — so live bindings / namespaces come back wrong.
"""
def _is_cyclic_import(test_path: Path, source: str) -> bool {
    own_name = test_path.name;
    if _imports_name(source, own_name) {
        return True;
    }
    for dep_name in _relative_specifiers(source) {
        dep_path = test_path.parent / dep_name;
        if dep_path == test_path or not dep_path.exists() {
            continue;
        }
        try {
            dep_src = dep_path.read_text(encoding="utf-8", errors="replace");
        } except OSError {
            continue;
        }
        if _imports_name(dep_src, own_name) {
            return True;
        }
    }
    return False;
}

# Harness globals a dependency module might reference (assert.*, sta.js's
# Test262Error, common includes).  If any transitively-imported module mentions
# one of these, that module needs the harness prepended too — otherwise it throws
# `assert is not defined` when the test evaluates it.
glob _HARNESS_SYMBOL_RE = re.compile(
         r"\b(assert|Test262Error|\$DONE|\$DONOTEVALUATE|verifyProperty|compareArray|"
         r"verifyPrimordialCallableNames|byteConversionValues)\b"
     );

def _needs_harness(source: str) -> bool {
    return _HARNESS_SYMBOL_RE.search(source) is not None;
}

"""
Return the list of dependency `.js` files (excluding the test itself) that the
test transitively imports *and* that reference harness globals — so they must
be served with the harness prepended.

In test262, module tests share one realm with their imported fixtures, and the
fixtures freely use `assert` / `Test262Error`.  Concatenation-injection only
prepends the harness to the entry, so an imported fixture that references
`assert` throws `ReferenceError`.  We fix that by injecting the harness into
every harness-using module in the import graph (each served under its own name
via the in-place swap so relative specifiers still resolve).

Bounded BFS over relative `./x.js` specifiers within the vendor tree.
"""
def _harness_closure(test_path: Path, source: str, meta: dict[str, any]) -> list[Path] {
    seen = {test_path.resolve()};
    out: list[Path] = [];
    frontier = [(test_path, source)];
    while frontier {
        (cur_path, cur_src) = frontier.pop();
        for spec in _relative_specifiers(cur_src) {
            dep = (cur_path.parent / spec).resolve();
            if dep in seen or not dep.exists() {
                continue;
            }
            seen.add(dep);
            try {
                dep_src = dep.read_text(encoding="utf-8", errors="replace");
            } except OSError {
                continue;
            }
            frontier.append((dep, dep_src));
            if _needs_harness(dep_src) {
                out.append(dep);
            }
        }
    }
    return out;
}

"""
Return a bash command that applies `ulimit -v` only to the engine process.
Structure: bash -c "ulimit -v <kb>; exec <engine> <args>"
This lets /usr/bin/time (if used as a parent) run unrestricted while
only the engine child is constrained.
"""
def _ulimit_wrap(engine_cmd: list[str], limit_bytes: int) -> list[str] {
    limit_kb = limit_bytes // 1024;
    inner = " ".join(f'"{a}"' for a in engine_cmd);
    return ["bash", "-c", f"ulimit -v {limit_kb}; exec {inner}"];
}

"""Format a KB value as a human-readable memory string."""
def _fmt_mem(kb: int | None) -> str {
    if kb is None or kb <= 0 {
        return "-";
    }
    if kb >= 1_048_576 {
        return f"{kb / 1_048_576:.1f}GB";
    }
    if kb >= 1024 {
        return f"{kb / 1024:.1f}MB";
    }
    return f"{kb}KB";
}

def _fmt_time(seconds: float) -> str {
    if seconds >= 1.0 {
        return f"{seconds:.2f}s";
    }
    return f"{seconds * 1000:.0f}ms";
}

"""
Returns (result, reason, detail, elapsed_s, peak_kb).
result is PASS/FAIL/HANG.
elapsed_s is wall-clock seconds for the engine run (0.0 for dry-run).
peak_kb is peak RSS in KB (None if not measured).
"""
def run_single_test(
    test_path: Path,
    engine: str,
    timeout: float,
    use_node: bool,
    dry_run: bool,
    skipped_flags: set[str],
    skipped_features: set[str],
    skipped_paths: set[str],
    skipped_prefixes: list[tuple[str, str]],
    path_skip_type: dict[str, str],
    mem_limit_bytes: int = 0
) -> tuple[str, str, str, float, int | None] {
    source = test_path.read_text(encoding="utf-8", errors="replace");
    meta = parse_frontmatter(source);

    flags = meta.get("flags", []);
    if isinstance(flags, str) {
        flags = [flags];
    }
    features = meta.get("features", []);
    if isinstance(features, str) {
        features = [features];
    }

    # Compute relative path from test262 root for skip lookup
    try {
        rel_path = str(test_path.relative_to(TEST262_ROOT));
    } except ValueError {
        rel_path = str(test_path);
    }

    # --- Skip checks (only when NOT using --node) ---
    if not use_node {
        if rel_path in skipped_paths {
            skip_type = path_skip_type.get(rel_path, "skip");
            return (SKIP, skip_type, f"skip_manifest: {rel_path}", 0.0, None);
        }

        for (prefix, prefix_skip_type) in skipped_prefixes {
            if rel_path.startswith(prefix) {
                return (SKIP, prefix_skip_type, f"skip_manifest: {prefix}*", 0.0, None);
            }
        }

        for flag in flags {
            if flag in skipped_flags {
                return (SKIP, "flag", f"flag={flag}", 0.0, None);
            }
        }

        for feat in features {
            if feat in skipped_features {
                return (SKIP, "feature", f"feature={feat}", 0.0, None);
            }
        }
    }

    if dry_run {
        return (PASS, "dry-run", "", 0.0, None);
    }

    negative = meta.get("negative");
    only_strict = "onlyStrict" in flags;

    injected = build_injected_source(test_path, meta, strict_prefix=only_strict);

    # Placement of the injected file.  Two strategies, and NEITHER ever modifies a
    # file in the vendor/ tree (an interrupted run must never corrupt the corpus —
    # vendor is gitignored, so a clobbered original cannot be recovered from git):
    #
    #   * Default — a **sibling temp file** (`.t262_run_*.js`) written next to the
    #     test.  `import './dep.js'` siblings resolve against the importer's dir, so
    #     this handles the common relative-import case.  The originals are untouched.
    #
    #   * Isolated temp dir — when the test imports itself by name, is part of a
    #     mutual A↔B cycle, or has harness-using dependencies.  Those cases need the
    #     *injected* code served under the file's real basename (so a self/back
    #     import resolves to the harness-carrying instance).  We build a private temp
    #     directory containing the injected test + injected harness-deps under their
    #     real names, plus symlinks to every other `.js` in the test's directory so
    #     plain `./sibling.js` imports still resolve.  No `../` imports exist in the
    #     corpus, so a per-directory sandbox is sufficient.  The whole dir is removed
    #     in `finally`; vendor is never written to.
    orig_path = str(test_path);
    tmp_path = orig_path;
    isolated_dir: str | None = None;
    sibling_tmp: str | None = None;

    harness_deps = _harness_closure(test_path, injected, meta);
    # The transitive closure of relative `.js` files this test references. For a
    # `dynamic-import` test the specifier is a runtime string (`import('./x.js')`,
    # or a value passed like `fn.call('./x.js')`) with NO static `import from`, so
    # harness_deps is empty and the test would run WITHOUT its `_FIXTURE.js` copied
    # into the sandbox → "Cannot find module". `_relative_specifiers` already matches
    # any `'./x.js'` literal, so build the sandbox whenever the closure is non-empty.
    import_closure = _import_closure_files(test_path, injected);
    need_isolated = (
        _is_cyclic_import(test_path, injected)
        or bool(harness_deps)
        or bool(import_closure)
    );

    if need_isolated {
        # Files that must carry the harness (basename -> injected content): the
        # test itself and every harness-using module in its import graph.
        injected_files = {test_path.name: injected};
        for dep in harness_deps {
            try {
                dep_meta = parse_frontmatter(
                    dep.read_text(encoding="utf-8", errors="replace")
                );
                injected_files[dep.name] = build_injected_source(dep, dep_meta);
            } except OSError {}
        }
        try {
            isolated_dir = tempfile.mkdtemp(
                prefix=".t262_iso_", dir=str(test_path.parent)
            );
            # Materialise the test + its whole transitive import closure as REAL
            # files in the sandbox (copies, not symlinks — a symlink would make a
            # dependency's own `./x.js` resolve against vendor again).  Harness-using
            # files get the injected source; the rest are copied verbatim.
            closure = import_closure;
            to_place = {test_path.name: test_path};
            for dep in closure {
                to_place[dep.name] = dep;
            }
            for (name, src_path) in to_place.items() {
                dst = os.path.join(isolated_dir, name);
                if name in injected_files {
                    with open(dst, "w", encoding="utf-8") as f {
                        f.write(injected_files[name]);
                    }
                } else {
                    shutil.copyfile(str(src_path), dst);
                }
            }
            tmp_path = os.path.join(isolated_dir, test_path.name);
        } except OSError {
            # Could not build the sandbox — fall back to the sibling-temp path.
            if isolated_dir and os.path.isdir(isolated_dir) {
                shutil.rmtree(isolated_dir, ignore_errors=True);
            }
            isolated_dir = None;
        }
    }

    if isolated_dir is None {
        # Sibling temp file (default / fallback): never touches the originals.
        # A `module`-flagged test is ESM: use a `.mjs` suffix so the engine parses it
        # with the module goal (top-level `await` / import.meta allowed) even when the
        # module has no import/export statement.
        tmp_suffix = ".mjs" if "module" in flags else ".js";
        (fd, sibling_tmp) = tempfile.mkstemp(
            suffix=tmp_suffix, prefix=".t262_run_", dir=str(test_path.parent)
        );
        with os.fdopen(fd, "w", encoding="utf-8") as tmp {
            tmp.write(injected);
        }
        tmp_path = sibling_tmp;
    }

    mem_file: str | None = None;
    peak_kb: int | None = None;

    try {
        # test262 leaves HostPromiseRejectionTracker to the host and judges async tests
        # by their $DONE markers, so an unhandled rejection must not abort the run.
        # The engine (like Node) makes it fatal by default; `warn` reports it on
        # stderr and continues. Several tests leave one on purpose (import('') in
        # dynamic-import/syntax/valid, `await new Promise()` in evaluation-body).
        base_cmd = (
            ["node", "--unhandled-rejections=warn", tmp_path]
                if use_node
                else [engine, "--unhandled-rejections=warn", tmp_path]
        );

        mem_limiter = None;
        if _TIME_BIN and not use_node {
            mem_file = tempfile.mktemp();
            # When mem limit is active, wrap only the engine with bash+ulimit so
            # /usr/bin/time itself runs unrestricted but the engine is constrained.
            inner_cmd = _ulimit_wrap(base_cmd, mem_limit_bytes)
                if mem_limit_bytes > 0
                else base_cmd;
            cmd = [_TIME_BIN, "-f", "%M", "-o", mem_file] + inner_cmd;
        } else {
            cmd = base_cmd;
            if mem_limit_bytes > 0 and not use_node {
                mem_limiter = _make_mem_limiter(mem_limit_bytes);
            }
        }

        # Launch the child in its OWN process group (os.setsid) so that on timeout
        # we can kill the *whole* tree.  The engine is frequently wrapped
        # (/usr/bin/time, or `bash -c "ulimit; exec engine"`); a plain
        # subprocess timeout only signals the direct child (time/bash), leaving
        # the real `js_engine` orphaned and pegging a CPU forever.  Killing the
        # process group reaps the wrapper *and* the engine it exec'd/forked.
        def _child_preexec {
            os.setsid();
            if mem_limiter is not None {
                mem_limiter();
            }
        }

        t0 = time.monotonic();
        proc_out = "";
        proc_err = "";
        returncode = 0;
        # The engine gates its test262 host object ($262, with createRealm)
        # behind this flag. Without it, every `features: [cross-realm]` test
        # fails with "$262.createRealm is not a function" even though the
        # implementation is present and working. Node supplies its own $262,
        # so only set it for the engine.
        proc_env = os.environ.copy();
        if not use_node {
            proc_env["JAC_ENGINE_ENABLE_262_HOST"] = "1";
        }
        try {
            proc_h = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                encoding="utf-8",
                errors="replace",
                preexec_fn=_child_preexec,
                env=proc_env
            );
        } except FileNotFoundError as e {
            return (FAIL, "engine-not-found", str(e), 0.0, None);
        }

        try {
            (proc_out, proc_err) = proc_h.communicate(timeout=timeout);
            returncode = proc_h.returncode;
        } except subprocess.TimeoutExpired {
            elapsed = time.monotonic() - t0;
            _kill_process_group(proc_h);
            return (HANG, "timeout", f"exceeded {timeout}s", elapsed, None);
        }

        # Lightweight stand-in for the previous CompletedProcess so the rest of
        # the function is unchanged.
        proc = _ProcResult(returncode, proc_out, proc_err);

        elapsed = time.monotonic() - t0;

        if mem_file {
            try {
                # /usr/bin/time prepends "Command exited with non-zero status N\n"
                # on non-zero exit before the %M value — take the last non-empty line.
                lines = [
                    l.strip()
                    for l in open(mem_file).read().splitlines()
                    if l.strip()
                ];
                last = lines[-1] if lines else "";
                peak_kb = int(last) if last.isdigit() else None;
            } except OSError {}
        }

        # RLIMIT_AS exceeded: process may be killed with SIGKILL (rc=-9/137),
        # crash with SIGSEGV when the allocator hits a bad ptr (rc=-11/139),
        # or exit non-zero with ENOMEM from libc (rc=1 with empty output).
        oom_rc = proc.returncode in (-9, -11, 137, 139);
        oom_silent = (
            mem_limit_bytes > 0
            and proc.returncode != 0
            and not (proc.stderr or proc.stdout).strip()
        );
        if not use_node and mem_limit_bytes > 0 and (oom_rc or oom_silent) {
            limit_gb = mem_limit_bytes / (1024 ** 3);
            return (
                HANG,
                "oom",
                f"exceeded {limit_gb:.0f}GB memory limit",
                elapsed,
                peak_kb
            );
        }

        if negative {
            expected_type = negative.get("type", "")
                if isinstance(negative, dict)
                else str(negative);
            if proc.returncode != 0 {
                return (PASS, "negative-threw", expected_type, elapsed, peak_kb);
            } else {
                return (
                    FAIL,
                    "negative-no-throw",
                    f"expected {expected_type}",
                    elapsed,
                    peak_kb
                );
            }
        } elif "async" in flags {
            # Async completion protocol (asyncHelpers.js + doneprintHandle.js):
            # PASS iff the test printed `Test262:AsyncTestComplete` and did NOT
            # print `Test262:AsyncTestFailure`. A clean exit-0 with no marker means
            # the async test never settled (e.g. an unhandled rejection swallowed,
            # or the promise chain never ran) → FAIL.
            out = (proc.stdout or "") + "\n" + (proc.stderr or "");
            if "Test262:AsyncTestFailure" in out {
                fail_line = "";
                for line in out.splitlines() {
                    if "Test262:AsyncTestFailure" in line {
                        fail_line = line.strip();
                        break;
                    }
                }
                return (FAIL, "async-failure", fail_line[:300], elapsed, peak_kb);
            }
            if proc.returncode == 0 and "Test262:AsyncTestComplete" in out {
                return (PASS, "async-complete", "", elapsed, peak_kb);
            }
            if proc.returncode != 0 {
                detail = (proc.stderr or proc.stdout or "").strip()[:300];
                return (FAIL, "non-zero-exit", detail, elapsed, peak_kb);
            }
            return (
                FAIL,
                "async-no-complete",
                "no Test262:AsyncTestComplete marker",
                elapsed,
                peak_kb
            );
        } else {
            if proc.returncode == 0 {
                return (PASS, "", "", elapsed, peak_kb);
            } else {
                detail = (proc.stderr or proc.stdout or "").strip()[:300];
                return (FAIL, "non-zero-exit", detail, elapsed, peak_kb);
            }
        }
    } finally {
        if mem_file {
            try {
                os.unlink(mem_file);
            } except OSError {}
        }
        # Remove whichever temp artifact we created.  Neither ever lives inside a
        # vendor source file, so cleanup (or a missed cleanup after SIGKILL) can
        # never corrupt the corpus.
        if isolated_dir is not None {
            shutil.rmtree(isolated_dir, ignore_errors=True);
        }
        if sibling_tmp is not None {
            try {
                os.unlink(sibling_tmp);
            } except OSError {}
        }
    }
}

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
"""Write a per-test log file under regression_logs/test262/."""
def write_log(
    test_path: Path, result: str, reason: str, detail: str, run_meta: dict[str, any]
) {
    try {
        rel = test_path.relative_to(TEST262_ROOT);
    } except ValueError {
        rel = Path(test_path.name);
    }

    log_path = LOG_ROOT / rel.with_suffix(".log");
    log_path.parent.mkdir(parents=True, exist_ok=True);
    with open(log_path, "w", encoding="utf-8") as f {
        f.write(f"result: {result}\n");
        f.write(f"reason: {reason}\n");
        f.write(f"run_id: {run_meta['run_id']}\n");
        f.write(f"engine_revision: {run_meta['engine_revision']}\n");
        f.write(f"test262_revision: {run_meta['test262_revision']}\n");
        if detail {
            f.write(f"detail: {detail}\n");
        }
    }
}

# ---------------------------------------------------------------------------
# Baseline helpers
# ---------------------------------------------------------------------------
glob RUN_LOG_DIR = Path(__file__).resolve().parent / ".run_logs",
     RUN_LOG_STALE_SECONDS = 3600.0;

"""Record/run-log key for a test path: relative to TEST262_ROOT (falls back to
the raw path if it lives outside the corpus). Must match how the run loop keys
`records` so --lf can look failures up by the same key."""
def _rel_key(tp: Path) -> str {
    try {
        return str(tp.relative_to(TEST262_ROOT));
    } except ValueError {
        return str(tp);
    }
}

"""
Derive a filesystem-safe log name from the --filter glob.

The log is per-filter so a `built-ins/String` run and a `built-ins/RegExp`
run never overwrite each other, and a later --save-baseline can only reuse a
log that covers the same scope. No filter (the full suite) is "full-suite".
"""
def _run_log_slug(filter_glob: str | None) -> str {
    if not filter_glob {
        return "full-suite";
    }
    slug = re.sub(r"[^A-Za-z0-9]+", "-", filter_glob).strip("-");
    return slug.lower() or "full-suite";
}

def _run_log_path(filter_glob: str | None) -> Path {
    return RUN_LOG_DIR / f"{_run_log_slug(filter_glob)}.json";
}

"""
Persist this run's per-test records so a subsequent --save-baseline can
promote them without re-running the suite.
"""
def _write_run_log(
    filter_glob: str | None,
    records: dict[str, dict[str, any]],
    jobs: int,
    run_meta: dict[str, any] | None = None
) -> Path {
    path = _run_log_path(filter_glob);
    path.parent.mkdir(parents=True, exist_ok=True);
    payload = {
        "version": 1,
        "filter": filter_glob,
        "created_at": time.time(),
        "jobs": jobs,
        "meta": run_meta or {},
        "tests": {rel: records[rel] for rel in sorted(records)},

    };
    with open(path, "w", encoding="utf-8") as f {
        json.dump(payload, f, indent=2, sort_keys=True);
        f.write("\n");
    }
    return path;
}

"""
Load the run log for this filter, or None when absent/unreadable.

A log recorded under a different --filter is rejected: promoting it would
silently write a baseline whose scope does not match the flag the user
passed, which is worse than re-running.
"""
def _load_run_log(filter_glob: str | None) -> dict[str, any] | None {
    path = _run_log_path(filter_glob);
    try {
        with open(path, encoding="utf-8") as f {
            data = json.load(f);
        }
    } except FileNotFoundError {
        return None;
    } except (OSError, json.JSONDecodeError) as exc {
        print(f"WARNING: ignoring unreadable run log {path}: {exc}", file=sys.stderr);
        return None;
    }

    if data.get("filter") != filter_glob {
        print(
            f"WARNING: ignoring run log {path} — it was recorded with "
            f"--filter {data.get('filter')!r}, not {filter_glob!r}",
            file=sys.stderr
        );
        return None;
    }
    return data;
}

"""Return (age_seconds, human string) for a run-log timestamp."""
def _describe_log_age(created_at: float) -> tuple[float, str] {
    age = max(0.0, time.time() - created_at);
    if age < 60 {
        return (age, f"{age:.0f}s");
    }
    if age < 3600 {
        return (age, f"{age / 60:.0f}m");
    }
    return (age, f"{age / 3600:.1f}h");
}

"""
The known-failures list: every test262 test js_engine does not pass at the
pinned test262 commit (test262.sha), one "<path>\t<FAIL|HANG>" line per test,
sorted. Passing tests are not listed (anything that runs and is not listed must
pass) and neither are tests the skip manifest skips. Timing and memory stay in
the run logs (.run_logs/), which are not committed.
"""
glob KNOWN_FAILURES_HEADER: str = (
         "# test262 tests js_engine does not pass at the pinned test262 commit\n"
         "# (engine/tests/test262/test262.sha): one \"<path>\\t<FAIL|HANG>\" line per test.\n"
         "# --check-baseline fails on a test that runs, is not listed here and does not\n"
         "# pass, and reports listed tests that now pass. Refresh the lines for a scope:\n"
         "#   make test_language T262_ARGS=\"--save-baseline engine/tests/test262/known_failures.txt\"\n"
     );

"""
Write the known-failures list at `path`: this run's FAIL/HANG tests replace
the lines for every test in `scope` (the tests this run discovered), and lines
for tests outside it are kept, so a --filter run updates only its own part.
Returns (listed, added, removed).
"""
def _write_known_failures(
    path: str, records: dict[str, dict[str, any]], scope: set[str]
) -> tuple[int, int, int] {
    known: dict[str, str] = {};
    if os.path.exists(path) {
        known = _load_known_failures(path);
    }
    before = set(known);
    for rel in list(known) {
        if rel in scope {
            del known[rel];
        }
    }
    for (rel, rec) in records.items() {
        result = str(rec.get("result", ""));
        if result in (FAIL, HANG) {  # jac:ignore[E1032]
            known[rel] = result;
        }
    }
    with open(path, "w", encoding="utf-8") as f {
        f.write(KNOWN_FAILURES_HEADER);
        for rel in sorted(known) {
            f.write(f"{rel}\t{known[rel]}\n");
        }
    }
    after = set(known);
    return (len(known), len(after - before), len(before - after));
}

"""
Load a known-failures list, returning {rel_path: "FAIL" | "HANG"}.

A JSON baseline from older runners ({"tests": {path: {"result": ...}}}) is
read as the list of its FAIL/HANG tests, so it can still be checked against
(and converted by --save-baseline).
"""
def _load_known_failures(path: str) -> dict[str, str] {
    try {
        with open(path, encoding="utf-8") as f {
            content = f.read();
        }
    } except FileNotFoundError {
        print(f"ERROR: known-failures file not found: {path}", file=sys.stderr);
        sys.`exit(1);
    }
    known: dict[str, str] = {};
    if content.lstrip().startswith("{") {
        data = json.loads(content);
        for (rel, rec) in dict(data.get("tests", {})).items() {
            result = str(rec.get("result", "")) if isinstance(rec, dict) else "";
            if result in (FAIL, HANG) {  # jac:ignore[E1032]
                known[rel] = result;
            }
        }
        return known;
    }
    for line in content.splitlines() {
        line = line.strip();
        if not line or line.startswith("#") {
            continue;
        }
        parts = line.split();
        known[parts[0]] = parts[1] if len(parts) > 1 else FAIL;
    }
    return known;
}

"""
Per-test records ({rel_path: {result, time_s, peak_kb}}) from a run log or a
JSON baseline, for the perf comparison. None when the file is missing or not
JSON.
"""
def _load_perf_records(path: str) -> dict[str, dict[str, any]] | None {
    try {
        with open(path, encoding="utf-8") as f {
            data = json.load(f);
        }
    } except (OSError, json.JSONDecodeError) {
        return None;
    }
    return dict(data.get("tests", {}));
}

"""The test262 commit the known-failures list is recorded against (test262.sha)."""
def _pinned_test262 -> str {
    try {
        for line in PIN_PATH.read_text(encoding="utf-8").splitlines() {
            line = line.strip();
            if line and not line.startswith("#") {
                return line;
            }
        }
    } except OSError {}
    return "";
}

"""Warn when vendor/ is not the pinned test262 commit: results (and the
known-failures list) only line up with the suite at that commit."""
def _warn_if_unpinned {
    pinned = _pinned_test262();
    if not pinned {
        return;
    }
    try {
        head = subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            cwd=TEST262_ROOT,
            stderr=subprocess.DEVNULL,
            text=True
        ).strip();
    } except (OSError, subprocess.CalledProcessError) {
        head = "";
    }
    if head != pinned {
        found = head or "not a git checkout";
        print(
            f"WARNING: {TEST262_ROOT} is at {found}, not the pinned test262 commit "
            f"{pinned} ({PIN_PATH.name}); known failures may not line up. "
            f"Run tools/fetch_test_deps.sh test262 from {JS_ENGINE_ROOT}.",
            file=sys.stderr
        );
    }
}

"""Return a stable revision for run provenance."""
def _git_revision(path: Path) -> str {
    try {
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=path, stderr=subprocess.DEVNULL, text=True
        ).strip()[:12];
    } except (OSError, subprocess.CalledProcessError) {
        return "unknown";
    }
}

"""
Compare per-test time and memory of tests that passed in BOTH the baseline
and this run. A metric regresses when it grows more than `pct` percent AND
the absolute increase clears the floor (time_floor_ms / mem_floor_mb) — the
floor suppresses noise on tiny/fast tests.

Returns a list of (rel_path, metric, old_value, new_value) tuples, where
metric is "time" (seconds) or "mem" (KB).
"""
def _check_perf(
    baseline: dict[str, dict[str, any]],
    current: dict[str, dict[str, any]],
    ran_paths: set[str],
    pct: float,
    time_floor_ms: float,
    mem_floor_mb: float
) -> list[tuple[str, str, float, float]] {
    time_floor_s = time_floor_ms / 1000.0;
    mem_floor_kb = mem_floor_mb * 1024.0;
    factor = 1.0 + pct / 100.0;
    regressions: list[tuple[str, str, float, float]] = [];

    for rel in sorted(ran_paths) {
        base = baseline.get(rel);
        cur = current.get(rel);
        if not base or not cur {
            continue;
        }
        # Only compare tests that pass in both runs — comparing perf across a
        # PASS/FAIL boundary is meaningless (a crash is "fast" but not better).
        if base.get("result") != "PASS" or cur.get("result") != "PASS" {
            continue;
        }

        (ot, nt) = (base.get("time_s"), cur.get("time_s"));
        if ot is not None and nt is not None and ot > 0 {
            if nt > ot * factor and (nt - ot) > time_floor_s {
                regressions.append((rel, "time", ot, nt));
            }
        }

        (om, nm) = (base.get("peak_kb"), cur.get("peak_kb"));
        if om is not None and nm is not None and om > 0 {
            if nm > om * factor and (nm - om) > mem_floor_kb {
                regressions.append((rel, "mem", float(om), float(nm)));
            }
        }
    }

    return regressions;
}

"""
Compare this run against the known-failures list at `known_path`.

Only tests this run discovered count (ran_paths), so a --filter run checks
just its scope. A test that FAILs or HANGs and is not listed is a regression;
a listed test that now passes is reported so its line can be dropped (it does
not fail the check). With `perf_records` (an earlier run of this scope, from a
run log or an explicit --perf-baseline file) per-test time and memory of tests
passing in both runs are compared too, and growth past the threshold counts as
a regression.
Returns the number of regressions (functional + perf); 0 = clean.
"""
def _check_baseline(
    known_path: str,
    current: dict[str, dict[str, any]],
    ran_paths: set[str],
    perf_records: dict[str, dict[str, any]] | None = None,
    perf_source: str = "",
    perf_pct: float = 50.0,
    perf_time_floor_ms: float = 20.0,
    perf_mem_floor_mb: float = 5.0
) -> int {
    known = _load_known_failures(known_path);
    known_in_scope = {rel for rel in known if rel in ran_paths};
    func_regressions = sorted(
        rel
        for (rel, r) in current.items()
        if rel in ran_paths
            and r.get("result") in (FAIL, HANG)  # jac:ignore[E1032]
            and rel not in known
    );
    now_passing = sorted(
        rel
        for rel in known_in_scope
        if current.get(rel, {}).get("result") == PASS
    );

    if now_passing {
        print(
            f"\nNow passing ({len(now_passing)} listed tests) — drop them from "
            f"{known_path} (rerun with --save-baseline {known_path}):"
        );
        for p in now_passing[:30] {
            print(f"  + {p}");
        }
        if len(now_passing) > 30 {
            print(f"  ... and {len(now_passing) - 30} more");
        }
    }

    if func_regressions {
        print(
            f"\nREGRESSIONS ({len(
                func_regressions
            )} tests fail that are not in {known_path}):"
        );
        for p in func_regressions {
            r = current[p];
            print(f"  - {p}  {r.get('result')} {r.get('reason', '')}".rstrip());
        }
    } else {
        print(
            f"\n✓ No regressions — every test that ran passes or is listed in "
            f"{known_path} ({len(known_in_scope)} listed in scope)"
        );
    }

    perf_regressions: list[tuple[str, str, float, float]] = [];
    if perf_records is not None {
        perf_regressions = _check_perf(
            perf_records,
            current,
            ran_paths,
            perf_pct,
            perf_time_floor_ms,
            perf_mem_floor_mb
        );
        if perf_regressions {
            print(
                f"\nPERFORMANCE REGRESSIONS ({len(
                    perf_regressions
                )} metric(s) exceeded +{perf_pct:g}% against {perf_source}):"
            );
            for (rel, metric, old, new) in perf_regressions {
                delta = (new / old - 1.0) * 100.0;
                if metric == "time" {
                    print(
                        f"  ~ {rel}  time {_fmt_time(old)} → {_fmt_time(new)}  (+{delta:.0f}%)"
                    );
                } else {
                    print(
                        f"  ~ {rel}  mem {_fmt_mem(int(old))} → {_fmt_mem(int(new))}  (+{delta:.0f}%)"
                    );
                }
            }
        } else {
            print(
                f"\n✓ No performance regressions against {perf_source} "
                f"(threshold +{perf_pct:g}%, floors {perf_time_floor_ms:g}ms / {perf_mem_floor_mb:g}MB)"
            );
        }
    }

    total = len(func_regressions) + len(perf_regressions);
    if total {
        print(
            f"\n✗ {len(func_regressions)} functional + {len(
                perf_regressions
            )} performance regression(s) — known failures: {known_path}"
        );
    }
    return total;
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def parse_args(argv: list[str] | None = None) -> argparse.Namespace {
    p = argparse.ArgumentParser(
        description="Run tc39/test262 conformance tests against js_engine."
    );
    p.add_argument(
        "--engine",
        `default=str(DEFAULT_ENGINE),
        help="Path to the JS engine binary (default: bin/js_engine relative to js_engine/)"
    );
    p.add_argument(
        "--node", action="store_true", help="Run under Node.js instead of the engine"
    );
    p.add_argument(
        "--gc",
        action="store_true",
        help="Run js_engine with the garbage collector explicitly enabled (engine --gc "
        "flag; the collector is on by default, so this matches a plain run). "
        "Ignored with --node."
    );
    p.add_argument(
        "--nogc",
        action="store_true",
        help="Run js_engine with the garbage collector disabled (engine --nogc flag)."
    );
    p.add_argument(
        "--timeout",
        type=float,
        `default=10.0,
        help="Per-test timeout in seconds (default: 10)"
    );
    p.add_argument(
        "--mem-limit",
        type=float,
        `default=float(_DEFAULT_MEM_LIMIT_GB),
        metavar="GB",
        help=f"Per-test virtual memory limit in GB (default: {_DEFAULT_MEM_LIMIT_GB}). Set to 0 to disable."
    );
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="List tests that would run without executing them"
    );
    p.add_argument(
        "--filter",
        `default=None,
        metavar="GLOB",
        help="Only run tests whose path matches this glob"
    );
    p.add_argument(
        "--jobs",
        "-j",
        type=int,
        `default=os.cpu_count() or 1,
        metavar="N",
        help="Number of parallel worker threads (default: CPU count). "
        "Use --jobs 1 for stable perf baselines."
    );
    p.add_argument(
        "--all",
        action="store_true",
        help="Ignore the skip manifest entirely and run every discovered test."
    );
    p.add_argument(
        "--run-fail",
        action="store_true",
        help="Also run tests the skip manifest marks as known failures (skip_type=fail)."
    );
    p.add_argument(
        "--run-hang",
        action="store_true",
        help="Also run tests the skip manifest marks as known hangs (skip_type=hang)."
    );
    p.add_argument(
        "--lf",
        "--last-failed",
        dest="last_failed",
        action="store_true",
        help=(
            "Re-run only the tests that FAILed (or HANGed) in the last run — read "
            "from the run log for this --filter scope (.run_logs/<slug>.json). Lets "
            "you confirm a fix against just the regressed tests instead of the full "
            "suite. Combine with --filter to narrow to a scope's last failures; "
            "combine with --check-baseline to re-check just those against a baseline. "
            "Exits non-zero if no run log exists for the scope."
        )
    );
    p.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Print each test result as it completes"
    );
    p.add_argument(
        "--extract",
        metavar="OUT_FILE",
        `default=None,
        help=(
            "Extract the test selected by --filter as a standalone .js file with harness injected. "
            "OUT_FILE is the output path (e.g. t1.js). --filter must match exactly one test."
        )
    );
    p.add_argument(
        "--save-baseline",
        metavar="FILE",
        `default=None,
        help=(
            "Refresh the known-failures list FILE (known_failures.txt): the FAIL/HANG "
            "tests of this --filter scope replace its lines for that scope, and lines "
            "for other scopes are kept. If a run log for this --filter already exists "
            "it is used without re-running the suite (pass --rerun to force a fresh "
            "run); otherwise the suite runs now."
        )
    );
    p.add_argument(
        "--rerun",
        action="store_true",
        help=(
            "With --save-baseline, ignore any existing run log and execute the "
            "suite again before writing the baseline."
        )
    );
    p.add_argument(
        "--max-log-age",
        type=float,
        `default=RUN_LOG_STALE_SECONDS,
        metavar="SECONDS",
        help=(
            "Warn when the reused run log is older than this (default: 3600, "
            "i.e. 1 hour). The log is still used — this is a staleness warning, "
            "not a hard limit."
        )
    );
    p.add_argument(
        "--check-baseline",
        metavar="FILE",
        `default=None,
        help=(
            "Check this run against the known-failures list FILE: exits non-zero if a "
            "test that ran FAILs or HANGs and is not listed. Listed tests that now "
            "pass are reported for removal (they do not fail the check). An older "
            "JSON baseline is accepted and read as its FAIL/HANG tests."
        )
    );
    p.add_argument(
        "--perf-check",
        action="store_true",
        help="With --check-baseline, also compare per-test time/memory with the "
        "previous run of this --filter scope on this machine (its run log in "
        ".run_logs/). Off by default."
    );
    p.add_argument(
        "--perf-baseline",
        metavar="FILE",
        `default=None,
        help="With --check-baseline, compare per-test time/memory with this run log "
        "(a .run_logs/<scope>.json kept from an earlier run, e.g. a CI artifact) "
        "instead of the previous run."
    );
    p.add_argument(
        "--no-perf-check",
        action="store_true",
        help="Deprecated no-op: perf check is already off by default. Kept for "
        "backward compatibility; use --perf-check to opt in."
    );
    p.add_argument(
        "--perf-pct",
        type=float,
        `default=50.0,
        metavar="PCT",
        help="Perf regression threshold: flag if time or memory grows more than this %% (default: 50)."
    );
    p.add_argument(
        "--perf-time-floor",
        type=float,
        `default=20.0,
        metavar="MS",
        help="Ignore time regressions whose absolute increase is below this many ms (default: 20)."
    );
    p.add_argument(
        "--perf-mem-floor",
        type=float,
        `default=5.0,
        metavar="MB",
        help="Ignore memory regressions whose absolute increase is below this many MB (default: 5)."
    );
    return p.parse_args(argv);
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int {
    args = parse_args(argv);

    if (args.gc or args.nogc) and args.`node {
        print(
            "ERROR: --gc/--nogc only apply to the js_engine runner (drop --node)",
            file=sys.stderr
        );
        return 1;
    }

    # --save-baseline with an existing run log for this filter: promote the
    # recorded results instead of spending another full run on them.
    if args.save_baseline and not args.rerun {
        log = _load_run_log(args.filter);
        if log is not None {
            (age, age_str) = _describe_log_age(log.get("created_at", 0.0));
            log_path = _run_log_path(args.filter);
            if age > args.max_log_age {
                print(
                    f"WARNING: run log is {age_str} old (> "
                    f"{args.max_log_age / 3600:.1f}h) — it may not reflect the "
                    f"current build. Re-run with --rerun to regenerate it.",
                    file=sys.stderr
                );
            }
            log_records = dict(log.get("tests", {}));
            (n_listed, n_added, n_removed) = _write_known_failures(
                args.save_baseline, log_records, set(log_records)
            );
            scope = args.filter or "full suite";
            print(
                f"Known failures saved → {args.save_baseline}  "
                f"({n_listed} listed: +{n_added} / -{n_removed})"
            );
            print(
                f"  Promoted from run log {log_path} "
                f"(scope: {scope}, recorded {age_str} ago) — suite not re-run."
            );
            return 0;
        }
    }

    # Verify test262 source exists
    if not TEST_DIR.exists() {
        print("ERROR: test262 source not found.", file=sys.stderr);
        print(f"  Expected: {TEST_DIR}", file=sys.stderr);
        print(f"  Fetch it (from {JS_ENGINE_ROOT}, pinned commit):", file=sys.stderr);
        print("    tools/fetch_test_deps.sh test262", file=sys.stderr);
        return 1;
    }

    # Verify harness exists
    if not HARNESS_DIR.exists() {
        print(f"ERROR: test262 harness not found at {HARNESS_DIR}", file=sys.stderr);
        return 1;
    }
    _warn_if_unpinned();

    # Safety net: remove any temp artifacts left by a hard-killed run.  The current
    # runner never writes inside a vendor source file (self/cyclic tests run in an
    # isolated temp dir of symlinks), so nothing here can corrupt the corpus — this
    # only sweeps stray sandbox dirs / temp files.  The `.t262_orig` restore is kept
    # for backward compatibility with older runs that used the in-place swap: if a
    # backup is found, move it back over its (possibly injected) original.
    for orig in TEST_DIR.rglob("*.js.t262_orig") {
        real = orig.with_suffix("");  # strip ".t262_orig" → back to ".js"
        try {
            os.replace(str(orig), str(real));
        } except OSError {}
    }
    for pattern in (".t262_run_*.js", ".t262_stage_*.js") {
        for stray in TEST_DIR.rglob(pattern) {
            try {
                stray.unlink();
            } except OSError {}
        }
    }
    for iso in TEST_DIR.rglob(".t262_iso_*") {
        if iso.is_dir() {
            shutil.rmtree(iso, ignore_errors=True);
        }
    }

    # --extract: write the test selected by --filter as a standalone injected file
    if args.extract {
        if not args.filter {
            print(
                "ERROR: --extract requires --filter to select the test", file=sys.stderr
            );
            return 1;
        }
        matches = discover_tests(TEST_DIR, filter_glob=args.filter);
        if not matches {
            print(
                f"ERROR: no test matching '{args.filter}' found under {TEST_DIR}",
                file=sys.stderr
            );
            return 1;
        }
        if len(matches) > 1 {
            print(
                f"ERROR: '{args.filter}' matched {len(
                    matches
                )} tests — be more specific:",
                file=sys.stderr
            );
            for m in matches[:20] {
                print(f"  {m.relative_to(TEST_DIR)}", file=sys.stderr);
            }
            if len(matches) > 20 {
                print(f"  ... and {len(matches) - 20} more", file=sys.stderr);
            }
            return 1;
        }
        test_path = matches[0];
        source = test_path.read_text(encoding="utf-8", errors="replace");
        meta = parse_frontmatter(source);
        flags = meta.get("flags", []);
        if isinstance(flags, str) {
            flags = [flags];
        }
        strict = "onlyStrict" in flags;
        injected = build_injected_source(test_path, meta, strict_prefix=strict);
        out_path = Path(args.extract);
        out_path.write_text(injected, encoding="utf-8");
        rel = test_path.relative_to(TEST_DIR);
        print(f"Extracted: {rel}");
        print(f"Written to: {out_path}");
        print(f"Run with:   bin/js_engine {out_path}");
        return 0;
    }

    # Load skip manifest
    manifest = load_skip_manifest(SKIP_MANIFEST_PATH);
    (
        skipped_flags,
        skipped_features,
        skipped_paths,
        skipped_prefixes,
        path_skip_type
    ) = build_skip_lookup(manifest);

    # Apply --all / --run-fail / --run-hang overrides
    if args.all {
        skipped_flags = set();
        skipped_features = set();
        skipped_paths = set();
        skipped_prefixes = [];
    } else {
        if args.run_fail {
            skipped_paths = {
                p
                for p in skipped_paths
                if path_skip_type.get(p) != "fail"
            };
            skipped_prefixes = [
                pt
                for pt in skipped_prefixes
                if pt[1] != "fail"
            ];
        }
        if args.run_hang {
            skipped_paths = {
                p
                for p in skipped_paths
                if path_skip_type.get(p) != "hang"
            };
            skipped_prefixes = [
                pt
                for pt in skipped_prefixes
                if pt[1] != "hang"
            ];
        }
    }

    # Discover tests
    tests = discover_tests(TEST_DIR, filter_glob=args.filter);

    # --lf / --last-failed: restrict to the tests that FAIL/HANG'd in the last run
    # (recorded in the run log for this --filter scope), so a fix can be confirmed
    # against just the regressed set instead of the whole suite.
    if args.last_failed {
        log = _load_run_log(args.filter);
        if log is None {
            scope = args.filter or "full suite";
            print(
                f"ERROR: --lf: no run log found for scope {scope!r} at "
                f"{_run_log_path(args.filter)}.\n"
                "  Do a normal run first (optionally with --filter) to record one.",
                file=sys.stderr
            );
            return 1;
        }
        (age, age_str) = _describe_log_age(log.get("created_at", 0.0));
        if age > RUN_LOG_STALE_SECONDS {
            print(
                f"WARNING: --lf: run log is {age_str} old — its failures may not "
                "reflect the current build. Do a full run to refresh it.",
                file=sys.stderr
            );
        }
        failed_keys = {
            rel
            for (rel, rec) in log.get("tests", {}).items()
            if rec.get("result") in (FAIL, HANG)  # jac:ignore[E1032]
        };
        if not failed_keys {
            print(
                f"--lf: last run for {(args.filter or 'full suite')!r} had no "
                f"failures (recorded {age_str} ago) — nothing to re-run."
            );
            return 0;
        }
        tests = [
            tp
            for tp in tests
            if _rel_key(tp) in failed_keys
        ];
        print(
            f"--lf: re-running {len(tests)} of {len(failed_keys)} tests that failed "
            f"in the last run (recorded {age_str} ago)."
        );
        # A failing key that no longer discovers (renamed/removed test) is dropped
        # silently — discovery is the source of truth for what can run now.
    }

    if not tests {
        print("No test files found.");
        return 0;
    }

    if args.dry_run {
        print(f"Dry run: {len(tests)} test files discovered under {TEST_DIR}");
        would_run = 0;
        would_skip = 0;
        for tp in tests {
            try {
                rel_path = str(tp.relative_to(TEST262_ROOT));
            } except ValueError {
                rel_path = str(tp);
            }

            meta = parse_frontmatter(tp.read_text(encoding="utf-8", errors="replace"));
            flags = meta.get("flags", []);
            if isinstance(flags, str) {
                flags = [flags];
            }
            features = meta.get("features", []);
            if isinstance(features, str) {
                features = [features];
            }

            # (`skip` is a Jac keyword, hence the backtick escape.)
            `skip = False;
            if not args.`node {
                if rel_path in skipped_paths {
                    `skip = True;
                } elif any(
                    rel_path.startswith(pref) for (pref, _) in skipped_prefixes
                ) {
                    `skip = True;
                } elif any(f in skipped_flags for f in flags) {
                    `skip = True;
                } elif any(f in skipped_features for f in features) {
                    `skip = True;
                }
            }
            if `skip {
                would_skip += 1;
            } else {
                would_run += 1;
                if args.verbose {
                    print(f"  WOULD RUN: {rel_path}");
                }
            }
        }

        print(f"\nWould run:  {would_run}");
        print(f"Would skip: {would_skip}");
        print(f"Total:      {len(tests)}");
        return 0;
    }

    # Parallel execution
    results = {PASS: 0, FAIL: 0, HANG: 0, SKIP: 0};
    failures: list[tuple[Path, str, str, float, int | None]] = [];
    passed_paths: set[str] = set();
    # Per-test records for baseline (result + perf metrics), keyed by rel path.
    records: dict[str, dict[str, any]] = {};

    engine = args.engine;
    mem_limit_bytes = int(args.mem_limit * (1024 ** 3)) if args.mem_limit > 0 else 0;
    run_started = datetime.now(timezone.utc);
    run_meta: dict[str, any] = {
        "run_id": run_started.strftime("%Y%m%dT%H%M%S.%fZ"),
        "timestamp": run_started.isoformat(),
        "engine_revision": _git_revision(JS_ENGINE_ROOT),
        "test262_revision": _git_revision(TEST262_ROOT),
        "command": " ".join([Path(sys.executable).name, *sys.argv]),
        "engine": "node" if args.`node else str(Path(engine).resolve()),
        "filter": args.filter,
        "timeout_s": args.timeout,
        "mem_limit_gb": args.mem_limit,
        "gc": (not args.nogc) and not args.`node,

    };

    if (args.gc or args.nogc) and not args.`node {
        # Bake the GC flag into a small wrapper executable so it flows through the
        # mem-limit/ulimit and process-group plumbing untouched (workers just exec
        # `engine`). Keep the basename "js_engine" for parity with the
        # direct-invocation path. The collector is on by default; --nogc disables it.
        gc_flag = "--nogc" if args.nogc else "--gc";
        gc_wrap_dir = Path(tempfile.mkdtemp(prefix="run_t262_gc_"));
        atexit.register(shutil.rmtree, gc_wrap_dir, ignore_errors=True);
        gc_wrapper = gc_wrap_dir / "js_engine";
        gc_wrapper.write_text(
            f'#!/bin/sh\nexec "{engine}" {gc_flag} "$@"\n', encoding="utf-8"
        );
        gc_wrapper.chmod(0o755);
        engine = str(gc_wrapper);
    }

    def _run(tp: Path) -> tuple[Path, tuple[str, str, str, float, int | None]] {
        return (
            tp,
            run_single_test(
                test_path=tp,
                engine=engine,
                timeout=args.timeout,
                use_node=args.`node,
                dry_run=False,
                skipped_flags=skipped_flags,
                skipped_features=skipped_features,
                skipped_paths=skipped_paths,
                skipped_prefixes=skipped_prefixes,
                path_skip_type=path_skip_type,
                mem_limit_bytes=mem_limit_bytes
            )
        );
    }

    total = len(tests);
    done = 0;
    peak_kb: int | None = None;
    peak_name: str = "";
    suite_start = time.monotonic();
    jobs = args.jobs;

    with ThreadPoolExecutor(max_workers=jobs) as pool {
        futures = {pool.submit(_run, tp): tp for tp in tests};
        for fut in as_completed(futures) {
            outcome: tuple[Path, tuple[str, str, str, float, int | None]] = fut.result();
            (tp, (result, reason, detail, elapsed, test_kb)) = outcome;
            results[result] += 1;
            done += 1;

            rel_key = _rel_key(tp);

            # Record result + perf metrics so the baseline can catch both
            # functional and performance regressions.
            records[rel_key] = {
                "result": result,
                "reason": reason,
                "time_s": round(elapsed, 4),
                "peak_kb": test_kb,

            };

            if result == PASS {
                passed_paths.add(rel_key);
            }

            if result == FAIL {
                failures.append((tp, reason, detail, elapsed, test_kb));
            }

            # Track peak memory across all tests
            if test_kb is not None and (peak_kb is None or test_kb > peak_kb) {
                peak_kb = test_kb;
                try {
                    peak_name = str(tp.relative_to(TEST262_ROOT));
                } except ValueError {
                    peak_name = tp.name;
                }
            }

            try {
                rel = tp.relative_to(TEST262_ROOT);
            } except ValueError {
                rel = tp;
            }

            elapsed_fmt = _fmt_time(elapsed);
            mem_fmt = _fmt_mem(test_kb);

            if result == PASS {
                print(
                    f"[{done:6d}/{total}] ok    {str(rel):<70}  {elapsed_fmt:>8}  {mem_fmt:>8}",
                    flush=True
                );
            } elif result == SKIP {
                if args.verbose {
                    print(
                        f"[{done:6d}/{total}] skip  {str(rel):<70}  ({reason})",
                        flush=True
                    );
                }
            } elif result == HANG {
                hang_note = f"OOM >{args.mem_limit:g}GB"
                    if reason == "oom"
                    else f"killed after {args.timeout}s";
                print(
                    f"[{done:6d}/{total}] TO    {str(rel):<70}  {elapsed_fmt:>8}  {mem_fmt:>8}  ({hang_note})",
                    flush=True
                );
            } else {
                # FAIL
                print(
                    f"[{done:6d}/{total}] FAIL  {str(rel):<70}  {elapsed_fmt:>8}  {mem_fmt:>8}",
                    flush=True
                );
                if detail {
                    for line in detail.splitlines()[:3] {
                        print(f"             {line}");
                    }
                }
            }

            # Write log for non-passing results
            if result in (FAIL, HANG) {
                write_log(tp, result, reason, detail, run_meta);
            }
        }
    }

    # Summary
    suite_elapsed = time.monotonic() - suite_start;
    n_pass = results[PASS];
    n_fail = results[FAIL];
    n_hang = results[HANG];
    n_skip = results[SKIP];
    n_total = n_pass + n_fail + n_hang;
    pass_rate = (100.0 * n_pass / n_total) if n_total > 0 else 0.0;

    # Always record this run so a later --save-baseline can promote it without
    # re-running. Keyed by --filter so different scopes never clobber each other.
    # Perf is compared against an earlier run, not the committed list: the
    # previous run of this scope on this machine (--perf-check, read before
    # this run's log replaces it) or an explicit run log (--perf-baseline).
    perf_records: dict[str, dict[str, any]] | None = None;
    perf_source = "";
    if args.check_baseline and args.perf_baseline {
        perf_records = _load_perf_records(args.perf_baseline);
        perf_source = args.perf_baseline;
        if perf_records is None {
            print(
                f"WARNING: --perf-baseline {args.perf_baseline} is missing or not a "
                "JSON run log; perf check skipped",
                file=sys.stderr
            );
        }
    } elif args.check_baseline and args.perf_check {
        prev_log = _load_run_log(args.filter);
        if prev_log is None {
            print(
                "(perf check skipped — no earlier run log for this scope on this machine)"
            );
        } else {
            perf_records = dict(prev_log.get("tests", {}));
            perf_source = f"the previous run ({_run_log_path(args.filter)})";
        }
    }

    run_log_path = _write_run_log(args.filter, records, args.jobs, run_meta);

    # --save-baseline: refresh this scope's lines of the known-failures list
    if args.save_baseline {
        (n_listed, n_added, n_removed) = _write_known_failures(
            args.save_baseline, records, set(records)
        );
        print(
            f"\nKnown failures saved → {args.save_baseline}  "
            f"({n_listed} listed: +{n_added} / -{n_removed})"
        );
    } else {
        print(f"\nRun log → {run_log_path}");
        print(
            f"  Promote it with: --save-baseline <FILE>"
                + (f" --filter {args.filter!r}" if args.filter else "")
        );
    }

    # --check-baseline: compare against a previously saved baseline
    regression_count = 0;
    if args.check_baseline {
        ran_paths: set[str] = set();
        for tp in tests {
            try {
                ran_paths.add(str(tp.relative_to(TEST262_ROOT)));
            } except ValueError {
                ran_paths.add(str(tp));
            }
        }
        regression_count = _check_baseline(
            args.check_baseline,
            records,
            ran_paths,
            perf_records=perf_records,
            perf_source=perf_source,
            perf_pct=args.perf_pct,
            perf_time_floor_ms=args.perf_time_floor,
            perf_mem_floor_mb=args.perf_mem_floor
        );
    }

    print();
    print("══════════════════════════════════════════════════");
    print(
        f"  Tests: {n_total} total  |  {n_pass} passed  |  {n_fail + n_hang} failed  |  {_fmt_time(
            suite_elapsed
        )} total"
    );
    if n_hang {
        print(f"  (of failures: {n_fail} FAIL, {n_hang} HANG/timeout)");
    }
    if n_skip {
        print(f"  Skipped: {n_skip} (skip manifest)");
    }
    print(f"  Pass rate: {pass_rate:.1f}%");
    if peak_kb is not None {
        print(f"  Peak memory: {_fmt_mem(peak_kb)}  ({peak_name})");
    }
    print("══════════════════════════════════════════════════");

    if failures {
        print(f"\nFailed tests ({min(20, len(failures))} of {len(failures)} shown):");
        for (tp, reason, detail, elapsed, test_kb) in failures[:20] {
            try {
                rel = tp.relative_to(TEST262_ROOT);
            } except ValueError {
                rel = tp;
            }
            print(f"  FAIL  {rel}  [{reason}]  {_fmt_time(elapsed)}");
            if detail {
                print(f"        {detail[:120]}");
            }
        }
    }

    # With a known-failures list the list is the gate: listed failures are
    # expected, so only regressions fail the run. Without one, any failure does.
    if args.check_baseline {
        return 1 if regression_count > 0 else 0;
    }
    return 0 if n_fail == 0 and n_hang == 0 else 1;
}

with entry:__main__ {
    raise SystemExit(main());
}
