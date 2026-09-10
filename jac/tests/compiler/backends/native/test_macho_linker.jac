"""Tests for the Mach-O (macOS) shared-object link path.

These pin the import-provenance rule for dlopen'd artifacts (seal libraries,
JIT/AOT dylibs): an undefined symbol with an explicit `symbol_lib_map` entry
binds two-level to that dylib's ordinal, and every OTHER undefined symbol
binds via the flat-namespace special ordinal -- the `-undefined dynamic_lookup`
shape real linkers emit for plugins -- so it resolves from whatever the host
process has loaded (the launcher dlopens the bundled libpython RTLD_GLOBAL).
The old default bound unmapped symbols to ordinal 1 (libSystem), which made
the first sealed artifact referencing a CPython C-API symbol fail its load
canary on macOS: `Symbol not found: _PyDict_New ... Expected in:
/usr/lib/libSystem.B.dylib`.

The dylib is validated structurally on any host (like test_pe_linker.jac);
the dlopen round trip runs only on a matching darwin host.
"""

import ctypes;
import os;
import struct;
import sys;
import tempfile;
import from jaclang.compiler.backends.native.macho_linker { MachOLinker }
import jaclang.compiler.backends.native.llvm.binding as llvm;

glob MACHO_TRIPLE = "arm64-apple-darwin",
     MACHO_TRIPLE_X86 = "x86_64-apple-darwin",
     LC_DYLD_INFO_ONLY = 0x80000022,
     MH_PIE = 0x200000;


"""IR with one unmapped extern (PyDict_New) and one mapped one (malloc)."""
def probe_ir(triple: str) -> str {
    return (
        f'target triple = "{triple}"\n'
        + 'declare ptr @PyDict_New()\n'
        + 'declare ptr @malloc(i64)\n'
        + 'define ptr @jac_probe() {\n'
        + 'entry:\n'
        + '  %d = call ptr @PyDict_New()\n'
        + '  ret ptr %d\n'
        + '}\n'
        + 'define ptr @jac_probe_malloc() {\n'
        + 'entry:\n'
        + '  %p = call ptr @malloc(i64 16)\n'
        + '  ret ptr %p\n'
        + '}\n'
    );
}


"""Emit a Mach-O relocatable object for the given triple."""
def emit_macho_object(triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(probe_ir(triple));
    mod.verify();
    tm = llvm.Target.from_triple(triple).create_target_machine(
        opt=2, reloc="pic", codemodel="small"
    );
    return tm.emit_object(mod);
}


"""Link the probe object into a dylib and return (path, bytes)."""
def link_dylib(triple: str) -> tuple {
    relobj = emit_macho_object(triple);
    d = tempfile.mkdtemp();
    out = os.path.join(d, "libprobe.dylib");
    ok = MachOLinker.link(
        objects=[relobj],
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        symbol_lib_map={"malloc": "/usr/lib/libSystem.B.dylib"},
        shared=True,
        export_symbols=["jac_probe", "jac_probe_malloc"],
        init_funcs=[],
        soname="libprobe.dylib"
    );
    assert ok , "MachOLinker.link returned False";
    with open(out, "rb") as f {
        img = f.read();
    }
    return (out, img);
}


"""Extract the LC_DYLD_INFO_ONLY bind stream from a 64-bit Mach-O image."""
def bind_stream(img: bytes) -> bytes {
    magic = struct.unpack_from("<I", img, 0)[0];
    assert magic == 0xFEEDFACF , f"not a 64-bit Mach-O: {hex(magic)}";
    ncmds = struct.unpack_from("<I", img, 16)[0];
    off = 32;
    for _i in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", img, off);
        if cmd == LC_DYLD_INFO_ONLY {
            (bind_off, bind_size) = struct.unpack_from("<II", img, off + 16);
            return img[bind_off:bind_off + bind_size];
        }
        off += cmdsize;
    }
    assert False , "no LC_DYLD_INFO_ONLY load command";
    return b"";
}


# ─── tests ───────────────────────────────────────────────────────────────────
test "unmapped undefined symbols bind via flat-namespace lookup" {
    (_out, img) = link_dylib(MACHO_TRIPLE);
    bind = bind_stream(img);
    # per-symbol bind record: [SET_DYLIB op] [0x40 name NUL] [type/seg/DO_BIND]
    idx = bind.find(b"\x40_PyDict_New\x00");
    assert idx >= 1 , "no bind record for _PyDict_New";
    # 0x3E = SET_DYLIB_SPECIAL_IMM | FLAT_LOOKUP (-2 & 0x0F), not an ordinal
    assert bind[idx - 1] == 0x3E , (
        f"_PyDict_New bind provenance byte {hex(bind[idx - 1])}, expected "
        "flat lookup (0x3E): unmapped symbols must resolve from the process, "
        "not dylib ordinal 1 (libSystem)"
    );
}

