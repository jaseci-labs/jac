import struct;
import os;
import hashlib;
import from jaclang.compiler.passes.native.linker_common {
    _align,
    _build_strtab,
    _append_to_blob,
    _resolve_seg_vaddr,
    _resolve_patch_site,
    _find_entry_vaddr
}

glob MH_MAGIC_64 = 0xFEEDFACF,
     MH_OBJECT = 1,
     MH_EXECUTE = 2,
     MH_DYLIB = 6;

glob CPU_TYPE_X86_64 = 0x01000007,
     CPU_TYPE_ARM64 = 0x0100000C,
     CPU_SUBTYPE_ALL = 0,
     CPU_SUBTYPE_X86_64_ALL = 3,
     CPU_SUBTYPE_ARM64_ALL = 0;

glob MH_NOUNDEFS = 0x1,
     MH_DYLDLINK = 0x4,
     MH_TWOLEVEL = 0x80,
     MH_PIE = 0x200000;

glob LC_SEGMENT_64 = 0x19,
     LC_SYMTAB = 0x02,
     LC_DYSYMTAB = 0x0B,
     LC_LOAD_DYLINKER = 0x0E,
     LC_LOAD_DYLIB = 0x0C,
     LC_ID_DYLIB = 0x0D,
     LC_MAIN = 0x80000028,
     LC_DYLD_INFO_ONLY = 0x80000022,
     LC_CODE_SIGNATURE = 0x1D,
     LC_BUILD_VERSION = 0x32,
     LC_DATA_IN_CODE = 0x29;

glob S_REGULAR = 0x0,
     S_MOD_INIT_FUNC_POINTERS = 0x9,
     S_NON_LAZY_SYMBOL_POINTERS = 0x6,
     S_SYMBOL_STUBS = 0x8,
     S_ATTR_PURE_INSTRUCTIONS = 0x80000000,
     S_ATTR_SOME_INSTRUCTIONS = 0x400;

glob EXPORT_SYMBOL_FLAGS_KIND_REGULAR = 0x00;

glob N_EXT = 0x01,
     N_TYPE_MASK = 0x0E,
     N_UNDF = 0x00,
     N_SECT = 0x0E;

glob ARM64_RELOC_UNSIGNED = 0,
     ARM64_RELOC_SUBTRACTOR = 1,
     ARM64_RELOC_BRANCH26 = 2,
     ARM64_RELOC_PAGE21 = 3,
     ARM64_RELOC_PAGEOFF12 = 4,
     ARM64_RELOC_GOT_LOAD_PAGE21 = 5,
     ARM64_RELOC_GOT_LOAD_PAGEOFF12 = 6,
     ARM64_RELOC_POINTER_TO_GOT = 7,
     ARM64_RELOC_ADDEND = 10;

glob X86_64_RELOC_UNSIGNED = 0,
     X86_64_RELOC_SIGNED = 1,
     X86_64_RELOC_BRANCH = 2,
     X86_64_RELOC_GOT_LOAD = 3,
     X86_64_RELOC_GOT = 4,
     X86_64_RELOC_SUBTRACTOR = 5,
     X86_64_RELOC_SIGNED_1 = 6,
     X86_64_RELOC_SIGNED_2 = 7,
     X86_64_RELOC_SIGNED_4 = 8;

glob BIND_OPCODE_DONE = 0x00,
     BIND_OPCODE_SET_DYLIB_ORDINAL_IMM = 0x10,
     BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM = 0x40,
     BIND_OPCODE_SET_TYPE_IMM = 0x50,
     BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB = 0x70,
     BIND_OPCODE_DO_BIND = 0x90,
     BIND_TYPE_POINTER = 1;

glob REBASE_OPCODE_DONE = 0x00,
     REBASE_OPCODE_SET_TYPE_IMM = 0x10,
     REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB = 0x20,
     REBASE_OPCODE_DO_REBASE = 0x51,
     REBASE_TYPE_POINTER = 1;

glob CSMAGIC_EMBEDDED_SIGNATURE = 0xFADE0CC0,
     CSMAGIC_CODEDIRECTORY = 0xFADE0C02,
     CS_ADHOC = 0x00000002,
     CS_LINKER_SIGNED = 0x00020000,
     CS_EXECSEG_MAIN_BINARY = 0x1,
     CS_HASHTYPE_SHA256 = 2,
     CS_PAGE_SIZE = 4096,
     CS_PAGE_SIZE_LOG2 = 12;


def _encode_uleb128(value: int) -> bytes {
    result = bytearray();
    while True {
        byte = value & 0x7F;
        value >>= 7;
        if value != 0 {
            byte |= 0x80;
        }
        result.append(byte);
        if value == 0 {
            break;
        }
    }
    return bytes(result);
}


def _resolve_macho_name(
    local_sym_map: dict[str, tuple[str, int]], nm: str
) -> (str | None) {
    if nm in local_sym_map {
        return nm;
    }
    if ("_" + nm) in local_sym_map {
        return "_" + nm;
    }
    return None;
}


def _build_export_trie(symbols: list[tuple[str, int]]) -> bytes {
    n = len(symbols);
    if n == 0 {
        return bytes([0, 0]);
    }

    term_nodes: list[bytes] = [];
    for (name, addr) in symbols {
        info = _encode_uleb128(EXPORT_SYMBOL_FLAGS_KIND_REGULAR) + _encode_uleb128(
            addr
        );
        tnode = _encode_uleb128(len(info)) + info + bytes([0]);
        term_nodes.append(tnode);
    }
    child_off: list[int] = [0] * n;

    for _iter in range(8) {
        rootbuf = bytearray();
        rootbuf.extend(_encode_uleb128(0));
        rootbuf.append(n);
        for (i, pair) in enumerate(symbols) {
            rootbuf.extend(pair[0].encode("utf-8") + b"\x00");
            rootbuf.extend(_encode_uleb128(child_off[i]));
        }
        pos = len(rootbuf);
        new_off: list[int] = [];
        for i in range(n) {
            new_off.append(pos);
            pos += len(term_nodes[i]);
        }
        if new_off == child_off {
            break;
        }
        child_off = new_off;
    }
    blob = bytearray();
    blob.extend(_encode_uleb128(0));
    blob.append(n);
    for (i, pair) in enumerate(symbols) {
        blob.extend(pair[0].encode("utf-8") + b"\x00");
        blob.extend(_encode_uleb128(child_off[i]));
    }
    for tn in term_nodes {
        blob.extend(tn);
    }
    return bytes(blob);
}


def _lc_str_pad(s: str, header_size: int) -> bytes {
    raw = s.encode("utf-8") + b"\x00";
    total = header_size + len(raw);
    pad = _align(total, 8) - total;
    return raw + b"\x00" * pad;
}


def _arm64_build_stub(stub_vaddr: int, got_entry_vaddr: int) -> bytes {
    data = bytearray();

    page_diff = ((got_entry_vaddr & ~0xFFF) - (stub_vaddr & ~0xFFF)) >> 12;
    immlo = (page_diff & 0x3) << 29;
    immhi = ((page_diff >> 2) & 0x7FFFF) << 5;
    data.extend(struct.pack("<I", 0x90000010 | immlo | immhi));

    imm12 = (got_entry_vaddr & 0xFFF) >> 3;
    data.extend(struct.pack("<I", 0xF9400210 | (imm12 << 10)));

    data.extend(struct.pack("<I", 0xD61F0200));
    return bytes(data);
}

glob ARM64_STUB_SIZE = 12;


