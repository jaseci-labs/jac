"""Architecture-agnostic ELF64 linker implementation.

Converts a relocatable .o (from llvmlite emit_object) into a runnable
ELF executable with dynamic linking against libc.
Architecture is auto-detected from the object file.
"""

import struct;
import os;

# ── ELF header ───────────────────────────────────────────────────
glob ELFMAG = b"\x7fELF",
     ELFCLASS64 = 2,
     ELFDATA2LSB = 1,
     ET_EXEC = 2;

# ── ELF machine types ──────────────────────────────────────────
glob EM_X86_64 = 62,
     EM_AARCH64 = 183;

# ── Section header types ─────────────────────────────────────────
glob SHT_NULL = 0,
     SHT_PROGBITS = 1,
     SHT_SYMTAB = 2,
     SHT_STRTAB = 3,
     SHT_RELA = 4,
     SHT_HASH = 5,
     SHT_DYNAMIC = 6,
     SHT_DYNSYM = 11;

# ── Section flags ────────────────────────────────────────────────
glob SHF_WRITE = 0x1,
     SHF_ALLOC = 0x2,
     SHF_EXECINSTR = 0x4;

# ── Program header types ─────────────────────────────────────────
glob PT_NULL = 0,
     PT_LOAD = 1,
     PT_DYNAMIC = 2,
     PT_INTERP = 3,
     PT_PHDR = 6;

# ── Program header flags ─────────────────────────────────────────
glob PF_X = 0x1,
     PF_W = 0x2,
     PF_R = 0x4;

# ── Dynamic section tags ─────────────────────────────────────────
glob DT_NULL = 0,
     DT_NEEDED = 1,
     DT_HASH = 4,
     DT_STRTAB = 5,
     DT_SYMTAB = 6,
     DT_STRSZ = 10,
     DT_SYMENT = 11,
     DT_DEBUG = 21,
     DT_PLTGOT = 3,
     DT_PLTRELSZ = 2,
     DT_PLTREL = 20,
     DT_JMPREL = 23,
     DT_RELA = 7,
     DT_RELASZ = 8,
     DT_RELAENT = 9;

# ── Symbol binding/type ──────────────────────────────────────────
glob STB_GLOBAL = 1,
     STT_NOTYPE = 0,
     STT_OBJECT = 1,
     STT_FUNC = 2,
     SHN_UNDEF = 0;

# ══════════════════════════════════════════════════════════════════
# x86_64 relocation types
# ══════════════════════════════════════════════════════════════════
glob R_X86_64_64 = 1,
     R_X86_64_PC32 = 2,
     R_X86_64_PLT32 = 4,
     R_X86_64_COPY = 5,
     R_X86_64_GLOB_DAT = 6,
     R_X86_64_JUMP_SLOT = 7,
     R_X86_64_GOTPCREL = 9,
     R_X86_64_REX_GOTPCRELX = 42;

# ══════════════════════════════════════════════════════════════════
# aarch64 relocation types
# ══════════════════════════════════════════════════════════════════
glob R_AARCH64_PREL32 = 261,
     R_AARCH64_ADR_PREL_PG_HI21 = 275,
     R_AARCH64_ADD_ABS_LO12_NC = 277,
     R_AARCH64_JUMP26 = 282,
     R_AARCH64_CALL26 = 283,
     R_AARCH64_LDST8_ABS_LO12_NC = 278,
     R_AARCH64_LDST16_ABS_LO12_NC = 284,
     R_AARCH64_LDST32_ABS_LO12_NC = 285,
     R_AARCH64_LDST64_ABS_LO12_NC = 286,
     R_AARCH64_LDST128_ABS_LO12_NC = 299,
     R_AARCH64_ADR_GOT_PAGE = 311,
     R_AARCH64_LD64_GOT_LO12_NC = 312,
     R_AARCH64_COPY = 1024,
     R_AARCH64_GLOB_DAT = 1025,
     R_AARCH64_JUMP_SLOT = 1026,
     R_AARCH64_ABS64 = 257;


# ── Helper: align to boundary ────────────────────────────────────
def _align(value: int, alignment: int) -> int {
    if alignment <= 1 {
        return value;
    }
    return (value + alignment - 1) & ~(alignment - 1);
}


# ── Helper: build ELF string table ──────────────────────────────
def _build_strtab(strings: list[str]) -> tuple[bytes, dict[str, int]] {
    data = bytearray(b"\x00");
    offsets: dict[str, int] = {};
    for s in strings {
        if s not in offsets {
            offsets[s] = len(data);
            data.extend(s.encode("utf-8") + b"\x00");
        }
    }
    return (bytes(data), offsets);
}


# ── Helper: build ELF hash table ────────────────────────────────
def _elf_hash(name: str) -> int {
    h = 0;
    for c in name.encode("utf-8") {
        h = (h << 4) + c;
        g = h & 0xF0000000;
        if g {
            h ^= g >> 24;
        }
        h &= ~g;
    }
    return h;
}


def _build_hash_table(num_symbols: int) -> bytes {
    nbucket = 1;
    nchain = num_symbols;
    data = bytearray();
    data.extend(struct.pack("<II", nbucket, nchain));
    data.extend(struct.pack("<I", 1 if num_symbols > 1 else 0));
    for i in range(nchain) {
        if i == 0 {
            data.extend(struct.pack("<I", 0));
        } elif i == nchain - 1 {
            data.extend(struct.pack("<I", 0));
        } else {
            data.extend(struct.pack("<I", i + 1));
        }
    }
    return bytes(data);
}


# ══════════════════════════════════════════════════════════════════
# ArchConfig implementations
# ══════════════════════════════════════════════════════════════════

# ── x86_64 PLT ───────────────────────────────────────────────────
impl ArchConfig.build_plt0(got_plt_vaddr: int, plt_vaddr: int) -> bytes {
    if self.e_machine == EM_X86_64 {
        return _x86_64_build_plt0(got_plt_vaddr, plt_vaddr);
    } elif self.e_machine == EM_AARCH64 {
        return _aarch64_build_plt0(got_plt_vaddr, plt_vaddr);
    }
    return b"";
}

