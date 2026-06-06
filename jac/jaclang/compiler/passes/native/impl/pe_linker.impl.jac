"""PE/COFF linker implementation (x86_64).

Converts a relocatable COFF .o (from llvmlite emit_object for a
`*-pc-windows-*` triple) into a runnable PE32+ executable, loaded at a
fixed ImageBase with base relocations stripped (so no .reloc section is
needed) and dynamically linked against system DLLs (msvcrt.dll by default).
"""

import struct;
import os;
import from jaclang.compiler.passes.native.linker_common {
    _align,
    _append_to_blob,
    _resolve_seg_vaddr
}

# ── COFF machine types ───────────────────────────────────────────
glob IMAGE_FILE_MACHINE_AMD64 = 0x8664;

# ── Section characteristics ──────────────────────────────────────
glob SCN_CNT_CODE = 0x20,
     SCN_CNT_INITIALIZED_DATA = 0x40,
     SCN_CNT_UNINITIALIZED_DATA = 0x80,
     SCN_LNK_REMOVE = 0x800,
     SCN_MEM_EXECUTE = 0x20000000,
     SCN_MEM_READ = 0x40000000,
     SCN_MEM_WRITE = 0x80000000;

# ── amd64 relocation types ───────────────────────────────────────
glob REL_ADDR64 = 1,
     REL_ADDR32 = 2,
     REL_ADDR32NB = 3,
     REL_REL32 = 4,
     REL_REL32_5 = 9;

# ── Symbol storage classes ───────────────────────────────────────
glob SYM_CLASS_EXTERNAL = 2,
     SYM_CLASS_WEAK_EXTERNAL = 105;

# ── PE layout constants ──────────────────────────────────────────
# x64 default preferred base; RELOCS_STRIPPED forces load here (no ASLR).
glob IMAGE_BASE = 0x140000000,
     SECT_ALIGN = 0x1000,
     FILE_ALIGN = 0x200;

# Windows import-name aliases for glibc-isms the native runtime emits that
# msvcrt.dll exports under a different (underscore-prefixed) name. The
# symbol the code references is preserved; only the imported name differs.
#   malloc_usable_size -> _msize   (same (ptr)->size_t signature)
#   snprintf           -> _snprintf (compatible when output fits the buffer,
#                                    which is how the runtime always calls it)
glob WIN_ALIAS = {"malloc_usable_size": "_msize", "snprintf": "_snprintf"};


# ══════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════
"""Read a COFF name field: an inline 8-byte name, or (when the first four
bytes are zero) a 4-byte offset into the string table."""
def _coff_name(raw: bytes, field_off: int, strtab_off: int) -> str {
    name8 = raw[field_off:field_off + 8];
    if name8[:4] == b"\x00\x00\x00\x00" {
        so = struct.unpack_from("<I", name8, 4)[0];
        end = raw.index(b"\x00", strtab_off + so);
        return raw[strtab_off + so:end].decode();
    }
    return name8.rstrip(b"\x00").decode("utf-8", "replace");
}


# ══════════════════════════════════════════════════════════════════
# Parse the relocatable COFF object
# ══════════════════════════════════════════════════════════════════
impl PeLinker.parse_object -> bool {
    raw = self.obj_data;
    if len(raw) < 20 {
        return False;
    }
    (machine, nsec, _ts, psym, nsym, ohsz, _ch) = struct.unpack_from(
        "<HHIIIHH", raw, 0
    );
    if machine != IMAGE_FILE_MACHINE_AMD64 {
        # Only x86_64 is supported in this first cut.
        return False;
    }
    strtab_off = psym + nsym * 18;

