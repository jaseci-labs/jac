"""End-to-end gate for static C-archive linking on Mach-O and ELF (#6978 0.1a).

The Mach-O tests compile a tiny `na` program that calls `lzma_crc32` (an extern
C symbol), select the defining member out of the bundled `liblzma.a` via the ar
reader, merge it through MachOLinker's multi-object path, and run the result --
proving the floor links statically into the executable instead of being a
runtime dylib dependency. Gated to macOS arm64 (where the binary can run and the
bundled archives are TLS-free); skips elsewhere or when no pbs build is staged.

The ELF test is the Linux counterpart of the same linker fix: it emits a member
relocatable object (the raw bytes select_ar_members hands back as `.data`) and
folds it into the binary through ElfLinker's new `archive_members` path. It
builds on any host (the object is ELF regardless) and executes only on a Linux
x86_64 host -- where an unmerged member would leave `jac_floor_magic` an
unresolved libc import and the loader would abort, so a clean run proves the
merge. Together the file covers the archive-merge path on both object formats.
"""

import os;
import struct;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.native.macho_linker { MachOLinker }
import from jaclang.compiler.backends.native.elf_linker { ElfLinker }
import from jaclang.compiler.backends.native.linker_common { select_ar_members }
import from jaclang.cli.commands.nacompile {
    _inject_entry_elf_static,
    _collect_musl_static,
    _musl_lib_dir
}
import jaclang.compiler.backends.native.llvm.binding as llvm;

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
            options=CompileOptions(aot_mode=True)
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
    return ir_txt
        + (
            "\n; --- injected entry point ---\n"
            + globals_ir
            + "define i32 @main(i32 %argc, ptr %argv) {\nentry:\n"
            + "    store i32 %argc, ptr @__jac_argc\n"
            + "    store ptr %argv, ptr @__jac_argv\n"
            + "    call void @jac_entry()\n    ret i32 0\n}\n"
        );
}


"""Inject `main` + `_start` for ELF — mirrors nacompile's _inject_entry_elf
(see test_exec_link). ELF executables need an explicit `_start` that calls
`main` and `exit`, unlike Mach-O where dyld provides the entry stub."""
def _inject_elf(ir_txt: str) -> str {
    # Static musl entry (crt1.o supplies `_start`); see test_exec_link.
    return _inject_entry_elf_static(ir_txt);
}


