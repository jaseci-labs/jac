"""Tests for the C-ABI shared-library build (`jac nacompile --shared`).

These exercise the three pure-Jac linkers' shared-object paths — ELF .so
(ET_DYN), Mach-O .dylib (MH_DYLIB), and PE .dll (IMAGE_FILE_DLL) — driven by a
single fixture whose `:pub` symbols form the export surface. The shared-init +
RC-wrapper injection mirrors what the nacompile CLI does before linking.

The ELF case is validated by actually loading the produced .so and calling its
exports through ctypes (the CI native suite runs on Linux); the Mach-O and PE
cases are validated structurally (filetype + export table + init mechanism),
since those binaries cannot be executed on a Linux host.
"""

import os;
import struct;
import sys;
import tempfile;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.compiler.passes.native.elf_linker { ElfLinker }
import from jaclang.compiler.passes.native.macho_linker { MachOLinker }
import from jaclang.compiler.passes.native.pe_linker { PeLinker }
import llvmlite.binding as llvm;

glob FIXTURES = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "native" / "fixtures"
     ),
     FIXTURE = "shared_export.na.jac";


# ─── helpers ─────────────────────────────────────────────────────────────────
"""Compile the fixture for `triple`, inject __jac_shared_init + the public RC
wrappers (mirroring the nacompile CLI), and emit a PIC relocatable object.

Returns (object_bytes, export_symbols)."""
def emit_shared_object(fixture: str, triple: str) -> tuple {
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
        exports = list(ir.gen._exported_symbols);
        init_call = "  call void @__jac_glob_init()\n"
            if "__jac_glob_init" in ir_txt
            else "";
        parts = [
            "\ndefine void @__jac_shared_init() {\nentry:\n" + init_call + "  ret void\n}"
        ];
        if "__rc_retain" in ir_txt {
            parts.append(
                "define void @jac_retain(ptr %p) {\nentry:\n"
                "  call void @__rc_retain(ptr %p)\n  ret void\n}"
            );
            exports.append("jac_retain");
        }
        if "__rc_release_simple" in ir_txt {
            parts.append(
                "define void @jac_release(ptr %p) {\nentry:\n"
                "  call void @__rc_release_simple(ptr %p)\n  ret void\n}"
            );
            exports.append("jac_release");
        }
        src = ir_txt + "\n".join(parts) + "\n";
        llvm.initialize_all_targets();
        llvm.initialize_all_asmprinters();
        mod = llvm.parse_assembly(src);
        mod.verify();
        tm = llvm.Target.from_triple(triple).create_target_machine(
            opt=2, reloc="pic", codemodel="small"
        );
        relobj = tm.emit_object(mod);
    } finally {
        if prev is None {
            os.environ.pop("JAC_NATIVE_TARGET", None);
        } else {
            os.environ["JAC_NATIVE_TARGET"] = prev;
        }
    }
    return (relobj, exports);
}


"""Parse execSegFlags out of an embedded ad-hoc code signature.

`sig_off` is the LC_CODE_SIGNATURE dataoff. Walks the SuperBlob to its
CodeDirectory and returns the 8-byte execSegFlags field (at CD offset 80 in
the 0x20400 layout). Returns None if the signature magics don't match — i.e.
the binary is unsigned (x86_64 dylibs/executables are not signed here)."""
def _exec_seg_flags(raw: bytes, sig_off: int) -> (int | None) {
    if struct.unpack_from(">I", raw, sig_off)[0] != 0xFADE0CC0 {  # SuperBlob
        return None;
    }
    count = struct.unpack_from(">I", raw, sig_off + 8)[0];
    idx = sig_off + 12;
    for _ in range(count) {
        boff = struct.unpack_from(">II", raw, idx)[1];  # (blobType, offset)
        cd = sig_off + boff;
        if struct.unpack_from(">I", raw, cd)[0] == 0xFADE0C02 {  # CodeDirectory
            return struct.unpack_from(">Q", raw, cd + 80)[0];  # execSegFlags
        }
        idx += 8;
    }
    return None;
}


