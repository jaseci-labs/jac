"""End-to-end gate for static C-archive linking on Mach-O (#6978 Phase 0.1a).

Compiles a tiny `na` program that calls `lzma_crc32` (an extern C symbol),
selects the defining member out of the bundled `liblzma.a` via the ar reader,
merges it into the binary through MachOLinker's new multi-object path, and runs
the result -- proving the floor links statically into the executable instead of
being a runtime dylib dependency. Gated to macOS arm64 (where the binary can run
and the bundled archives are TLS-free); skips elsewhere or when no pbs build is
staged.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.native.macho_linker { MachOLinker }
import from jaclang.compiler.passes.native.linker_common { select_ar_members }
import jaclang.compiler.passes.native.llvm.binding as llvm;

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");


"""Compile a fixture for `triple` and return its LLVM IR text (mirrors the
nacompile CLI AOT path; see test_exec_link)."""
def _compile_ir(fixture: str, triple: str) -> str {
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = triple;
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, fixture),
            options=CompileOptions(aot_mode=True, type_check=False)
        );
        assert not prog.errors_had , f"compile errors: {[
            str(e) for e in prog.errors_had
        ]}";
        ir_txt = str(ir.gen.llvm_ir);
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
    return ir_txt;
}


"""Assemble IR into a relocatable object using the fixed-base large code model,
exactly as nacompile does for an executable."""
def _emit_object(ir_txt: str, triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(ir_txt);
    mod.verify();
    tm = llvm.Target.from_triple(triple).create_target_machine(
        opt=2, codemodel="large"
    );
    return tm.emit_object(mod);
}


"""Inject `main` for Mach-O — mirrors nacompile's _inject_entry_macho."""
def _inject_macho(ir_txt: str) -> str {
    globals_ir = ""
        if "__jac_argc" in ir_txt
        else "@__jac_argc = global i32 0\n@__jac_argv = global ptr null\n\n";
    return ir_txt + (
        "\n; --- injected entry point ---\n" + globals_ir + "define i32 @main(i32 %argc, ptr %argv) {\nentry:\n" + "    store i32 %argc, ptr @__jac_argc\n" + "    store ptr %argv, ptr @__jac_argv\n" + "    call void @jac_entry()\n    ret i32 0\n}\n"
    );
}


"""Locate a bundled archive by name from any pbs build, or None."""
def _find_bundled(libname: str) -> (str | None) {
    jac_dir = Path(__file__).resolve().parents[4];
    hits = list(jac_dir.glob(f".pbs-build/*/python/build/lib/{libname}"));
    return str(hits[0]) if hits else None;
}


test "Mach-O: static-link lzma_crc32 from liblzma.a, run, verify (#6978 0.1a)" {
    triple = llvm.get_default_triple();
    # Only macOS arm64 can both run the result and offers TLS-free floor archives.
    if not (sys.platform == "darwin" and "arm64" in triple) {
        return;
    }
    archive_path = _find_bundled("liblzma.a");
    if archive_path is None {
        return;  # no pbs build staged here
    }
    archive = Path(archive_path).read_bytes();

    # Pull only the member(s) that define lzma_crc32 (a 0-undefined leaf).
    members = select_ar_members(archive, ["_lzma_crc32"]);
    assert members , "ar selection found no member defining _lzma_crc32";
    member_bytes = [m.data for m in members];

    relobj = _emit_object(
        _inject_macho(_compile_ir("static_archive_crc32.na.jac", triple)), triple
    );
    d = tempfile.mkdtemp();
    out = os.path.join(d, "crc32_static");
    ok = MachOLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        shared=False,
        archive_members=member_bytes
    );
    assert ok , "MachOLinker.link with archive_members returned False";

    res = subprocess.run([out], capture_output=True, timeout=30);
    assert res.returncode == 0 , (f"exec exited {res.returncode}, stderr={res.stderr}");
    # CRC-32/ISO of "123456789" == 0xCBF43926 == 3421780262.
    assert b"3421780262" in res.stdout , f"unexpected output: {res.stdout}";
}


test "Mach-O: static-link XML_ExpatVersion from libexpat.a (multi-member) (#6978 0.1a)" {
    triple = llvm.get_default_triple();
    if not (sys.platform == "darwin" and "arm64" in triple) {
        return;
    }
    archive_path = _find_bundled("libexpat.a");
    if archive_path is None {
        return;
    }
    archive = Path(archive_path).read_bytes();

    # Transitive closure pulls multiple cross-referencing members (xmlparse +
    # xmltok + xmlrole + an entropy helper), exercising member<->member symbol
    # resolution and GOT references to libc.
    members = select_ar_members(archive, ["_XML_ExpatVersion"]);
    assert len(members) > 1 , f"expected a multi-member closure, got {len(members)}";
    member_bytes = [m.data for m in members];

    relobj = _emit_object(
        _inject_macho(_compile_ir("static_archive_expat.na.jac", triple)), triple
    );
    d = tempfile.mkdtemp();
    out = os.path.join(d, "expat_static");
    ok = MachOLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        shared=False,
        archive_members=member_bytes
    );
    assert ok , "MachOLinker.link with archive_members returned False";

    res = subprocess.run([out], capture_output=True, timeout=30);
    assert res.returncode == 0 , (f"exec exited {res.returncode}, stderr={res.stderr}");
    assert b"expat_" in res.stdout , f"unexpected output: {res.stdout}";
}