    # ── Section headers ───────────────────────────────────────────
    self.sections = [];
    sec_table_off = 20 + ohsz;
    for i in range(nsec) {
        off = sec_table_off + i * 40;
        nameb = raw[off:off + 8];
        if nameb[:1] == b"/" {
            so = int(nameb[1:].rstrip(b"\x00").decode());
            end = raw.index(b"\x00", strtab_off + so);
            name = raw[strtab_off + so:end].decode();
        } else {
            name = nameb.rstrip(b"\x00").decode("utf-8", "replace");
        }
        (_vsz, _vaddr, rawsz, praw, prel, _plnum, nrel, _nln, chars) = struct.unpack_from(
            "<IIIIIIHHI", raw, off + 8
        );
        if chars & SCN_CNT_UNINITIALIZED_DATA {
            data = b"";
            vsize = rawsz;
        } else {
            data = raw[praw:praw + rawsz] if (praw and rawsz) else b"";
            vsize = rawsz;
        }
        sec = CoffSection(name=name, characteristics=chars, data=data, vsize=vsize);
        self.sections.append(sec);
        # Parse this section's relocations now (REL-style, 10 bytes each).
        for r in range(nrel) {
            ro = prel + r * 10;
            (rva, symidx, rtype) = struct.unpack_from("<IIH", raw, ro);
            self.relocations.append(
                CoffReloc(offset=rva, sym_idx=symidx, rtype=rtype, target_sec=i)
            );
        }
    }

    # ── Symbol table (keep aux slots as None so indices line up) ──
    self.symbols = [];
    i = 0;
    while i < nsym {
        off = psym + i * 18;
        name = _coff_name(raw, off, strtab_off);
        (val, secn, _typ, sc, naux) = struct.unpack_from("<IhHBB", raw, off + 8);
        wtag = -1;
        if sc == SYM_CLASS_WEAK_EXTERNAL and naux >= 1 {
            wtag = struct.unpack_from("<I", raw, off + 18)[0];
        }
        self.symbols.append(
            CoffSymbol(
                name=name, value=val, sec_num=secn, storage_class=sc, weak_tag=wtag
            )
        );
        for _a in range(naux) {
            self.symbols.append(None);
        }
        i += 1 + naux;
    }

    # ── Resolve weak externals to their default symbol's placement ──
    # A weak external (e.g. the __rc_* runtime globals LLVM emits) is
    # undefined in the symbol table but carries an aux record naming a
    # default symbol that IS defined locally. Copy that placement so the
    # weak symbol resolves locally instead of being mistaken for an import.
    for s in self.symbols {
        if s is not None and s.weak_tag >= 0 and s.weak_tag < len(self.symbols) {
            d = self.symbols[s.weak_tag];
            if d is not None {
                s.sec_num = d.sec_num;
                s.value = d.value;
            }
        }
    }
    return True;
}


# ══════════════════════════════════════════════════════════════════
# Build the PE32+ executable
# ══════════════════════════════════════════════════════════════════
impl PeLinker.build_executable -> bytes {
    default_dll = self.needed_libs[0] if self.needed_libs else "msvcrt.dll";

    # ── Classify sections into output segments by characteristics ──
    # code: executable .text | rodata: read-only initialized (.rdata,
    # .pdata, .xdata) | data: writable (.data, .bss).
    code_secs: list[int] = [];
    rodata_secs: list[int] = [];
    data_secs: list[int] = [];
    sec_i = 0;
    for s in self.sections {
        if not (s.characteristics & SCN_LNK_REMOVE) {
            if s.characteristics & SCN_CNT_CODE {
                code_secs.append(sec_i);
            } elif s.characteristics & SCN_MEM_WRITE {
                data_secs.append(sec_i);
            } else {
                rodata_secs.append(sec_i);
            }
        }
        sec_i += 1;
    }

    # ── Identify undefined external imports (functions) ───────────
    extern_funcs: list[str] = [];
    for s in self.symbols {
        if s is not None
        and s.sec_num == 0
        and s.storage_class == SYM_CLASS_EXTERNAL
        and s.name
        and s.weak_tag < 0 {
            if s.name not in extern_funcs {
                extern_funcs.append(s.name);
            }
        }
    }