"""Scan Mach-O load commands for the fields the dylib test asserts on."""
def _macho_info(raw: bytes) -> dict {
    filetype = struct.unpack_from("<I", raw, 12)[0];
    ncmds = struct.unpack_from("<I", raw, 16)[0];
    off = 32;
    has_id_dylib = False;
    has_load_dylinker = False;
    export_size = 0;
    has_mod_init = False;
    sig_off = 0;
    for _ in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", raw, off);
        if cmd == 0x0D {  # LC_ID_DYLIB
            has_id_dylib = True;
        } elif cmd == 0x0E {  # LC_LOAD_DYLINKER
            has_load_dylinker = True;
        } elif cmd == 0x1D {  # LC_CODE_SIGNATURE
            sig_off = struct.unpack_from("<I", raw, off + 8)[0];  # dataoff
        } elif cmd == 0x80000022 {  # LC_DYLD_INFO_ONLY
            export_size = struct.unpack_from("<I", raw, off + 44)[0];
        } elif cmd == 0x19 {  # LC_SEGMENT_64
            nsects = struct.unpack_from("<I", raw, off + 64)[0];
            so = off + 72;
            for _s in range(nsects) {
                sn = raw[so:so + 16].split(b"\x00")[0];
                if sn == b"__mod_init_func" {
                    has_mod_init = True;
                }
                so += 80;
            }
        }
        off += cmdsize;
    }
    return {
        "filetype": filetype,
        "has_id_dylib": has_id_dylib,
        "has_load_dylinker": has_load_dylinker,
        "export_size": export_size,
        "has_mod_init": has_mod_init,
        "exec_seg_flags": _exec_seg_flags(raw, sig_off) if sig_off else None
    };
}


# ─── tests ───────────────────────────────────────────────────────────────────
test "ELF shared object loads and runs through the C ABI" {
    # Pin an explicit ELF triple so the emitted object is ELF on any host (the
    # macOS native job runs this same file; its default triple is darwin, which
    # would yield a Mach-O object that ElfLinker cannot link). Execution below
    # stays gated to a Linux x86_64 host that can actually dlopen the result.
    (relobj, exports) = emit_shared_object(FIXTURE, "x86_64-unknown-linux-gnu");
    d = tempfile.mkdtemp();
    out = os.path.join(d, "libshared_export.so");
    ok = ElfLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["libc.so.6", "libm.so.6"],
        shared=True,
        export_symbols=exports,
        init_funcs=["__jac_shared_init"],
        soname="libshared_export.so"
    );
    assert ok , "ElfLinker.link(shared=True) returned False";
    raw = Path(out).read_bytes();
    assert raw[:4] == b"\x7fELF" , "not an ELF image";
    e_type = struct.unpack_from("<H", raw, 16)[0];
    assert e_type == 3 , f"expected ET_DYN (3), got {e_type}";

    # Only a Linux x86_64 host can dlopen + execute the produced .so.
    if sys.platform.startswith("linux") and ("x86_64" in llvm.get_default_triple()) {
        import ctypes;
        lib = ctypes.CDLL(out);
        lib.jadd.restype = ctypes.c_int64;
        lib.jadd.argtypes = [ctypes.c_int64, ctypes.c_int64];
        assert lib.jadd(2, 3) == 5;
        lib.jmul.restype = ctypes.c_int64;
        lib.jmul.argtypes = [ctypes.c_int64, ctypes.c_int64];
        assert lib.jmul(4, 5) == 20;
        lib.get_counter.restype = ctypes.c_int64;
        assert lib.get_counter() == 7;  # glob:pub counter
        lib.make_point.restype = ctypes.c_void_p;
        lib.make_point.argtypes = [ctypes.c_int64, ctypes.c_int64];
        lib.point_sum.restype = ctypes.c_int64;
        lib.point_sum.argtypes = [ctypes.c_void_p];
        p = lib.make_point(3, 4);
        assert p , "make_point returned NULL";
        assert lib.point_sum(p) == 7 , "opaque object handle round-trip failed";
        lib.jac_release.argtypes = [ctypes.c_void_p];
        lib.jac_release(p);  # public RC wrapper over __rc_release_simple
    }
}


