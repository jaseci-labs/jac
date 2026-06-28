"""Shared linker utility implementations."""

import struct;

impl _align(value: int, alignment: int) -> int {
    if alignment <= 1 {
        return value;
    }
    return (value + alignment - 1) & ~(alignment - 1);
}


impl _build_strtab(
    strings: list[str], initial_bytes: bytes = b"\x00"
) -> tuple[bytes, dict[str, int]] {
    data = bytearray(initial_bytes);
    offsets: dict[str, int] = {};
    for s in strings {
        if s not in offsets {
            offsets[s] = len(data);
            data.extend(s.encode("utf-8") + b"\x00");
        }
    }
    return (bytes(data), offsets);
}


"""Align blob, append data (with BSS zero-fill if mem_size > data),
return the offset where data was placed."""
impl _append_to_blob(
    blob: bytearray, data: bytes, alignment: int, mem_size: int
) -> int {
    aligned_off = _align(len(blob), max(alignment, 1));
    blob.extend(b"\x00" * (aligned_off - len(blob)));
    result_off = len(blob);
    if len(data) > 0 {
        blob.extend(data);
        if mem_size > len(data) {
            blob.extend(b"\x00" * (mem_size - len(data)));
        }
    } else {
        blob.extend(b"\x00" * mem_size);
    }
    return result_off;
}


impl _resolve_seg_vaddr(
    seg: str, seg_off: int, code_vaddr: int, rodata_vaddr: int, data_vaddr: int
) -> int {
    if seg == "code" {
        return code_vaddr + seg_off;
    } elif seg == "rodata" {
        return rodata_vaddr + seg_off;
    } elif seg == "data" {
        return data_vaddr + seg_off;
    }
    return 0;
}


"""Resolve a relocation's patch site. Locates the output blob holding
`target_sec` and returns (patch_buf, patch_off, patch_vaddr): the buffer to
write into, the byte offset of the fixup within that buffer, and the final
virtual address of the fixup. Returns None when `target_sec` is not placed in
the loadable image (e.g. metadata like .eh_frame), so the caller skips it.

A section sits at `sec_off` within its segment's blob, and that blob loads at
`<seg>_vaddr`; the fixup is `reloc_offset` bytes into the section. So both the
buffer offset and the vaddr are `sec_off + reloc_offset` past the segment base.
This is the arithmetic every ELF/Mach-O relocation loop (executable and
shared-object) used to inline by hand — centralized here so the two cannot
drift. (ELF previously added `sec_off` a second time to the vaddr, which only
agreed with the correct value while a segment held a single section, i.e.
`sec_off == 0`; this unifies on the correct form.)"""
impl _resolve_patch_site(
    reloc_offset: int,
    target_sec: str,
    code_sections: dict[str, tuple[int, int]],
    rodata_sections: dict[str, tuple[int, int]],
    data_sections: dict[str, tuple[int, int]],
    code_bytes: bytearray,
    rodata_bytes: bytearray,
    data_bytes: bytearray,
    code_vaddr: int,
    rodata_vaddr: int,
    data_vaddr: int
) -> tuple[bytearray, int, int] | None {
    if target_sec in code_sections {
        sec_off = code_sections[target_sec][0];
        return (
            code_bytes,
            sec_off + reloc_offset,
            code_vaddr + sec_off + reloc_offset
        );
    } elif target_sec in rodata_sections {
        sec_off = rodata_sections[target_sec][0];
        return (
            rodata_bytes,
            sec_off + reloc_offset,
            rodata_vaddr + sec_off + reloc_offset
        );
    } elif target_sec in data_sections {
        sec_off = data_sections[target_sec][0];
        return (
            data_bytes,
            sec_off + reloc_offset,
            data_vaddr + sec_off + reloc_offset
        );
    }
    return None;
}


impl _find_entry_vaddr(
    local_sym_map: dict[str, tuple[str, int]], code_vaddr: int
) -> int {
    for name in ["_start", "main"] {
        local = local_sym_map.get(name);
        if local is not None {
            (seg, seg_off) = local;
            if seg == "code" {
                return code_vaddr + seg_off;
            }
        }
    }
    return code_vaddr;
}


# ─── Static `ar` archive support (#6978 Phase 0.1a) ───────────
"""Read one little/given-endian scalar at `off` as a plain int. `struct.unpack`
yields `Any`, which Jac's checker will not let flow into int arithmetic, so this
pins the cast in one place."""
def _u(fmt: str, buf: bytes, off: int) -> int {
    return int(struct.unpack_from(fmt, buf, off)[0]);
}


"""Read a NUL-terminated C string out of `buf` starting at `off`."""
def _ar_cstr(buf: bytes, off: int) -> str {
    end = buf.find(b"\x00", off);
    if end < 0 {
        end = len(buf);
    }
    return buf[off:end].decode("ascii", "replace");
}


"""Names the archive uses for its own bookkeeping members (symbol index and
GNU long-name table), never real objects."""
def _ar_is_special(name: str) -> bool {
    return name in ["/", "/SYM64/", "//"] or name.startswith("__.SYMDEF");
}