def _arm64_apply_reloc(
    rtype: int,
    patch_buf: bytearray,
    patch_off: int,
    sym_addr: int,
    addend: int,
    patch_vaddr: int
) -> bool {
    if rtype == ARM64_RELOC_BRANCH26 {
        offset = ((sym_addr + addend - patch_vaddr) >> 2) & 0x3FFFFFF;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0xFC000000) | offset;
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == ARM64_RELOC_PAGE21 or rtype == ARM64_RELOC_GOT_LOAD_PAGE21 {
        page_s = (sym_addr + addend) & ~0xFFF;
        page_p = patch_vaddr & ~0xFFF;
        page_off = (page_s - page_p) >> 12;
        immlo = (page_off & 0x3) << 29;
        immhi = ((page_off >> 2) & 0x7FFFF) << 5;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0x9F00001F) | immlo | immhi;
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == ARM64_RELOC_PAGEOFF12 or rtype == ARM64_RELOC_GOT_LOAD_PAGEOFF12 {
        lo12 = (sym_addr + addend) & 0xFFF;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        opc = (insn >> 22) & 0x3FF;
        if (insn & 0x3B000000) == 0x39000000 {
            size_bits = (insn >> 30) & 0x3;
            is_128 = ((insn >> 23) & 1) == 1 and size_bits == 0;
            if is_128 {
                lo12 >>= 4;
            } elif size_bits == 3 {
                lo12 >>= 3;
            } elif size_bits == 2 {
                lo12 >>= 2;
            } elif size_bits == 1 {
                lo12 >>= 1;
            }
        }
        insn = (insn & 0xFFC003FF) | ((lo12 & 0xFFF) << 10);
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == ARM64_RELOC_UNSIGNED {
        val = (sym_addr + addend) & 0xFFFFFFFFFFFFFFFF;
        struct.pack_into("<Q", patch_buf, patch_off, val);
        return True;
    } elif rtype == ARM64_RELOC_POINTER_TO_GOT {
        val = sym_addr + addend - patch_vaddr;
        struct.pack_into("<i", patch_buf, patch_off, val);
        return True;
    }
    return False;
}


def _x86_64_build_stub(stub_vaddr: int, got_entry_vaddr: int) -> bytes {
    disp32 = got_entry_vaddr - (stub_vaddr + 6);
    return b"\xFF\x25" + struct.pack("<i", disp32);
}

glob X86_64_STUB_SIZE = 6;


def _x86_64_apply_reloc(
    rtype: int,
    patch_buf: bytearray,
    patch_off: int,
    sym_addr: int,
    addend: int,
    patch_vaddr: int
) -> bool {
    if rtype == X86_64_RELOC_BRANCH or rtype == X86_64_RELOC_SIGNED {
        val = sym_addr + addend - patch_vaddr - 4;
        struct.pack_into("<i", patch_buf, patch_off, val);
        return True;
    } elif rtype == X86_64_RELOC_SIGNED_1 {
        val = sym_addr + addend - patch_vaddr - 4 - 1;
        struct.pack_into("<i", patch_buf, patch_off, val);
        return True;
    } elif rtype == X86_64_RELOC_SIGNED_2 {
        val = sym_addr + addend - patch_vaddr - 4 - 2;
        struct.pack_into("<i", patch_buf, patch_off, val);
        return True;
    } elif rtype == X86_64_RELOC_SIGNED_4 {
        val = sym_addr + addend - patch_vaddr - 4 - 4;
        struct.pack_into("<i", patch_buf, patch_off, val);
        return True;
    } elif rtype == X86_64_RELOC_UNSIGNED {
        val = (sym_addr + addend) & 0xFFFFFFFFFFFFFFFF;
        struct.pack_into("<Q", patch_buf, patch_off, val);
        return True;
    } elif rtype == X86_64_RELOC_GOT_LOAD or rtype == X86_64_RELOC_GOT {
        val = sym_addr + addend - patch_vaddr - 4;
        struct.pack_into("<i", patch_buf, patch_off, val);
        return True;
    }
    return False;
}


def _build_code_signature(
    binary_data: bytes,
    code_limit: int,
    text_offset: int,
    text_size: int,
    ident: str = "jac-binary",
    exec_seg_flags: int = 0
) -> bytes {
    hash_size = 32;
    n_code_slots = (code_limit + CS_PAGE_SIZE - 1) // CS_PAGE_SIZE;
    ident_bytes = ident.encode("utf-8") + b"\x00";

    cd_header_size = 88;
    ident_offset = cd_header_size;
    hash_offset = ident_offset + len(ident_bytes);
    cd_length = hash_offset + n_code_slots * hash_size;

    cd = bytearray();
    cd.extend(struct.pack(">I", CSMAGIC_CODEDIRECTORY));
    cd.extend(struct.pack(">I", cd_length));
    cd.extend(struct.pack(">I", 0x20400));
    cd.extend(struct.pack(">I", CS_ADHOC | CS_LINKER_SIGNED));
    cd.extend(struct.pack(">I", hash_offset));
    cd.extend(struct.pack(">I", ident_offset));
    cd.extend(struct.pack(">I", 0));
    cd.extend(struct.pack(">I", n_code_slots));
    cd.extend(struct.pack(">I", code_limit));
    cd.extend(struct.pack(">B", hash_size));
    cd.extend(struct.pack(">B", CS_HASHTYPE_SHA256));
    cd.extend(struct.pack(">B", 0));
    cd.extend(struct.pack(">B", CS_PAGE_SIZE_LOG2));
    cd.extend(struct.pack(">I", 0));
    cd.extend(struct.pack(">I", 0));
    cd.extend(struct.pack(">I", 0));
    cd.extend(struct.pack(">I", 0));
    cd.extend(struct.pack(">Q", 0));
    cd.extend(struct.pack(">Q", text_offset));
    cd.extend(struct.pack(">Q", text_size));
    cd.extend(struct.pack(">Q", exec_seg_flags));
    cd.extend(ident_bytes);

    for i in range(n_code_slots) {
        page_start = i * CS_PAGE_SIZE;
        page_end = min(page_start + CS_PAGE_SIZE, code_limit);
        page_data = binary_data[page_start:page_end];
        cd.extend(hashlib.sha256(page_data).digest());
    }

    sb_header_size = 12 + 8;
    sb_length = sb_header_size + cd_length;

    sb = bytearray();
    sb.extend(struct.pack(">I", CSMAGIC_EMBEDDED_SIGNATURE));
    sb.extend(struct.pack(">I", sb_length));
    sb.extend(struct.pack(">I", 1));
    sb.extend(struct.pack(">II", 0, sb_header_size));
    sb.extend(cd);
    return bytes(sb);
}


impl MachOLinker.parse_object -> bool {
    raw = self.obj_data;
    if len(raw) < 32 {
        return False;
    }

    magic = struct.unpack_from("<I", raw, 0)[0];
    if magic != MH_MAGIC_64 {
        return False;
    }

    (cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags) = struct.unpack_from(
        "<iIIIII", raw, 4
    );
    if filetype != MH_OBJECT {
        return False;
    }
    self.cpu_type = cputype;
    self.cpu_subtype = cpusubtype;

    cmd_offset = 32;
    symtab_info: tuple | None = None;
    self.sections = [];
    self.symbols = [];
    self.relocations = [];

    for _ in range(ncmds) {
        (cmd, cmdsize) = struct.unpack_from("<II", raw, cmd_offset);

        if cmd == LC_SEGMENT_64 {
            (vmaddr, vmsize, fileoff, filesize, maxprot, initprot, nsects, seg_flags) = struct.unpack_from(
                "<QQQQIIII", raw, cmd_offset + 24
            );
            sec_off = cmd_offset + 72;
            for _ in range(nsects) {
                raw_sectname = raw[sec_off:sec_off + 16];
                raw_segname = raw[sec_off + 16:sec_off + 32];
                sectname = raw_sectname.split(b"\x00")[0].decode(
                    "utf-8", errors="replace"
                );
                segname = raw_segname.split(b"\x00")[0].decode(
                    "utf-8", errors="replace"
                );
                (
                    s_addr,
                    s_size,
                    s_offset,
                    s_align,
                    s_reloff,
                    s_nreloc,
                    s_flags,
                    s_res1,
                    s_res2,
                    s_res3
                ) = struct.unpack_from("<QQIIIIIIII", raw, sec_off + 32);
                sec_data = raw[s_offset:s_offset + s_size]
                    if s_size > 0 and s_offset > 0
                    else b"";
                self.sections.append(
                    MachOSection(
                        name=sectname,
                        segname=segname,
                        addr=s_addr,
                        size=s_size,
                        data=sec_data,
                        align=1 << s_align if s_align < 30 else 1,
                        flags=s_flags,
                        reserved1=s_res1,
                        reserved2=s_res2
                    )
                );

                for k in range(s_nreloc) {
                    r_off = s_reloff + k * 8;
                    (r_address, r_info) = struct.unpack_from("<iI", raw, r_off);
                    r_symbolnum = r_info & 0xFFFFFF;
                    r_pcrel = (r_info >> 24) & 1;
                    r_length = (r_info >> 25) & 3;
                    r_extern = (r_info >> 27) & 1;
                    r_type = (r_info >> 28) & 0xF;
                    self.relocations.append(
                        MachOReloc(
                            address=r_address,
                            symbolnum=r_symbolnum,
                            pcrel=r_pcrel,
                            length=r_length,
                            extern=r_extern,
                            rtype=r_type,
                            target_sec=f"{segname}:{sectname}",
                            addend=0
                        )
                    );
                }
                sec_off += 80;
            }
        } elif cmd == LC_SYMTAB {
            (symoff, nsyms, stroff, strsize) = struct.unpack_from(
                "<IIII", raw, cmd_offset + 8
            );
            symtab_info = (symoff, nsyms, stroff, strsize);
        }
        cmd_offset += cmdsize;
    }

    if symtab_info is not None {
        (symoff, nsyms, stroff, strsize) = symtab_info;
        strtab = raw[stroff:stroff + strsize];
        for i in range(nsyms) {
            off = symoff + i * 16;
            (n_strx, n_type, n_sect, n_desc, n_value) = struct.unpack_from(
                "<IBBhQ", raw, off
            );
            nul_pos = strtab.index(b"\x00", n_strx) if n_strx < len(strtab) else n_strx;
            name = strtab[n_strx:nul_pos].decode("utf-8", errors="replace");
            self.symbols.append(
                MachOSymbol(
                    name=name,
                    n_type=n_type,
                    n_sect=n_sect,
                    n_desc=n_desc,
                    n_value=n_value
                )
            );
        }
    }

    if self.cpu_type == CPU_TYPE_ARM64 {
        merged: list[MachOReloc] = [];
        pending_addend = 0;
        for rel in self.relocations {
            if rel.rtype == ARM64_RELOC_ADDEND {
                pending_addend = rel.symbolnum;
            } else {
                merged.append(
                    MachOReloc(
                        address=rel.address,
                        symbolnum=rel.symbolnum,
                        pcrel=rel.pcrel,
                        length=rel.length,
                        extern=rel.extern,
                        rtype=rel.rtype,
                        target_sec=rel.target_sec,
                        addend=pending_addend
                    )
                );
                pending_addend = 0;
            }
        }
        self.relocations = merged;
    }

    return True;
}


impl MachOLinker._merge_member(raw: bytes) -> bool {
    sub = MachOLinker(
        obj_data=raw, sections=[], symbols=[], relocations=[], needed_libs=[]
    );
    if not sub.parse_object() {
        return False;
    }
    self._consolidate(sub.sections, sub.symbols, sub.relocations);
    return True;
}


impl MachOLinker._consolidate(
    secs: list[MachOSection], syms: list[MachOSymbol], relocs: list[MachOReloc]
) -> None {
    existing: dict[str, int] = {};
    for (i, s) in enumerate(self.sections) {
        existing[f"{s.segname}:{s.name}"] = i;
    }

    sec_to_merged: dict[int, int] = {};
    sec_dataoff: dict[int, int] = {};
    sec_addrbase: dict[int, int] = {};
    dataoff_by_name: dict[str, int] = {};

    for (mi, ms) in enumerate(secs) {
        key = f"{ms.segname}:{ms.name}";
        if key in existing {
            ti = existing[key];
            tgt = self.sections[ti];
            aligned = _align(len(tgt.data), max(ms.align, 1));
            new_data = bytearray(tgt.data);
            new_data.extend(b"\x00" * (aligned - len(tgt.data)));
            data_off = len(new_data);
            new_data.extend(ms.data);
            tgt.data = bytes(new_data);
            ms_logical = ms.size if ms.size > len(ms.data) else len(ms.data);
            tgt.size = data_off + ms_logical;
            sec_to_merged[mi] = ti;
            sec_dataoff[mi] = data_off;
        } else {
            ni = len(self.sections);
            self.sections.append(
                MachOSection(
                    name=ms.name,
                    segname=ms.segname,
                    addr=ms.addr,
                    size=ms.size,
                    data=ms.data,
                    align=ms.align,
                    flags=ms.flags,
                    reserved1=ms.reserved1,
                    reserved2=ms.reserved2
                )
            );
            existing[key] = ni;
            sec_to_merged[mi] = ni;
            sec_dataoff[mi] = 0;
        }
        sec_addrbase[mi] = ms.addr;
        dataoff_by_name[key] = sec_dataoff[mi];
    }

    sym_remap: dict[int, int] = {};
    for (si, sym) in enumerate(syms) {
        ttype = sym.n_type & N_TYPE_MASK;
        if ttype == N_SECT and sym.n_sect > 0 and (sym.n_sect - 1) in sec_to_merged {
            msi = sym.n_sect - 1;
            merged_idx = sec_to_merged[msi];
            base = self.sections[merged_idx].addr;
            new_val = base + sec_dataoff[msi] + (sym.n_value - sec_addrbase[msi]);
            ni = len(self.symbols);
            self.symbols.append(
                MachOSymbol(
                    name=sym.name,
                    n_type=sym.n_type,
                    n_sect=merged_idx + 1,
                    n_desc=sym.n_desc,
                    n_value=new_val
                )
            );
            sym_remap[si] = ni;
        } else {
            keep_val = sym.n_value if (sym.n_type & N_TYPE_MASK) == 0x02 else 0;
            ni = len(self.symbols);
            self.symbols.append(
                MachOSymbol(
                    name=sym.name,
                    n_type=sym.n_type,
                    n_sect=0,
                    n_desc=sym.n_desc,
                    n_value=keep_val
                )
            );
            sym_remap[si] = ni;
        }
    }

    for r in relocs {
        new_addr = r.address + dataoff_by_name.get(r.target_sec, 0);
        if r.extern == 1 {
            new_symnum = sym_remap.get(r.symbolnum, r.symbolnum);
        } else {
            msi = r.symbolnum - 1;
            new_symnum = (sec_to_merged[msi] + 1)
                if msi in sec_to_merged
                else r.symbolnum;
        }
        self.relocations.append(
            MachOReloc(
                address=new_addr,
                symbolnum=new_symnum,
                pcrel=r.pcrel,
                length=r.length,
                extern=r.extern,
                rtype=r.rtype,
                target_sec=r.target_sec,
                addend=r.addend
            )
        );
    }
}


impl MachOLinker._resolve_crossrefs -> None {
    defined: dict[str, int] = {};
    for (i, s) in enumerate(self.symbols) {
        if (s.n_type & N_TYPE_MASK) == N_SECT and (s.n_type & N_EXT) != 0 and s.name {
            if s.name not in defined {
                defined[s.name] = i;
            }
        }
    }

    resolved: dict[int, int] = {};
    for (i, s) in enumerate(self.symbols) {
        if (s.n_type & N_TYPE_MASK) == N_UNDF
        and (s.n_type & N_EXT) != 0
        and s.name in defined {
            resolved[i] = defined[s.name];
        }
    }
    if not resolved {
        return;
    }
    for r in self.relocations {
        if r.extern == 1 and r.symbolnum in resolved {
            r.symbolnum = resolved[r.symbolnum];
        }
    }
    for i in resolved.keys() {
        self.symbols[i].name = "";
        self.symbols[i].n_type = 0;
    }
}


impl MachOLinker.build_executable -> bytes {
    is_arm64 = self.cpu_type == CPU_TYPE_ARM64;
    page_size = 0x4000 if is_arm64 else 0x1000;
    base_vmaddr = 0x100000000;
    stub_size = ARM64_STUB_SIZE if is_arm64 else X86_64_STUB_SIZE;

    code_data = bytearray();
    rodata_data = bytearray();
    data_data = bytearray();

    code_sections: dict[str, tuple[int, int]] = {};
    rodata_sections: dict[str, tuple[int, int]] = {};
    data_sections: dict[str, tuple[int, int]] = {};

    sec_placement: dict[int, tuple[str, int]] = {};

    for (sec_idx, sec) in enumerate(self.sections) {
        if sec.name.startswith("__debug")
        or sec.name.startswith("__apple")
        or sec.name == "__compact_unwind"
        or sec.name == "__eh_frame" {
            continue;
        }
        is_text = sec.segname == "__TEXT"
        and (sec.flags & S_ATTR_PURE_INSTRUCTIONS) != 0;
        is_rodata = sec.segname == "__TEXT" and not is_text and len(sec.data) > 0;
        is_data = sec.segname == "__DATA";

        sec_key = f"{sec.segname}:{sec.name}";
        if is_text and len(sec.data) > 0 {
            off = _append_to_blob(code_data, sec.data, sec.align, len(sec.data));
            code_sections[sec_key] = (off, len(sec.data));
            sec_placement[sec_idx] = ("code", off);
        } elif is_rodata {
            off = _append_to_blob(rodata_data, sec.data, sec.align, len(sec.data));
            rodata_sections[sec_key] = (off, len(sec.data));
            sec_placement[sec_idx] = ("rodata", off);
        } elif is_data and sec.size > 0 {
            off = _append_to_blob(data_data, sec.data, sec.align, sec.size);
            data_sections[sec_key] = (off, sec.size);
            sec_placement[sec_idx] = ("data", off);
        }
    }

    extern_func_syms: list[str] = [];
    extern_data_syms: list[str] = [];
    known_data_syms: set = {
        "__stdinp",
        "__stdoutp",
        "__stderrp",
        "environ",
        "_environ"
    };
    local_sym_map: dict[str, tuple[str, int]] = {};
    sym_idx_map: dict[int, tuple[str, int]] = {};

    for (sym_idx, sym) in enumerate(self.symbols) {
        sym_type_field = sym.n_type & N_TYPE_MASK;
        is_extern = (sym.n_type & N_EXT) != 0;
        is_undef = sym_type_field == N_UNDF;
        is_defined = sym_type_field == N_SECT;

        if is_undef and is_extern and sym.name {
            if sym.name not in extern_func_syms and sym.name not in extern_data_syms {
                if sym.name in known_data_syms {
                    extern_data_syms.append(sym.name);
                } else {
                    extern_func_syms.append(sym.name);
                }
            }
        } elif is_defined and sym.n_sect > 0 {
            sec_index = sym.n_sect - 1;
            placement = sec_placement.get(sec_index);
            if placement is not None {
                if sym.name {
                    local_sym_map[sym.name] = (
                        placement[0],
                        placement[1] + sym.n_value - self.sections[sec_index].addr
                    );
                }
                sym_idx_map[sym_idx] = (
                    placement[0],
                    placement[1] + sym.n_value - self.sections[sec_index].addr
                );
            }
        }
    }

    internal_got_syms: list[str] = [];
    all_extern_names: set = set(extern_func_syms) | set(extern_data_syms);
    for rel in self.relocations {
        is_got_rel = False;
        if is_arm64 {
            is_got_rel = rel.rtype in (
                ARM64_RELOC_GOT_LOAD_PAGE21,
                ARM64_RELOC_GOT_LOAD_PAGEOFF12
            );
        } else {
            is_got_rel = rel.rtype in (X86_64_RELOC_GOT_LOAD, X86_64_RELOC_GOT);
        }
        if is_got_rel and rel.extern == 1 and rel.symbolnum < len(self.symbols) {
            sname = self.symbols[rel.symbolnum].name;
            if sname
            and sname not in all_extern_names
            and sname not in internal_got_syms {
                internal_got_syms.append(sname);
            }
        }
    }

    num_extern_got = len(extern_func_syms) + len(extern_data_syms);
    num_stubs = len(extern_func_syms);
    num_got = num_extern_got + len(internal_got_syms);
    stubs_total_size = _align(num_stubs * stub_size, 4) if num_stubs > 0 else 0;
    got_total_size = num_got * 8;

    mh_size = 32;

    num_lcs = 0;
    lc_total_size = 0;

    num_lcs += 1;
    lc_total_size += 72;

    num_text_sects = 1;
    if num_stubs > 0 {
        num_text_sects += 1;
    }
    if len(rodata_data) > 0 {
        num_text_sects += 1;
    }
    num_lcs += 1;
    lc_total_size += 72 + num_text_sects * 80;

    num_data_sects = 0;
    if num_got > 0 {
        num_data_sects += 1;
    }
    if len(data_data) > 0 {
        num_data_sects += 1;
    }
    has_data_seg = num_data_sects > 0;
    if has_data_seg {
        num_lcs += 1;
        lc_total_size += 72 + num_data_sects * 80;
    }

    num_lcs += 1;
    lc_total_size += 72;

    num_lcs += 1;
    lc_total_size += 48;

    num_lcs += 1;
    lc_total_size += 24;

    num_lcs += 1;
    lc_total_size += 80;

    dylinker_path = "/usr/lib/dyld";
    dylinker_str = _lc_str_pad(dylinker_path, 12);
    num_lcs += 1;
    lc_total_size += 12 + len(dylinker_str);

    dylib_strs: list[bytes] = [];
    for lib in self.needed_libs {
        _dylib_name = lib;
        if (not lib.startswith("/")) and (not lib.startswith("@")) {
            _dylib_name = "@loader_path/" + lib;
        }
        padded = _lc_str_pad(_dylib_name, 24);
        dylib_strs.append(padded);
        num_lcs += 1;
        lc_total_size += 24 + len(padded);
    }

    num_lcs += 1;
    lc_total_size += 24;

    if is_arm64 {
        num_lcs += 1;
        lc_total_size += 16;
    }

    text_seg_start = 0;
    header_area = mh_size + lc_total_size;

    text_sec_foff = _align(header_area, 16);
    text_sec_size = len(code_data);

    stubs_sec_foff = _align(text_sec_foff + text_sec_size, 4) if num_stubs > 0 else 0;

    if num_stubs > 0 {
        const_sec_foff = _align(stubs_sec_foff + stubs_total_size, 16)
            if len(rodata_data) > 0
            else 0;
    } else {
        const_sec_foff = _align(text_sec_foff + text_sec_size, 16)
            if len(rodata_data) > 0
            else 0;
    }

    text_content_end = text_sec_foff + text_sec_size;
    if num_stubs > 0 {
        text_content_end = stubs_sec_foff + stubs_total_size;
    }
    if len(rodata_data) > 0 {
        text_content_end = const_sec_foff + len(rodata_data);
    }
    text_seg_size = _align(text_content_end, page_size);

    text_sec_vaddr = base_vmaddr + text_sec_foff;
    stubs_sec_vaddr = base_vmaddr + stubs_sec_foff if num_stubs > 0 else 0;
    const_sec_vaddr = base_vmaddr + const_sec_foff if len(rodata_data) > 0 else 0;

    data_seg_foff = text_seg_size;
    data_seg_vmaddr = base_vmaddr + data_seg_foff;

    got_sec_foff = data_seg_foff if num_got > 0 else 0;
    got_sec_vaddr = data_seg_vmaddr if num_got > 0 else 0;

    data_sec_foff = 0;
    data_sec_vaddr = 0;
    if len(data_data) > 0 {
        if num_got > 0 {
            data_sec_foff = _align(got_sec_foff + got_total_size, 16);
        } else {
            data_sec_foff = data_seg_foff;
        }
        data_sec_vaddr = base_vmaddr + data_sec_foff;
    }

    data_content_end = data_seg_foff;
    if num_got > 0 {
        data_content_end = got_sec_foff + got_total_size;
    }
    if len(data_data) > 0 {
        data_content_end = data_sec_foff + len(data_data);
    }
    data_seg_size = _align(data_content_end - data_seg_foff, page_size)
        if has_data_seg
        else 0;

    linkedit_foff = data_seg_foff + data_seg_size;
    linkedit_vmaddr = base_vmaddr + linkedit_foff;

    lib_ordinals: dict[str, int] = {};
    for (li, lib) in enumerate(self.needed_libs) {
        lib_ordinals[lib] = li + 1;
    }
    bind_data = bytearray();

    data_seg_idx = 2;
    all_bind_syms = extern_func_syms + extern_data_syms;
    for (i, sym_name) in enumerate(all_bind_syms) {
        got_offset = i * 8;

        _lookup = sym_name[1:] if sym_name.startswith("_") else sym_name;
        _lib = self.symbol_lib_map.get(_lookup);
        ordinal = lib_ordinals.get(_lib, 1) if _lib is not None else 1;

        bind_data.append(0x20);
        bind_data.extend(_encode_uleb128(ordinal));

        bind_data.append(BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM);
        bind_data.extend(sym_name.encode("utf-8") + b"\x00");
        bind_data.append(BIND_OPCODE_SET_TYPE_IMM | BIND_TYPE_POINTER);
        bind_data.append(BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | data_seg_idx);
        bind_data.extend(_encode_uleb128(got_offset));
        bind_data.append(BIND_OPCODE_DO_BIND);
    }
    if len(bind_data) > 0 {
        bind_data.append(BIND_OPCODE_DONE);
    }
    bind_info = bytes(bind_data);

    rebase_offsets: list[int] = [];

    data_sec_seg_off = data_sec_foff - data_seg_foff
        if data_sec_foff > data_seg_foff
        else 0;
    for rel in self.relocations {
        is_unsigned = (is_arm64 and rel.rtype == ARM64_RELOC_UNSIGNED)
        or (not is_arm64 and rel.rtype == X86_64_RELOC_UNSIGNED);
        if is_unsigned and rel.target_sec in data_sections and rel.length == 3 {
            if rel.extern == 1 {
                sym = self.symbols[rel.symbolnum]
                    if rel.symbolnum < len(self.symbols)
                    else None;
                if sym is not None and (sym.n_type & N_TYPE_MASK) == N_SECT {
                    sec_info = data_sections.get(rel.target_sec);
                    if sec_info is not None {
                        rebase_offsets.append(
                            data_sec_seg_off + sec_info[0] + rel.address
                        );
                    }
                }
            } elif rel.extern == 0 {
                sec_info = data_sections.get(rel.target_sec);
                if sec_info is not None {
                    rebase_offsets.append(data_sec_seg_off + sec_info[0] + rel.address);
                }
            }
        }
    }

    for k in range(len(internal_got_syms)) {
        rebase_offsets.append((num_extern_got + k) * 8);
    }

    rebase_data = bytearray();
    if len(rebase_offsets) > 0 {
        rebase_data.append(REBASE_OPCODE_SET_TYPE_IMM | REBASE_TYPE_POINTER);
        for off in rebase_offsets {
            rebase_data.append(
                (REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB & 0xF0) | data_seg_idx
            );
            rebase_data.extend(_encode_uleb128(off));
            rebase_data.append(REBASE_OPCODE_DO_REBASE);
        }
        rebase_data.append(REBASE_OPCODE_DONE);
    }
    rebase_info = bytes(rebase_data);

    all_extern_syms = extern_func_syms + extern_data_syms;
    out_sym_names = all_extern_syms;

    defined_syms: list[tuple[str, str, int]] = [];
    for sym in self.symbols {
        if (sym.n_type & N_EXT) and (sym.n_type & N_TYPE_MASK) == N_SECT and sym.name {
            place = local_sym_map.get(sym.name);
            if place is not None {
                defined_syms.append((sym.name, place[0], place[1]));
            }
        }
    }

    strtab_names: list[str] = [];
    for (name, _, _) in defined_syms {
        strtab_names.append(name);
    }
    for name in all_extern_syms {
        strtab_names.append(name);
    }
    (strtab_data, strtab_offsets) = _build_strtab(strtab_names, b" \x00");

    symtab_entries = bytearray();
    n_defined = len(defined_syms);
    n_undef = len(all_extern_syms);

    out_sec_num_text = 1;
    out_sec_num_stubs = 2 if num_stubs > 0 else 0;
    next_sec = out_sec_num_stubs + 1 if num_stubs > 0 else 2;
    out_sec_num_const = next_sec if len(rodata_data) > 0 else 0;
    if len(rodata_data) > 0 {
        next_sec += 1;
    }
    out_sec_num_got = next_sec if num_got > 0 else 0;
    if num_got > 0 {
        next_sec += 1;
    }
    out_sec_num_data = next_sec if len(data_data) > 0 else 0;

    for (name, seg, off) in defined_syms {
        n_strx = strtab_offsets.get(name, 0);
        if seg == "code" {
            out_sect = out_sec_num_text;
            out_val = text_sec_vaddr + off;
        } elif seg == "rodata" {
            out_sect = out_sec_num_const;
            out_val = const_sec_vaddr + off;
        } elif seg == "data" {
            out_sect = out_sec_num_data;
            out_val = data_sec_vaddr + off;
        } else {
            out_sect = 0;
            out_val = 0;
        }
        symtab_entries.extend(
            struct.pack("<IBBhQ", n_strx, N_SECT | N_EXT, out_sect, 0, out_val)
        );
    }
    for name in all_extern_syms {
        n_strx = strtab_offsets.get(name, 0);
        symtab_entries.extend(struct.pack("<IBBhQ", n_strx, N_EXT, 0, 0, 0));
    }

    INDIRECT_SYMBOL_LOCAL = 0x80000000;
    indirect_syms = bytearray();

    for i in range(num_extern_got) {
        indirect_syms.extend(struct.pack("<I", n_defined + i));
    }

    for i in range(len(internal_got_syms)) {
        indirect_syms.extend(struct.pack("<I", INDIRECT_SYMBOL_LOCAL));
    }

    for i in range(num_stubs) {
        indirect_syms.extend(struct.pack("<I", n_defined + i));
    }

    cur_linkedit = linkedit_foff;

    rebase_off = cur_linkedit if len(rebase_info) > 0 else 0;
    cur_linkedit += len(rebase_info);
    cur_linkedit = _align(cur_linkedit, 8);

    bind_off = cur_linkedit if len(bind_info) > 0 else 0;
    cur_linkedit += len(bind_info);
    cur_linkedit = _align(cur_linkedit, 8);

    export_off = 0;
    export_size = 0;

    symtab_off = _align(cur_linkedit, 8);
    cur_linkedit = symtab_off + len(symtab_entries);
    cur_linkedit = _align(cur_linkedit, 8);

    indirect_off = cur_linkedit;
    cur_linkedit += len(indirect_syms);
    cur_linkedit = _align(cur_linkedit, 4);

    strtab_off = _align(cur_linkedit, 4);
    cur_linkedit = strtab_off + len(strtab_data);

    codesig_off = 0;
    codesig_size = 0;
    if is_arm64 {
        cur_linkedit = _align(cur_linkedit, 16);
        codesig_off = cur_linkedit;
    }

    linkedit_size_before_sig = cur_linkedit - linkedit_foff;

    extern_stub_addr: dict[str, int] = {};
    got_addr_map: dict[str, int] = {};
    for i in range(len(extern_func_syms)) {
        extern_stub_addr[extern_func_syms[i]] = stubs_sec_vaddr + i * stub_size;
        got_addr_map[extern_func_syms[i]] = got_sec_vaddr + i * 8;
    }
    for i in range(len(extern_data_syms)) {
        got_addr_map[extern_data_syms[i]] = got_sec_vaddr + (
            len(extern_func_syms) + i
        ) * 8;
    }
    for i in range(len(internal_got_syms)) {
        got_addr_map[internal_got_syms[i]] = got_sec_vaddr + (num_extern_got + i) * 8;
    }

    code_bytes = bytearray(code_data);
    rodata_bytes = bytearray(rodata_data);
    data_bytes = bytearray(data_data);

    for rel in self.relocations {
        if (is_arm64 and rel.rtype == ARM64_RELOC_SUBTRACTOR)
        or (not is_arm64 and rel.rtype == X86_64_RELOC_SUBTRACTOR) {
            continue;
        }

        sym_addr = 0;
        sym_name = "";
        is_got_reloc = False;

        if rel.extern == 1 and rel.symbolnum < len(self.symbols) {
            sym = self.symbols[rel.symbolnum];
            sym_name = sym.name;

            if is_arm64 {
                is_got_reloc = rel.rtype in (
                    ARM64_RELOC_GOT_LOAD_PAGE21,
                    ARM64_RELOC_GOT_LOAD_PAGEOFF12
                );
            } else {
                is_got_reloc = rel.rtype in (X86_64_RELOC_GOT_LOAD, X86_64_RELOC_GOT);
            }

            if is_got_reloc {
                got_addr = got_addr_map.get(sym_name);
                if got_addr is not None {
                    sym_addr = got_addr;
                }
            } elif sym_name in extern_stub_addr {
                sym_addr = extern_stub_addr[sym_name];
            } else {
                place = local_sym_map.get(sym_name);
                if place is not None {
                    (seg, seg_off) = place;
                    sym_addr = _resolve_seg_vaddr(
                        seg, seg_off, text_sec_vaddr, const_sec_vaddr, data_sec_vaddr
                    );
                } elif sym_name in got_addr_map {
                    sym_addr = got_addr_map[sym_name];
                }
            }
        } elif rel.extern == 0 {
            target_section_idx = rel.symbolnum - 1;
            place = sec_placement.get(target_section_idx);
            if place is not None {
                (seg, seg_off) = place;
                sym_addr = _resolve_seg_vaddr(
                    seg, seg_off, text_sec_vaddr, const_sec_vaddr, data_sec_vaddr
                );
            }
        }

        site = _resolve_patch_site(
            rel.address,
            rel.target_sec,
            code_sections,
            rodata_sections,
            data_sections,
            code_bytes,
            rodata_bytes,
            data_bytes,
            text_sec_vaddr,
            const_sec_vaddr,
            data_sec_vaddr
        );
        if site is None {
            continue;
        }
        (patch_buf, patch_off, patch_vaddr) = site;

        if is_arm64 {
            _arm64_apply_reloc(
                rel.rtype, patch_buf, patch_off, sym_addr, rel.addend, patch_vaddr
            );
        } else {
            _x86_64_apply_reloc(
                rel.rtype, patch_buf, patch_off, sym_addr, rel.addend, patch_vaddr
            );
        }
    }

    stubs_bytes = bytearray();
    for i in range(num_stubs) {
        s_vaddr = stubs_sec_vaddr + i * stub_size;
        g_vaddr = got_sec_vaddr + i * 8;
        if is_arm64 {
            stubs_bytes.extend(_arm64_build_stub(s_vaddr, g_vaddr));
        } else {
            stubs_bytes.extend(_x86_64_build_stub(s_vaddr, g_vaddr));
        }
    }

    entry_off = _find_entry_vaddr(local_sym_map, text_sec_vaddr);
    if entry_off == text_sec_vaddr {
        _main_local = local_sym_map.get("_main");
        if _main_local is not None and _main_local[0] == "code" {
            entry_off = text_sec_vaddr + _main_local[1];
        }
    }
    main_offset = entry_off - text_sec_vaddr + text_sec_foff
        if entry_off >= text_sec_vaddr
        else 0;

    total_pre_sig = codesig_off if is_arm64 else _align(cur_linkedit, 16);
    if is_arm64 {
        n_pages = (total_pre_sig + CS_PAGE_SIZE - 1) // CS_PAGE_SIZE;
        est_sig_size = _align(20 + 88 + 11 + n_pages * 32 + 16, 16);
        total_file_size = total_pre_sig + est_sig_size;
    } else {
        total_file_size = total_pre_sig;
    }

    output = bytearray(total_file_size);

    mh_flags = MH_NOUNDEFS | MH_DYLDLINK | MH_TWOLEVEL | MH_PIE;
    struct.pack_into(
        "<IiIIIII",
        output,
        0,
        MH_MAGIC_64,
        self.cpu_type,
        self.cpu_subtype,
        MH_EXECUTE,
        num_lcs,
        lc_total_size,
        mh_flags
    );
    struct.pack_into("<I", output, 28, 0);

    lc_off = mh_size;

    pagezero_name = b"__PAGEZERO\x00\x00\x00\x00\x00\x00";
    struct.pack_into("<II", output, lc_off, LC_SEGMENT_64, 72);
    output[lc_off + 8:lc_off + 24] = pagezero_name;
    struct.pack_into(
        "<QQQQIIII", output, lc_off + 24, 0, base_vmaddr, 0, 0, 0, 0, 0, 0
    );
    lc_off += 72;

    text_seg_name = b"__TEXT\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    text_seg_cmdsize = 72 + num_text_sects * 80;
    struct.pack_into("<II", output, lc_off, LC_SEGMENT_64, text_seg_cmdsize);
    output[lc_off + 8:lc_off + 24] = text_seg_name;
    struct.pack_into(
        "<QQQQIIII",
        output,
        lc_off + 24,
        base_vmaddr,
        text_seg_size,
        0,
        text_seg_size,
        5,
        5,
        num_text_sects,
        0
    );
    lc_off += 72;

    _write_section_header(
        output,
        lc_off,
        "__text",
        "__TEXT",
        text_sec_vaddr,
        text_sec_size,
        text_sec_foff,
        4,
        S_REGULAR | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS,
        0,
        0
    );
    lc_off += 80;

    stubs_indirect_idx = num_got;
    if num_stubs > 0 {
        _write_section_header(
            output,
            lc_off,
            "__stubs",
            "__TEXT",
            stubs_sec_vaddr,
            stubs_total_size,
            stubs_sec_foff,
            0,
            S_SYMBOL_STUBS | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS,
            stubs_indirect_idx,
            stub_size
        );
        lc_off += 80;
    }

    if len(rodata_data) > 0 {
        _write_section_header(
            output,
            lc_off,
            "__const",
            "__TEXT",
            const_sec_vaddr,
            len(rodata_data),
            const_sec_foff,
            4,
            S_REGULAR,
            0,
            0
        );
        lc_off += 80;
    }

    if has_data_seg {
        data_seg_name = b"__DATA\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
        data_seg_cmdsize = 72 + num_data_sects * 80;
        struct.pack_into("<II", output, lc_off, LC_SEGMENT_64, data_seg_cmdsize);
        output[lc_off + 8:lc_off + 24] = data_seg_name;
        struct.pack_into(
            "<QQQQIIII",
            output,
            lc_off + 24,
            data_seg_vmaddr,
            data_seg_size,
            data_seg_foff,
            data_seg_size,
            3,
            3,
            num_data_sects,
            0
        );
        lc_off += 72;

        if num_got > 0 {
            _write_section_header(
                output,
                lc_off,
                "__got",
                "__DATA",
                got_sec_vaddr,
                got_total_size,
                got_sec_foff,
                3,
                S_NON_LAZY_SYMBOL_POINTERS,
                0,
                0
            );
            lc_off += 80;
        }

        if len(data_data) > 0 {
            _write_section_header(
                output,
                lc_off,
                "__data",
                "__DATA",
                data_sec_vaddr,
                len(data_data),
                data_sec_foff,
                4,
                S_REGULAR,
                0,
                0
            );
            lc_off += 80;
        }
    }

    linkedit_name = b"__LINKEDIT\x00\x00\x00\x00\x00\x00";
    linkedit_total = total_file_size - linkedit_foff;
    struct.pack_into("<II", output, lc_off, LC_SEGMENT_64, 72);
    output[lc_off + 8:lc_off + 24] = linkedit_name;
    struct.pack_into(
        "<QQQQIIII",
        output,
        lc_off + 24,
        linkedit_vmaddr,
        linkedit_total,
        linkedit_foff,
        linkedit_total,
        1,
        1,
        0,
        0
    );
    lc_off += 72;

    struct.pack_into("<II", output, lc_off, LC_DYLD_INFO_ONLY, 48);
    struct.pack_into("<II", output, lc_off + 8, rebase_off, len(rebase_info));
    struct.pack_into("<II", output, lc_off + 16, bind_off, len(bind_info));
    struct.pack_into("<II", output, lc_off + 24, 0, 0);
    struct.pack_into("<II", output, lc_off + 32, 0, 0);
    struct.pack_into("<II", output, lc_off + 40, export_off, export_size);
    lc_off += 48;

    struct.pack_into(
        "<IIIIII",
        output,
        lc_off,
        LC_SYMTAB,
        24,
        symtab_off,
        n_defined + n_undef,
        strtab_off,
        len(strtab_data)
    );
    lc_off += 24;

    struct.pack_into("<II", output, lc_off, LC_DYSYMTAB, 80);
    struct.pack_into("<II", output, lc_off + 8, 0, 0);
    struct.pack_into("<II", output, lc_off + 16, 0, n_defined);
    struct.pack_into("<II", output, lc_off + 24, n_defined, n_undef);
    struct.pack_into("<II", output, lc_off + 32, 0, 0);
    struct.pack_into("<II", output, lc_off + 40, 0, 0);
    struct.pack_into("<II", output, lc_off + 48, 0, 0);
    struct.pack_into("<II", output, lc_off + 56, indirect_off, num_got + num_stubs);
    struct.pack_into("<II", output, lc_off + 64, 0, 0);
    struct.pack_into("<II", output, lc_off + 72, 0, 0);
    lc_off += 80;

    dylinker_cmdsize = 12 + len(dylinker_str);
    struct.pack_into("<III", output, lc_off, LC_LOAD_DYLINKER, dylinker_cmdsize, 12);
    output[lc_off + 12:lc_off + 12 + len(dylinker_str)] = dylinker_str;
    lc_off += dylinker_cmdsize;

    for (i, lib) in enumerate(self.needed_libs) {
        padded = dylib_strs[i];
        cmdsize = 24 + len(padded);
        struct.pack_into("<III", output, lc_off, LC_LOAD_DYLIB, cmdsize, 24);
        struct.pack_into("<III", output, lc_off + 12, 2, 0x010000, 0x010000);
        output[lc_off + 24:lc_off + 24 + len(padded)] = padded;
        lc_off += cmdsize;
    }

    struct.pack_into("<IIQQ", output, lc_off, LC_MAIN, 24, main_offset, 0);
    lc_off += 24;

    codesig_lc_off = 0;
    if is_arm64 {
        codesig_lc_off = lc_off;
        struct.pack_into(
            "<IIII", output, lc_off, LC_CODE_SIGNATURE, 16, codesig_off, 0
        );
        lc_off += 16;
    }

    output[text_sec_foff:text_sec_foff + len(code_bytes)] = bytes(code_bytes);
    if num_stubs > 0 {
        output[stubs_sec_foff:stubs_sec_foff + len(stubs_bytes)] = bytes(stubs_bytes);
    }
    if len(rodata_bytes) > 0 {
        output[const_sec_foff:const_sec_foff + len(rodata_bytes)] = bytes(rodata_bytes);
    }

    for i in range(len(internal_got_syms)) {
        isym_name = internal_got_syms[i];
        isym_vaddr = 0;
        place = local_sym_map.get(isym_name);
        if place is not None {
            (seg, seg_off) = place;
            isym_vaddr = _resolve_seg_vaddr(
                seg, seg_off, text_sec_vaddr, const_sec_vaddr, data_sec_vaddr
            );
        }
        got_slot_foff = got_sec_foff + (num_extern_got + i) * 8;
        struct.pack_into("<Q", output, got_slot_foff, isym_vaddr);
    }

    if len(data_bytes) > 0 {
        output[data_sec_foff:data_sec_foff + len(data_bytes)] = bytes(data_bytes);
    }

    if len(rebase_info) > 0 {
        output[rebase_off:rebase_off + len(rebase_info)] = rebase_info;
    }
    if len(bind_info) > 0 {
        output[bind_off:bind_off + len(bind_info)] = bind_info;
    }
    output[symtab_off:symtab_off + len(symtab_entries)] = bytes(symtab_entries);
    if len(indirect_syms) > 0 {
        output[indirect_off:indirect_off + len(indirect_syms)] = bytes(indirect_syms);
    }
    output[strtab_off:strtab_off + len(strtab_data)] = strtab_data;

    if is_arm64 {
        sig = _build_code_signature(
            bytes(output),
            codesig_off,
            0,
            text_seg_size,
            exec_seg_flags=CS_EXECSEG_MAIN_BINARY
        );
        codesig_size = len(sig);
        actual_total = codesig_off + codesig_size;

        if actual_total > len(output) {
            output.extend(b"\x00" * (actual_total - len(output)));
        } elif actual_total < len(output) {
            output = bytearray(output[:actual_total]);
        }

        output[codesig_off:codesig_off + codesig_size] = sig;

        struct.pack_into(
            "<IIII",
            output,
            codesig_lc_off,
            LC_CODE_SIGNATURE,
            16,
            codesig_off,
            codesig_size
        );

        scan_off = mh_size;
        for _ in range(num_lcs) {
            (scan_cmd, scan_size) = struct.unpack_from("<II", output, scan_off);
            if scan_cmd == LC_SEGMENT_64 {
                seg_check = output[scan_off + 8:scan_off + 24];
                if seg_check.startswith(b"__LINKEDIT") {
                    new_linkedit_size = actual_total - linkedit_foff;
                    struct.pack_into("<Q", output, scan_off + 32, new_linkedit_size);
                    struct.pack_into("<Q", output, scan_off + 48, new_linkedit_size);
                    break;
                }
            }
            scan_off += scan_size;
        }

        sig = _build_code_signature(
            bytes(output[:codesig_off]),
            codesig_off,
            0,
            text_seg_size,
            exec_seg_flags=CS_EXECSEG_MAIN_BINARY
        );
        output[codesig_off:codesig_off + len(sig)] = sig;
    }

    return bytes(output);
}


impl MachOLinker.build_shared_object -> bytes {
    is_arm64 = self.cpu_type == CPU_TYPE_ARM64;
    page_size = 0x4000 if is_arm64 else 0x1000;
    base_vmaddr = 0;
    stub_size = ARM64_STUB_SIZE if is_arm64 else X86_64_STUB_SIZE;

    code_data = bytearray();
    rodata_data = bytearray();
    data_data = bytearray();
    code_sections: dict[str, tuple[int, int]] = {};
    rodata_sections: dict[str, tuple[int, int]] = {};
    data_sections: dict[str, tuple[int, int]] = {};
    sec_placement: dict[int, tuple[str, int]] = {};
    for (sec_idx, sec) in enumerate(self.sections) {
        if sec.name.startswith("__debug")
        or sec.name.startswith("__apple")
        or sec.name == "__compact_unwind"
        or sec.name == "__eh_frame" {
            continue;
        }
        is_text = sec.segname == "__TEXT"
        and (sec.flags & S_ATTR_PURE_INSTRUCTIONS) != 0;
        is_rodata = sec.segname == "__TEXT" and not is_text and len(sec.data) > 0;
        is_data = sec.segname == "__DATA";
        sec_key = f"{sec.segname}:{sec.name}";
        if is_text and len(sec.data) > 0 {
            off = _append_to_blob(code_data, sec.data, sec.align, len(sec.data));
            code_sections[sec_key] = (off, len(sec.data));
            sec_placement[sec_idx] = ("code", off);
        } elif is_rodata {
            off = _append_to_blob(rodata_data, sec.data, sec.align, len(sec.data));
            rodata_sections[sec_key] = (off, len(sec.data));
            sec_placement[sec_idx] = ("rodata", off);
        } elif is_data and sec.size > 0 {
            off = _append_to_blob(data_data, sec.data, sec.align, sec.size);
            data_sections[sec_key] = (off, sec.size);
            sec_placement[sec_idx] = ("data", off);
        }
    }

    extern_func_syms: list[str] = [];
    extern_data_syms: list[str] = [];
    known_data_syms: set = {
        "__stdinp",
        "__stdoutp",
        "__stderrp",
        "environ",
        "_environ"
    };
    local_sym_map: dict[str, tuple[str, int]] = {};
    sym_idx_map: dict[int, tuple[str, int]] = {};
    for (sym_idx, sym) in enumerate(self.symbols) {
        sym_type_field = sym.n_type & N_TYPE_MASK;
        is_extern = (sym.n_type & N_EXT) != 0;
        is_undef = sym_type_field == N_UNDF;
        is_defined = sym_type_field == N_SECT;
        if is_undef and is_extern and sym.name {
            if sym.name not in extern_func_syms and sym.name not in extern_data_syms {
                if sym.name in known_data_syms {
                    extern_data_syms.append(sym.name);
                } else {
                    extern_func_syms.append(sym.name);
                }
            }
        } elif is_defined and sym.n_sect > 0 {
            sec_index = sym.n_sect - 1;
            placement = sec_placement.get(sec_index);
            if placement is not None {
                _seg_off = placement[1] + sym.n_value - self.sections[sec_index].addr;
                if sym.name {
                    local_sym_map[sym.name] = (placement[0], _seg_off);
                }
                sym_idx_map[sym_idx] = (placement[0], _seg_off);
            }
        }
    }

    internal_got_syms: list[str] = [];
    all_extern_names: set = set(extern_func_syms) | set(extern_data_syms);
    for rel in self.relocations {
        is_got_rel = False;
        if is_arm64 {
            is_got_rel = rel.rtype in (
                ARM64_RELOC_GOT_LOAD_PAGE21,
                ARM64_RELOC_GOT_LOAD_PAGEOFF12
            );
        } else {
            is_got_rel = rel.rtype in (X86_64_RELOC_GOT_LOAD, X86_64_RELOC_GOT);
        }
        if is_got_rel and rel.extern == 1 and rel.symbolnum < len(self.symbols) {
            sname = self.symbols[rel.symbolnum].name;
            if sname
            and sname not in all_extern_names
            and sname not in internal_got_syms {
                internal_got_syms.append(sname);
            }
        }
    }

    init_macho_names: list[str] = [];
    for nm in self.init_funcs {
        _mn = _resolve_macho_name(local_sym_map, nm);
        if _mn is not None and _mn not in init_macho_names {
            init_macho_names.append(_mn);
        }
    }

    num_extern_got = len(extern_func_syms) + len(extern_data_syms);
    num_stubs = len(extern_func_syms);
    num_got = num_extern_got + len(internal_got_syms);
    stubs_total_size = _align(num_stubs * stub_size, 4) if num_stubs > 0 else 0;
    got_total_size = num_got * 8;
    mod_init_size = len(init_macho_names) * 8;

    mh_size = 32;
    num_lcs = 0;
    lc_total_size = 0;

    num_text_sects = 1;
    if num_stubs > 0 {
        num_text_sects += 1;
    }
    if len(rodata_data) > 0 {
        num_text_sects += 1;
    }
    num_lcs += 1;
    lc_total_size += 72 + num_text_sects * 80;

    num_data_sects = 0;
    if num_got > 0 {
        num_data_sects += 1;
    }
    if len(data_data) > 0 {
        num_data_sects += 1;
    }
    if mod_init_size > 0 {
        num_data_sects += 1;
    }
    has_data_seg = num_data_sects > 0;
    if has_data_seg {
        num_lcs += 1;
        lc_total_size += 72 + num_data_sects * 80;
    }

    num_lcs += 1;
    lc_total_size += 72;

    num_lcs += 1;
    lc_total_size += 48;

    num_lcs += 1;
    lc_total_size += 24;

    num_lcs += 1;
    lc_total_size += 80;

    _install_name = self.soname or "libjac.dylib";
    if (not _install_name.startswith("@")) and (not _install_name.startswith("/")) {
        _install_name = "@rpath/" + _install_name;
    }
    id_dylib_str = _lc_str_pad(_install_name, 24);
    num_lcs += 1;
    lc_total_size += 24 + len(id_dylib_str);

    dylib_strs: list[bytes] = [];
    for lib in self.needed_libs {
        _dylib_name = lib;
        if (not lib.startswith("/")) and (not lib.startswith("@")) {
            _dylib_name = "@loader_path/" + lib;
        }
        padded = _lc_str_pad(_dylib_name, 24);
        dylib_strs.append(padded);
        num_lcs += 1;
        lc_total_size += 24 + len(padded);
    }

    if is_arm64 {
        num_lcs += 1;
        lc_total_size += 16;
    }

    header_area = mh_size + lc_total_size;
    text_sec_foff = _align(header_area, 16);
    text_sec_size = len(code_data);
    stubs_sec_foff = _align(text_sec_foff + text_sec_size, 4) if num_stubs > 0 else 0;
    if num_stubs > 0 {
        const_sec_foff = _align(stubs_sec_foff + stubs_total_size, 16)
            if len(rodata_data) > 0
            else 0;
    } else {
        const_sec_foff = _align(text_sec_foff + text_sec_size, 16)
            if len(rodata_data) > 0
            else 0;
    }
    text_content_end = text_sec_foff + text_sec_size;
    if num_stubs > 0 {
        text_content_end = stubs_sec_foff + stubs_total_size;
    }
    if len(rodata_data) > 0 {
        text_content_end = const_sec_foff + len(rodata_data);
    }
    text_seg_size = _align(text_content_end, page_size);
    text_sec_vaddr = base_vmaddr + text_sec_foff;
    stubs_sec_vaddr = base_vmaddr + stubs_sec_foff if num_stubs > 0 else 0;
    const_sec_vaddr = base_vmaddr + const_sec_foff if len(rodata_data) > 0 else 0;

    data_seg_foff = text_seg_size;
    data_seg_vmaddr = base_vmaddr + data_seg_foff;
    got_sec_foff = data_seg_foff if num_got > 0 else 0;
    got_sec_vaddr = data_seg_vmaddr if num_got > 0 else 0;
    data_sec_foff = 0;
    data_sec_vaddr = 0;
    if len(data_data) > 0 {
        if num_got > 0 {
            data_sec_foff = _align(got_sec_foff + got_total_size, 16);
        } else {
            data_sec_foff = data_seg_foff;
        }
        data_sec_vaddr = base_vmaddr + data_sec_foff;
    }
    mod_init_foff = 0;
    mod_init_vaddr = 0;
    if mod_init_size > 0 {
        _prev_end = data_seg_foff;
        if len(data_data) > 0 {
            _prev_end = data_sec_foff + len(data_data);
        } elif num_got > 0 {
            _prev_end = got_sec_foff + got_total_size;
        }
        mod_init_foff = _align(_prev_end, 8);
        mod_init_vaddr = base_vmaddr + mod_init_foff;
    }
    data_content_end = data_seg_foff;
    if num_got > 0 {
        data_content_end = got_sec_foff + got_total_size;
    }
    if len(data_data) > 0 {
        data_content_end = data_sec_foff + len(data_data);
    }
    if mod_init_size > 0 {
        data_content_end = mod_init_foff + mod_init_size;
    }
    data_seg_size = _align(data_content_end - data_seg_foff, page_size)
        if has_data_seg
        else 0;

    linkedit_foff = data_seg_foff + data_seg_size;
    linkedit_vmaddr = base_vmaddr + linkedit_foff;

    data_seg_idx = 1;

    lib_ordinals: dict[str, int] = {};
    for (li, lib) in enumerate(self.needed_libs) {
        lib_ordinals[lib] = li + 1;
    }
    bind_data = bytearray();
    all_bind_syms = extern_func_syms + extern_data_syms;
    for (i, sym_name) in enumerate(all_bind_syms) {
        got_offset = i * 8;
        _lookup = sym_name[1:] if sym_name.startswith("_") else sym_name;
        _lib = self.symbol_lib_map.get(_lookup);
        ordinal = lib_ordinals.get(_lib, 1) if _lib is not None else 1;
        bind_data.append(0x20);
        bind_data.extend(_encode_uleb128(ordinal));
        bind_data.append(BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM);
        bind_data.extend(sym_name.encode("utf-8") + b"\x00");
        bind_data.append(BIND_OPCODE_SET_TYPE_IMM | BIND_TYPE_POINTER);
        bind_data.append(BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | data_seg_idx);
        bind_data.extend(_encode_uleb128(got_offset));
        bind_data.append(BIND_OPCODE_DO_BIND);
    }
    if len(bind_data) > 0 {
        bind_data.append(BIND_OPCODE_DONE);
    }
    bind_info = bytes(bind_data);

    rebase_offsets: list[int] = [];
    data_sec_seg_off = data_sec_foff - data_seg_foff
        if data_sec_foff > data_seg_foff
        else 0;
    for rel in self.relocations {
        is_unsigned = (is_arm64 and rel.rtype == ARM64_RELOC_UNSIGNED)
        or (not is_arm64 and rel.rtype == X86_64_RELOC_UNSIGNED);
        if is_unsigned and rel.target_sec in data_sections and rel.length == 3 {
            if rel.extern == 1 {
                sym = self.symbols[rel.symbolnum]
                    if rel.symbolnum < len(self.symbols)
                    else None;
                if sym is not None and (sym.n_type & N_TYPE_MASK) == N_SECT {
                    sec_info = data_sections.get(rel.target_sec);
                    if sec_info is not None {
                        rebase_offsets.append(
                            data_sec_seg_off + sec_info[0] + rel.address
                        );
                    }
                }
            } elif rel.extern == 0 {
                sec_info = data_sections.get(rel.target_sec);
                if sec_info is not None {
                    rebase_offsets.append(data_sec_seg_off + sec_info[0] + rel.address);
                }
            }
        }
    }
    for k in range(len(internal_got_syms)) {
        rebase_offsets.append((num_extern_got + k) * 8);
    }

    mod_init_seg_off = mod_init_foff - data_seg_foff if mod_init_size > 0 else 0;
    for k in range(len(init_macho_names)) {
        rebase_offsets.append(mod_init_seg_off + k * 8);
    }
    rebase_data = bytearray();
    if len(rebase_offsets) > 0 {
        rebase_data.append(REBASE_OPCODE_SET_TYPE_IMM | REBASE_TYPE_POINTER);
        for off in rebase_offsets {
            rebase_data.append(
                (REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB & 0xF0) | data_seg_idx
            );
            rebase_data.extend(_encode_uleb128(off));
            rebase_data.append(REBASE_OPCODE_DO_REBASE);
        }
        rebase_data.append(REBASE_OPCODE_DONE);
    }
    rebase_info = bytes(rebase_data);

    all_extern_syms = extern_func_syms + extern_data_syms;
    defined_syms: list[tuple[str, str, int]] = [];
    for sym in self.symbols {
        if (sym.n_type & N_EXT) and (sym.n_type & N_TYPE_MASK) == N_SECT and sym.name {
            place = local_sym_map.get(sym.name);
            if place is not None {
                defined_syms.append((sym.name, place[0], place[1]));
            }
        }
    }
    strtab_names: list[str] = [];
    for (name, _, _) in defined_syms {
        strtab_names.append(name);
    }
    for name in all_extern_syms {
        strtab_names.append(name);
    }
    (strtab_data, strtab_offsets) = _build_strtab(strtab_names, b" \x00");
    symtab_entries = bytearray();
    n_defined = len(defined_syms);
    n_undef = len(all_extern_syms);
    out_sec_num_text = 1;
    out_sec_num_stubs = 2 if num_stubs > 0 else 0;
    next_sec = out_sec_num_stubs + 1 if num_stubs > 0 else 2;
    out_sec_num_const = next_sec if len(rodata_data) > 0 else 0;
    if len(rodata_data) > 0 {
        next_sec += 1;
    }
    out_sec_num_got = next_sec if num_got > 0 else 0;
    if num_got > 0 {
        next_sec += 1;
    }
    out_sec_num_data = next_sec if len(data_data) > 0 else 0;
    for (name, seg, off) in defined_syms {
        n_strx = strtab_offsets.get(name, 0);
        if seg == "code" {
            out_sect = out_sec_num_text;
            out_val = text_sec_vaddr + off;
        } elif seg == "rodata" {
            out_sect = out_sec_num_const;
            out_val = const_sec_vaddr + off;
        } elif seg == "data" {
            out_sect = out_sec_num_data;
            out_val = data_sec_vaddr + off;
        } else {
            out_sect = 0;
            out_val = 0;
        }
        symtab_entries.extend(
            struct.pack("<IBBhQ", n_strx, N_SECT | N_EXT, out_sect, 0, out_val)
        );
    }
    for name in all_extern_syms {
        n_strx = strtab_offsets.get(name, 0);
        symtab_entries.extend(struct.pack("<IBBhQ", n_strx, N_EXT, 0, 0, 0));
    }
    INDIRECT_SYMBOL_LOCAL = 0x80000000;
    indirect_syms = bytearray();
    for i in range(num_extern_got) {
        indirect_syms.extend(struct.pack("<I", n_defined + i));
    }
    for i in range(len(internal_got_syms)) {
        indirect_syms.extend(struct.pack("<I", INDIRECT_SYMBOL_LOCAL));
    }
    for i in range(num_stubs) {
        indirect_syms.extend(struct.pack("<I", n_defined + i));
    }

    export_pairs: list[tuple[str, int]] = [];
    for nm in self.export_symbols {
        _mn = _resolve_macho_name(local_sym_map, nm);
        if _mn is None {
            continue;
        }
        (seg, off) = local_sym_map[_mn];
        va = _resolve_seg_vaddr(
            seg, off, text_sec_vaddr, const_sec_vaddr, data_sec_vaddr
        );

        export_pairs.append((_mn, va));
    }
    export_trie = _build_export_trie(export_pairs);

    cur_linkedit = linkedit_foff;
    rebase_off = cur_linkedit if len(rebase_info) > 0 else 0;
    cur_linkedit += len(rebase_info);
    cur_linkedit = _align(cur_linkedit, 8);
    bind_off = cur_linkedit if len(bind_info) > 0 else 0;
    cur_linkedit += len(bind_info);
    cur_linkedit = _align(cur_linkedit, 8);
    export_off = cur_linkedit if len(export_trie) > 0 else 0;
    cur_linkedit += len(export_trie);
    cur_linkedit = _align(cur_linkedit, 8);
    export_size = len(export_trie);
    symtab_off = _align(cur_linkedit, 8);
    cur_linkedit = symtab_off + len(symtab_entries);
    cur_linkedit = _align(cur_linkedit, 8);
    indirect_off = cur_linkedit;
    cur_linkedit += len(indirect_syms);
    cur_linkedit = _align(cur_linkedit, 4);
    strtab_off = _align(cur_linkedit, 4);
    cur_linkedit = strtab_off + len(strtab_data);
    codesig_off = 0;
    codesig_size = 0;
    if is_arm64 {
        cur_linkedit = _align(cur_linkedit, 16);
        codesig_off = cur_linkedit;
    }

    extern_stub_addr: dict[str, int] = {};
    got_addr_map: dict[str, int] = {};
    for i in range(len(extern_func_syms)) {
        extern_stub_addr[extern_func_syms[i]] = stubs_sec_vaddr + i * stub_size;
        got_addr_map[extern_func_syms[i]] = got_sec_vaddr + i * 8;
    }
    for i in range(len(extern_data_syms)) {
        got_addr_map[extern_data_syms[i]] = got_sec_vaddr + (
            len(extern_func_syms) + i
        ) * 8;
    }
    for i in range(len(internal_got_syms)) {
        got_addr_map[internal_got_syms[i]] = got_sec_vaddr + (num_extern_got + i) * 8;
    }
    code_bytes = bytearray(code_data);
    rodata_bytes = bytearray(rodata_data);
    data_bytes = bytearray(data_data);
    for rel in self.relocations {
        if (is_arm64 and rel.rtype == ARM64_RELOC_SUBTRACTOR)
        or (not is_arm64 and rel.rtype == X86_64_RELOC_SUBTRACTOR) {
            continue;
        }
        sym_addr = 0;
        sym_name = "";
        is_got_reloc = False;
        if rel.extern == 1 and rel.symbolnum < len(self.symbols) {
            sym = self.symbols[rel.symbolnum];
            sym_name = sym.name;
            if is_arm64 {
                is_got_reloc = rel.rtype in (
                    ARM64_RELOC_GOT_LOAD_PAGE21,
                    ARM64_RELOC_GOT_LOAD_PAGEOFF12
                );
            } else {
                is_got_reloc = rel.rtype in (X86_64_RELOC_GOT_LOAD, X86_64_RELOC_GOT);
            }
            if is_got_reloc {
                got_addr = got_addr_map.get(sym_name);
                if got_addr is not None {
                    sym_addr = got_addr;
                }
            } elif sym_name in extern_stub_addr {
                sym_addr = extern_stub_addr[sym_name];
            } else {
                place = local_sym_map.get(sym_name);
                if place is not None {
                    (seg, seg_off) = place;
                    sym_addr = _resolve_seg_vaddr(
                        seg, seg_off, text_sec_vaddr, const_sec_vaddr, data_sec_vaddr
                    );
                } elif sym_name in got_addr_map {
                    sym_addr = got_addr_map[sym_name];
                }
            }
        } elif rel.extern == 0 {
            target_section_idx = rel.symbolnum - 1;
            place = sec_placement.get(target_section_idx);
            if place is not None {
                (seg, seg_off) = place;
                sym_addr = _resolve_seg_vaddr(
                    seg, seg_off, text_sec_vaddr, const_sec_vaddr, data_sec_vaddr
                );
            }
        }
        site = _resolve_patch_site(
            rel.address,
            rel.target_sec,
            code_sections,
            rodata_sections,
            data_sections,
            code_bytes,
            rodata_bytes,
            data_bytes,
            text_sec_vaddr,
            const_sec_vaddr,
            data_sec_vaddr
        );
        if site is None {
            continue;
        }
        (patch_buf, patch_off, patch_vaddr) = site;
        if is_arm64 {
            _arm64_apply_reloc(
                rel.rtype, patch_buf, patch_off, sym_addr, rel.addend, patch_vaddr
            );
        } else {
            _x86_64_apply_reloc(
                rel.rtype, patch_buf, patch_off, sym_addr, rel.addend, patch_vaddr
            );
        }
    }

    stubs_bytes = bytearray();
    for i in range(num_stubs) {
        s_vaddr = stubs_sec_vaddr + i * stub_size;
        g_vaddr = got_sec_vaddr + i * 8;
        if is_arm64 {
            stubs_bytes.extend(_arm64_build_stub(s_vaddr, g_vaddr));
        } else {
            stubs_bytes.extend(_x86_64_build_stub(s_vaddr, g_vaddr));
        }
    }

    total_pre_sig = codesig_off if is_arm64 else _align(cur_linkedit, 16);
    if is_arm64 {
        n_pages = (total_pre_sig + CS_PAGE_SIZE - 1) // CS_PAGE_SIZE;
        est_sig_size = _align(20 + 88 + 11 + n_pages * 32 + 16, 16);
        total_file_size = total_pre_sig + est_sig_size;
    } else {
        total_file_size = total_pre_sig;
    }
    output = bytearray(total_file_size);

    mh_flags = MH_DYLDLINK | MH_TWOLEVEL;
    struct.pack_into(
        "<IiIIIII",
        output,
        0,
        MH_MAGIC_64,
        self.cpu_type,
        self.cpu_subtype,
        MH_DYLIB,
        num_lcs,
        lc_total_size,
        mh_flags
    );
    struct.pack_into("<I", output, 28, 0);

    lc_off = mh_size;

    text_seg_name = b"__TEXT\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    text_seg_cmdsize = 72 + num_text_sects * 80;
    struct.pack_into("<II", output, lc_off, LC_SEGMENT_64, text_seg_cmdsize);
    output[lc_off + 8:lc_off + 24] = text_seg_name;
    struct.pack_into(
        "<QQQQIIII",
        output,
        lc_off + 24,
        base_vmaddr,
        text_seg_size,
        0,
        text_seg_size,
        5,
        5,
        num_text_sects,
        0
    );
    lc_off += 72;
    _write_section_header(
        output,
        lc_off,
        "__text",
        "__TEXT",
        text_sec_vaddr,
        text_sec_size,
        text_sec_foff,
        4,
        S_REGULAR | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS,
        0,
        0
    );
    lc_off += 80;
    stubs_indirect_idx = num_got;
    if num_stubs > 0 {
        _write_section_header(
            output,
            lc_off,
            "__stubs",
            "__TEXT",
            stubs_sec_vaddr,
            stubs_total_size,
            stubs_sec_foff,
            0,
            S_SYMBOL_STUBS | S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS,
            stubs_indirect_idx,
            stub_size
        );
        lc_off += 80;
    }
    if len(rodata_data) > 0 {
        _write_section_header(
            output,
            lc_off,
            "__const",
            "__TEXT",
            const_sec_vaddr,
            len(rodata_data),
            const_sec_foff,
            4,
            S_REGULAR,
            0,
            0
        );
        lc_off += 80;
    }

    if has_data_seg {
        data_seg_name = b"__DATA\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
        data_seg_cmdsize = 72 + num_data_sects * 80;
        struct.pack_into("<II", output, lc_off, LC_SEGMENT_64, data_seg_cmdsize);
        output[lc_off + 8:lc_off + 24] = data_seg_name;
        struct.pack_into(
            "<QQQQIIII",
            output,
            lc_off + 24,
            data_seg_vmaddr,
            data_seg_size,
            data_seg_foff,
            data_seg_size,
            3,
            3,
            num_data_sects,
            0
        );
        lc_off += 72;
        if num_got > 0 {
            _write_section_header(
                output,
                lc_off,
                "__got",
                "__DATA",
                got_sec_vaddr,
                got_total_size,
                got_sec_foff,
                3,
                S_NON_LAZY_SYMBOL_POINTERS,
                0,
                0
            );
            lc_off += 80;
        }
        if len(data_data) > 0 {
            _write_section_header(
                output,
                lc_off,
                "__data",
                "__DATA",
                data_sec_vaddr,
                len(data_data),
                data_sec_foff,
                4,
                S_REGULAR,
                0,
                0
            );
            lc_off += 80;
        }
        if mod_init_size > 0 {
            _write_section_header(
                output,
                lc_off,
                "__mod_init_func",
                "__DATA",
                mod_init_vaddr,
                mod_init_size,
                mod_init_foff,
                3,
                S_MOD_INIT_FUNC_POINTERS,
                0,
                0
            );
            lc_off += 80;
        }
    }

    linkedit_name = b"__LINKEDIT\x00\x00\x00\x00\x00\x00";
    linkedit_total = total_file_size - linkedit_foff;
    struct.pack_into("<II", output, lc_off, LC_SEGMENT_64, 72);
    output[lc_off + 8:lc_off + 24] = linkedit_name;
    struct.pack_into(
        "<QQQQIIII",
        output,
        lc_off + 24,
        linkedit_vmaddr,
        linkedit_total,
        linkedit_foff,
        linkedit_total,
        1,
        1,
        0,
        0
    );
    lc_off += 72;

    struct.pack_into("<II", output, lc_off, LC_DYLD_INFO_ONLY, 48);
    struct.pack_into("<II", output, lc_off + 8, rebase_off, len(rebase_info));
    struct.pack_into("<II", output, lc_off + 16, bind_off, len(bind_info));
    struct.pack_into("<II", output, lc_off + 24, 0, 0);
    struct.pack_into("<II", output, lc_off + 32, 0, 0);
    struct.pack_into("<II", output, lc_off + 40, export_off, export_size);
    lc_off += 48;

    struct.pack_into(
        "<IIIIII",
        output,
        lc_off,
        LC_SYMTAB,
        24,
        symtab_off,
        n_defined + n_undef,
        strtab_off,
        len(strtab_data)
    );
    lc_off += 24;

    struct.pack_into("<II", output, lc_off, LC_DYSYMTAB, 80);
    struct.pack_into("<II", output, lc_off + 8, 0, 0);
    struct.pack_into("<II", output, lc_off + 16, 0, n_defined);
    struct.pack_into("<II", output, lc_off + 24, n_defined, n_undef);
    struct.pack_into("<II", output, lc_off + 32, 0, 0);
    struct.pack_into("<II", output, lc_off + 40, 0, 0);
    struct.pack_into("<II", output, lc_off + 48, 0, 0);
    struct.pack_into("<II", output, lc_off + 56, indirect_off, num_got + num_stubs);
    struct.pack_into("<II", output, lc_off + 64, 0, 0);
    struct.pack_into("<II", output, lc_off + 72, 0, 0);
    lc_off += 80;

    id_cmdsize = 24 + len(id_dylib_str);
    struct.pack_into("<III", output, lc_off, LC_ID_DYLIB, id_cmdsize, 24);
    struct.pack_into("<III", output, lc_off + 12, 0, 0x010000, 0x010000);
    output[lc_off + 24:lc_off + 24 + len(id_dylib_str)] = id_dylib_str;
    lc_off += id_cmdsize;

    for (i, lib) in enumerate(self.needed_libs) {
        padded = dylib_strs[i];
        cmdsize = 24 + len(padded);
        struct.pack_into("<III", output, lc_off, LC_LOAD_DYLIB, cmdsize, 24);
        struct.pack_into("<III", output, lc_off + 12, 2, 0x010000, 0x010000);
        output[lc_off + 24:lc_off + 24 + len(padded)] = padded;
        lc_off += cmdsize;
    }

    codesig_lc_off = 0;
    if is_arm64 {
        codesig_lc_off = lc_off;
        struct.pack_into(
            "<IIII", output, lc_off, LC_CODE_SIGNATURE, 16, codesig_off, 0
        );
        lc_off += 16;
    }

    output[text_sec_foff:text_sec_foff + len(code_bytes)] = bytes(code_bytes);
    if num_stubs > 0 {
        output[stubs_sec_foff:stubs_sec_foff + len(stubs_bytes)] = bytes(stubs_bytes);
    }
    if len(rodata_bytes) > 0 {
        output[const_sec_foff:const_sec_foff + len(rodata_bytes)] = bytes(rodata_bytes);
    }
    for i in range(len(internal_got_syms)) {
        isym_name = internal_got_syms[i];
        isym_vaddr = 0;
        place = local_sym_map.get(isym_name);
        if place is not None {
            (seg, seg_off) = place;
            isym_vaddr = _resolve_seg_vaddr(
                seg, seg_off, text_sec_vaddr, const_sec_vaddr, data_sec_vaddr
            );
        }
        got_slot_foff = got_sec_foff + (num_extern_got + i) * 8;
        struct.pack_into("<Q", output, got_slot_foff, isym_vaddr);
    }
    if len(data_bytes) > 0 {
        output[data_sec_foff:data_sec_foff + len(data_bytes)] = bytes(data_bytes);
    }

    for (k, _mn) in enumerate(init_macho_names) {
        (seg, seg_off) = local_sym_map[_mn];
        _iva = _resolve_seg_vaddr(
            seg, seg_off, text_sec_vaddr, const_sec_vaddr, data_sec_vaddr
        );
        struct.pack_into("<Q", output, mod_init_foff + k * 8, _iva);
    }

    if len(rebase_info) > 0 {
        output[rebase_off:rebase_off + len(rebase_info)] = rebase_info;
    }
    if len(bind_info) > 0 {
        output[bind_off:bind_off + len(bind_info)] = bind_info;
    }
    if export_size > 0 {
        output[export_off:export_off + export_size] = export_trie;
    }
    output[symtab_off:symtab_off + len(symtab_entries)] = bytes(symtab_entries);
    if len(indirect_syms) > 0 {
        output[indirect_off:indirect_off + len(indirect_syms)] = bytes(indirect_syms);
    }
    output[strtab_off:strtab_off + len(strtab_data)] = strtab_data;

    if is_arm64 {
        sig = _build_code_signature(
            bytes(output), codesig_off, 0, text_seg_size, exec_seg_flags=0
        );
        codesig_size = len(sig);
        actual_total = codesig_off + codesig_size;
        if actual_total > len(output) {
            output.extend(b"\x00" * (actual_total - len(output)));
        } elif actual_total < len(output) {
            output = bytearray(output[:actual_total]);
        }
        output[codesig_off:codesig_off + codesig_size] = sig;
        struct.pack_into(
            "<IIII",
            output,
            codesig_lc_off,
            LC_CODE_SIGNATURE,
            16,
            codesig_off,
            codesig_size
        );
        scan_off = mh_size;
        for _ in range(num_lcs) {
            (scan_cmd, scan_size) = struct.unpack_from("<II", output, scan_off);
            if scan_cmd == LC_SEGMENT_64 {
                seg_check = output[scan_off + 8:scan_off + 24];
                if seg_check.startswith(b"__LINKEDIT") {
                    new_linkedit_size = actual_total - linkedit_foff;
                    struct.pack_into("<Q", output, scan_off + 32, new_linkedit_size);
                    struct.pack_into("<Q", output, scan_off + 48, new_linkedit_size);
                    break;
                }
            }
            scan_off += scan_size;
        }
        sig = _build_code_signature(
            bytes(output[:codesig_off]), codesig_off, 0, text_seg_size, exec_seg_flags=0
        );
        output[codesig_off:codesig_off + len(sig)] = sig;
    }

    return bytes(output);
}


def _write_section_header(
    buf: bytearray,
    offset: int,
    sectname: str,
    segname: str,
    addr: int,
    size: int,
    foff: int,
    align: int,
    flags: int,
    reserved1: int,
    reserved2: int
) {
    sn = sectname.encode("utf-8");
    sg = segname.encode("utf-8");
    buf[offset:offset + 16] = sn + b"\x00" * (16 - len(sn));
    buf[offset + 16:offset + 32] = sg + b"\x00" * (16 - len(sg));
    struct.pack_into("<QQ", buf, offset + 32, addr, size);
    struct.pack_into(
        "<IIIIIII", buf, offset + 48, foff, align, 0, 0, flags, reserved1, reserved2
    );
    struct.pack_into("<I", buf, offset + 76, 0);
}


impl MachOLinker.link(
    obj_bytes: bytes,
    output_path: str,
    needed_libs: list[str] = ["/usr/lib/libSystem.B.dylib"],
    symbol_lib_map: dict[str, str] = {},
    shared: bool = False,
    export_symbols: list[str] = [],
    init_funcs: list[str] = [],
    soname: str = "",
    archive_members: list[bytes] = []
) -> bool {
    linker = MachOLinker(
        obj_data=obj_bytes,
        sections=[],
        symbols=[],
        relocations=[],
        needed_libs=needed_libs,
        symbol_lib_map=symbol_lib_map,
        shared=shared,
        export_symbols=export_symbols,
        init_funcs=init_funcs,
        soname=soname
    );
    if not linker.parse_object() {
        return False;
    }

    for member in archive_members {
        if not linker._merge_member(member) {
            return False;
        }
    }
    if archive_members {
        linker._resolve_crossrefs();
    }
    exe_bytes = linker.build_shared_object() if shared else linker.build_executable();
    if not exe_bytes {
        return False;
    }
    with open(output_path, "wb") as f {
        f.write(exe_bytes);
    }
    os.chmod(output_path, 0o755);
    return True;
}