test "mapped symbols keep their two-level dylib ordinal" {
    (_out, img) = link_dylib(MACHO_TRIPLE);
    bind = bind_stream(img);
    jdx = bind.find(b"\x40_malloc\x00");
    assert jdx >= 2 , "no bind record for _malloc";
    # 0x20 = SET_DYLIB_ORDINAL_ULEB, then uleb ordinal 1 = libSystem
    assert bind[jdx - 2] == 0x20 and bind[jdx - 1] == 0x01 , (
        f"_malloc bind bytes {hex(bind[jdx - 2])},{hex(bind[jdx - 1])}, "
        "expected two-level ordinal 1 (libSystem)"
    );
}

test "darwin host: the dylib loads and resolves CPython from the process" {
    if sys.platform != "darwin" {
        return;
    }
    import platform;
    host_arch = platform.machine();
    triple = llvm.get_default_triple();
    if ("arm64" in triple) != (host_arch == "arm64") {
        return;
    }
    (out, _img) = link_dylib(triple);
    # PyDLL keeps the GIL held across the call, which PyDict_New needs
    lib = ctypes.PyDLL(out);
    lib.jac_probe.restype = ctypes.c_void_p;
    d = lib.jac_probe();
    assert d , "PyDict_New returned NULL through the linked dylib";
    ctypes.pythonapi.Py_DecRef.argtypes = [ctypes.c_void_p];
    ctypes.pythonapi.Py_DecRef(d);
}


"""IR whose private literal carries the same name every LLVM object uses."""
def literal_ir(triple: str, text: str, fn: str) -> str {
    n = len(text) + 1;
    return (
        f'target triple = "{triple}"\n'
        + f'@.str.0 = private constant [{n} x i8] c"{text}\\00"\n'
        + f'define ptr @{fn}() {{\nentry:\n  ret ptr @.str.0\n}}\n'
        + 'define i32 @main() {\nentry:\n  ret i32 0\n}\n'
    );
}


"""Emit the way nacompile emits executables: large code model, every global
reached through a GOT slot."""
def emit_large_object(ir_txt: str, triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(ir_txt);
    mod.verify();
    tm = llvm.Target.from_triple(triple).create_target_machine(
        opt=2, codemodel="large"
    );
    return tm.emit_object(mod);
}


"""Every C string an internal GOT slot of the image points at."""
def got_slot_strings(img: bytes) -> set[str] {
    ncmds = struct.unpack_from("<I", img, 16)[0];
    off = 32;
    secs: list[tuple[str, int, int, int]] = [];
    for _i in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", img, off);
        if cmd == 0x19 {
            nsects = struct.unpack_from("<I", img, off + 64)[0];
            so = off + 72;
            for _j in range(nsects) {
                name = img[so:so + 16].rstrip(b"\x00").decode();
                (addr, size, foff) = struct.unpack_from("<QQI", img, so + 32);
                secs.append((name, addr, size, foff));
                so += 80;
            }
        }
        off += cmdsize;
    }
    found: set[str] = set();
    for (name, addr, size, foff) in secs {
        if name != "__got" {
            continue;
        }
        for k in range(0, size, 8) {
            target = struct.unpack_from("<Q", img, foff + k)[0];
            for (_n, a2, s2, f2) in secs {
                if a2 <= target < a2 + s2 {
                    raw = img[f2 + target - a2:f2 + target - a2 + 64];
                    found.add(raw.split(b"\x00")[0].decode("utf-8", errors="replace"));
                }
            }
        }
    }
    return found;
}