"""Walk an `ar` archive's member headers, resolving BSD (`#1/N`) and GNU
(`//`-table) extended names, and return raw (name, header_offset, object_bytes)
triples -- including the symbol-index member so callers can find it."""
def _ar_raw_members(data: bytes) -> list[tuple[str, int, bytes]] {
    out: list[tuple[str, int, bytes]] = [];
    if len(data) < 8 or data[0:8] != b"!<arch>\n" {
        return out;
    }
    gnu_longnames: bytes = b"";
    pos = 8;
    n = len(data);
    while pos + 60 <= n {
        hdr = data[pos:pos + 60];
        if hdr[58:60] != b"`\n" {
            break;  # malformed / trailing padding -- stop cleanly
        }
        name_field = hdr[0:16].decode("ascii", "replace").rstrip();
        size_str = hdr[48:58].decode("ascii", "replace").strip();
        if not size_str.isdigit() {
            break;
        }
        size = int(size_str);
        dstart = pos + 60;
        raw = data[dstart:dstart + size];
        header_off = pos;
        # Members are 2-byte aligned in the archive.
        pos = dstart + size + (size % 2);
        if name_field == "//" {
            gnu_longnames = raw;  # GNU long-name string table; not an object
            continue;
        }
        name = name_field;
        obj_data = raw;
        if name_field.startswith("#1/") {
            # BSD: the real name is the first N bytes of the payload (and `size`
            # counts them), NUL/space padded.
            ext_len = int(name_field[3:]);
            name = _ar_cstr(raw[0:ext_len], 0).rstrip();
            obj_data = raw[ext_len:];
        } elif name_field == "/" or name_field == "/SYM64/" {
            name = name_field;  # GNU symbol index member
        } elif name_field.startswith("/") and name_field[1:].isdigit() {
            # GNU long-name reference: byte offset into the `//` table, '\n'- or
            # '/'-terminated.
            off = int(name_field[1:]);
            end = gnu_longnames.find(b"\n", off);
            if end < 0 {
                end = len(gnu_longnames);
            }
            name = gnu_longnames[off:end].decode("ascii", "replace").rstrip(
                "/"
            ).rstrip();
        } else {
            name = name_field.rstrip("/");  # GNU appends '/' to short names
        }
        out.append((name, header_off, obj_data));
    }
    return out;
}


impl parse_ar_archive(data: bytes) -> list[ArMember] {
    members: list[ArMember] = [];
    for (name, header_off, obj_data) in _ar_raw_members(data) {
        if _ar_is_special(name) {
            continue;
        }
        members.append(ArMember(name=name, header_offset=header_off, data=obj_data));
    }
    return members;
}


"""Decode a BSD `__.SYMDEF` ranlib table: a size-prefixed array of
(string-offset, member-offset) pairs followed by a size-prefixed string blob.
`wide` selects the 64-bit (`_64`) variant."""
def _ar_parse_bsd_symdef(payload: bytes, wide: bool) -> dict[str, int] {
    result: dict[str, int] = {};
    word = 8 if wide else 4;
    wfmt = "<Q" if wide else "<I";
    if len(payload) < word {
        return result;
    }
    tab_size = _u(wfmt, payload, 0);
    pair = word * 2;
    npairs = tab_size // pair;
    str_base = word + tab_size + word;  # skip pairs and the strtab-size word
    for i in range(npairs) {
        off = word + i * pair;
        str_off = _u(wfmt, payload, off);
        mem_off = _u(wfmt, payload, off + word);
        name = _ar_cstr(payload, str_base + str_off);
        if name {
            result[name] = mem_off;
        }
    }
    return result;
}


"""Decode a GNU `/` symbol table: a big-endian count, that many big-endian
member-offsets, then that many NUL-terminated names in the same order. `wide`
selects the `/SYM64/` 8-byte variant."""
def _ar_parse_gnu_symtab(payload: bytes, wide: bool) -> dict[str, int] {
    result: dict[str, int] = {};
    word = 8 if wide else 4;
    wfmt = ">Q" if wide else ">I";
    if len(payload) < word {
        return result;
    }
    count = _u(wfmt, payload, 0);
    offs: list[int] = [];
    for i in range(count) {
        offs.append(_u(wfmt, payload, word + i * word));
    }
    str_pos = word + count * word;
    for i in range(count) {
        name = _ar_cstr(payload, str_pos);
        str_pos = str_pos + len(name) + 1;
        if name {
            result[name] = offs[i];
        }
    }
    return result;
}


impl parse_ar_symbol_index(data: bytes) -> dict[str, int] {
    for (name, _header_off, payload) in _ar_raw_members(data) {
        if name.startswith("__.SYMDEF") {
            return _ar_parse_bsd_symdef(payload, name.endswith("_64"));
        }
        if name == "/" {
            return _ar_parse_gnu_symtab(payload, False);
        }
        if name == "/SYM64/" {
            return _ar_parse_gnu_symtab(payload, True);
        }
    }
    return {};
}


