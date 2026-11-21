"""Boundary guard for the nogc package carve-out (nogc_resolve_provenance).

Bundled na_stdlib modules outside NOGC_NATIVE_STDLIB are exempt from
ownership enforcement, but enforced modules still call into them: zlib's
compress/decompress round-trip crosses the boundary with heap args, and
socket/os cover the FFI-floor chains (_socket_native, _os_native ->
_replace_native -> _fd_native). No existing test compiled a bundled module
under enforcement before this guard.
"""

import os;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "nogc_bundled_stdlib.jac"
     );

test "bundled na_stdlib modules coexist with nogc enforcement" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True,
            na_gc_mode="none",
            nogc_enforce_all=True,
            no_ir_cache=True,
            skip_native_engine=True
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    assert ir is not None and ir.gen.nogc_enforced , (
        "entry module did not carry the nogc-enforced stamp -- guard is vacuous"
    );
}
