"""Tests for the PE/COFF (Windows) link path.

These exercise the pure-Jac `PeLinker`'s relocatable COFF object -> runnable
PE32+ executable transformation (segment layout at a fixed ImageBase, import
directory + IAT + import thunks, relocation application, entry-point wiring)
and the `nacompile --target windows` CLI -- not LLVM codegen, which the rest
of the native suite covers. One representative fixture drives the linker's
whole transform: it pulls in the libc import surface (puts/printf/snprintf/
malloc/free), a data segment, and floating point.

The produced .exe is validated structurally (it parses as a well-formed
PE32+ image whose imports resolve to msvcrt.dll). Actually running the binary
requires a Windows host (or WSL interop) and is not assumed here.
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
import from jaclang.compiler.passes.native.pe_linker { PeLinker }
import llvmlite.binding as llvm;

glob FIXTURES = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "native" / "fixtures"
     ),
     WIN_TRIPLE = "x86_64-pc-windows-msvc",
     FIXTURE = "pe_smoke.na.jac";


# ─── helpers ─────────────────────────────────────────────────────────────────
"""Inject the PE entry stub the way nacompile does (main + _jac_win_start +
the _fltused / __getmainargs / exit declarations)."""
def _inject_pe_entry(ir: str) -> str {
    glob_ir = ""
        if "__jac_argc" in ir
        else ('@__jac_argc = global i32 0\n@__jac_argv = global ptr null\n\n');
    exit_decl = ""
        if ("@exit" in ir or '@"exit"' in ir)
        else 'declare void @exit(i32)\n\n';
    fltused = "" if "@_fltused" in ir else '@_fltused = global i32 0\n\n';
    return ir + (
        '\n' + glob_ir + exit_decl + fltused + 'declare i32 @__getmainargs(ptr, ptr, ptr, i32, ptr)\n\n' + 'define i32 @main(i32 %argc, ptr %argv) {\n' + 'entry:\n' + '  store i32 %argc, ptr @__jac_argc\n' + '  store ptr %argv, ptr @__jac_argv\n' + '  call void @jac_entry()\n' + '  ret i32 0\n' + '}\n\n' + 'define void @_jac_win_start() {\n' + 'entry:\n' + '  %argc.addr = alloca i32\n' + '  %argv.addr = alloca ptr\n' + '  %env.addr = alloca ptr\n' + '  %si = alloca i32\n' + '  store i32 0, ptr %si\n' + '  %gr = call i32 @__getmainargs(ptr %argc.addr, ptr %argv.addr, ptr %env.addr, i32 0, ptr %si)\n' + '  %ac = load i32, ptr %argc.addr\n' + '  %av = load ptr, ptr %argv.addr\n' + '  %r = call i32 @main(i32 %ac, ptr %av)\n' + '  call void @exit(i32 %r)\n' + '  ret void\n' + '}\n'
    );
}


"""Compile a fixture to a relocatable COFF object the way nacompile does."""
def emit_coff_object(fixture: str) -> bytes {
    prev = os.environ.get("JAC_NATIVE_TARGET", None);
    os.environ["JAC_NATIVE_TARGET"] = WIN_TRIPLE;
    try {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(FIXTURES, fixture),
            options=CompileOptions(aot_mode=True, type_check=False)
        );
        assert not prog.errors_had , f"compile errors: {[
            str(e) for e in prog.errors_had
        ]}";
        src = _inject_pe_entry(str(ir.gen.llvm_ir));
        llvm.initialize_all_targets();
        llvm.initialize_all_asmprinters();
        mod = llvm.parse_assembly(src);
        mod.verify();
        # codemodel="large" (not the default "jitdefault"): on a Windows host
        # llvmlite appends "-elf" to the triple under jitdefault, so emit_object
        # would produce an ELF object for this COFF target and PeLinker would
        # reject it. Pinning the model keeps the windows-msvc triple intact and
        # mirrors nacompile's executable emit branch. See the dedicated guard
        # test in test_exec_link.jac (#6819).
        tm = llvm.Target.from_triple(WIN_TRIPLE).create_target_machine(
            opt=2, codemodel="large"
        );
        pto = llvm.create_pipeline_tuning_options(speed_level=2, size_level=0);
        pb = llvm.create_pass_builder(tm, pto);
        mpm = pb.getModulePassManager();
        mpm.add_internalize_pass();
        mpm.run(mod, pb);
        relobj = tm.emit_object(mod);
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
    return relobj;
}


"""Link a COFF object into a PE image and return its bytes."""
def link_pe(relobj: bytes) -> bytes {
    d = tempfile.mkdtemp();
    out = os.path.join(d, "a.exe");
    ok = PeLinker.link(obj_bytes=relobj, output_path=out);
    assert ok , "PeLinker.link returned False";
    return Path(out).read_bytes();
}


"""Map an image RVA to a file offset using the section table."""
def _rva_to_off(b: bytes, secs: list, rva: int) -> int {
    for (va, vsz, foff, rsz) in secs {
        if rva >= va and rva < va + max(vsz, rsz) {
            return foff + (rva - va);
        }
    }
    return -1;
}


"""Read a NUL-terminated ASCII string at a file offset."""
def _cstr(b: bytes, off: int) -> str {
    end = b.index(b"\x00", off);
    return b[off:end].decode("latin1");
}


"""Parse a PE32+ image into a dict of the fields the tests assert on."""
def parse_pe(b: bytes) -> dict {
    assert b[0:2] == b"MZ" , "missing MZ signature";
    e_lfanew = struct.unpack_from("<I", b, 0x3C)[0];
    assert b[e_lfanew:e_lfanew + 4] == b"PE\x00\x00" , "missing PE signature";
    (machine, nsec) = struct.unpack_from("<HH", b, e_lfanew + 4);
    opt_sz = struct.unpack_from("<H", b, e_lfanew + 4 + 16)[0];
    opt = e_lfanew + 4 + 20;
    magic = struct.unpack_from("<H", b, opt)[0];
    entry_rva = struct.unpack_from("<I", b, opt + 16)[0];
    subsystem = struct.unpack_from("<H", b, opt + 68)[0];
    dd = opt + 112;
    (imp_rva, imp_sz) = struct.unpack_from("<II", b, dd + 1 * 8);
    # section table
    st = opt + opt_sz;
    secs: list = [];
    sec_names: list = [];
    for i in range(nsec) {
        o = st + i * 40;
        nm = b[o:o + 8].rstrip(b"\x00").decode("latin1");
        (vsz, va, rsz, foff) = struct.unpack_from("<IIII", b, o + 8);
        secs.append((va, vsz, foff, rsz));
        sec_names.append(nm);
    }
    # import descriptors -> dll -> [imported names]
    imports: dict = {};
    base = _rva_to_off(b, secs, imp_rva);
    di = 0;
    while base >= 0 {
        o = base + di * 20;
        (ilt, _ts, _fc, name_rva, _iat) = struct.unpack_from("<IIIII", b, o);
        if ilt == 0 and name_rva == 0 {
            break;
        }
        dll = _cstr(b, _rva_to_off(b, secs, name_rva));
        names: list = [];
        toff = _rva_to_off(b, secs, ilt);
        j = 0;
        while True {
            thunk = struct.unpack_from("<Q", b, toff + j * 8)[0];
            if thunk == 0 {
                break;
            }
            # by-name import: low 31 bits are the hint/name RVA (hint is 2 bytes)
            hn = _rva_to_off(b, secs, thunk & 0x7FFFFFFF);
            names.append(_cstr(b, hn + 2));
            j += 1;
        }
        imports[dll] = names;
        di += 1;
    }
    return {
        "machine": machine,
        "nsec": nsec,
        "magic": magic,
        "entry_rva": entry_rva,
        "subsystem": subsystem,
        "sec_names": sec_names,
        "secs": secs,
        "imports": imports
    };
}


# ─── tests ───────────────────────────────────────────────────────────────────
test "linker emits a well-formed PE32+ image" {
    pe = parse_pe(link_pe(emit_coff_object(FIXTURE)));
    assert pe["machine"] == 0x8664;  # IMAGE_FILE_MACHINE_AMD64
    assert pe["magic"] == 0x20B;  # PE32+
    assert pe["subsystem"] == 3;  # IMAGE_SUBSYSTEM_WINDOWS_CUI
    for want in [".text", ".rdata", ".data", ".idata"] {
        assert want in pe["sec_names"] , f"missing section {want}";
    }
    # entry point falls inside the .text section's virtual range
    text_i = pe["sec_names"].index(".text");
    (tva, tvsz, _tf, trsz) = pe["secs"][text_i];
    assert pe["entry_rva"] >= tva and pe["entry_rva"] < tva + max(tvsz, trsz);
}

test "imports resolve to msvcrt.dll via the import directory" {
    pe = parse_pe(link_pe(emit_coff_object(FIXTURE)));
    assert "msvcrt.dll" in pe["imports"] , f"DLLs: {list(pe['imports'].keys())}";
    syms = [];
    for (_dll, names) in pe["imports"].items() {
        syms += names;
    }
    # the entry stub always needs exit + __getmainargs; the fixture prints
    for need in ["exit", "__getmainargs", "puts"] {
        assert need in syms , f"missing import {need} in {syms}";
    }
    # the glibc-only malloc_usable_size must be aliased to msvcrt's _msize
    assert "malloc_usable_size" not in syms;
}

test "linking is deterministic" {
    relobj = emit_coff_object(FIXTURE);
    assert link_pe(relobj) == link_pe(relobj);
}

test "nacompile --target windows writes a valid PE via the CLI" {
    out = os.path.join(tempfile.mkdtemp(), "smoke.exe");
    proc = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "nacompile",
            "--target",
            "windows",
            os.path.join(FIXTURES, FIXTURE),
            "-o",
            out
        ],
        capture_output=True,
        text=True,
        timeout=300
    );
    assert proc.returncode == 0 , f"nacompile failed: {proc.stderr}\n{proc.stdout}";
    assert os.path.exists(out);
    pe = parse_pe(Path(out).read_bytes());
    assert pe["magic"] == 0x20B;
    assert "msvcrt.dll" in pe["imports"];
}