"""Collect the externally-visible undefined symbols of a single relocatable
object (Mach-O or ELF, 64-bit LE). Used to chase transitive archive deps; a
lightweight scan independent of the linkers' full parse_object."""
def _ar_member_undefs(mem: bytes) -> list[str] {
    if len(mem) < 4 {
        return [];
    }
    magic = mem[0:4];
    if magic == b"\xcf\xfa\xed\xfe" {
        return _macho_obj_undefs(mem);
    }
    if magic == b"\x7fELF" {
        return _elf_obj_undefs(mem);
    }
    return [];
}


def _macho_obj_undefs(mem: bytes) -> list[str] {
    undefs: list[str] = [];
    if len(mem) < 32 {
        return undefs;
    }
    ncmds = _u("<I", mem, 16);
    off = 32;  # past mach_header_64
    for _ in range(ncmds) {
        if off + 8 > len(mem) {
            break;
        }
        cmd = _u("<I", mem, off);
        cmdsize = _u("<I", mem, off + 4);
        if cmd == 0x02 {  # LC_SYMTAB
            symoff = _u("<I", mem, off + 8);
            nsyms = _u("<I", mem, off + 12);
            stroff = _u("<I", mem, off + 16);
            strsize = _u("<I", mem, off + 20);
            strtab = mem[stroff:stroff + strsize];
            for i in range(nsyms) {
                e = symoff + i * 16;
                if e + 16 > len(mem) {
                    break;
                }
                n_strx = _u("<I", mem, e);
                n_type = _u("<B", mem, e + 4);
                n_sect = _u("<B", mem, e + 5);
                # N_UNDF (type bits 0) + N_EXT (0x01), no defining section.
                if (n_type & 0x0e) == 0 and (n_type & 0x01) != 0 and n_sect == 0 {
                    name = _ar_cstr(strtab, n_strx);
                    if name {
                        undefs.append(name);
                    }
                }
            }
        }
        if cmdsize == 0 {
            break;
        }
        off = off + cmdsize;
    }
    return undefs;
}


def _elf_obj_undefs(mem: bytes) -> list[str] {
    undefs: list[str] = [];
    if len(mem) < 64 {
        return undefs;
    }
    e_shoff = _u("<Q", mem, 0x28);
    e_shentsize = _u("<H", mem, 0x3a);
    e_shnum = _u("<H", mem, 0x3c);
    # Locate SHT_SYMTAB and the string-table section it links to.
    symtab_off = 0;
    symtab_size = 0;
    symtab_ent = 0;
    strtab_idx = 0;
    for i in range(e_shnum) {
        sh = e_shoff + i * e_shentsize;
        if sh + 64 > len(mem) {
            break;
        }
        sh_type = _u("<I", mem, sh + 4);
        if sh_type == 2 {  # SHT_SYMTAB
            symtab_off = _u("<Q", mem, sh + 0x18);
            symtab_size = _u("<Q", mem, sh + 0x20);
            strtab_idx = _u("<I", mem, sh + 0x28);
            symtab_ent = _u("<Q", mem, sh + 0x38);
        }
    }
    if symtab_ent == 0 {
        return undefs;
    }
    strsh = e_shoff + strtab_idx * e_shentsize;
    str_off = _u("<Q", mem, strsh + 0x18);
    str_size = _u("<Q", mem, strsh + 0x20);
    strtab = mem[str_off:str_off + str_size];
    nsyms = symtab_size // symtab_ent;
    for i in range(nsyms) {
        e = symtab_off + i * symtab_ent;
        if e + 24 > len(mem) {
            break;
        }
        st_name = _u("<I", mem, e);
        st_info = _u("<B", mem, e + 4);
        st_shndx = _u("<H", mem, e + 6);
        bind = st_info >> 4;
        # SHN_UNDEF (0) + GLOBAL/WEAK binding.
        if st_shndx == 0 and bind >= 1 {
            name = _ar_cstr(strtab, st_name);
            if name {
                undefs.append(name);
            }
        }
    }
    return undefs;
}


impl select_ar_members(data: bytes, root_undef: list[str]) -> list[ArMember] {
    index = parse_ar_symbol_index(data);
    by_off: dict[int, ArMember] = {};
    for m in parse_ar_archive(data) {
        by_off[m.header_offset] = m;
    }
    selected: dict[int, ArMember] = {};
    seen_syms: set[str] = set();
    worklist: list[str] = list(root_undef);
    while worklist {
        sym = worklist.pop();
        if sym in seen_syms {
            continue;
        }
        seen_syms.add(sym);
        off = index.get(sym);
        if off is None or off in selected {
            continue;
        }
        m = by_off.get(off);
        if m is None {
            continue;
        }
        selected[off] = m;
        for u in _ar_member_undefs(m.data) {
            if u not in seen_syms {
                worklist.append(u);
            }
        }
    }
    ordered = sorted(selected.keys());
    return [selected[o] for o in ordered];
}