test "Mach-O dylib has MH_DYLIB filetype, export trie, and init section" {
    (relobj, exports) = emit_shared_object(FIXTURE, "x86_64-apple-darwin");
    d = tempfile.mkdtemp();
    out = os.path.join(d, "libshared_export.dylib");
    ok = MachOLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        shared=True,
        export_symbols=exports,
        init_funcs=["__jac_shared_init"],
        soname="libshared_export.dylib"
    );
    assert ok , "MachOLinker.link(shared=True) returned False";
    raw = Path(out).read_bytes();
    assert struct.unpack_from("<I", raw, 0)[0] == 0xFEEDFACF , "not a Mach-O 64 image";
    info = _macho_info(raw);
    assert info["filetype"] == 6 , f"expected MH_DYLIB (6), got {info['filetype']}";
    assert info["has_id_dylib"] , "missing LC_ID_DYLIB";
    assert info["export_size"] > 0 , "empty export trie";
    assert info["has_mod_init"] , "missing __mod_init_func";
}


"""Build a dylib from the scalar-only fixture for `triple` and return its
parsed Mach-O info. Kept separate from the object-handle FIXTURE so these
load-command assertions don't depend on object attribute-access support."""
def _build_scalar_dylib(triple: str, name: str) -> dict {
    (relobj, exports) = emit_shared_object("shared_export_scalar.na.jac", triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, name);
    ok = MachOLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        shared=True,
        export_symbols=exports,
        init_funcs=["__jac_shared_init"],
        soname="libshared_export_scalar.dylib"
    );
    assert ok , f"MachOLinker.link(shared=True) returned False for {triple}";
    info = _macho_info(Path(out).read_bytes());
    assert info["filetype"] == 6 , f"expected MH_DYLIB (6), got {info['filetype']}";
    return info;
}


test "Mach-O dylib does not carry LC_LOAD_DYLINKER (x86_64 and arm64)" {
    # LC_LOAD_DYLINKER is only valid in MH_EXECUTE — a dylib that carries it
    # fails to load on macOS. Both arch paths must omit it (PR #6828).
    for triple in ["x86_64-apple-darwin", "arm64-apple-darwin"] {
        info = _build_scalar_dylib(triple, "libld.dylib");
        assert not info["has_load_dylinker"] , f"MH_DYLIB ({triple}) must not carry LC_LOAD_DYLINKER";
    }
}


test "Mach-O arm64 dylib is ad-hoc signed with execSegFlags == 0" {
    # The arm64 path emits an embedded code signature. CS_EXECSEG_MAIN_BINARY
    # (0x1) in execSegFlags is only valid for the main executable's __TEXT
    # segment; setting it on a dylib triggers a macOS load error. Guard that
    # dylibs sign with execSegFlags == 0 — the counterpart to the executable
    # test in test_exec_link asserting it is set (PR #6828).
    info = _build_scalar_dylib("arm64-apple-darwin", "libexecseg.dylib");
    assert info["exec_seg_flags"] is not None , "arm64 dylib is not code-signed";
    assert info["exec_seg_flags"] == 0 , f"dylib execSegFlags must be 0, got {info[
        'exec_seg_flags'
    ]}";
}