"""Locate a bundled archive by name from any pbs build, or None."""
def _find_bundled(libname: str) -> (str | None) {
    jac_dir = Path(__file__).resolve().parents[4];
    hits = list(jac_dir.`glob(f".pbs-build/*/python/build/lib/{libname}"));
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
        _inject_macho(_compile_ir("static_archive_crc32.jac", triple)), triple
    );
    d = tempfile.mkdtemp();
    out = os.path.join(d, "crc32_static");
    ok = MachOLinker.link(
        objects=[relobj],
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
        _inject_macho(_compile_ir("static_archive_expat.jac", triple)), triple
    );
    d = tempfile.mkdtemp();
    out = os.path.join(d, "expat_static");
    ok = MachOLinker.link(
        objects=[relobj],
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


test "nacompile CLI: `import from lzma` static-links the floor, no dylib dep (#6978 0.1a)" {
    # Full integration through the real CLI: the clib floor import resolves to the
    # bundled archive, members are selected and merged, and the result has no
    # liblzma dependency (otool -L shows only libSystem).
    triple = llvm.get_default_triple();
    if not (sys.platform == "darwin" and "arm64" in triple) {
        return;
    }
    if _find_bundled("liblzma.a") is None {
        return;
    }
    fixture = os.path.join(FIXTURES, "static_archive_crc32.jac");
    d = tempfile.mkdtemp();
    out = os.path.join(d, "crc32_cli");
    comp = subprocess.run(
        [sys.executable, "-m", "jaclang", "nacompile", fixture, "-o", out],
        capture_output=True,
        text=True,
        timeout=180
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-600:]}";
    assert "Static-linking" in comp.stdout , (
        f"floor was not static-linked: {comp.stdout[-600:]}"
    );

    res = subprocess.run([out], capture_output=True, timeout=30);
    assert res.returncode == 0 , f"exec exited {res.returncode}, stderr={res.stderr}";
    assert b"3421780262" in res.stdout , f"unexpected output: {res.stdout}";

    # The floor must be linked in, not a runtime dylib dependency.
    deps = subprocess.run(
        ["otool", "-L", out], capture_output=True, text=True, timeout=30
    );
    assert "lzma" not in deps.stdout , f"unexpected liblzma dep:\n{deps.stdout}";
}


"""Emit a PIC relocatable object for `triple` (shared-object flavor, matching
link_plan.link_artifact's target-machine settings)."""
def _emit_pic_object(ir_txt: str, triple: str) -> bytes {
    llvm.initialize_all_targets();
    llvm.initialize_all_asmprinters();
    mod = llvm.parse_assembly(ir_txt);
    mod.verify();
    tm = llvm.Target.from_triple(triple).create_target_machine(
        opt=2, reloc="pic", codemodel="small"
    );
    return tm.emit_object(mod);
}


"""Link a shared ELF .so from a main object plus archive members and return
(image bytes, {symbol: vaddr}) for byte-level inspection on any host. In the
ElfLinker shared layout BASE_VADDR is 0, so every vaddr is also a file offset."""
def _link_elf_shared(main_ir: str, member_irs: list[str], triple: str) -> tuple {
    d = tempfile.mkdtemp();
    out = os.path.join(d, "libt.so");
    prev = os.environ.get("JAC_SYMMAP", None);
    os.environ["JAC_SYMMAP"] = "1";
    try {
        ok = ElfLinker.link(
            objects=[_emit_pic_object(main_ir, triple)],
            output_path=out,
            needed_libs=["libc.so.6"],
            crt_objects=[],
            shared=True,
            export_symbols=[],
            init_funcs=[],
            soname="libt.so",
            archive_members=[_emit_pic_object(m, triple) for m in member_irs],
            static_link=False
        );
    } finally {
        if prev is None {
            os.environ.pop("JAC_SYMMAP", None);
        } else {
            os.environ["JAC_SYMMAP"] = prev;
        }
    }
    assert ok , "ElfLinker.link(shared) returned False";
    raw = Path(out).read_bytes();
    symmap: dict = {};
    for line in Path(out + ".symmap").read_text().splitlines() {
        (n, v) = line.rsplit(" ", 1);
        symmap[n] = int(v, 16);
    }
    return (raw, symmap);
}


"""Parse an ELF image's section headers into {name: (file_off, size)}."""
def _elf_section_map(raw: bytes) -> dict {
    e_shoff = struct.unpack_from("<Q", raw, 40)[0];
    (e_shentsize, e_shnum, e_shstrndx) = struct.unpack_from("<HHH", raw, 58);
    hdrs: list = [];
    for i in range(e_shnum) {
        hdrs.append(struct.unpack_from("<IIQQQQIIQQ", raw, e_shoff + i * e_shentsize));
    }
    shstr = hdrs[e_shstrndx];
    sdata = raw[shstr[4]:shstr[4] + shstr[5]];
    smap: dict = {};
    for h in hdrs {
        end = sdata.index(b"\x00", h[0]);
        smap[sdata[h[0]:end].decode()] = (h[4], h[5]);
    }
    return smap;
}


glob ELF_SO_TRIPLE = "x86_64-unknown-linux-gnu",
     ELF_SO_HDR = f'target triple = "{ELF_SO_TRIPLE}"\n\n';


test "ELF: merged zerofill (.bss) members get distinct non-overlapping slots" {
    # Regression for the archive-merge offset accounting (Mach-O f032a12eb6
    # ported to ELF): zerofill sections carry mem_size with no file data, so
    # advancing member offsets from len(data) would hand every merged member
    # the same slot and alias all their globals.
    main_ir = ELF_SO_HDR + "@anchor = global i64 7, align 8\n";
    member_a = ELF_SO_HDR + "@bss_a = global [40 x i8] zeroinitializer, align 16\n";
    member_b = ELF_SO_HDR + "@bss_b = global [40 x i8] zeroinitializer, align 16\n";
    (raw, symmap) = _link_elf_shared(main_ir, [member_a, member_b], ELF_SO_TRIPLE);
    assert raw[:4] == b"\x7fELF" , "not an ELF image";
    a = symmap.get("bss_a");
    b = symmap.get("bss_b");
    assert a is not None and b is not None , f"missing .bss symbols: {symmap.keys()}";
    assert a != b , f"merged .bss members alias one slot: {hex(a)}";
    assert a % 16 == 0 and b % 16 == 0 , f"alignment lost: {hex(a)}, {hex(b)}";
    lo = a if a < b else b;
    hi = b if a < b else a;
    assert hi >= lo + 40 , f"merged .bss members overlap: {hex(lo)}..{hex(hi)}";
}


test "ELF: commons merge by max size/alignment and a real def beats tentative" {
    # Regression for SHN_COMMON handling in the archive merge: tentative
    # definitions (st_value = alignment, st_size = size) must merge by
    # largest size and strictest alignment, and a later REAL definition must
    # replace the tentative one instead of being dropped. The pre-fix merge
    # kept the first-seen common verbatim: com_a stayed 24 bytes (its true
    # 64-byte span overlapping the commons placed after it in .bss) and
    # gdef's initialized quad was silently lost to zerofill.
    member_a = ELF_SO_HDR
        + "@com_a = common global [24 x i8] zeroinitializer, align 8\n";
    member_b = ELF_SO_HDR
        + "@com_a = common global [64 x i8] zeroinitializer, align 16\n"
        + "@com_z = common global [16 x i8] zeroinitializer, align 8\n"
        + "@gdef = common global i64 0, align 8\n";
    member_c = ELF_SO_HDR
        + "@gdef = dso_local global i64 1234605616436508552, align 8\n";
    main_ir = ELF_SO_HDR + "@anchor = global i64 7, align 8\n";
    (raw, symmap) = _link_elf_shared(
        main_ir, [member_a, member_b, member_c], ELF_SO_TRIPLE
    );
    com_a = symmap.get("com_a");
    com_z = symmap.get("com_z");
    gdef = symmap.get("gdef");
    assert com_a is not None and com_z is not None and gdef is not None , (
        f"commons not allocated: {symmap.keys()}"
    );
    assert com_a % 16 == 0 , f"com_a lost its strictest alignment: {hex(com_a)}";
    for (nm, other, sz) in [("com_z", com_z, 16), ("gdef", gdef, 8)] {
        disjoint = (other + sz <= com_a) or (other >= com_a + 64);
        assert disjoint , (
            f"{nm} at {hex(other)} overlaps com_a's true span "
            f"[{hex(com_a)}, {hex(com_a + 64)})"
        );
    }
    # vaddr == file offset in this layout, so the kept definition is readable.
    quad = struct.unpack_from("<Q", raw, gdef)[0];
    assert quad == 1234605616436508552 , (
        f"real definition lost to a tentative one: gdef bytes = {hex(quad)}"
    );
}


test "ELF: RELA addends survive into RELATIVE dynamic relocs" {
    # Regression mirroring the Mach-O inline-addend fix (61aad1c9ea): data
    # pointers into the middle of a blob (the static-string-struct +16
    # header skip in sealed artifacts) must keep their addend. A dropped
    # addend re-points every slot at the blob base.
    main_ir = ELF_SO_HDR
        + '@lstr = private unnamed_addr constant [12 x i8] c"ADDENDPROBE\\00", align 1\n'
        + "@tbl = global [2 x ptr] ["
        + "ptr getelementptr inbounds (i8, ptr @lstr, i64 5), "
        + "ptr getelementptr inbounds (i8, ptr @lstr, i64 9)], align 8\n";
    (raw, symmap) = _link_elf_shared(main_ir, [], ELF_SO_TRIPLE);
    smap = _elf_section_map(raw);
    assert ".rela.dyn" in smap , f"no .rela.dyn emitted: {smap.keys()}";
    (rd_off, rd_size) = smap[".rela.dyn"];
    rels: list = [];
    for i in range(rd_size // 24) {
        rels.append(struct.unpack_from("<QQq", raw, rd_off + i * 24));
    }
    probe = raw.find(b"ADDENDPROBE");
    assert probe > 0 , "probe string missing from image";
    tbl = symmap.get("tbl");
    assert tbl is not None , f"tbl not placed: {symmap.keys()}";
    # R_X86_64_RELATIVE == 8; slot vaddr == r_offset, pointer == r_addend.
    for (slot, want) in [(tbl, probe + 5), (tbl + 8, probe + 9)] {
        hit = [
            r
            for r in rels
            if (r[1] & 0xFFFFFFFF) == 8 and r[0] == slot
        ];
        assert hit , f"no RELATIVE reloc covers slot {hex(slot)}";
        assert hit[0][2] == want , (
            f"addend dropped: slot {hex(slot)} -> {hex(hit[0][2])}, "
            f"expected {hex(want)} (base would be {hex(probe)})"
        );
    }
}


test "ELF: static-link jac_floor_magic from a member object, run, verify (#6978 0.1a)" {
    # Pin an explicit ELF triple so the object is ELF on any host (this file also
    # runs on the macOS native job, whose default triple is darwin/Mach-O).
    # Execution stays gated to a Linux x86_64 host that can run the result.
    triple = "x86_64-unknown-linux-gnu";
    main_obj = _emit_object(
        _inject_elf(_compile_ir("static_archive_elf_leaf.jac", triple)), triple
    );
    # The archive member as a raw relocatable object -- the same shape
    # select_ar_members hands back as `.data`: a leaf defining the extern the
    # main object calls. Emitted from IR so the test needs no checked-in binary
    # and no host C toolchain, and stays cross-host (Mach-O `ar` cannot build an
    # ELF member's symbol index, so a real archive can't be assembled on macOS).
    member_ir = f'target triple = "{triple}"\n\n'
        + "define i64 @jac_floor_magic() {\nentry:\n  ret i64 1234605616436508552\n}\n";
    member_obj = _emit_object(member_ir, triple);

    d = tempfile.mkdtemp();
    out = os.path.join(d, "floor_static_elf");
    if _musl_lib_dir(triple) is None {
        return;
    }
    musl = _collect_musl_static(main_obj, triple);
    assert musl is not None , "musl runtime unexpectedly unavailable";
    (members, crt) = musl;
    # Prepend the member-under-test to the vendored musl members: an unmerged
    # member would leave `jac_floor_magic` undefined (resolved to 0) and the
    # program would crash, so a clean run proves the merge.
    ok = ElfLinker.link(
        objects=[main_obj],
        output_path=out,
        needed_libs=[],
        crt_objects=crt,
        archive_members=[member_obj] + members,
        static_link=True
    );
    assert ok , "ElfLinker.link with archive_members returned False";
    raw = Path(out).read_bytes();
    assert raw[:4] == b"\x7fELF" , "not an ELF image";
    e_type = struct.unpack_from("<H", raw, 16)[0];
    assert e_type == 2 , f"expected ET_EXEC (2), got {e_type}";

    # Only a Linux x86_64 host can execute the produced ELF. Were the member not
    # merged, jac_floor_magic would stay an unresolved libc import and the loader
    # would abort -- so a clean run with the right value proves the merge.
    if sys.platform.startswith("linux") and ("x86_64" in llvm.get_default_triple()) {
        res = subprocess.run([out], capture_output=True, timeout=30);
        assert res.returncode == 0 , (
            f"exec exited {res.returncode}, stderr={res.stderr}"
        );
        assert b"1234605616436508552" in res.stdout , f"unexpected output: {res.stdout}";
    }
}
