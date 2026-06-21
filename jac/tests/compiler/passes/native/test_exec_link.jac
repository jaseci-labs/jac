"""Direct tests for the pure-Jac linkers' executable path (build_executable).

Before this, `jac nacompile` was the only thing that exercised
ElfLinker/MachOLinker.build_executable(): the JIT-based native suite never
touches the linkers, and test_shared_lib only covers build_shared_object(). So
the executable layout + relocation path had no direct regression coverage.

These tests link a real relocatable object straight through
ElfLinker.link / MachOLinker.link with shared=False, injecting `main` + the
platform entry exactly as the nacompile CLI does. The ELF executable is run for
real on a Linux x86_64 host (exit code + stdout); the Mach-O executable is
validated structurally (MH_EXECUTE + LC_MAIN), since it cannot run on Linux.
"""

import os;
import struct;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.native.elf_linker { ElfLinker }
import from jaclang.compiler.passes.native.macho_linker { MachOLinker }
import llvmlite.binding as llvm;

glob FIXTURES = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "native" / "fixtures"
     ),
     FIXTURE = "exec_smoke.na.jac";


# ─── helpers ─────────────────────────────────────────────────────────────────
"""Compile the fixture for `triple` and return its LLVM IR text."""
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


"""Assemble `ir_txt` for `triple` into a relocatable object using the default
(fixed-base) model — exactly what nacompile emits for an executable. Forcing
`pic` here would emit GOT-relative data refs that the fixed-base ET_EXEC layout
mislinks into a segfaulting binary, so this mirrors the real CLI path."""
def _emit_object(ir_txt: str, triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(ir_txt);
    mod.verify();
    tm = llvm.Target.from_triple(triple).create_target_machine(opt=2);
    return tm.emit_object(mod);
}


"""Emit a minimal relocatable object for `triple` through an explicit target
machine `tm` and return its leading bytes. Lets a test assert the on-disk
object format (COFF vs ELF) a given code model produces, since LLVM picks the
format from the triple — so a Linux runner emits a real COFF object for a
windows-msvc triple and a real ELF object for a '...-elf' one."""
def _emit_for_tm(tm: any, triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(f'target triple = "{triple}"\n');
    mod.triple = triple;
    mod.data_layout = str(tm.target_data);
    return tm.emit_object(mod);
}


"""Inject `main` + `_start` for ELF — mirrors nacompile's _inject_entry_elf."""
def _inject_elf(ir_txt: str) -> str {
    globals_ir = ""
        if "__jac_argc" in ir_txt
        else "@__jac_argc = global i32 0\n@__jac_argv = global ptr null\n\n";
    exit_decl = ""
        if ("@exit" in ir_txt or '@"exit"' in ir_txt)
        else "declare void @exit(i32) noreturn\n\n";
    return ir_txt + (
        "\n; --- injected entry point ---\n" + globals_ir + exit_decl + "declare ptr @llvm.stacksave()\n\n" + "define i32 @main(i32 %argc, ptr %argv) {\nentry:\n" + "    store i32 %argc, ptr @__jac_argc\n" + "    store ptr %argv, ptr @__jac_argv\n" + "    call void @jac_entry()\n    ret i32 0\n}\n\n" + "define void @_start() naked noreturn {\nentry:\n" + "    %sp = call ptr @llvm.stacksave()\n" + "    %argc = load i32, ptr %sp\n" + "    %argv = getelementptr i8, ptr %sp, i64 8\n" + "    %ret = call i32 @main(i32 %argc, ptr %argv)\n" + "    call void @exit(i32 %ret)\n    unreachable\n}\n"
    );
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


# ─── tests ───────────────────────────────────────────────────────────────────
test "ELF executable links, runs, and prints through the C ABI" {
    triple = llvm.get_default_triple();
    relobj = _emit_object(_inject_elf(_compile_ir(FIXTURE, triple)), triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "exec_smoke");
    ok = ElfLinker.link(
        obj_bytes=relobj, output_path=out, needed_libs=["libc.so.6"], shared=False
    );
    assert ok , "ElfLinker.link(shared=False) returned False";
    raw = Path(out).read_bytes();
    assert raw[:4] == b"\x7fELF" , "not an ELF image";
    e_type = struct.unpack_from("<H", raw, 16)[0];
    assert e_type == 2 , f"expected ET_EXEC (2), got {e_type}";

    # Only a Linux x86_64 host can execute the produced ELF.
    if sys.platform.startswith("linux") and ("x86_64" in triple) {
        res = subprocess.run([out], capture_output=True, timeout=30);
        assert res.returncode == 0 , f"exec exited {res.returncode}, stderr={res.stderr}";
        assert b"JAC_EXEC_OK" in res.stdout , f"missing marker in stdout: {res.stdout}";
        assert b"42" in res.stdout , f"missing result in stdout: {res.stdout}";
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
    # Scan load commands for LC_MAIN — the executable entry-point command.
    ncmds = struct.unpack_from("<I", raw, 16)[0];
    off = 32;
    has_main = False;
    for _ in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", raw, off);
        if cmd == 0x80000028 {  # LC_MAIN
            has_main = True;
            break;
        }
        off += cmdsize;
    }
    assert has_main , "missing LC_MAIN entry command";
}


# ─── #6819: Windows AOT must emit COFF, not ELF ───────────────────────────────
# llvmlite appends "-elf" to the triple only when os.name == "nt" and
# codemodel == "jitdefault" (its MCJIT-on-Windows workaround). nacompile's AOT
# executable branch and NaIRGenPass.postinit therefore pin an explicit code
# model so a Windows host emits a COFF object for a COFF target rather than a
# bogus ELF one. We simulate a Windows host on any runner (patch os.name) and
# assert on the *emitted object*, not just the triple string: LLVM selects the
# object format from the triple, so this catches the regression at the real
# emit seam without a Windows runner. patch.object auto-restores os.name even
# if an assertion below raises.
test "AOT executable code model emits COFF, not ELF, on a Windows triple" {
    import llvmlite.binding.targets as _tgt;
    import from unittest.mock { patch }
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    win_triple = "x86_64-pc-windows-msvc";
    target = llvm.Target.from_triple(win_triple);
    with patch.object(_tgt.os, "name", "nt") {
        # The default jitdefault model demonstrates the quirk this guards
        # against: the triple gains "-elf" and LLVM emits an ELF object.
        bad_tm = target.create_target_machine();
        assert bad_tm.triple.endswith("-elf") , f"expected llvmlite to append -elf under jitdefault, got {bad_tm.triple}";
        assert _emit_for_tm(bad_tm, bad_tm.triple).startswith(b"\x7fELF") , "jitdefault on a Windows host should emit an ELF object (the #6819 bug)";
        # nacompile pins codemodel="large" for the executable branch (postinit
        # does the same for the module triple): the triple stays COFF and LLVM
        # emits a real COFF object (x86_64 machine 0x8664 -> little-endian 64 86).
        good_tm = target.create_target_machine(opt=2, codemodel="large");
        assert not good_tm.triple.endswith("-elf") , f"pinned code model still produced an ELF triple: {good_tm.triple}";
        good_obj = _emit_for_tm(good_tm, good_tm.triple);
        assert not good_obj.startswith(b"\x7fELF") , "pinned code model still emitted an ELF object";
        assert good_obj[:2] == b"\x64\x86" , f"expected a COFF x86_64 object (machine 0x8664), got header {good_obj[:4]!r}";
    }
}
