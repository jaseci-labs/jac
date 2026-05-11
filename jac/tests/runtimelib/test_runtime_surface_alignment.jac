"""Structural drift guard for `@jac/runtime` cross-runtime surface alignment.

`@jac/runtime` resolves to two backing files: bare-serve's
`jaclang/runtimelib/client_runtime.cl.jac` (no React/Vite/Bun deps), and
jac-client's `jac_client/plugin/client_runtime.cl.jac` (React + React Router).
User code is portable between the two only if the public surface stays
aligned — issue #5847 is what happens when it drifts.

This test extracts top-level `def`/`glob` symbol names from both files and
asserts that the routing/hooks/walker surface bare-serve advertises is also
exported by jac-client. Skipped when jac-client isn't installed.
"""

import os;
import re;
import pytest;
import importlib;
import from pathlib { Path }
import jaclang;

glob ALIGNED_SURFACE = {
     # React Router v6-shaped routing. jac-client maps `Router` to
     # ReactRouterBrowserRouter, so the same name covers both modes.
     "Router","Routes","Route","Link","Navigate","Outlet","useNavigate","useLocation","useParams","useRouter","navigate",
     # Hook aliases (different semantics across runtimes, but same names)
     "useState","useEffect",
     # JSX factory
     "__jacJsx",
     # Walker / function calls
     "__jacSpawn","jacSpawn","__jacCallFunction",
     # Auth
     "jacSignup","jacLogin","jacLogout","jacIsLoggedIn",
     # Browser API shims
     "__getLocalStorage","__setLocalStorage","__removeLocalStorage",
     # Error reporting
     "__jacReportError","__jacInstallErrorHandlers","__jacReactErrorHandler"};

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

test "bare-serve and jac-client expose the aligned @jac/runtime surface" {
    bareserve_syms = _extract_symbols(_bareserve_runtime_path());
    missing_from_bareserve = ALIGNED_SURFACE - bareserve_syms;
    assert not missing_from_bareserve , (
        f"Aligned surface missing from bare-serve runtime: "
        f"{sorted(missing_from_bareserve)}"
    );
    jac_client_path = _jac_client_runtime_path();
    if not jac_client_path {
        pytest.skip("jac-client plugin not installed");
    }
    jac_client_syms = _extract_symbols(jac_client_path);
    missing_from_jac_client = ALIGNED_SURFACE - jac_client_syms;
    assert not missing_from_jac_client , (
        f"Aligned surface missing from jac-client runtime: "
        f"{sorted(missing_from_jac_client)}"
    );
    # Drift detector: anything bare-serve adds but jac-client lacks (or vice
    # versa) within the routing/hooks subset means user code that compiles in
    # one mode breaks in the other.
    routing_subset = {"Router","Routes","Route","Link","Navigate","Outlet","useNavigate","useLocation","useParams","useRouter","navigate"};
    bareserve_routing = bareserve_syms & routing_subset;
    jac_client_routing = jac_client_syms & routing_subset;
    drift = bareserve_routing.symmetric_difference(jac_client_routing);
    assert not drift , f"Routing surface drift between runtimes: {sorted(drift)}";
}
