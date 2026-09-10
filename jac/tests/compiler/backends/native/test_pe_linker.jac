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
import from jaclang.compiler.driver.compile_options {
    push_native_target,
    pop_native_target
}
import struct;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR, program_ir }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.native.pe_linker { PeLinker }
import jaclang.compiler.backends.native.llvm.binding as llvm;
import from tests.support { program_ir }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     WIN_TRIPLE = "x86_64-pc-windows-msvc",
     FIXTURE = "pe_smoke.jac";


# ─── helpers ─────────────────────────────────────────────────────────────────
"""Compile a fixture to a relocatable COFF object the way nacompile does:
the plan's whole-program IR carries the PE entry (main + _jac_win_start)."""
def emit_coff_object(fixture: str) -> bytes {
    prev = push_native_target(WIN_TRIPLE);
    try {
        src = program_ir(fixture, WIN_TRIPLE);
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
        pto = llvm.create_pipeline_tuning_options(speed_level=2);
        pb = llvm.create_pass_builder(tm, pto);
        mpm = pb.getModulePassManager();
        mpm.add_internalize_pass();
        mpm.run(mod, pb);
        relobj = tm.emit_object(mod);
    } finally {
        pop_native_target(prev);
    }
    return relobj;
}


"""Link a COFF object into a PE image and return its bytes."""
def link_pe(relobj: bytes) -> bytes {
    d = tempfile.mkdtemp();
    out = os.path.join(d, "a.exe");
    ok = PeLinker.link(objects=[relobj], output_path=out);
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

test "data import: dllimport global resolves through an IAT slot (#7626 C4)" {
    # A `dllimport` data global makes LLVM reference `__imp_ext_counter`;
    # the linker must import `ext_counter`, give it an IAT slot, emit NO
    # .text call thunk for it, and resolve the reference to the slot.
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    src = (
        'target triple = "x86_64-pc-windows-msvc"\n'
        + '@ext_counter = external dllimport global i64\n'
        + 'declare void @exit(i32)\n'
        + 'define i64 @read_it() {\n'
        + 'entry:\n'
        + '  %v = load i64, i64* @ext_counter\n'
        + '  ret i64 %v\n'
        + '}\n'
        + 'define void @_jac_win_start() {\n'
        + 'entry:\n'
        + '  %r = call i64 @read_it()\n'
        + '  call void @exit(i32 0)\n'
        + '  ret void\n'
        + '}\n'
    );
    mod = llvm.parse_assembly(src);
    mod.verify();
    tm = llvm.Target.from_triple(WIN_TRIPLE).create_target_machine(
        opt=2, codemodel="large"
    );
    relobj = tm.emit_object(mod);
    img = link_pe(relobj);
    pe = parse_pe(img);
    _all_names: list = [];
    for (_d, _ns) in pe["imports"].items() {
        _all_names.extend(_ns);
    }
    assert "ext_counter" in _all_names , (
        f"expected 'ext_counter' among imports, got {pe['imports']}"
    );
    assert "__imp_ext_counter" not in _all_names , (
        "the __imp_ prefix must be stripped before the hint/name table"
    );
}

test "data import: direct reference to imported data is a loud link error (#7626 C4)" {
    # Without dllimport the object carries a direct reference to the
    # data symbol; PE cannot absorb the IAT indirection there, so the
    # linker must refuse with guidance instead of emitting a thunk that
    # would read the slot address as the value (the old silent-garbage
    # failure).
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    src = (
        'target triple = "x86_64-pc-windows-msvc"\n'
        + '@stdout = external global i8*\n'
        + 'declare void @exit(i32)\n'
        + 'define i8* @read_it() {\n'
        + 'entry:\n'
        + '  %v = load i8*, i8** @stdout\n'
        + '  ret i8* %v\n'
        + '}\n'
        + 'define void @_jac_win_start() {\n'
        + 'entry:\n'
        + '  %r = call i8* @read_it()\n'
        + '  call void @exit(i32 0)\n'
        + '  ret void\n'
        + '}\n'
    );
    mod = llvm.parse_assembly(src);
    mod.verify();
    tm = llvm.Target.from_triple(WIN_TRIPLE).create_target_machine(
        opt=2, codemodel="large"
    );
    relobj = tm.emit_object(mod);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "a.exe");
    raised = False;
    try {
        PeLinker.link(objects=[relobj], output_path=out);
    } except ValueError as e {
        raised = True;
        assert "__imp_stdout" in str(e) , (
            f"error should point at the __imp_ fix, got: {e}"
        );
    }
    assert raised , "direct data-import reference must refuse to link";
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
            "build",
            "--native",
            "--target-triple",
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