impl ArchConfig.build_plt_entry(
    entry_vaddr: int, got_entry_vaddr: int, idx: int, plt_vaddr: int
) -> bytes {
    if self.e_machine == EM_X86_64 {
        return _x86_64_build_plt_entry(entry_vaddr, got_entry_vaddr, idx, plt_vaddr);
    } elif self.e_machine == EM_AARCH64 {
        return _aarch64_build_plt_entry(entry_vaddr, got_entry_vaddr, idx, plt_vaddr);
    }
    return b"";
}

impl ArchConfig.apply_reloc(
    rtype: int,
    patch_buf: bytearray,
    patch_off: int,
    sym_addr: int,
    addend: int,
    patch_vaddr: int
) -> bool {
    if self.e_machine == EM_X86_64 {
        return _x86_64_apply_reloc(
            rtype, patch_buf, patch_off, sym_addr, addend, patch_vaddr
        );
    } elif self.e_machine == EM_AARCH64 {
        return _aarch64_apply_reloc(
            rtype, patch_buf, patch_off, sym_addr, addend, patch_vaddr
        );
    }
    return False;
}

impl ArchConfig.get_lazy_bind_addr(
    plt_vaddr: int, plt0_size: int, idx: int, plt_entry_size: int
) -> int {
    if self.e_machine == EM_X86_64 {
        # x86_64: point to push instruction in PLT[n] (offset +6)
        return plt_vaddr + plt0_size + idx * plt_entry_size + 6;
    } elif self.e_machine == EM_AARCH64 {
        # aarch64: point back to PLT[0] resolver
        return plt_vaddr;
    }
    return plt_vaddr;
}

impl ArchConfig.from_e_machine(e_machine: int) -> (ArchConfig | None) {
    if e_machine == EM_X86_64 {
        return ArchConfig(
            e_machine=EM_X86_64,
            base_vaddr=0x400000,
            page_size=0x1000,
            interp_paths=[
                "/lib64/ld-linux-x86-64.so.2",
                "/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"
            ],
            plt0_size=16,
            plt_entry_size=16,
            jump_slot_rtype=R_X86_64_JUMP_SLOT,
            copy_rtype=R_X86_64_COPY,
            glob_dat_rtype=R_X86_64_GLOB_DAT,
            gotpcrel_rtypes={R_X86_64_GOTPCREL,R_X86_64_REX_GOTPCRELX}
        );
    } elif e_machine == EM_AARCH64 {
        return ArchConfig(
            e_machine=EM_AARCH64,
            base_vaddr=0x400000,
            page_size=0x10000,
            interp_paths=[
                "/lib/ld-linux-aarch64.so.1",
                "/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1"
            ],
            plt0_size=32,
            plt_entry_size=16,
            jump_slot_rtype=R_AARCH64_JUMP_SLOT,
            copy_rtype=R_AARCH64_COPY,
            glob_dat_rtype=R_AARCH64_GLOB_DAT,
            gotpcrel_rtypes={R_AARCH64_ADR_GOT_PAGE,R_AARCH64_LD64_GOT_LO12_NC}
        );
    }
    return None;
}


# ── x86_64 PLT stubs ─────────────────────────────────────────────
def _x86_64_build_plt0(got_plt_vaddr: int, plt_vaddr: int) -> bytes {
    data = bytearray();
    # ff 35 XX XX XX XX    push QWORD [rip + got_plt+8]
    got8_rel = (got_plt_vaddr + 8) - (plt_vaddr + 6);
    data.extend(b"\xff\x35" + struct.pack("<i", got8_rel));
    # ff 25 XX XX XX XX    jmp  QWORD [rip + got_plt+16]
    got16_rel = (got_plt_vaddr + 16) - (plt_vaddr + 12);
    data.extend(b"\xff\x25" + struct.pack("<i", got16_rel));
    # 0f 1f 40 00          nop padding
    data.extend(b"\x0f\x1f\x40\x00");
    return bytes(data);
}


def _x86_64_build_plt_entry(
    entry_vaddr: int, got_entry_vaddr: int, idx: int, plt_vaddr: int
) -> bytes {
    data = bytearray();
    # ff 25 XX XX XX XX    jmp QWORD [rip + got_entry]
    jmp_rel = got_entry_vaddr - (entry_vaddr + 6);
    data.extend(b"\xff\x25" + struct.pack("<i", jmp_rel));
    # 68 XX XX XX XX       push idx
    data.extend(b"\x68" + struct.pack("<i", idx));
    # e9 XX XX XX XX       jmp PLT[0]
    jmp_plt0_rel = plt_vaddr - (entry_vaddr + 16);
    data.extend(b"\xe9" + struct.pack("<i", jmp_plt0_rel));
    return bytes(data);
}


# ── x86_64 relocation application ────────────────────────────────
def _x86_64_apply_reloc(
    rtype: int,
    patch_buf: bytearray,
    patch_off: int,
    sym_addr: int,
    addend: int,
    patch_vaddr: int
) -> bool {
    if rtype == R_X86_64_64 {
        val = sym_addr + addend;
        struct.pack_into("<Q", patch_buf, patch_off, val & 0xFFFFFFFFFFFFFFFF);
        return True;
    } elif rtype == R_X86_64_PC32 or rtype == R_X86_64_PLT32 {
        val = sym_addr + addend - patch_vaddr;
        struct.pack_into("<i", patch_buf, patch_off, val);
        return True;
    } elif rtype == R_X86_64_GOTPCREL or rtype == R_X86_64_REX_GOTPCRELX {
        # GOT-directed: sym_addr is already the GOT entry address
        val = sym_addr + addend - patch_vaddr;
        struct.pack_into("<i", patch_buf, patch_off, val);
        return True;
    }
    return False;
}