    # ── Place sections into segment blobs ─────────────────────────
    code_blob = bytearray();
    rodata_blob = bytearray();
    data_blob = bytearray();
    sec_seg: dict[int, tuple[str, int]] = {};
    pdata_idx = -1;
    for i in code_secs {
        off = _append_to_blob(
            code_blob, self.sections[i].data, 16, self.sections[i].vsize
        );
        sec_seg[i] = ("code", off);
    }
    for i in rodata_secs {
        off = _append_to_blob(
            rodata_blob, self.sections[i].data, 16, self.sections[i].vsize
        );
        sec_seg[i] = ("rodata", off);
        if self.sections[i].name == ".pdata" {
            pdata_idx = i;
        }
    }
    for i in data_secs {
        off = _append_to_blob(
            data_blob, self.sections[i].data, 16, self.sections[i].vsize
        );
        sec_seg[i] = ("data", off);
    }

    # ── Append one import thunk per external function ─────────────
    # Each thunk is `jmp qword ptr [rip + IAT_slot]` (FF 25 disp32). The
    # external symbol resolves to its thunk's address (PLT-style), so both
    # `call func` and `&func` work; the loader fills the IAT slot.
    thunk_off: dict[str, int] = {};
    for name in extern_funcs {
        o = _align(len(code_blob), 16);
        code_blob.extend(b"\x00" * (o - len(code_blob)));
        thunk_off[name] = len(code_blob);
        code_blob.extend(b"\x00" * 6);
    }

    # ── Segment RVAs (advance by max(vsize,1) so empty segments still
    #    get a distinct page — overlapping RVAs make the loader reject it) ──
    nsec_out = 4;  # .text .rdata .data .idata
    dos_pe = 0x80 + 4 + 20 + 240 + nsec_out * 40;
    headers_file = _align(dos_pe, FILE_ALIGN);
    sz_headers = _align(dos_pe, SECT_ALIGN);

    text_rva = _align(sz_headers, SECT_ALIGN);
    rodata_rva = _align(text_rva + max(len(code_blob), 1), SECT_ALIGN);
    data_rva = _align(rodata_rva + max(len(rodata_blob), 1), SECT_ALIGN);
    data_vsize = len(data_blob);
    idata_rva = _align(data_rva + max(data_vsize, 1), SECT_ALIGN);

    # ── Group external functions by DLL ───────────────────────────
    dll_of: dict[str, str] = {};
    dlls: list[str] = [];
    for name in extern_funcs {
        raw_dll = self.symbol_lib_map.get(name, default_dll);
        # A clib import may name a non-Windows library (a Linux ".so", a macOS
        # ".dylib", or an absolute Unix path) whose functions are standard C
        # (strlen, calloc, ...) and live in msvcrt on Windows. Only honor a
        # mapping that actually names a ".dll" (taking its basename for a full
        # path); otherwise bind to the default DLL.
        if ".dll" in raw_dll.lower() {
            d = os.path.basename(raw_dll.replace("\\", "/"));
        } else {
            d = default_dll;
        }
        dll_of[name] = d;
        if d not in dlls {
            dlls.append(d);
        }
    }
    by_dll: dict[str, list[str]] = {};
    for d in dlls {
        by_dll[d] = [];
    }
    for name in extern_funcs {
        by_dll[dll_of[name]].append(name);
    }

    # ── Lay out the .idata section ────────────────────────────────
    #  [descriptors+null] [all ILTs] [all IATs (contiguous)] [hint/names]
    #  [dll name strings]. ILTs and IATs are grouped so the IAT data
    #  directory spans one contiguous region.
    ndll = len(dlls);
    desc_sz = (ndll + 1) * 20;
    cur = desc_sz;
    ilt_rva: dict[str, int] = {};
    for d in dlls {
        ilt_rva[d] = cur;
        cur += (len(by_dll[d]) + 1) * 8;
    }
    iat_start = cur;
    iat_rva: dict[str, int] = {};
    for d in dlls {
        iat_rva[d] = cur;
        cur += (len(by_dll[d]) + 1) * 8;
    }
    iat_total = cur - iat_start;
    # Hint/name entries (one per function, keyed by referenced symbol name).
    name_rva: dict[str, int] = {};
    for d in dlls {
        for name in by_dll[d] {
            imp = WIN_ALIAS.get(name, name);
            cur = _align(cur, 2);
            name_rva[name] = cur;
            cur += 2 + len(imp.encode()) + 1;
        }
    }
    dllname_rva: dict[str, int] = {};
    for d in dlls {
        dllname_rva[d] = cur;
        cur += len(d.encode()) + 1;
    }
    idata_vsize = cur;
    idata = bytearray(idata_vsize);

