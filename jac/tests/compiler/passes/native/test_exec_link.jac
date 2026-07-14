import os;
import struct;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.native.elf_linker { ElfLinker }
import from jaclang.compiler.passes.native.macho_linker { MachOLinker }
import from jaclang.cli.commands.nacompile {
    _inject_entry_elf_static,
    _collect_musl_static,
    _musl_lib_dir
}
import jaclang.compiler.passes.native.llvm.binding as llvm;

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures"),
     FIXTURE = "exec_smoke.na.jac";


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


def _emit_for_tm(tm: any, triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(f'target triple = "{triple}"\n');
    mod.triple = triple;
    mod.data_layout = str(tm.target_data);
    return tm.emit_object(mod);
}


def _inject_elf(ir_txt: str) -> str {
    # Linux executables are now fully static against musl, whose crt1.o supplies
    # `_start`; we inject only `main` (the real path nacompile uses).
    return _inject_entry_elf_static(ir_txt);
}


def _musl_ok(triple: str) -> bool {
    return _musl_lib_dir(triple) is not None;
}


def _link_static(relobj: bytes, triple: str, out: str) -> bool {
    # Static-link against vendored musl (libc.a + libzigc.a + compiler-rt + crt),
    # exactly as `jac nacompile` does. Returns False if the musl runtime is not
    # vendored in this environment (callers skip the link/run in that case).
    musl = _collect_musl_static(relobj, triple);
    if musl is None {
        return False;
    }
    (members, crt) = musl;
    return ElfLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=[],
        crt_objects=crt,
        archive_members=members,
        static_link=True
    );
}


def _inject_macho(ir_txt: str) -> str {
    globals_ir = ""
        if "__jac_argc" in ir_txt
        else "@__jac_argc = global i32 0\n@__jac_argv = global ptr null\n\n";
    return ir_txt + (
        "\n; --- injected entry point ---\n" + globals_ir + "define i32 @main(i32 %argc, ptr %argv) {\nentry:\n" + "    store i32 %argc, ptr @__jac_argc\n" + "    store ptr %argv, ptr @__jac_argv\n" + "    call void @jac_entry()\n    ret i32 0\n}\n"
    );
}


def _exec_seg_flags(raw: bytes, sig_off: int) -> (int | None) {
    if struct.unpack_from(">I", raw, sig_off)[0] != 0xFADE0CC0 {
        return None;
    }
    count = struct.unpack_from(">I", raw, sig_off + 8)[0];
    idx = sig_off + 12;
    for _ in range(count) {
        boff = struct.unpack_from(">II", raw, idx)[1];
        cd = sig_off + boff;
        if struct.unpack_from(">I", raw, cd)[0] == 0xFADE0C02 {
            return struct.unpack_from(">Q", raw, cd + 80)[0];
        }
        idx += 8;
    }
    return None;
}


def _codesig_off(raw: bytes) -> int {
    ncmds = struct.unpack_from("<I", raw, 16)[0];
    off = 32;
    for _ in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", raw, off);
        if cmd == 0x1D {
            return struct.unpack_from("<I", raw, off + 8)[0];
        }
        off += cmdsize;
    }
    return 0;
}


test "ELF executable links, runs, and prints through the C ABI" {
    triple = "x86_64-unknown-linux-gnu";
    relobj = _emit_object(_inject_elf(_compile_ir(FIXTURE, triple)), triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "exec_smoke");
    if not _musl_ok(triple) {
        return;
    }
    ok = _link_static(relobj, triple, out);
    assert ok , "ElfLinker static link returned False";
    raw = Path(out).read_bytes();
    assert raw[:4] == b"\x7fELF" , "not an ELF image";
    e_type = struct.unpack_from("<H", raw, 16)[0];
    assert e_type == 2 , f"expected ET_EXEC (2), got {e_type}";
    # Clean break: the executable must be fully static (no PT_INTERP).
    phoff = struct.unpack_from("<Q", raw, 32)[0];
    phnum = struct.unpack_from("<H", raw, 56)[0];
    has_interp = False;
    for _pi in range(phnum) {
        p_type = struct.unpack_from("<I", raw, phoff + _pi * 56)[0];
        if p_type == 3 {
            has_interp = True;
        }
    }
    assert not has_interp , "static executable must not request a dynamic interpreter";

    if sys.platform.startswith("linux") and ("x86_64" in llvm.get_default_triple()) {
        res = subprocess.run([out], capture_output=True, timeout=30);
        assert res.returncode == 0 , f"exec exited {res.returncode}, stderr={res.stderr}";
        assert b"JAC_EXEC_OK" in res.stdout , f"missing marker in stdout: {res.stdout}";
        assert b"42" in res.stdout , f"missing result in stdout: {res.stdout}";
    }
}