# ── aarch64 PLT stubs ────────────────────────────────────────────
def _aarch64_build_plt0(got_plt_vaddr: int, plt_vaddr: int) -> bytes {
    data = bytearray();
    # stp x16, x30, [sp, #-16]!
    data.extend(struct.pack("<I", 0xa9bf7bf0));
    # adrp x16, page(GOT+16)
    got16 = got_plt_vaddr + 16;
    page_off = ((got16 & ~0xFFF) - ((plt_vaddr + 4) & ~0xFFF)) >> 12;
    immlo = (page_off & 0x3) << 29;
    immhi = ((page_off >> 2) & 0x7FFFF) << 5;
    data.extend(struct.pack("<I", 0x90000010 | immlo | immhi));
    # ldr x17, [x16, #lo12:GOT+16]
    lo12_ldr = (got16 & 0xFFF) >> 3;
    data.extend(struct.pack("<I", 0xf9400211 | (lo12_ldr << 10)));
    # add x16, x16, #lo12:GOT+16
    lo12_add = got16 & 0xFFF;
    data.extend(struct.pack("<I", 0x91000210 | (lo12_add << 10)));
    # br x17
    data.extend(struct.pack("<I", 0xd61f0220));
    # nop padding to 32 bytes
    data.extend(struct.pack("<I", 0xd503201f));
    data.extend(struct.pack("<I", 0xd503201f));
    data.extend(struct.pack("<I", 0xd503201f));
    return bytes(data);
}


def _aarch64_build_plt_entry(
    entry_vaddr: int, got_entry_vaddr: int, idx: int, plt_vaddr: int
) -> bytes {
    data = bytearray();
    # adrp x16, page(GOT[n])
    page_off = ((got_entry_vaddr & ~0xFFF) - (entry_vaddr & ~0xFFF)) >> 12;
    immlo = (page_off & 0x3) << 29;
    immhi = ((page_off >> 2) & 0x7FFFF) << 5;
    data.extend(struct.pack("<I", 0x90000010 | immlo | immhi));
    # ldr x17, [x16, #lo12:GOT[n]]
    lo12_ldr = (got_entry_vaddr & 0xFFF) >> 3;
    data.extend(struct.pack("<I", 0xf9400211 | (lo12_ldr << 10)));
    # add x16, x16, #lo12:GOT[n]
    lo12_add = got_entry_vaddr & 0xFFF;
    data.extend(struct.pack("<I", 0x91000210 | (lo12_add << 10)));
    # br x17
    data.extend(struct.pack("<I", 0xd61f0220));
    return bytes(data);
}


# ── aarch64 relocation application ───────────────────────────────
def _aarch64_apply_reloc(
    rtype: int,
    patch_buf: bytearray,
    patch_off: int,
    sym_addr: int,
    addend: int,
    patch_vaddr: int
) -> bool {
    if rtype == R_AARCH64_CALL26 or rtype == R_AARCH64_JUMP26 {
        offset = ((sym_addr + addend - patch_vaddr) >> 2) & 0x3FFFFFF;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0xFC000000) | offset;
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == R_AARCH64_ADR_PREL_PG_HI21 or rtype == R_AARCH64_ADR_GOT_PAGE {
        page_s = (sym_addr + addend) & ~0xFFF;
        page_p = patch_vaddr & ~0xFFF;
        page_off = (page_s - page_p) >> 12;
        immlo = (page_off & 0x3) << 29;
        immhi = ((page_off >> 2) & 0x7FFFF) << 5;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0x9F00001F) | immlo | immhi;
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == R_AARCH64_ADD_ABS_LO12_NC {
        val = (sym_addr + addend) & 0xFFF;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0xFFC003FF) | (val << 10);
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == R_AARCH64_LDST64_ABS_LO12_NC
    or rtype == R_AARCH64_LD64_GOT_LO12_NC {
        val = ((sym_addr + addend) & 0xFFF) >> 3;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0xFFC003FF) | (val << 10);
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == R_AARCH64_LDST32_ABS_LO12_NC {
        val = ((sym_addr + addend) & 0xFFF) >> 2;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0xFFC003FF) | (val << 10);
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == R_AARCH64_LDST16_ABS_LO12_NC {
        val = ((sym_addr + addend) & 0xFFF) >> 1;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0xFFC003FF) | (val << 10);
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == R_AARCH64_LDST8_ABS_LO12_NC {
        val = (sym_addr + addend) & 0xFFF;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0xFFC003FF) | (val << 10);
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == R_AARCH64_LDST128_ABS_LO12_NC {
        val = ((sym_addr + addend) & 0xFFF) >> 4;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0xFFC003FF) | (val << 10);
        struct.pack_into("<I", patch_buf, patch_off, insn);
        return True;
    } elif rtype == R_AARCH64_PREL32 {
        val = sym_addr + addend - patch_vaddr;
        struct.pack_into("<i", patch_buf, patch_off, val);
        return True;
    } elif rtype == R_AARCH64_ABS64 {
        val = sym_addr + addend;
        struct.pack_into("<Q", patch_buf, patch_off, val & 0xFFFFFFFFFFFFFFFF);
        return True;
    }
    return False;
}


# ══════════════════════════════════════════════════════════════════
# ElfLinker implementation
# ══════════════════════════════════════════════════════════════════

# ── Parse the relocatable object ─────────────────────────────────
impl ElfLinker.parse_object -> bool {
    raw = self.obj_data;
    if len(raw) < 64 or raw[:4] != ELFMAG {
        return False;
    }
    # Parse ELF header
    (
        e_type,
        e_machine,
        e_version,
        e_entry,
        e_phoff,
        e_shoff,
        e_flags,
        e_ehsize,
        e_phentsize,
        e_phnum,
        e_shentsize,
        e_shnum,
        e_shstrndx
    ) = struct.unpack_from("<HHIQQQIHHHHHH", raw, 16);
    if e_type != 1 {  # Must be ET_REL
        return False;
    }

    # Detect architecture from the object file
    self.arch = ArchConfig.from_e_machine(e_machine);
    if self.arch is None {
        return False;
    }

    # Parse section headers
    raw_sections: list[dict] = [];
    for i in range(e_shnum) {
        off = e_shoff + i * e_shentsize;
        (
            sh_name,
            sh_type,
            sh_flags,
            sh_addr,
            sh_offset,
            sh_size,
            sh_link,
            sh_info,
            sh_addralign,
            sh_entsize
        ) = struct.unpack_from("<IIQQQQIIQQ", raw, off);
        raw_sections.append(
            {
                "name_idx": sh_name,
                "type": sh_type,
                "flags": sh_flags,
                "addr": sh_addr,
                "offset": sh_offset,
                "size": sh_size,
                "link": sh_link,
                "info": sh_info,
                "align": sh_addralign,
                "entsize": sh_entsize
            }
        );
    }