    # Import descriptors
    di = 0;
    for d in dlls {
        base = di * 20;
        struct.pack_into(
            "<IIIII",
            idata,
            base,
            idata_rva + ilt_rva[d],
            0,
            0,
            idata_rva + dllname_rva[d],
            idata_rva + iat_rva[d]
        );
        di += 1;
    }
    # ILT + IAT thunks (both point to the hint/name entry; high bit clear
    # selects import-by-name).
    for d in dlls {
        j = 0;
        for name in by_dll[d] {
            thunk = idata_rva + name_rva[name];
            struct.pack_into("<Q", idata, ilt_rva[d] + j * 8, thunk);
            struct.pack_into("<Q", idata, iat_rva[d] + j * 8, thunk);
            j += 1;
        }
    }
    # Hint/name entries
    for d in dlls {
        for name in by_dll[d] {
            impb = WIN_ALIAS.get(name, name).encode();
            o = name_rva[name];
            struct.pack_into("<H", idata, o, 0);
            idata[o + 2:o + 2 + len(impb)] = impb;
        }
    }
    # DLL name strings
    for d in dlls {
        db = d.encode();
        o = dllname_rva[d];
        idata[o:o + len(db)] = db;
    }

    # ── Patch import thunks now that IAT VAs are known ────────────
    func_iat_va: dict[str, int] = {};
    for d in dlls {
        j = 0;
        for name in by_dll[d] {
            func_iat_va[name] = IMAGE_BASE + idata_rva + iat_rva[d] + j * 8;
            j += 1;
        }
    }
    for name in extern_funcs {
        toff = thunk_off[name];
        thunk_va = IMAGE_BASE + text_rva + toff;
        disp = func_iat_va[name] - (thunk_va + 6);
        struct.pack_into("<H", code_blob, toff, 0x25ff);
        struct.pack_into("<i", code_blob, toff + 2, disp);
    }

    # ── Apply relocations ─────────────────────────────────────────
    for rel in self.relocations {
        pl = sec_seg.get(rel.target_sec);
        if pl is None {
            # Relocation targets a section we don't place (dropped/debug).
            continue;
        }
        (seg, segoff) = pl;
        if seg == "code" {
            buf = code_blob;
        } elif seg == "rodata" {
            buf = rodata_blob;
        } else {
            buf = data_blob;
        }
        patch_off = segoff + rel.offset;
        patch_rva = _resolve_seg_vaddr(seg, patch_off, text_rva, rodata_rva, data_rva);

        # Resolve the referenced symbol to a target RVA.
        trva = 0;
        s = self.symbols[rel.sym_idx] if rel.sym_idx < len(self.symbols) else None;
        if s is not None {
            if s.sec_num == 0 and s.name in thunk_off {
                trva = text_rva + thunk_off[s.name];
            } elif s.sec_num > 0 {
                ssec = s.sec_num - 1;
                spl = sec_seg.get(ssec);
                if spl is not None {
                    trva = _resolve_seg_vaddr(
                        spl[0], spl[1] + s.value, text_rva, rodata_rva, data_rva
                    );
                }
            } elif s.sec_num == -1 {
                trva = s.value;  # absolute
            }
        }

        if rel.rtype == REL_ADDR64 {
            a = struct.unpack_from("<q", buf, patch_off)[0];
            val = IMAGE_BASE + trva + a;
            struct.pack_into("<Q", buf, patch_off, val & 0xFFFFFFFFFFFFFFFF);
        } elif rel.rtype == REL_ADDR32 {
            a = struct.unpack_from("<i", buf, patch_off)[0];
            val = (IMAGE_BASE + trva + a) & 0xFFFFFFFF;
            struct.pack_into("<I", buf, patch_off, val);
        } elif rel.rtype == REL_ADDR32NB {
            a = struct.unpack_from("<i", buf, patch_off)[0];
            struct.pack_into("<i", buf, patch_off, trva + a);
        } elif rel.rtype >= REL_REL32 and rel.rtype <= REL_REL32_5 {
            extra = rel.rtype - REL_REL32;
            a = struct.unpack_from("<i", buf, patch_off)[0];
            val = trva + a - (patch_rva + 4 + extra);
            struct.pack_into("<i", buf, patch_off, val);
        } else {
            raise ValueError(
                f"PE linker: no handler for relocation type {rel.rtype}. "
                f"Refusing to emit a binary with an unrelocated reference."
            );
        }
    }

