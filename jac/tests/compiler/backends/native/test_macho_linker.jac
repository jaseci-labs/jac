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
import from jaclang.compiler.backends.native.macho_linker { MachOLinker, MachOSection }
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
def link_dylib(triple: str) -> tuple[any, ...] {
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
def link_exec(triple: str) -> tuple[any, ...] {
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


"""Decode pointer-rebase sites as file offsets, independently of symbol lookup."""
def pointer_rebase_sites(img: bytes) -> set[int] {
    segments: list[int] = [];
    stream = b"";
    off = 32;
    for _ in range(struct.unpack_from("<I", img, 16)[0]) {
        (cmd, size) = struct.unpack_from("<II", img, off);
        if cmd == 0x19 {
            segments.append(struct.unpack_from("<Q", img, off + 40)[0]);
        } elif cmd == LC_DYLD_INFO_ONLY {
            (start, length) = struct.unpack_from("<II", img, off + 8);
            stream = img[start:start + length];
        }
        off += size;
    }
    sites: set[int] = set();
    cursor = 0;
    segment = 0;
    offset = 0;
    while cursor < len(stream) {
        op = stream[cursor];
        cursor += 1;
        kind = op & 0xF0;
        if kind == 0 {
            break;
        }
        if kind == 0x10 {
            assert (op & 15) == 1;
        } elif kind == 0x20 {
            segment = op & 15;
            offset = 0;
            shift = 0;
            while True {
                part = stream[cursor];
                cursor += 1;
                offset |= (part & 127) << shift;
                if (part & 128) == 0 {
                    break;
                }
                shift += 7;
            }
        } elif kind == 0x50 {
            for _ in range(op & 15) {
                sites.add(segments[segment] + offset);
                offset += 8;
            }
        } else {
            assert False , f"unsupported rebase opcode {hex(op)}";
        }
    }
    return sites;
}


test "stored imported function pointers follow ASLR in executables and dylibs" {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    for triple in [MACHO_TRIPLE, MACHO_TRIPLE_X86] {
        mod = llvm.parse_assembly(
            f'target triple = "{triple}"\n'
                + 'declare ptr @malloc(i64)\n'
                + 'declare void @free(ptr)\n'
                + '@callback_slot = global ptr @malloc\n'
                + 'define i32 @main() { ret i32 0 }\n'
                + 'define i32 @jac_allocates() {\n'
                + ' %f = load volatile ptr, ptr @callback_slot\n'
                + ' %p = call ptr %f(i64 16)\n'
                + ' %ok = icmp ne ptr %p, null\n'
                + ' call void @free(ptr %p)\n'
                + ' %result = zext i1 %ok to i32\n'
                + ' ret i32 %result\n}\n'
        );
        mod.verify();
        tm = llvm.Target.from_triple(triple).create_target_machine(
            opt=2, reloc="pic", codemodel="small"
        );
        relobj = tm.emit_object(mod);
        for shared in [False, True] {
            with tempfile.TemporaryDirectory() as directory {
                out = os.path.join(directory, "probe.dylib" if shared else "probe");
                assert MachOLinker.link(
                    objects=[relobj],
                    output_path=out,
                    shared=shared,
                    symbol_lib_map={
                        "malloc": "/usr/lib/libSystem.B.dylib",
                        "free": "/usr/lib/libSystem.B.dylib"
                    },
                    export_symbols=["jac_allocates"],
                    soname="probe.dylib"
                );
                with open(out, "rb") as f {
                    img = f.read();
                }
                off = 32;
                slot = -1;
                stubs = 0;
                stub_size = 0;
                for _ in range(struct.unpack_from("<I", img, 16)[0]) {
                    (cmd, size) = struct.unpack_from("<II", img, off);
                    if cmd == 0x19 {
                        for i in range(struct.unpack_from("<I", img, off + 64)[0]) {
                            sec = off + 72 + 80 * i;
                            name = img[sec:sec + 16].split(b"\x00")[0];
                            if name == b"__data" {
                                slot = struct.unpack_from("<I", img, sec + 48)[0];
                            } elif name == b"__stubs" {
                                (stubs, stub_size) = struct.unpack_from(
                                    "<QQ", img, sec + 32
                                );
                            }
                        }
                    }
                    off += size;
                }
                assert slot >= 0 and stub_size > 0;
                pointer = struct.unpack_from("<Q", img, slot)[0];
                slide = 0x2DD0000;
                moved = pointer + (slide if slot in pointer_rebase_sites(img) else 0);
                assert stubs + slide <= moved < stubs + stub_size + slide , (
                    f"{triple}, shared={shared}: stored import pointer escaped relocated stubs"
                );
                if shared and sys.platform == "darwin" {
                    import platform;
                    host_arm = platform.machine() == "arm64";
                    if host_arm == (triple == MACHO_TRIPLE) {
                        assert ctypes.CDLL(out).jac_allocates() == 1;
                    }
                }
            }
        }
    }
}


"""IR whose exported function calls an internal one and an imported one."""
def local_symbol_ir(triple: str) -> str {
    return (
        f'target triple = "{triple}"\n'
        + 'declare ptr @malloc(i64)\n'
        + 'define internal ptr @jac_hidden_helper(i64 %n) noinline {\n'
        + 'entry:\n'
        + '  %p = call ptr @malloc(i64 %n)\n'
        + '  ret ptr %p\n'
        + '}\n'
        + 'define ptr @jac_visible(i64 %n) {\n'
        + 'entry:\n'
        + '  %p = call ptr @jac_hidden_helper(i64 %n)\n'
        + '  ret ptr %p\n'
        + '}\n'
    );
}


"""The symbol table of a linked image: its (name, type, section, value)
entries, the LC_DYSYMTAB local/extdef/undef ranges and its indirect symbol
indices."""
def symbol_table(
    img: bytes
) -> tuple[list[tuple[str, int, int, int]], list[int], list[int]] {
    entries: list[tuple[str, int, int, int]] = [];
    ranges: list[int] = [];
    indirect: list[int] = [];
    off = 32;
    for _ in range(struct.unpack_from("<I", img, 16)[0]) {
        (cmd, size) = struct.unpack_from("<II", img, off);
        if cmd == 0x2 {
            (symoff, nsyms, stroff, _strsize) = struct.unpack_from(
                "<IIII", img, off + 8
            );
            for i in range(nsyms) {
                (strx, n_type, n_sect, _desc, value) = struct.unpack_from(
                    "<IBBhQ", img, symoff + i * 16
                );
                end = img.index(b"\x00", stroff + strx);
                entries.append(
                    (img[stroff + strx:end].decode(), n_type, n_sect, value)
                );
            }
        } elif cmd == 0xB {
            ranges = list(struct.unpack_from("<IIIIII", img, off + 8));
            (ind_off, n_ind) = struct.unpack_from("<II", img, off + 56);
            indirect = [
                struct.unpack_from("<I", img, ind_off + i * 4)[0] for i in range(n_ind)
            ];
        }
        off += size;
    }
    return (entries, ranges, indirect);
}


test "linked images keep internal functions' names as local symbols" {
    # Without them a profiler or crash report attributes every internal
    # function's samples to the nearest exported symbol before it.
    relobj = emit_large_object(local_symbol_ir(MACHO_TRIPLE), MACHO_TRIPLE);
    for shared in [False, True] {
        d = tempfile.mkdtemp();
        out = os.path.join(d, "probe.dylib" if shared else "probe");
        ok = MachOLinker.link(
            objects=[relobj],
            output_path=out,
            needed_libs=["/usr/lib/libSystem.B.dylib"],
            shared=shared,
            export_symbols=["jac_visible"],
            soname="probe.dylib" if shared else ""
        );
        assert ok , "MachOLinker.link returned False";
        with open(out, "rb") as f {
            img = f.read();
        }
        (entries, ranges, indirect) = symbol_table(img);
        (ilocal, nlocal, iextdef, nextdef, iundef, nundef) = ranges;
        names = [symbol[0] for symbol in entries];
        assert "_jac_hidden_helper" in names , f"shared={shared}: {names}";
        helper = entries[names.index("_jac_hidden_helper")];
        visible = entries[names.index("_jac_visible")];
        assert helper[1] == 0x0E
            and helper[2] == visible[2]
            and helper[3] != 0 , helper;
        assert visible[1] == 0x0F , visible;
        # Locals first, then the defined externals, then the undefined ones,
        # and every indirect entry still names an undefined import.
        assert (ilocal, iextdef, iundef) == (0, nlocal, nlocal + nextdef) , ranges;
        assert iundef + nundef == len(entries) , ranges;
        assert names.index("_jac_hidden_helper")
            < nlocal
            <= names.index("_jac_visible");
        imports = [
            entries[i][0]
            for i in indirect
            if i < 0x80000000
        ];
        assert imports
            and all(
                iundef <= i < iundef + nundef
                for i in indirect
                if i < 0x80000000
            );
        assert "_malloc" in imports , imports;
    }
}


"""Emit a position-independent object, the way a dylib's units are emitted."""
def emit_pic_object(ir_txt: str, triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(ir_txt);
    mod.verify();
    tm = llvm.Target.from_triple(triple).create_target_machine(
        opt=2, reloc="pic", codemodel="small"
    );
    return tm.emit_object(mod);
}


"""A linker holding one parsed object and nothing merged into it yet."""
def parsed_linker(relobj: bytes) -> MachOLinker {
    lk = MachOLinker(
        obj_data=relobj, sections=[], symbols=[], relocations=[], needed_libs=[]
    );
    assert lk.parse_object() , "not a Mach-O relocatable object";
    return lk;
}


"""The section a linker holds as `segname:name`."""
def held_section(lk: MachOLinker, segname: str, name: str) -> MachOSection {
    for sec in lk.sections {
        if sec.segname == segname and sec.name == name {
            return sec;
        }
    }
    raise AssertionError(f"the linker holds no {segname}:{name} section");
}


"""Link the objects as an executable or a dylib; return the image's bytes."""
def link_image(
    objects: list[bytes], shared: bool, directory: str, exports: list[str]
) -> bytes {
    out = os.path.join(directory, "probe.dylib" if shared else "probe");
    ok = MachOLinker.link(
        objects=objects,
        output_path=out,
        needed_libs=["/usr/lib/libSystem.B.dylib"],
        shared=shared,
        export_symbols=exports,
        soname="probe.dylib" if shared else ""
    );
    assert ok , f"MachOLinker.link(shared={shared}) returned False";
    with open(out, "rb") as f {
        return f.read();
    }
}


"""Each output section of a linked image: its address, size and the log2
alignment its header declares."""
def output_sections(img: bytes) -> dict[str, tuple[int, int, int]] {
    found: dict[str, tuple[int, int, int]] = {};
    off = 32;
    for _ in range(struct.unpack_from("<I", img, 16)[0]) {
        (cmd, size) = struct.unpack_from("<II", img, off);
        if cmd == 0x19 {
            for i in range(struct.unpack_from("<I", img, off + 64)[0]) {
                sec = off + 72 + 80 * i;
                name = img[sec:sec + 16].split(b"\x00")[0].decode();
                (addr, length) = struct.unpack_from("<QQ", img, sec + 32);
                found[name] = (
                    addr,
                    length,
                    struct.unpack_from("<I", img, sec + 52)[0]
                );
            }
        }
        off += size;
    }
    return found;
}


"""The address a linked image gives each named symbol."""
def symbol_addresses(img: bytes) -> dict[str, int] {
    (entries, _ranges, _indirect) = symbol_table(img);
    found: dict[str, int] = {};
    for (name, _n_type, _n_sect, value) in entries {
        found[name] = value;
    }
    return found;
}


"""Whether this host can load and run an image built for the triple."""
def host_runs(triple: str) -> bool {
    if sys.platform != "darwin" {
        return False;
    }
    import platform;
    return (platform.machine() == "arm64") == (triple == MACHO_TRIPLE);
}


test "a merged section takes the strictest alignment of its parts" {
    # The merge aligns each incoming part inside the merged section, which
    # only reaches the final address if the section itself is placed on the
    # strictest of those alignments.
    lk = MachOLinker(
        obj_data=b"",
        sections=[
            MachOSection(
                name="__const",
                segname="__TEXT",
                addr=0,
                size=8,
                data=b"\x11" * 8,
                align=8,
                flags=0,
                reserved1=0,
                reserved2=0
            )
        ],
        symbols=[],
        relocations=[],
        needed_libs=[]
    );
    for (fill, align) in [(b"\x22", 16), (b"\x33", 4)] {
        lk._consolidate(
            [
                MachOSection(
                    name="__const",
                    segname="__TEXT",
                    addr=0,
                    size=align,
                    data=fill * align,
                    align=align,
                    flags=0,
                    reserved1=0,
                    reserved2=0
                )
            ],
            [],
            []
        );
    }
    assert len(lk.sections) == 1 , [sec.name for sec in lk.sections];
    merged = lk.sections[0];
    expected = b"\x11" * 8 + b"\x00" * 8 + b"\x22" * 16 + b"\x33" * 4;
    assert merged.data == expected , merged.data;
    assert merged.align == 16 , (
        f"the merged section is placed on a {merged.align}-byte boundary but "
        "holds a part its object aligned to 16: that part lands wherever the "
        "first part's alignment happens to put it"
    );
}


glob WIDE_LO = 0x0123456789ABCDEF,
     WIDE_HI = 0x1032547698BADCFE;


"""The first unit of the merge: eight bytes of another read-only section,
then a `__TEXT,__const` that only needs 8-byte alignment."""
def narrow_unit_ir(triple: str) -> str {
    return (
        f'target triple = "{triple}"\n'
        + '@jac_lead = constant i64 1, section "__TEXT,__lead", align 8\n'
        + '@jac_narrow = constant i64 2, section "__TEXT,__const", align 8\n'
        + 'define i32 @main() {\nentry:\n  ret i32 0\n}\n'
    );
}


"""A later unit whose `__TEXT,__const` holds a 16-byte vector, read back with
the aligned load a vectorized loop uses for its constants."""
def wide_unit_ir(triple: str) -> str {
    return (
        f'target triple = "{triple}"\n'
        + f'@jac_wide = constant <2 x i64> <i64 {WIDE_LO}, i64 {WIDE_HI}>, '
        + 'section "__TEXT,__const", align 16\n'
        + 'define i64 @jac_wide_fold() {\n'
        + 'entry:\n'
        + '  %v = load volatile <2 x i64>, ptr @jac_wide, align 16\n'
        + '  %lo = extractelement <2 x i64> %v, i32 0\n'
        + '  %hi = extractelement <2 x i64> %v, i32 1\n'
        + '  %x = xor i64 %lo, %hi\n'
        + '  ret i64 %x\n'
        + '}\n'
        + 'define i64 @jac_wide_addr() {\n'
        + 'entry:\n'
        + '  %a = ptrtoint ptr @jac_wide to i64\n'
        + '  ret i64 %a\n'
        + '}\n'
    );
}


test "a 16-byte constant merged behind an 8-byte one lands on a 16-byte address" {
    # arm64 reads such a constant with `adrp` + `ldr q, [x, #pageoff]`, whose
    # offset field counts 16-byte units: off a 16-byte address the load reads
    # the bytes before the constant. x86_64's `movdqa` faults instead.
    for triple in [MACHO_TRIPLE, MACHO_TRIPLE_X86] {
        first = emit_pic_object(narrow_unit_ir(triple), triple);
        second = emit_pic_object(wide_unit_ir(triple), triple);
        first_align = held_section(parsed_linker(first), "__TEXT", "__const").align;
        second_align = held_section(parsed_linker(second), "__TEXT", "__const").align;
        assert (first_align, second_align) == (8, 16) , (
            f"{triple}: premise gone: the two units no longer bring a "
            "__TEXT,__const of alignment 8 then 16, so this test merges nothing"
        );
        lk = parsed_linker(first);
        assert lk._merge_member(second);
        assert held_section(lk, "__TEXT", "__const").align == 16 , (
            f"{triple}: merged __TEXT,__const kept the first unit's alignment"
        );
        for shared in [False, True] {
            with tempfile.TemporaryDirectory() as directory {
                img = link_image(
                    [first, second],
                    shared,
                    directory,
                    ["jac_wide_fold", "jac_wide_addr"]
                );
                addrs = symbol_addresses(img);
                where = f"{triple}, shared={shared}";
                assert addrs["_jac_wide"] % 16 == 0 , (
                    f"{where}: the 16-byte-aligned constant sits at "
                    f"{hex(addrs['_jac_wide'])}"
                );
                # The eight bytes ahead of the merged section are what would
                # put it, and so the constant, 8 bytes off a 16-byte address.
                assert addrs["_jac_narrow"] - addrs["_jac_lead"] == 16 , (
                    f"{where}: premise gone: __lead no longer sits eight bytes "
                    "ahead of the merged __const, so the address above is "
                    "aligned whatever the merge does"
                );
                if shared and host_runs(triple) {
                    lib = ctypes.CDLL(os.path.join(directory, "probe.dylib"));
                    lib.jac_wide_addr.restype = ctypes.c_uint64;
                    lib.jac_wide_fold.restype = ctypes.c_uint64;
                    assert lib.jac_wide_addr() % 16 == 0;
                    assert lib.jac_wide_fold() == WIDE_LO ^ WIDE_HI , (
                        f"{where}: the aligned load read "
                        f"{hex(lib.jac_wide_fold())}, not the constant"
                    );
                }
            }
        }
    }
}


test "common symbols are allocated on their own alignment" {
    # A common symbol states its alignment as a power of two; the section the
    # linker allocates it in has to be placed at least that strictly.
    for triple in [MACHO_TRIPLE, MACHO_TRIPLE_X86] {
        first = emit_pic_object(
            f'target triple = "{triple}"\n'
                + '@jac_odd = global i8 7, section "__DATA,__lead"\n'
                + 'define i32 @main() {\nentry:\n  ret i32 0\n}\n',
            triple
        );
        second = emit_pic_object(
            f'target triple = "{triple}"\n'
                + '@jac_common = common global [2 x i64] zeroinitializer, align 16\n'
                + 'define i32 @jac_unit() {\nentry:\n  ret i32 0\n}\n',
            triple
        );
        lk = parsed_linker(first);
        assert lk._merge_member(second);
        assert lk._commons.get("_jac_common") == (16, 4) , (
            f"{triple}: premise gone: the second unit no longer declares a "
            f"16-byte common aligned to 16: {lk._commons}"
        );
        lk._allocate_commons();
        assert held_section(lk, "__DATA", "__data").align == 16 , (
            f"{triple}: the section holding a 16-byte-aligned common is placed "
            f"on a {held_section(lk, '__DATA', '__data').align}-byte boundary"
        );
        for shared in [False, True] {
            with tempfile.TemporaryDirectory() as directory {
                addrs = symbol_addresses(
                    link_image([first, second], shared, directory, [])
                );
                where = f"{triple}, shared={shared}";
                assert addrs["_jac_common"] % 16 == 0 , (
                    f"{where}: the 16-byte-aligned common sits at "
                    f"{hex(addrs['_jac_common'])}"
                );
                assert addrs["_jac_common"] - addrs["_jac_odd"] == 16 , (
                    f"{where}: premise gone: the common no longer follows a "
                    "one-byte section, so its address is aligned whatever the "
                    "allocation does"
                );
            }
        }
    }
}


"""A unit whose read-only and writable data both ask for a 64-byte boundary,
behind `pads` one-instruction functions that move where the code ends."""
def cache_line_unit_ir(triple: str, pads: int) -> str {
    ir_txt = (
        f'target triple = "{triple}"\n'
        + 'declare ptr @malloc(i64)\n'
        + 'declare void @free(ptr)\n'
        + '@jac_line_const = constant [64 x i8] zeroinitializer, '
        + 'section "__TEXT,__const", align 64\n'
        + '@jac_line_data = global i64 5, section "__DATA,__data", align 64\n'
        + 'define i32 @main() {\n'
        + 'entry:\n'
        + '  %p = call ptr @malloc(i64 8)\n'
        + '  call void @free(ptr %p)\n'
        + '  ret i32 0\n'
        + '}\n'
    );
    for i in range(pads) {
        ir_txt += f'define void @jac_pad_{i}() {{\nentry:\n  ret void\n}}\n';
    }
    return ir_txt;
}


test "data aligned past 16 bytes is placed on its own alignment" {
    # The output's __const and __data each gather every input section of their
    # kind; they have to start on the strictest boundary any of those asked
    # for, not on a fixed 16 bytes.
    for triple in [MACHO_TRIPLE, MACHO_TRIPLE_X86] {
        for shared in [False, True] {
            where = f"{triple}, shared={shared}";
            const_floor: list[int] = [];
            data_floor: list[int] = [];
            for pads in range(4) {
                relobj = emit_pic_object(cache_line_unit_ir(triple, pads), triple);
                with tempfile.TemporaryDirectory() as directory {
                    img = link_image([relobj], shared, directory, []);
                }
                secs = output_sections(img);
                addrs = symbol_addresses(img);
                for (symbol, section) in [
                    ("_jac_line_const", "__const"),
                    ("_jac_line_data", "__data")
                ] {
                    assert addrs[symbol] % 64 == 0 , (
                        f"{where}, pads={pads}: the 64-byte-aligned {symbol} "
                        f"sits at {hex(addrs[symbol])}"
                    );
                    assert secs[section][2] == 6 , (
                        f"{where}, pads={pads}: {section} declares alignment "
                        f"2^{secs[section][2]} for 64-byte-aligned contents"
                    );
                }
                # Where each output section would start on a 16-byte boundary:
                # right behind the stubs, and right behind the GOT.
                (stubs_addr, stubs_size, _) = secs["__stubs"];
                (got_addr, got_size, _) = secs["__got"];
                const_floor.append((stubs_addr + stubs_size + 15) & ~15);
                data_floor.append((got_addr + got_size + 15) & ~15);
            }
            off_const = [
                a
                for a in const_floor
                if a % 64 != 0
            ];
            off_data = [
                a
                for a in data_floor
                if a % 64 != 0
            ];
            assert off_const and off_data , (
                f"{where}: premise gone: every link already ends its stubs "
                f"({const_floor}) and its GOT ({data_floor}) on a 64-byte "
                "boundary, so 16-byte placement would pass too"
            );
        }
    }
}


"""Where a linked image maps the named segment."""
def segment_address(img: bytes, segname: str) -> int {
    off = 32;
    for _ in range(struct.unpack_from("<I", img, 16)[0]) {
        (cmd, size) = struct.unpack_from("<II", img, off);
        if cmd == 0x19
            and img[off + 8:off + 24].split(b"\x00")[0].decode() == segname {
            return struct.unpack_from("<Q", img, off + 24)[0];
        }
        off += size;
    }
    raise AssertionError(f"the image has no {segname} segment");
}


test "data aligned past a page is placed on its own alignment without a GOT" {
    # With nothing imported there is no GOT ahead of __data, which then starts
    # the __DATA segment: on a page boundary, and no stricter unless asked.
    for triple in [MACHO_TRIPLE, MACHO_TRIPLE_X86] {
        relobj = emit_pic_object(
            f'target triple = "{triple}"\n'
                + '@jac_wide_data = global i64 5, section "__DATA,__data", '
                + 'align 32768\n'
                + 'define i32 @main() {\nentry:\n  ret i32 0\n}\n',
            triple
        );
        for shared in [False, True] {
            where = f"{triple}, shared={shared}";
            with tempfile.TemporaryDirectory() as directory {
                img = link_image([relobj], shared, directory, []);
            }
            secs = output_sections(img);
            addrs = symbol_addresses(img);
            assert addrs["_jac_wide_data"] % 32768 == 0 , (
                f"{where}: the 32768-byte-aligned global sits at "
                f"{hex(addrs['_jac_wide_data'])}"
            );
            assert secs["__data"][2] == 15 , secs["__data"];
            assert "__got" not in secs
                and segment_address(img, "__DATA") % 32768 != 0 , (
                f"{where}: premise gone: __data no longer opens a __DATA segment "
                "that starts off a 32768-byte boundary, so page alignment "
                "would pass too"
            );
        }
    }
}