    # Get section name string table
    shstrtab = raw_sections[e_shstrndx];
    shstrtab_data = raw[shstrtab["offset"]:shstrtab["offset"] + shstrtab["size"]];

    # Build section list
    self.sections = [];
    for rs in raw_sections {
        name_end = shstrtab_data.index(b"\x00", rs["name_idx"]);
        name = shstrtab_data[rs["name_idx"]:name_end].decode();
        sh_type = rs["type"];
        sh_size = rs["size"];
        if sh_type == 8 {  # SHT_NOBITS
            data = b"";
            mem_sz = sh_size;
        } else {
            data = raw[rs["offset"]:rs["offset"] + sh_size] if sh_size > 0 else b"";
            mem_sz = sh_size;
        }
        self.sections.append(
            ElfSection(
                name=name,
                typ=sh_type,
                flags=rs["flags"],
                addr=rs["addr"],
                data=data,
                mem_size=mem_sz,
                align=rs["align"],
                link=rs["link"],
                info=rs["info"],
                entsize=rs["entsize"]
            )
        );
    }

    # Parse symbol table
    self.symbols = [];
    symtab_sec = None;
    strtab_data = b"\x00";
    for sec in self.sections {
        if sec.typ == SHT_SYMTAB {
            symtab_sec = sec;
            strtab_data = self.sections[sec.link].data;
            break;
        }
    }
    if symtab_sec is not None {
        num_syms = len(symtab_sec.data) // symtab_sec.entsize
            if symtab_sec.entsize
            else 0;
        for i in range(num_syms) {
            off = i * symtab_sec.entsize;
            (st_name, st_info, st_other, st_shndx, st_value, st_size) = struct.unpack_from(
                "<IBBHQQ", symtab_sec.data, off
            );
            end = strtab_data.index(b"\x00", st_name);
            name = strtab_data[st_name:end].decode();
            self.symbols.append(
                ElfSymbol(
                    name=name,
                    value=st_value,
                    size=st_size,
                    bind=st_info >> 4,
                    typ=st_info & 0xF,
                    shndx=st_shndx
                )
            );
        }
    }

    # Parse relocations — include all .rela.* sections except eh_frame
    self.relocations = [];
    for sec in self.sections {
        if sec.typ == SHT_RELA and "eh_frame" not in sec.name {
            target_name = sec.name;
            if target_name.startswith(".rela.") {
                target_name = "." + target_name[6:];
            } elif target_name.startswith(".rela") {
                target_name = "." + target_name[5:];
            }
            num_relas = len(sec.data) // 24 if len(sec.data) >= 24 else 0;
            for i in range(num_relas) {
                (r_offset, r_info, r_addend) = struct.unpack_from(
                    "<QQq", sec.data, i * 24
                );
                r_sym = r_info >> 32;
                r_type = r_info & 0xFFFFFFFF;
                sym_name = self.symbols[r_sym].name if r_sym < len(self.symbols) else "";
                self.relocations.append(
                    ElfRela(
                        offset=r_offset,
                        sym_idx=r_sym,
                        rtype=r_type,
                        addend=r_addend,
                        sym_name=sym_name,
                        target_sec=target_name
                    )
                );
            }
        }
    }
    return True;
}


# ── Build the executable ─────────────────────────────────────────
impl ElfLinker.build_executable -> bytes {
    arch = self.arch;
    BASE_VADDR = arch.base_vaddr;
    PAGE_SIZE = arch.page_size;

    # Collect code and data sections from the .o file
    code_data = bytearray();
    rodata_blob = bytearray();
    data_blob = bytearray();

    code_sections: dict[str, tuple[int, int]] = {};
    rodata_sections: dict[str, tuple[int, int]] = {};
    data_sections: dict[str, tuple[int, int]] = {};

    section_placement: dict[int, tuple[str, int]] = {};
    sec_idx = 0;
    for sec in self.sections {
        if sec.typ == SHT_PROGBITS and (sec.flags & SHF_EXECINSTR) {
            if len(sec.data) > 0 {
                aligned_off = _align(len(code_data), max(sec.align, 1));
                code_data.extend(b"\x00" * (aligned_off - len(code_data)));
                code_sections[sec.name] = (len(code_data), len(sec.data));
                section_placement[sec_idx] = ("code", len(code_data));
                code_data.extend(sec.data);
            }
        } elif sec.typ == SHT_PROGBITS
        and (sec.flags & SHF_ALLOC)
        and not (sec.flags & SHF_WRITE) {
            if len(sec.data) > 0 {
                aligned_off = _align(len(rodata_blob), max(sec.align, 1));
                rodata_blob.extend(b"\x00" * (aligned_off - len(rodata_blob)));
                rodata_sections[sec.name] = (len(rodata_blob), len(sec.data));
                section_placement[sec_idx] = ("rodata", len(rodata_blob));
                rodata_blob.extend(sec.data);
            }
        } elif (sec.flags & SHF_WRITE) and (sec.flags & SHF_ALLOC) {
            alloc_size = sec.mem_size;
            if alloc_size > 0 {
                aligned_off = _align(len(data_blob), max(sec.align, 1));
                data_blob.extend(b"\x00" * (aligned_off - len(data_blob)));
                data_sections[sec.name] = (len(data_blob), alloc_size);
                section_placement[sec_idx] = ("data", len(data_blob));
                if len(sec.data) > 0 {
                    data_blob.extend(sec.data);
                    if alloc_size > len(sec.data) {
                        data_blob.extend(b"\x00" * (alloc_size - len(sec.data)));
                    }
                } else {
                    data_blob.extend(b"\x00" * alloc_size);
                }
            }
        }
        sec_idx += 1;
    }