test "multiple `with entry` blocks emit a single jac_entry (issue #6660)" {
    ir_txt = _compile_ir("multi_entry.na.jac", llvm.get_default_triple());
    n = ir_txt.count('define void @"jac_entry"');
    assert n == 1 , f"expected exactly one jac_entry definition, got {n}";
}


test "concatenated `with entry` blocks run in source order (issue #6660)" {
    triple = llvm.get_default_triple();

    if sys.platform.startswith("linux") and ("x86_64" in triple) and _musl_ok(triple) {
        relobj = _emit_object(
            _inject_elf(_compile_ir("multi_entry.na.jac", triple)), triple
        );
        d = tempfile.mkdtemp();
        out = os.path.join(d, "multi_entry");
        ok = _link_static(relobj, triple, out);
        assert ok , "ElfLinker static link returned False";
        res = subprocess.run([out], capture_output=True, timeout=30);
        assert res.returncode == 0 , f"exec exited {res.returncode}, stderr={res.stderr}";
        i = res.stdout.find(b"FIRST");
        j = res.stdout.find(b"SECOND");
        assert i != -1 and j != -1 , f"missing markers in stdout: {res.stdout}";
        assert i < j , f"entry blocks ran out of order: {res.stdout}";
    }
}


test "a terminating `with entry` block stops later blocks (issue #6660)" {
    triple = llvm.get_default_triple();
    ir_txt = _compile_ir("multi_entry_terminator.na.jac", triple);

    n = ir_txt.count('define void @"jac_entry"');
    assert n == 1 , f"expected exactly one jac_entry definition, got {n}";

    if sys.platform.startswith("linux") and ("x86_64" in triple) and _musl_ok(triple) {
        relobj = _emit_object(_inject_elf(ir_txt), triple);
        d = tempfile.mkdtemp();
        out = os.path.join(d, "multi_entry_terminator");
        ok = _link_static(relobj, triple, out);
        assert ok , "ElfLinker static link returned False";
        res = subprocess.run([out], capture_output=True, timeout=30);

        assert res.returncode != 0 , f"expected non-zero exit from uncaught raise, got 0: {res.stdout}";
        assert b"SHOULD_NOT_RUN" not in res.stdout , f"second block ran after a terminating first block: {res.stdout}";
    }
}


test "glob-init runs before every `with entry` block (issue #6660)" {
    triple = llvm.get_default_triple();
    ir_txt = _compile_ir("multi_entry_glob.na.jac", triple);

    assert ir_txt.count('define void @"jac_entry"') == 1 , "expected exactly one jac_entry";
    assert "__jac_glob_init" in ir_txt , "expected a __jac_glob_init call in jac_entry";

    if sys.platform.startswith("linux") and ("x86_64" in triple) and _musl_ok(triple) {
        relobj = _emit_object(_inject_elf(ir_txt), triple);
        d = tempfile.mkdtemp();
        out = os.path.join(d, "multi_entry_glob");
        ok = _link_static(relobj, triple, out);
        assert ok , "ElfLinker static link returned False";
        res = subprocess.run([out], capture_output=True, timeout=30);

        assert res.returncode == 0 , f"exec exited {res.returncode}, stderr={res.stderr}";
        i = res.stdout.find(b"A_RAN");
        j = res.stdout.find(b"B_RAN");
        assert i != -1 and j != -1 , f"missing markers in stdout: {res.stdout}";
        assert i < j , f"entry blocks ran out of order: {res.stdout}";
    }
}