test "internal GOT slots are keyed by symbol, not by private symbol name" {
    # Every LLVM object names its first private literal `l_.str.0`; merging an
    # archive member must not let its literal claim the main object's slot.
    main_obj = emit_large_object(
        literal_ir(MACHO_TRIPLE, "main-literal", "jac_main_ptr"), MACHO_TRIPLE
    );
    member = emit_large_object(
        literal_ir(MACHO_TRIPLE, "member-literal", "jac_member_ptr"), MACHO_TRIPLE
    );
    for shared in [False, True] {
        d = tempfile.mkdtemp();
        out = os.path.join(d, "probe.dylib" if shared else "probe");
        ok = MachOLinker.link(
            objects=[main_obj],
            output_path=out,
            shared=shared,
            export_symbols=["jac_main_ptr", "jac_member_ptr"],
            soname="probe.dylib" if shared else "",
            archive_members=[member]
        );
        assert ok , "MachOLinker.link returned False";
        with open(out, "rb") as f {
            img = f.read();
        }
        seen = got_slot_strings(img);
        assert "main-literal" in seen and "member-literal" in seen , (
            f"shared={shared}: GOT slots reach {sorted(seen)}; both literals "
            "must keep their own slot"
        );
    }
}


"""The mach header's flags word of a linked image."""
def header_flags(img: bytes) -> int {
    assert struct.unpack_from("<I", img, 0)[0] == 0xFEEDFACF , "not a 64-bit Mach-O";
    return struct.unpack_from("<I", img, 24)[0];
}


"""How many absolute 64-bit relocations the object aims at a placed __TEXT
section.

These are the sites an executable link patches with a hard-coded image
address. __TEXT is mapped read-only + executable and no rebase opcode can
reach it, so an image carrying even one of them cannot be slid.
Both ARM64_RELOC_UNSIGNED and X86_64_RELOC_UNSIGNED are relocation type 0.
"""
def absolute_text_relocs(relobj: bytes) -> int {
    lk = MachOLinker(
        obj_data=relobj, sections=[], symbols=[], relocations=[], needed_libs=[]
    );
    lk.parse_object();
    placed: set[str] = set();
    for sec in lk.sections {
        if sec.segname == "__TEXT"
            and (not sec.name.startswith("__debug"))
            and sec.name != "__eh_frame" {
            placed.add(f"{sec.segname}:{sec.name}");
        }
    }
    n = 0;
    for rel in lk.relocations {
        if rel.rtype == 0 and rel.length == 3 and rel.target_sec in placed {
            n += 1;
        }
    }
    return n;
}


"""Link an executable the way `jac build --native` does; return (object, image)."""
def link_exec(triple: str) -> tuple {
    relobj = emit_large_object(
        literal_ir(triple, "exec-literal", "jac_exec_ptr"), triple
    );
    d = tempfile.mkdtemp();
    out = os.path.join(d, "probe_exec");
    ok = MachOLinker.link(
        objects=[relobj],
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        shared=False
    );
    assert ok , f"{triple}: MachOLinker.link(shared=False) returned False";
    with open(out, "rb") as f {
        img = f.read();
    }
    return (relobj, img);
}


test "an x86_64 executable whose text holds absolute addresses is not PIE" {
    # `nacompile` builds executables with the large code model (#6819), and on
    # x86_64 that is absolute code: every global, literal and callee is
    # materialized with `movabsq $imm64`, landing as X86_64_RELOC_UNSIGNED in
    # __TEXT. Nothing can rebase those -- __TEXT is r-x and the rebase stream
    # only reaches __DATA -- so claiming MH_PIE hands dyld permission to slide
    # an image whose every code-side address is then stale. That is a SIGSEGV
    # before `main` can print anything (#8800).
    (relobj, img) = link_exec(MACHO_TRIPLE_X86);
    n_abs = absolute_text_relocs(relobj);
    assert n_abs > 0 , (
        "premise gone: the x86_64 large code model no longer puts absolute "
        "addresses in __TEXT, so this test pins nothing"
    );
    flags = header_flags(img);
    assert (flags & MH_PIE) == 0 , (
        f"x86_64 executable carries {n_abs} absolute address(es) in read-only "
        f"__TEXT but sets MH_PIE (flags={hex(flags)}): dyld slides the image "
        "and every one of those addresses goes stale"
    );
}


test "an arm64 executable is position-independent and stays PIE" {
    # arm64 code is PAGE21/PAGEOFF12/BRANCH26 -- no absolute address reaches
    # __TEXT -- and arm64 macOS refuses a non-PIE main executable, so the flag
    # must survive the x86_64 fix.
    (relobj, img) = link_exec(MACHO_TRIPLE);
    assert absolute_text_relocs(relobj) == 0 , (
        "arm64 object put an absolute address in __TEXT; an arm64 main "
        "executable must be PIE, so that image could not be linked at all"
    );
    flags = header_flags(img);
    assert (flags & MH_PIE) != 0 , (
        f"arm64 executable lost MH_PIE (flags={hex(flags)}); arm64 macOS "
        "refuses a non-PIE main executable"
    );
}