    # Identify external symbols
    known_data_syms = {"stdin","stdout","stderr","environ"};
    extern_func_syms: list[str] = [];
    extern_data_syms: list[str] = [];
    local_sym_map: dict[str, tuple[str, int]] = {};
    sym_idx_placement: dict[int, tuple[str, int]] = {};
    sym_i = 0;
    for sym in self.symbols {
        if sym.shndx == SHN_UNDEF and sym.name and sym.bind >= STB_GLOBAL {
            is_data = sym.typ == STT_OBJECT
            or (sym.typ == STT_NOTYPE and sym.name in known_data_syms);
            if is_data {
                if sym.name not in extern_data_syms {
                    extern_data_syms.append(sym.name);
                }
            } else {
                if sym.name not in extern_func_syms {
                    extern_func_syms.append(sym.name);
                }
            }
        } elif sym.shndx != SHN_UNDEF and sym.shndx < len(self.sections) {
            placement = section_placement.get(sym.shndx);
            if placement is not None {
                if sym.name {
                    local_sym_map[sym.name] = (placement[0], placement[1] + sym.value);
                }
                sym_idx_placement[sym_i] = (placement[0], placement[1]);
            }
        }
        sym_i += 1;
    }
    extern_syms: list[str] = extern_func_syms + extern_data_syms;

    # ── Layout ────────────────────────────────────────────────────
    ehdr_size = 64;
    num_phdrs = 5;
    phdr_size = num_phdrs * 56;

    # Build interp
    interp_data = b"\x00";
    for path in arch.interp_paths {
        if os.path.exists(path) {
            interp_data = path.encode() + b"\x00";
            break;
        }
    }

    # Build dynamic string table
    dynstr_strings = [""] + extern_syms + self.needed_libs;
    (dynstr_data, dynstr_offsets) = _build_strtab(dynstr_strings);

    # Build dynamic symbol table
    num_dynsyms = 1 + len(extern_syms);
    dynsym_data = bytearray();
    dynsym_data.extend(struct.pack("<IBBHQQ", 0, 0, 0, 0, 0, 0));
    extern_data_set = set(extern_data_syms);
    for sym_name in extern_syms {
        st_name = dynstr_offsets.get(sym_name, 0);
        sym_type = STT_OBJECT if sym_name in extern_data_set else STT_FUNC;
        st_info = (STB_GLOBAL << 4) | sym_type;
        dynsym_data.extend(
            struct.pack("<IBBHQQ", st_name, st_info, 0, SHN_UNDEF, 0, 0)
        );
    }

    # Build hash table
    hash_data = _build_hash_table(num_dynsyms);

    # PLT sizing
    plt0_size = arch.plt0_size;
    plt_entry_size = arch.plt_entry_size;
    plt_size = plt0_size + len(extern_func_syms) * plt_entry_size;

    # GOT.PLT: 3 reserved entries + one per extern function
    got_plt_entries = 3 + len(extern_func_syms);
    got_plt_size = got_plt_entries * 8;

    # Dynamic section entries
    dyn_entries: list[tuple[int, int]] = [];
    for lib in self.needed_libs {
        dyn_entries.append((DT_NEEDED, dynstr_offsets.get(lib, 0)));
    }
    dyn_entries.append((DT_HASH, 0));
    dyn_entries.append((DT_STRTAB, 0));
    dyn_entries.append((DT_SYMTAB, 0));
    dyn_entries.append((DT_STRSZ, len(dynstr_data)));
    dyn_entries.append((DT_SYMENT, 24));
    dyn_entries.append((DT_PLTGOT, 0));
    dyn_entries.append((DT_PLTRELSZ, len(extern_func_syms) * 24));
    dyn_entries.append((DT_PLTREL, DT_RELA));
    dyn_entries.append((DT_JMPREL, 0));
    if len(extern_data_syms) > 0 {
        dyn_entries.append((DT_RELA, 0));
        dyn_entries.append((DT_RELASZ, len(extern_data_syms) * 24));
        dyn_entries.append((DT_RELAENT, 24));
    }
    dyn_entries.append((DT_DEBUG, 0));
    dyn_entries.append((DT_NULL, 0));
    dynamic_data = bytearray();
    for (tag, val) in dyn_entries {
        dynamic_data.extend(struct.pack("<qQ", tag, val));
    }

    # ── Compute file offsets and virtual addresses ────────────────
    cur_offset = ehdr_size + phdr_size;
    interp_foff = cur_offset;
    cur_offset += len(interp_data);
    cur_offset = _align(cur_offset, 8);
    hash_foff = cur_offset;
    cur_offset += len(hash_data);
    cur_offset = _align(cur_offset, 8);
    dynsym_foff = cur_offset;
    cur_offset += len(dynsym_data);
    cur_offset = _align(cur_offset, 8);
    dynstr_foff = cur_offset;
    cur_offset += len(dynstr_data);
    cur_offset = _align(cur_offset, 8);
    rela_plt_foff = cur_offset;
    cur_offset += len(extern_func_syms) * 24;
    cur_offset = _align(cur_offset, 8);
    rela_dyn_foff = cur_offset;
    rela_dyn_size = len(extern_data_syms) * 24;
    cur_offset += rela_dyn_size;
    cur_offset = _align(cur_offset, 16);
    plt_foff = cur_offset;
    cur_offset += plt_size;
    cur_offset = _align(cur_offset, 16);
    text_foff = cur_offset;
    cur_offset += len(code_data);
    cur_offset = _align(cur_offset, 16);
    rodata_foff = cur_offset;
    cur_offset += len(rodata_blob);
    code_seg_size = cur_offset;

    # Data segment on a new page
    data_seg_foff = _align(cur_offset, PAGE_SIZE);
    data_seg_vaddr = BASE_VADDR + data_seg_foff;
    got_plt_foff = data_seg_foff;
    cur_offset = data_seg_foff + got_plt_size;
    cur_offset = _align(cur_offset, 8);
    data_got_foff = cur_offset;
    data_got_size = len(extern_data_syms) * 8;
    cur_offset += data_got_size;
    cur_offset = _align(cur_offset, 8);
    dynamic_foff = cur_offset;
    cur_offset += len(dynamic_data);
    cur_offset = _align(cur_offset, 8);
    data_foff = cur_offset;
    cur_offset += len(data_blob);
    data_seg_size = cur_offset - data_seg_foff;
    total_file_size = data_seg_foff + data_seg_size;