    # ── Entry point ───────────────────────────────────────────────
    entry_rva = text_rva;
    for cand in ["_jac_win_start", "mainCRTStartup", "main"] {
        found = False;
        for s in self.symbols {
            if s is not None and s.name == cand and s.sec_num > 0 {
                spl = sec_seg.get(s.sec_num - 1);
                if spl is not None and spl[0] == "code" {
                    entry_rva = text_rva + spl[1] + s.value;
                    found = True;
                    break;
                }
            }
        }
        if found {
            break;
        }
    }

    # ── Exception directory (.pdata) ──────────────────────────────
    exc_rva = 0;
    exc_sz = 0;
    if pdata_idx >= 0 {
        spl = sec_seg[pdata_idx];
        exc_rva = rodata_rva + spl[1];
        exc_sz = self.sections[pdata_idx].vsize;
    }

    # ── File offsets ──────────────────────────────────────────────
    text_foff = _align(headers_file, FILE_ALIGN);
    text_rawsz = _align(len(code_blob), FILE_ALIGN);
    rodata_foff = text_foff + text_rawsz;
    rodata_rawsz = _align(len(rodata_blob), FILE_ALIGN);
    data_foff = rodata_foff + rodata_rawsz;
    data_rawsz = _align(len(data_blob), FILE_ALIGN);
    idata_foff = data_foff + data_rawsz;
    idata_rawsz = _align(len(idata), FILE_ALIGN);
    total = idata_foff + idata_rawsz;
    size_image = _align(idata_rva + idata_vsize, SECT_ALIGN);

    out = bytearray(total);

    # ── DOS header + e_lfanew (no DOS stub program) ───────────────
    out[0:2] = b"MZ";
    struct.pack_into("<I", out, 0x3C, 0x80);
    pe_off = 0x80;
    out[pe_off:pe_off + 4] = b"PE\x00\x00";

    # ── COFF file header ──────────────────────────────────────────
    # EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE | RELOCS_STRIPPED
    file_chars = 0x0002 | 0x0020 | 0x0001;
    struct.pack_into(
        "<HHIIIHH",
        out,
        pe_off + 4,
        IMAGE_FILE_MACHINE_AMD64,
        nsec_out,
        0,
        0,
        0,
        240,
        file_chars
    );

    # ── Optional header (PE32+) ───────────────────────────────────
    opt = pe_off + 4 + 20;
    size_code = text_rawsz;
    size_initdata = rodata_rawsz + data_rawsz + idata_rawsz;
    struct.pack_into(
        "<HBBIIIII",
        out,
        opt,
        0x20B,
        14,
        0,
        size_code,
        size_initdata,
        0,
        entry_rva,
        text_rva
    );
    struct.pack_into("<Q", out, opt + 24, IMAGE_BASE);
    struct.pack_into("<II", out, opt + 32, SECT_ALIGN, FILE_ALIGN);
    struct.pack_into("<HHHHHH", out, opt + 40, 6, 0, 0, 0, 6, 0);
    struct.pack_into("<I", out, opt + 52, 0);
    struct.pack_into("<I", out, opt + 56, size_image);
    struct.pack_into("<I", out, opt + 60, sz_headers);
    struct.pack_into("<I", out, opt + 64, 0);
    # Subsystem = WINDOWS_CUI (console), DllCharacteristics = 0 (load at base)
    struct.pack_into("<HH", out, opt + 68, 3, 0);
    struct.pack_into("<QQQQ", out, opt + 72, 0x100000, 0x1000, 0x100000, 0x1000);
    struct.pack_into("<II", out, opt + 104, 0, 16);