test "Mach-O dylib dlopen/dlsym round-trip resolves :pub exports (macOS host only)" {
    # The issue (#6821) reported the produced dylib "loads, codesigns" but
    # dlsym fails — a symbol-resolution symptom distinct from the load-command
    # fixes covered by the structural tests above. This test closes that gap by
    # actually dlopen-ing the dylib and calling its :pub exports through ctypes,
    # mirroring the ELF round-trip. The CI native suite runs on Linux, where a
    # Mach-O dylib can't be loaded, so this is a no-op there; on a macOS host it
    # exercises the full load -> resolve -> call chain the issue described.
    triple = llvm.get_default_triple();
    if not (sys.platform == "darwin" and "apple" in triple) {
        return;
    }
    (relobj, exports) = emit_shared_object("shared_export_scalar.na.jac", triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "libdlopen_roundtrip.dylib");
    ok = MachOLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        shared=True,
        export_symbols=exports,
        init_funcs=["__jac_shared_init"],
        soname="libdlopen_roundtrip.dylib"
    );
    assert ok , "MachOLinker.link(shared=True) returned False";

    import ctypes;
    lib = ctypes.CDLL(out);  # dlopen — fails if the load-command fix regressed
    # Resolve whichever spelling the export trie carries — bare (the linker's
    # convention) or leading-underscore (macOS C convention). The dedicated
    # trie-naming test below pins which; this one only cares that a consumer
    # can actually dlsym + call the export (the issue's reported symptom).
    jadd = lib?.jadd or lib?._jadd;
    assert jadd is not None , "neither 'jadd' nor '_jadd' resolved via dlsym";
    jadd.restype = ctypes.c_int64;
    jadd.argtypes = [ctypes.c_int64, ctypes.c_int64];
    assert jadd(2, 3) == 5 , "jadd resolved but returned wrong value";
    jmul = lib?.jmul or lib?._jmul;
    assert jmul is not None , "neither 'jmul' nor '_jmul' resolved via dlsym";
    jmul.restype = ctypes.c_int64;
    jmul.argtypes = [ctypes.c_int64, ctypes.c_int64];
    assert jmul(4, 5) == 20 , "jmul resolved but returned wrong value";
    counter = lib?.get_counter or lib?._get_counter;
    assert counter is not None , "neither 'get_counter' nor '_get_counter' resolved";
    counter.restype = ctypes.c_int64;
    assert counter() == 7 , "get_counter resolved but returned wrong value";
}


test "Mach-O dylib export trie uses bare (non-underscored) :pub names (macOS host only)" {
    # The issue flagged the leading-underscore convention as an open question.
    # On macOS a C symbol `jadd` is exported as `_jadd` in the trie; dyld's dlsym
    # prepends the underscore, so a consumer resolves it with the BARE spelling
    # (`dlsym("jadd")`) while the underscored spelling (`dlsym("_jadd")` -> seeks
    # `__jadd`) does NOT resolve. Pin that consumer-facing contract so a
    # regression in the export-trie builder flips this test rather than silently
    # breaking dlsym for consumers (issue #6821). No-op on non-macOS.
    triple = llvm.get_default_triple();
    if not (sys.platform == "darwin" and "apple" in triple) {
        return;
    }
    (relobj, exports) = emit_shared_object("shared_export_scalar.na.jac", triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "libtrie_probe.dylib");
    ok = MachOLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        shared=True,
        export_symbols=exports,
        init_funcs=["__jac_shared_init"],
        soname="libtrie_probe.dylib"
    );
    assert ok , "MachOLinker.link(shared=True) returned False";

    import ctypes;
    lib = ctypes.CDLL(out);
    bare = lib?.jadd;
    under = lib?._jadd;
    assert bare is not None , "bare 'jadd' missing from export trie — trie empty or mis-built";
    assert under is None , "both 'jadd' and '_jadd' resolve — trie naming convention changed";
}


test "PE dll has IMAGE_FILE_DLL, export directory, and a non-zero entry" {
    (relobj, exports) = emit_shared_object(FIXTURE, "x86_64-pc-windows-msvc");
    d = tempfile.mkdtemp();
    out = os.path.join(d, "libshared_export.dll");
    ok = PeLinker.link(
        obj_bytes=relobj,
        output_path=out,
        needed_libs=["msvcrt.dll"],
        shared=True,
        export_symbols=exports,
        init_funcs=["__jac_shared_init"],
        soname="libshared_export.dll"
    );
    assert ok , "PeLinker.link(shared=True) returned False";
    raw = Path(out).read_bytes();
    assert raw[0:2] == b"MZ" , "missing MZ signature";
    e_lfanew = struct.unpack_from("<I", raw, 0x3C)[0];
    assert raw[e_lfanew:e_lfanew + 4] == b"PE\x00\x00" , "missing PE signature";
    chars = struct.unpack_from("<H", raw, e_lfanew + 4 + 18)[0];
    assert chars & 0x2000 , "IMAGE_FILE_DLL characteristic not set";
    opt = e_lfanew + 4 + 20;
    entry_rva = struct.unpack_from("<I", raw, opt + 16)[0];
    assert entry_rva != 0 , "DllMain entry point not set";
    # Data directory 0 = export table.
    (exp_rva, exp_sz) = struct.unpack_from("<II", raw, opt + 112);
    assert exp_sz > 0 , "no export directory";
}
