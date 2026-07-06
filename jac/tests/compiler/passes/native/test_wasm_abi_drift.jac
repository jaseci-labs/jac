"""Drift tripwires for the hand-synced wasm ABI name sets.

The wasm import contract lives in four places kept in sync by hand:
`_ABI64_ADAPTED` (wasm_build.jac) must mirror the `__jac64_*` adapters defined
in wasm_rt/jac_abi64.c, and `WASM_HOST_ABI` (wasm_host_abi.jac) must mirror
the host functions actually implemented by make_jac_host in
runtimelib/wasm_host.cl.jac. A missed edit surfaces at link time at best and
as a silent `unreachable` trap in the browser at worst; these tests fail it
in CI instead.
"""

import re;

import jaclang;
import from pathlib { Path }
import from jaclang.compiler.passes.native.wasm_build { _ABI64_ADAPTED }
import from jaclang.compiler.passes.native.wasm_host_abi { WASM_HOST_ABI }

glob _PKG_DIR: Path = Path(str(jaclang.__file__)).parent;

test "_ABI64_ADAPTED matches the adapters defined in jac_abi64.c" {
    c_src = (
        _PKG_DIR / "compiler" / "passes" / "native" / "wasm_rt" / "jac_abi64.c"
    ).read_text(
        encoding="utf-8"
    );
    defined = {str(m) for m in re.findall(r"__jac64_(\w+)\s*\(", c_src)};
    adapted = {str(x) for x in _ABI64_ADAPTED};
    assert defined == adapted , (
        f"only in .c: {sorted(defined - adapted)}; "
        f"only in _ABI64_ADAPTED: {sorted(adapted - defined)}"
    );
}

test "WASM_HOST_ABI matches the host functions in wasm_host.cl.jac" {
    host_src = (_PKG_DIR / "runtimelib" / "wasm_host.cl.jac").read_text(
        encoding="utf-8"
    );
    implemented = {str(m) for m in re.findall(r'"(\w+)": lambda', host_src)};
    declared = {str(x) for x in WASM_HOST_ABI};
    assert implemented == declared , (
        f"only in host impl: {sorted(implemented - declared)}; "
        f"only in WASM_HOST_ABI: {sorted(declared - implemented)}"
    );
}
