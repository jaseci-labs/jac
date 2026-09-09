"""Build the CEF dispatch shim + subprocess binary and audit the artifacts.

The suite home of ci.yml's `test-cef-build` job: nacompile the dispatch
shared object and helper the way `jac build` does for a desktop app with
`[desktop] engine = "cef"`, then hold
the .so to its ABI contract -- the three dispatch exports present, an
$ORIGIN runpath so the bundle relocates, and no missing shared-library
dependencies beyond the intentionally absent libcef stub. Compile-only
binding drift is covered by `test_cef_binding.jac`; this one proves the
shipped build path end to end.
"""

import subprocess;
import sys;
import from pathlib { Path }
import from jaclang.testing.requires { require_tool }
import from importlib.util { find_spec }
import from jaclang.client.targets.desktop.desktop_build {
    build_cef_dispatch,
    build_cef_subprocess
}


def _run(cmd: list[str]) -> str {
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600);
    return (proc.stdout or "") + (proc.stderr or "");
}


test "cef dispatch builds with exports, $ORIGIN runpath, and clean deps" {
    if sys.platform != "linux" {
        testskip("CEF dispatch build audit is a Linux (ELF) check");
    }
    require_tool("nm", "readelf", "ldd");
    spec = find_spec("jaclang.client.targets.desktop.desktop_build");
    assert spec is not None and spec.origin is not None;
    cef_dir = Path(spec.origin).parent / "native" / "cef";
    assert cef_dir.is_dir() , f"cef sources missing at {cef_dir}";
    dispatch = build_cef_dispatch(cef_dir);
    assert dispatch.is_file() , f"dispatch build produced nothing at {dispatch}";
    helper = build_cef_subprocess(cef_dir);
    assert helper.is_file() , f"subprocess build produced nothing at {helper}";

    exports = _run(["nm", "-D", str(dispatch)]);
    for sym in (
        "cef_dispatch_startup",
        "cef_dispatch_execute_process",
        "cef_platform_bootstrap",

    ) {
        assert sym in exports , f"{dispatch.name} does not export {sym}";
    }

    dynamic = _run(["readelf", "-d", str(dispatch)]);
    assert any(
        (("RUNPATH" in line) or ("RPATH" in line)) and ("$ORIGIN" in line)
        for line in dynamic.splitlines()
    ) , f"{dispatch.name} lacks an $ORIGIN runpath:\n{dynamic}";

    missing = [
        line.strip()
        for line in _run(["ldd", str(dispatch)]).splitlines()
        if ("not found" in line) and ("libcef" not in line)
    ];
    assert not missing , f"unexpected missing deps: {missing}";
}