    # Virtual addresses
    interp_vaddr = BASE_VADDR + interp_foff;
    hash_vaddr = BASE_VADDR + hash_foff;
    dynsym_vaddr = BASE_VADDR + dynsym_foff;
    dynstr_vaddr = BASE_VADDR + dynstr_foff;
    rela_plt_vaddr = BASE_VADDR + rela_plt_foff;
    rela_dyn_vaddr = BASE_VADDR + rela_dyn_foff;
    data_got_vaddr = BASE_VADDR + data_got_foff;
    plt_vaddr = BASE_VADDR + plt_foff;
    got_plt_vaddr = BASE_VADDR + got_plt_foff;
    text_vaddr = BASE_VADDR + text_foff;
    rodata_vaddr = BASE_VADDR + rodata_foff;
    dynamic_vaddr = BASE_VADDR + dynamic_foff;
    data_vaddr = BASE_VADDR + data_foff;

    # ── Patch dynamic section addresses ───────────────────────────
    dyn_entries_patched: list[tuple[int, int]] = [];
    for (tag, val) in dyn_entries {
        if tag == DT_HASH {
            dyn_entries_patched.append((tag, hash_vaddr));
        } elif tag == DT_STRTAB {
            dyn_entries_patched.append((tag, dynstr_vaddr));
        } elif tag == DT_SYMTAB {
            dyn_entries_patched.append((tag, dynsym_vaddr));
        } elif tag == DT_PLTGOT {
            dyn_entries_patched.append((tag, got_plt_vaddr));
        } elif tag == DT_JMPREL {
            dyn_entries_patched.append((tag, rela_plt_vaddr));
        } elif tag == DT_RELA {
            dyn_entries_patched.append((tag, rela_dyn_vaddr));
        } else {
            dyn_entries_patched.append((tag, val));
        }
    }
    dynamic_data = bytearray();
    for (tag, val) in dyn_entries_patched {
        dynamic_data.extend(struct.pack("<qQ", tag, val));
    }

    # ── Patch dynsym entries for data externals ───────────────────
    for idx in range(len(extern_data_syms)) {
        dynsym_offset = (1 + len(extern_func_syms) + idx) * 24;
        copy_vaddr = data_got_vaddr + idx * 8;
        struct.pack_into("<QQ", dynsym_data, dynsym_offset + 8, copy_vaddr, 8);
    }

    # ── Build PLT (architecture-dispatched) ───────────────────────
    plt_data = bytearray();
    plt_data.extend(arch.build_plt0(got_plt_vaddr, plt_vaddr));
    for idx in range(len(extern_func_syms)) {
        entry_vaddr = plt_vaddr + plt0_size + idx * plt_entry_size;
        got_entry_vaddr = got_plt_vaddr + (3 + idx) * 8;
        plt_data.extend(
            arch.build_plt_entry(entry_vaddr, got_entry_vaddr, idx, plt_vaddr)
        );
    }

    # ── Build GOT.PLT ─────────────────────────────────────────────
    got_plt_data = bytearray();
    got_plt_data.extend(struct.pack("<Q", dynamic_vaddr));
    got_plt_data.extend(struct.pack("<Q", 0));
    got_plt_data.extend(struct.pack("<Q", 0));
    for idx in range(len(extern_func_syms)) {
        lazy_addr = arch.get_lazy_bind_addr(plt_vaddr, plt0_size, idx, plt_entry_size);
        got_plt_data.extend(struct.pack("<Q", lazy_addr));
    }

    # ── Build .rela.plt (architecture-dispatched reloc type) ──────
    rela_plt_data = bytearray();
    for idx in range(len(extern_func_syms)) {
        r_offset = got_plt_vaddr + (3 + idx) * 8;
        r_info = ((idx + 1) << 32) | arch.jump_slot_rtype;
        r_addend = 0;
        rela_plt_data.extend(struct.pack("<QQq", r_offset, r_info, r_addend));
    }

    # ── Build .rela.dyn (data externals: COPY reloc) ──────────────
    rela_dyn_data = bytearray();
    for idx in range(len(extern_data_syms)) {
        r_offset = data_got_vaddr + idx * 8;
        dynsym_idx = 1 + len(extern_func_syms) + idx;
        r_info = (dynsym_idx << 32) | arch.copy_rtype;
        r_addend = 0;
        rela_dyn_data.extend(struct.pack("<QQq", r_offset, r_info, r_addend));
    }

    # ── Build copy relocation area ────────────────────────────────
    data_got_data = bytearray(b"\x00" * data_got_size);

    # ── Apply relocations (architecture-dispatched) ───────────────
    extern_plt_addr: dict[str, int] = {};
    for plt_idx in range(len(extern_func_syms)) {
        extern_plt_addr[extern_func_syms[plt_idx]] = plt_vaddr + plt0_size + plt_idx * plt_entry_size;
    }
    extern_got_addr: dict[str, int] = {};
    for got_idx in range(len(extern_data_syms)) {
        extern_got_addr[extern_data_syms[got_idx]] = data_got_vaddr + got_idx * 8;
    }

    code_bytes = bytearray(code_data);
    rodata_bytes = bytearray(rodata_blob);
    data_bytes = bytearray(data_blob);

    for rela in self.relocations {
        sym_addr = 0;
        is_func_extern = rela.sym_name in extern_plt_addr;
        is_data_extern = rela.sym_name in extern_got_addr;

        # For GOT-directed relocations, resolve the GOT entry address
        if rela.rtype in arch.gotpcrel_rtypes {
            if is_data_extern {
                sym_addr = extern_got_addr[rela.sym_name];
            } elif is_func_extern {
                func_idx = extern_func_syms.index(rela.sym_name);
                sym_addr = got_plt_vaddr + (3 + func_idx) * 8;
            } else {
                sym_addr = 0;
            }
        } elif is_func_extern {
            sym_addr = extern_plt_addr[rela.sym_name];
        } elif is_data_extern {
            sym_addr = extern_got_addr[rela.sym_name];
        } else {
            local = local_sym_map.get(rela.sym_name) if rela.sym_name else None;
            if local is None {
                sec_place = sym_idx_placement.get(rela.sym_idx);
                if sec_place is not None {
                    local = sec_place;
                }
            }
            if local is not None {
                (seg, seg_off) = local;
                if seg == "code" {
                    sym_addr = text_vaddr + seg_off;
                } elif seg == "rodata" {
                    sym_addr = rodata_vaddr + seg_off;
                } elif seg == "data" {
                    sym_addr = data_vaddr + seg_off;
                }
            }
        }

        # Determine target buffer and base vaddr
        target_is_code = rela.target_sec in code_sections;
        target_is_data = rela.target_sec in data_sections;
        target_is_rodata = rela.target_sec in rodata_sections;
        if target_is_code {
            sec_blob_off = code_sections[rela.target_sec][0];
            patch_buf = code_bytes;
            patch_base_vaddr = text_vaddr + sec_blob_off;
        } elif target_is_data {
            sec_blob_off = data_sections[rela.target_sec][0];
            patch_buf = data_bytes;
            patch_base_vaddr = data_vaddr + sec_blob_off;
        } elif target_is_rodata {
            sec_blob_off = rodata_sections[rela.target_sec][0];
            patch_buf = rodata_bytes;
            patch_base_vaddr = rodata_vaddr + sec_blob_off;
        } else {
            sec_blob_off = 0;
            patch_buf = code_bytes;
            patch_base_vaddr = text_vaddr;
        }
        patch_off = sec_blob_off + rela.offset;
        patch_vaddr = patch_base_vaddr + patch_off;

        # Apply via architecture-specific handler
        arch.apply_reloc(
            rela.rtype, patch_buf, patch_off, sym_addr, rela.addend, patch_vaddr
        );
    }

