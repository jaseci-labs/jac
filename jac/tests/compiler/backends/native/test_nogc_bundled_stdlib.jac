"""Boundary guard for the nogc package carve-out (nogc_resolve_provenance).

Bundled na_stdlib modules outside NOGC_NATIVE_STDLIB are exempt from
ownership enforcement, but enforced modules still call into them: zlib's
compress/decompress round-trip crosses the boundary with heap args, and
socket/os cover the FFI-floor chains (_socket_native, _os_native ->
_replace_native -> _fd_native). No existing test compiled a bundled module
under enforcement before this guard.
"""

import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support { compile_native_ir }

test "bundled na_stdlib modules coexist with nogc enforcement" {
    fx = compile_native_ir(
        "nogc_bundled_stdlib.jac",
        options=CompileOptions(aot_mode=True, na_gc_mode="none", nogc_enforce_all=True)
    );
    assert fx.iface() is not None and fx.iface().headerless , (
        "entry module was not built headerless under enforcement -- guard is vacuous"
    );
}
