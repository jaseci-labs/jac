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


"""Scan Mach-O load commands for the fields the dylib test asserts on."""
def _macho_info(raw: bytes) -> dict {
    filetype = struct.unpack_from("<I", raw, 12)[0];
    ncmds = struct.unpack_from("<I", raw, 16)[0];
    off = 32;
    has_id_dylib = False;
    export_size = 0;
    has_mod_init = False;
    for _ in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", raw, off);
        if cmd == 0x0D {  # LC_ID_DYLIB
            has_id_dylib = True;
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
        "export_size": export_size,
        "has_mod_init": has_mod_init
    };
}


# ─── tests ───────────────────────────────────────────────────────────────────
test "ELF shared object loads and runs through the C ABI" {
    (relobj, exports) = emit_shared_object(FIXTURE, llvm.get_default_triple());
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