    # ── Find entry point ──────────────────────────────────────────
    # Look for _start (generated by nacompile via inline asm)
    entry_vaddr = text_vaddr;
    start_local = local_sym_map.get("_start");
    if start_local is not None {
        (seg, seg_off) = start_local;
        if seg == "code" {
            entry_vaddr = text_vaddr + seg_off;
        }
    } else {
        # Fallback: look for main
        main_local = local_sym_map.get("main");
        if main_local is not None {
            (seg, seg_off) = main_local;
            if seg == "code" {
                entry_vaddr = text_vaddr + seg_off;
            }
        }
    }

    # ── Assemble the ELF file ────────────────────────────────────
    output = bytearray(total_file_size);

    # ELF header
    ident = bytearray(16);
    ident[0:4] = ELFMAG;
    ident[4] = ELFCLASS64;
    ident[5] = ELFDATA2LSB;
    ident[6] = 1;  # EV_CURRENT
    ident[7] = 0;  # ELFOSABI_NONE
    struct.pack_into("16s", output, 0, bytes(ident));
    struct.pack_into(
        "<HHIQQQIHHHHHH",
        output,
        16,
        ET_EXEC,
        arch.e_machine,
        1,
        entry_vaddr,
        ehdr_size,
        0,
        0,
        ehdr_size,
        56,
        num_phdrs,
        0,
        0,
        0
    );

    # Program headers
    phdr_off = ehdr_size;

    # PT_PHDR
    struct.pack_into(
        "<IIQQQQQQ",
        output,
        phdr_off,
        PT_PHDR,
        PF_R,
        ehdr_size,
        BASE_VADDR + ehdr_size,
        BASE_VADDR + ehdr_size,
        phdr_size,
        phdr_size,
        8
    );
    phdr_off += 56;

    # PT_INTERP
    struct.pack_into(
        "<IIQQQQQQ",
        output,
        phdr_off,
        PT_INTERP,
        PF_R,
        interp_foff,
        interp_vaddr,
        interp_vaddr,
        len(interp_data),
        len(interp_data),
        1
    );
    phdr_off += 56;

    # PT_LOAD (code segment - RX)
    struct.pack_into(
        "<IIQQQQQQ",
        output,
        phdr_off,
        PT_LOAD,
        PF_R | PF_X,
        0,
        BASE_VADDR,
        BASE_VADDR,
        code_seg_size,
        code_seg_size,
        PAGE_SIZE
    );
    phdr_off += 56;

    # PT_LOAD (data segment - RW)
    struct.pack_into(
        "<IIQQQQQQ",
        output,
        phdr_off,
        PT_LOAD,
        PF_R | PF_W,
        data_seg_foff,
        data_seg_vaddr,
        data_seg_vaddr,
        data_seg_size,
        data_seg_size,
        PAGE_SIZE
    );
    phdr_off += 56;

    # PT_DYNAMIC
    struct.pack_into(
        "<IIQQQQQQ",
        output,
        phdr_off,
        PT_DYNAMIC,
        PF_R | PF_W,
        dynamic_foff,
        dynamic_vaddr,
        dynamic_vaddr,
        len(dynamic_data),
        len(dynamic_data),
        8
    );

    # Write sections into output
    output[interp_foff:interp_foff + len(interp_data)] = interp_data;
    output[hash_foff:hash_foff + len(hash_data)] = hash_data;
    output[dynsym_foff:dynsym_foff + len(dynsym_data)] = bytes(dynsym_data);
    output[dynstr_foff:dynstr_foff + len(dynstr_data)] = dynstr_data;
    output[rela_plt_foff:rela_plt_foff + len(rela_plt_data)] = bytes(rela_plt_data);
    if len(rela_dyn_data) > 0 {
        output[rela_dyn_foff:rela_dyn_foff + len(rela_dyn_data)] = bytes(rela_dyn_data);
    }
    output[plt_foff:plt_foff + len(plt_data)] = bytes(plt_data);
    output[got_plt_foff:got_plt_foff + len(got_plt_data)] = bytes(got_plt_data);
    if data_got_size > 0 {
        output[data_got_foff:data_got_foff + data_got_size] = bytes(data_got_data);
    }
    output[text_foff:text_foff + len(code_bytes)] = bytes(code_bytes);
    if len(rodata_bytes) > 0 {
        output[rodata_foff:rodata_foff + len(rodata_bytes)] = bytes(rodata_bytes);
    }
    output[dynamic_foff:dynamic_foff + len(dynamic_data)] = bytes(dynamic_data);
    if len(data_bytes) > 0 {
        output[data_foff:data_foff + len(data_bytes)] = bytes(data_bytes);
    }
    return bytes(output);
}