    # Data directories: Import (1), Exception (3), IAT (12)
    dd = opt + 112;
    struct.pack_into("<II", out, dd + 1 * 8, idata_rva, desc_sz);
    if exc_sz > 0 {
        struct.pack_into("<II", out, dd + 3 * 8, exc_rva, exc_sz);
    }
    if dlls {
        struct.pack_into("<II", out, dd + 12 * 8, idata_rva + iat_start, iat_total);
    }

    # ── Section table ─────────────────────────────────────────────
    st = opt + 240;
    _pe_write_shdr(
        out,
        st,
        0,
        ".text",
        len(code_blob),
        text_rva,
        text_rawsz,
        text_foff,
        SCN_CNT_CODE | SCN_MEM_EXECUTE | SCN_MEM_READ
    );
    _pe_write_shdr(
        out,
        st,
        1,
        ".rdata",
        max(len(rodata_blob), 1),
        rodata_rva,
        rodata_rawsz,
        rodata_foff if rodata_rawsz else 0,
        SCN_CNT_INITIALIZED_DATA | SCN_MEM_READ
    );
    _pe_write_shdr(
        out,
        st,
        2,
        ".data",
        max(data_vsize, 1),
        data_rva,
        data_rawsz,
        data_foff if data_rawsz else 0,
        SCN_CNT_INITIALIZED_DATA | SCN_MEM_READ | SCN_MEM_WRITE
    );
    _pe_write_shdr(
        out,
        st,
        3,
        ".idata",
        idata_vsize,
        idata_rva,
        idata_rawsz,
        idata_foff,
        SCN_CNT_INITIALIZED_DATA | SCN_MEM_READ | SCN_MEM_WRITE
    );

    # ── Section data ──────────────────────────────────────────────
    out[text_foff:text_foff + len(code_blob)] = bytes(code_blob);
    if len(rodata_blob) > 0 {
        out[rodata_foff:rodata_foff + len(rodata_blob)] = bytes(rodata_blob);
    }
    if len(data_blob) > 0 {
        out[data_foff:data_foff + len(data_blob)] = bytes(data_blob);
    }
    out[idata_foff:idata_foff + len(idata)] = bytes(idata);

    return bytes(out);
}


"""Write one 40-byte PE section header into the section table."""
def _pe_write_shdr(
    out: bytearray,
    table_off: int,
    idx: int,
    name: str,
    vsize: int,
    rva: int,
    rawsz: int,
    foff: int,
    chars: int
) {
    o = table_off + idx * 40;
    nb = name.encode()[:8];
    nb = nb + b"\x00" * (8 - len(nb));
    out[o:o + 8] = nb;
    struct.pack_into(
        "<IIIIIIHHI", out, o + 8, vsize, rva, rawsz, foff, 0, 0, 0, 0, chars
    );
}


# ══════════════════════════════════════════════════════════════════
# Static link entry point
# ══════════════════════════════════════════════════════════════════
impl PeLinker.link(
    obj_bytes: bytes,
    output_path: str,
    needed_libs: list[str] = ["msvcrt.dll"],
    symbol_lib_map: dict[str, str] = {}
) -> bool {
    linker = PeLinker(
        obj_data=obj_bytes,
        symbols=[],
        sections=[],
        relocations=[],
        needed_libs=needed_libs,
        symbol_lib_map=symbol_lib_map
    );
    if not linker.parse_object() {
        return False;
    }
    exe_bytes = linker.build_executable();
    if not exe_bytes {
        return False;
    }
    with open(output_path, "wb") as f {
        f.write(exe_bytes);
    }
    return True;
}