test "a cross-module raise unwinds to the importer's handler (issue #7013)" {
    triple = llvm.get_default_triple();
    if sys.platform.startswith("linux") and ("x86_64" in triple) and _musl_ok(triple) {
        relobj = _emit_object(
            _inject_elf(_compile_ir("xmod_exc_main.na.jac", triple)), triple
        );
        d = tempfile.mkdtemp();
        out = os.path.join(d, "xmod_exc_main");
        ok = _link_static(relobj, triple, out);
        assert ok , "ElfLinker static link returned False";
        res = subprocess.run([out], capture_output=True, timeout=30);
        assert res.returncode == 0 , f"cross-module raise did not unwind (exit {res.returncode}); stderr={res.stderr}";
        assert b"XMOD_CAUGHT" in res.stdout , f"handler did not catch cross-module raise: {res.stdout}";
        assert b"DONE_OK" in res.stdout , f"program did not continue past the handler: {res.stdout}";
        assert b"NO_RAISE" not in res.stdout , f"raise did not fire: {res.stdout}";
    }
}


test "Mach-O executable has MH_EXECUTE filetype and an LC_MAIN entry" {
    triple = "x86_64-apple-darwin";
    relobj = _emit_object(_inject_macho(_compile_ir(FIXTURE, triple)), triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "exec_smoke");
    ok = MachOLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        shared=False
    );
    assert ok , "MachOLinker.link(shared=False) returned False";
    raw = Path(out).read_bytes();
    assert struct.unpack_from("<I", raw, 0)[0] == 0xFEEDFACF , "not a Mach-O 64 image";
    filetype = struct.unpack_from("<I", raw, 12)[0];
    assert filetype == 2 , f"expected MH_EXECUTE (2), got {filetype}";

    ncmds = struct.unpack_from("<I", raw, 16)[0];
    off = 32;
    has_main = False;
    for _ in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", raw, off);
        if cmd == 0x80000028 {
            has_main = True;
            break;
        }
        off += cmdsize;
    }
    assert has_main , "missing LC_MAIN entry command";
}


test "Mach-O arm64 executable is ad-hoc signed with CS_EXECSEG_MAIN_BINARY" {
    triple = "arm64-apple-darwin";
    relobj = _emit_object(_inject_macho(_compile_ir(FIXTURE, triple)), triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "exec_smoke_arm64");
    ok = MachOLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        shared=False
    );
    assert ok , "MachOLinker.link(shared=False) returned False for arm64";
    raw = Path(out).read_bytes();
    assert struct.unpack_from("<I", raw, 12)[0] == 2 , "expected MH_EXECUTE (2)";
    sig_off = _codesig_off(raw);
    assert sig_off != 0 , "arm64 executable is not code-signed";
    flags = _exec_seg_flags(raw, sig_off);
    assert flags == 0x1 , f"executable execSegFlags must be CS_EXECSEG_MAIN_BINARY (0x1), got {flags}";
}


test "AOT executable code model emits COFF, not ELF, on a Windows triple" {
    import jaclang.compiler.passes.native.llvm.binding.targets as _tgt;
    import from unittest.mock { patch }
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    win_triple = "x86_64-pc-windows-msvc";
    target = llvm.Target.from_triple(win_triple);
    with patch.object(_tgt.os, "name", "nt") {
        bad_tm = target.create_target_machine();
        assert bad_tm.triple.endswith("-elf") , f"expected llvmlite to append -elf under jitdefault, got {bad_tm.triple}";
        assert _emit_for_tm(bad_tm, bad_tm.triple).startswith(b"\x7fELF") , "jitdefault on a Windows host should emit an ELF object (the #6819 bug)";
        good_tm = target.create_target_machine(opt=2, codemodel="large");
        assert not good_tm.triple.endswith("-elf") , f"pinned code model still produced an ELF triple: {good_tm.triple}";
        good_obj = _emit_for_tm(good_tm, good_tm.triple);
        assert not good_obj.startswith(b"\x7fELF") , "pinned code model still emitted an ELF object";
        assert good_obj[:2] == b"\x64\x86" , f"expected a COFF x86_64 object (machine 0x8664), got header {good_obj[:4]!r}";
    }
}
