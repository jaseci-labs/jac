"""Structural drift guard for `@jac/runtime` cross-runtime surface alignment.

`@jac/runtime` resolves to two backing files: bare-serve's
`jaclang/runtimelib/client_runtime.cl.jac` (no React/Vite/Bun deps), and
jac-client's `jac_client/plugin/client_runtime.cl.jac` (React + React Router).
User code is portable between the two only if the public surface stays
aligned — issue #5847 is what happens when it drifts.

The surface itself is declared once in `jaclang.runtimelib.client_surface`;
this test extracts top-level `def`/`glob` symbol names from both files and
asserts each runtime honors its slice of that contract:
  * both runtimes export every ALIGNED symbol;
  * bare-serve exports every symbol the compiler emits (so emitted imports
    always resolve);
  * jac-client exports every PRODUCTION (jac-client-only) symbol;
  * the routing subset matches exactly.
Skipped when jac-client isn't installed.
"""

import os;
import re;
import pytest;
import importlib;
import from pathlib { Path }
import jaclang;
import from jaclang.runtimelib.client_surface {
    aligned_surface,
    production_surface,
    routing_surface,
    compiler_emitted_surface
}

def _bareserve_runtime_path -> str {
    runtimelib_dir = os.path.dirname(jaclang.runtimelib.__file__);
    return os.path.join(runtimelib_dir, "client_runtime.cl.jac");
}

def _jac_client_runtime_path -> (str | None) {
    try {
        plugin = importlib.import_module("jac_client.plugin");
    } except ImportError {
        return None;
    }
    paths = `list(getattr(plugin, "__path__", []) or []);
    if not paths {
        return None;
    }
    candidate = os.path.join(paths[0], "client_runtime.cl.jac");
    return candidate if os.path.isfile(candidate) else None;
}

def _extract_symbols(path: str) -> set[str] {
    # Top-level `def NAME` (with or without trailing `(...)`/`->`),
    # `async def NAME(...)`, and `glob[:pub] NAME = ...` (incl. comma chains).
    text = Path(path).read_text();
    names: set[str] = set();
    def_pat = re.compile(r"^(?:async\s+)?def(?::\w+)?\s+(\w+)", re.MULTILINE);
    for m in def_pat.finditer(text) {
        names.add(m.group(1));
    }
    # glob block: `glob[:pub] NAME = ..., NAME = ..., ...;` (multi-line)
    glob_block = re.compile(r"^glob(?::\w+)?\s+(.+?);", re.MULTILINE | re.DOTALL);
    name_eq = re.compile(r"(\w+)\s*=");
    for m in glob_block.finditer(text) {
        for nm in name_eq.findall(m.group(1)) {
            names.add(nm);
        }
    }
    return names;
}

test "bare-serve exposes the aligned and compiler-emitted @jac/runtime surface" {
    bareserve_syms = _extract_symbols(_bareserve_runtime_path());
    missing_from_bareserve = aligned_surface() - bareserve_syms;
    assert not missing_from_bareserve , (
        f"Aligned surface missing from bare-serve runtime: "
        f"{sorted(missing_from_bareserve)}"
    );
    # Every `@jac/runtime` symbol the compiler emits must exist in bare-serve,
    # or apps using that construct emit an import bare-serve can't resolve.
    emitted_missing = compiler_emitted_surface() - bareserve_syms;
    assert not emitted_missing , (
        f"Compiler-emitted runtime symbols missing from bare-serve: "
        f"{sorted(emitted_missing)}"
    );
}

test "jac-client and bare-serve honor the @jac/runtime contract" {
    bareserve_syms = _extract_symbols(_bareserve_runtime_path());
    jac_client_path = _jac_client_runtime_path();
    if not jac_client_path {
        pytest.skip("jac-client plugin not installed");
    }
    jac_client_syms = _extract_symbols(jac_client_path);
    missing_from_jac_client = aligned_surface() - jac_client_syms;
    assert not missing_from_jac_client , (
        f"Aligned surface missing from jac-client runtime: "
        f"{sorted(missing_from_jac_client)}"
    );
    # jac-client must provide every production-tier (jac-client-only) symbol.
    production_missing = production_surface() - jac_client_syms;
    assert not production_missing , (
        f"Production surface missing from jac-client runtime: "
        f"{sorted(production_missing)}"
    );
    # Drift detector: any routing symbol present in one runtime but not the
    # other means user routing code that compiles in one mode breaks in the
    # other.
    routing = routing_surface();
    bareserve_routing = bareserve_syms & routing;
    jac_client_routing = jac_client_syms & routing;
    drift = bareserve_routing.symmetric_difference(jac_client_routing);
    assert not drift , f"Routing surface drift between runtimes: {sorted(drift)}";
}