# ── Merge a CRT object file's sections/symbols/relocs into self ──
def _merge_crt_object(linker: ElfLinker, crt_bytes: bytes) -> bool {
    """Parse a CRT object and merge its sections, symbols, and relocations
    into the linker's existing parsed state.

    When a CRT section has the same name as an existing section (e.g. .text),
    the CRT data is appended to the existing section. Symbol values and
    relocation offsets are adjusted by the merge offset.
    """
    crt = ElfLinker(
        obj_data=crt_bytes, sections=[], symbols=[], relocations=[], needed_libs=[]
    );
    if not crt.parse_object() {
        return False;
    }

    # Build index of existing sections by name
    existing_sec_by_name: dict[str, int] = {};
    for (i, sec) in enumerate(linker.sections) {
        if sec.name {
            existing_sec_by_name[sec.name] = i;
        }
    }

    # Map CRT section indices -> merged section indices.
    # Track the data offset where CRT data was appended (for adjusting symbols/relocs).
    sec_idx_map: dict[int, int] = {};
    sec_data_offset: dict[int, int] = {};  # crt_sec_idx -> byte offset within merged section
    for (crt_idx, crt_sec) in enumerate(crt.sections) {
        if crt_sec.name and crt_sec.name in existing_sec_by_name {
            # Merge into existing section
            merged_idx = existing_sec_by_name[crt_sec.name];
            merged_sec = linker.sections[merged_idx];
            # Align the append offset
            align = max(crt_sec.align, 1);
            cur_len = len(merged_sec.data);
            aligned_off = _align(cur_len, align);
            padding = b"\x00" * (aligned_off - cur_len);
            # Append CRT section data to existing section
            new_data = merged_sec.data + padding + crt_sec.data;
            new_mem_size = max(merged_sec.mem_size, len(new_data));
            linker.sections[merged_idx] = ElfSection(
                name=merged_sec.name,
                typ=merged_sec.typ,
                flags=merged_sec.flags | crt_sec.flags,
                addr=merged_sec.addr,
                data=new_data,
                mem_size=new_mem_size,
                align=max(merged_sec.align, crt_sec.align),
                link=merged_sec.link,
                info=merged_sec.info,
                entsize=merged_sec.entsize
            );
            sec_idx_map[crt_idx] = merged_idx;
            sec_data_offset[crt_idx] = aligned_off;
        } else {
            # New section — append
            sec_idx_map[crt_idx] = len(linker.sections);
            sec_data_offset[crt_idx] = 0;
            linker.sections.append(crt_sec);
            if crt_sec.name {
                existing_sec_by_name[crt_sec.name] = sec_idx_map[crt_idx];
            }
        }
    }

    # Map CRT symbol indices -> merged symbol indices.
    sym_idx_map: dict[int, int] = {};
    existing_syms: dict[str, int] = {};
    for (i, sym) in enumerate(linker.symbols) {
        if sym.name {
            existing_syms[sym.name] = i;
        }
    }
    for (crt_sym_idx, crt_sym) in enumerate(crt.symbols) {
        # Adjust symbol value by the section merge offset
        adjusted_value = crt_sym.value;
        if crt_sym.shndx != SHN_UNDEF and crt_sym.shndx < len(crt.sections) {
            adjusted_value += sec_data_offset.get(crt_sym.shndx, 0);
        }

        if crt_sym.name and crt_sym.name in existing_syms {
            existing_idx = existing_syms[crt_sym.name];
            existing_sym = linker.symbols[existing_idx];
            # If existing is undefined and CRT defines it, replace
            if existing_sym.shndx == SHN_UNDEF and crt_sym.shndx != SHN_UNDEF {
                new_shndx = sec_idx_map.get(crt_sym.shndx, crt_sym.shndx);
                linker.symbols[existing_idx] = ElfSymbol(
                    name=crt_sym.name,
                    value=adjusted_value,
                    size=crt_sym.size,
                    bind=crt_sym.bind,
                    typ=crt_sym.typ,
                    shndx=new_shndx
                );
            }
            sym_idx_map[crt_sym_idx] = existing_idx;
        } else {
            new_idx = len(linker.symbols);
            new_shndx = sec_idx_map.get(crt_sym.shndx, crt_sym.shndx);
            linker.symbols.append(
                ElfSymbol(
                    name=crt_sym.name,
                    value=adjusted_value,
                    size=crt_sym.size,
                    bind=crt_sym.bind,
                    typ=crt_sym.typ,
                    shndx=new_shndx
                )
            );
            sym_idx_map[crt_sym_idx] = new_idx;
            if crt_sym.name {
                existing_syms[crt_sym.name] = new_idx;
            }
        }
    }

    # Merge relocations with remapped indices and adjusted offsets
    for rel in crt.relocations {
        new_sym_idx = sym_idx_map.get(rel.sym_idx, rel.sym_idx);
        new_sym_name = linker.symbols[new_sym_idx].name
            if new_sym_idx < len(linker.symbols)
            else rel.sym_name;
        # Find the CRT section index for this relocation's target section
        crt_target_idx: int | None = None;
        for (ci, cs) in enumerate(crt.sections) {
            if cs.name == rel.target_sec {
                crt_target_idx = ci;
                break;
            }
        }
        # Adjust relocation offset by the section merge offset
        adjusted_offset = rel.offset;
        if crt_target_idx is not None {
            adjusted_offset += sec_data_offset.get(crt_target_idx, 0);
        }
        linker.relocations.append(
            ElfRela(
                offset=adjusted_offset,
                sym_idx=new_sym_idx,
                rtype=rel.rtype,
                addend=rel.addend,
                sym_name=new_sym_name,
                target_sec=rel.target_sec
            )
        );
    }
    return True;
}


# ── Static link method ───────────────────────────────────────────
impl ElfLinker.link(
    obj_bytes: bytes,
    output_path: str,
    needed_libs: list[str] = ["libc.so.6"],
    crt_objects: list[bytes] = []
) -> bool {
    linker = ElfLinker(
        obj_data=obj_bytes,
        sections=[],
        symbols=[],
        relocations=[],
        needed_libs=needed_libs
    );
    if not linker.parse_object() {
        return False;
    }

    # Merge CRT objects (e.g. crt1.o) into the main object
    for crt_bytes in crt_objects {
        if not _merge_crt_object(linker, crt_bytes) {
            return False;
        }
    }

    exe_bytes = linker.build_executable();
    if not exe_bytes {
        return False;
    }
    with open(output_path, "wb") as f {
        f.write(exe_bytes);
    }
    os.chmod(output_path, 0o755);
    return True;
}
