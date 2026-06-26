"""Architecture-agnostic ELF64 linker implementation.

Converts a relocatable .o (from llvmlite emit_object) into a runnable
ELF executable with dynamic linking against libc.
Architecture is auto-detected from the object file.
"""

import struct;
import os;
import sys;
import from jaclang.compiler.passes.native.linker_common {
    _align,
    _build_strtab,
    _append_to_blob,
    _resolve_seg_vaddr,
    _resolve_patch_site,
    _find_entry_vaddr
}

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
     SHT_DYNSYM = 11,
     SHT_INIT_ARRAY = 14;

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
     DT_RELAENT = 9,
     DT_RUNPATH = 29,
     # Shared-object dynamic tags: SONAME names the library, INIT_ARRAY points
     # at a vector of init function pointers the loader runs on dlopen/load.
     DT_SONAME = 14,
     DT_INIT_ARRAY = 25,
     DT_INIT_ARRAYSZ = 27;

# ── ELF object type ──────────────────────────────────────────────
# ET_EXEC = 2 (declared above); ET_DYN = 3 is a shared object / PIE.
glob ET_DYN = 3;

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
     R_X86_64_RELATIVE = 8,
     R_X86_64_GOTPCREL = 9,
     # Absolute 32-bit relocations. DWARF debug sections use these for 4-byte
     # intra-section offsets (.debug_info → .debug_str, .debug_names, …); the
     # loadable code path never emits them. _32 is unsigned, _32S sign-extended.
     R_X86_64_32 = 10,
     R_X86_64_32S = 11,
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
     R_AARCH64_ABS64 = 257,
     # MOVZ/MOVK absolute-address materialization. A 64-bit address is built
     # across four instructions; each reloc patches one 16-bit slice into the
     # imm16 field. G0/G1/G2/G3 carry address bits [15:0]/[31:16]/[47:32]/[63:48].
     # The _NC ("no check") variants suppress the per-group overflow check.
     R_AARCH64_MOVW_UABS_G0 = 263,
     R_AARCH64_MOVW_UABS_G0_NC = 264,
     R_AARCH64_MOVW_UABS_G1 = 265,
     R_AARCH64_MOVW_UABS_G1_NC = 266,
     R_AARCH64_MOVW_UABS_G2 = 267,
     R_AARCH64_MOVW_UABS_G2_NC = 268,
     R_AARCH64_MOVW_UABS_G3 = 269,
     # Absolute 32-bit data relocation (DWARF intra-section offsets on arm64).
     R_AARCH64_ABS32 = 258,
     R_AARCH64_RELATIVE = 1027;


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


# ── Proper SysV hash table over named dynamic symbols ───────────
"""Build a correct SysV (.hash) table for a list of dynamic-symbol names.

Unlike _build_hash_table (a degenerate single-bucket chain used by the
executable path, where the loader only ever resolves *undefined* imports),
a shared object must let `dlsym`/the loader find each *exported* symbol by
name. names[0] is the reserved null entry (""), and names[i] must line up
with dynamic-symbol index i. Buckets index the first symbol whose hash lands
there; chain[i] threads collisions, terminating at 0 (STN_UNDEF)."""
def _build_sysv_hash_for_names(names: list[str]) -> bytes {
    n = len(names);
    nbucket = max(1, n // 2);
    buckets = [0] * nbucket;
    chain = [0] * n;
    i = 1;
    while i < n {
        b = _elf_hash(names[i]) % nbucket;
        chain[i] = buckets[b];
        buckets[b] = i;
        i += 1;
    }
    data = bytearray();
    data.extend(struct.pack("<II", nbucket, n));
    for x in buckets {
        data.extend(struct.pack("<I", x));
    }
    for x in chain {
        data.extend(struct.pack("<I", x));
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
            gotpcrel_rtypes={R_X86_64_GOTPCREL, R_X86_64_REX_GOTPCRELX},
            relative_rtype=R_X86_64_RELATIVE,
            abs64_rtype=R_X86_64_64
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
            gotpcrel_rtypes={R_AARCH64_ADR_GOT_PAGE, R_AARCH64_LD64_GOT_LO12_NC},
            relative_rtype=R_AARCH64_RELATIVE,
            abs64_rtype=R_AARCH64_ABS64
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
    } elif rtype == R_AARCH64_MOVW_UABS_G0
    or rtype == R_AARCH64_MOVW_UABS_G0_NC
    or rtype == R_AARCH64_MOVW_UABS_G1
    or rtype == R_AARCH64_MOVW_UABS_G1_NC
    or rtype == R_AARCH64_MOVW_UABS_G2
    or rtype == R_AARCH64_MOVW_UABS_G2_NC
    or rtype == R_AARCH64_MOVW_UABS_G3 {
        # Patch one 16-bit slice of the absolute address (S + A) into the
        # MOVZ/MOVK imm16 field at bits [20:5]. The reloc type selects the
        # group: G0/G1/G2/G3 -> address bits [15:0]/[31:16]/[47:32]/[63:48].
        # Each {G,G_NC} pair is two consecutive codes, so dividing the offset
        # from G0 by two yields the group index.
        val = sym_addr + addend;
        group = (rtype - R_AARCH64_MOVW_UABS_G0) // 2;
        imm16 = (val >> (group * 16)) & 0xFFFF;
        insn = struct.unpack_from("<I", patch_buf, patch_off)[0];
        insn = (insn & 0xFFE0001F) | (imm16 << 5);
        struct.pack_into("<I", patch_buf, patch_off, insn);
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
                sym_name = self.symbols[r_sym].name
                    if r_sym < len(self.symbols)
                    else "";
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


# ── Apply an absolute DWARF relocation ───────────────────────────
"""Patch an absolute relocation inside a (non-loaded) .debug_* section.

DWARF relocations are all absolute: a 64-bit (R_X86_64_64 / R_AARCH64_ABS64)
or 32-bit (R_X86_64_32 / _32S / R_AARCH64_ABS32) field set to sym_addr+addend.
References to code resolve to the final virtual address; references to another
debug section resolve to 0 (those sections are not loaded), so the field ends
up holding just the addend, i.e. the in-section offset DWARF consumers expect.
Returns False for any other relocation type so the caller can skip it."""
def _apply_debug_reloc(
    rtype: int, patch_buf: bytearray, patch_off: int, value: int
) -> bool {
    if rtype == R_X86_64_64 or rtype == R_AARCH64_ABS64 {
        struct.pack_into("<Q", patch_buf, patch_off, value & 0xFFFFFFFFFFFFFFFF);
        return True;
    } elif rtype == R_X86_64_32 or rtype == R_X86_64_32S or rtype == R_AARCH64_ABS32 {
        struct.pack_into("<I", patch_buf, patch_off, value & 0xFFFFFFFF);
        return True;
    }
    return False;
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
                off = _append_to_blob(code_data, sec.data, sec.align, len(sec.data));
                code_sections[sec.name] = (off, len(sec.data));
                section_placement[sec_idx] = ("code", off);
            }
        } elif sec.typ == SHT_PROGBITS
        and (sec.flags & SHF_ALLOC)
        and not (sec.flags & SHF_WRITE) {
            if len(sec.data) > 0 {
                off = _append_to_blob(rodata_blob, sec.data, sec.align, len(sec.data));
                rodata_sections[sec.name] = (off, len(sec.data));
                section_placement[sec_idx] = ("rodata", off);
            }
        } elif (sec.flags & SHF_WRITE) and (sec.flags & SHF_ALLOC) {
            alloc_size = sec.mem_size;
            if alloc_size > 0 {
                off = _append_to_blob(data_blob, sec.data, sec.align, alloc_size);
                data_sections[sec.name] = (off, alloc_size);
                section_placement[sec_idx] = ("data", off);
            }
        }
        sec_idx += 1;
    }

    # Identify external symbols
    known_data_syms = {"stdin", "stdout", "stderr", "environ"};
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
    # Defined symbols exported for dlsym (e.g. close() for CEF hosts).
    exec_exports: list[str] = [];
    for nm in self.export_symbols {
        if nm in local_sym_map and nm not in extern_syms {
            exec_exports.append(nm);
        }
    }

    # ── Layout ────────────────────────────────────────────────────
    ehdr_size = 64;
    num_phdrs = 5;
    phdr_size = num_phdrs * 56;

    # Build interp. Prefer a loader that exists on the build host (native
    # build), but when cross-compiling the target loader is absent here, so
    # fall back to the canonical (first) interpreter path for the target arch.
    interp_data = b"\x00";
    for path in arch.interp_paths {
        if os.path.exists(path) {
            interp_data = path.encode() + b"\x00";
            break;
        }
    }
    if interp_data == b"\x00" and arch.interp_paths {
        interp_data = arch.interp_paths[0].encode() + b"\x00";
    }

    # Build dynamic string table. "$ORIGIN" backs the DT_RUNPATH entry so the
    # loader resolves needed libraries relative to the executable's own
    # directory (a sibling .so is found no matter the launch CWD).
    dynstr_strings = [""] + extern_syms + exec_exports + self.needed_libs + ["$ORIGIN"];
    (dynstr_data, dynstr_offsets) = _build_strtab(dynstr_strings);

    # Build dynamic symbol table
    num_dynsyms = 1 + len(extern_syms) + len(exec_exports);
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
    for sym_name in exec_exports {
        st_name = dynstr_offsets.get(sym_name, 0);
        st_info = (STB_GLOBAL << 4) | STT_FUNC;
        dynsym_data.extend(struct.pack("<IBBHQQ", st_name, st_info, 0, 0, 0, 0));
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
    # Resolve needed libraries relative to the executable directory ($ORIGIN),
    # so a sibling shared library is found regardless of the launch CWD. The
    # value is a .dynstr offset (like DT_NEEDED), so it is not vaddr-patched.
    dyn_entries.append((DT_RUNPATH, dynstr_offsets.get("$ORIGIN", 0)));
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

    # ── Patch dynsym entries for exported defined symbols ─────────
    for idx in range(len(exec_exports)) {
        nm = exec_exports[idx];
        place = local_sym_map[nm];
        sym_vaddr = _resolve_seg_vaddr(
            place[0], place[1], text_vaddr, rodata_vaddr, data_vaddr
        );
        dynsym_offset = (1 + len(extern_syms) + idx) * 24;
        struct.pack_into("<Q", dynsym_data, dynsym_offset + 8, sym_vaddr);
        struct.pack_into("<H", dynsym_data, dynsym_offset + 6, 1);
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
                sym_addr = _resolve_seg_vaddr(
                    local[0], local[1], text_vaddr, rodata_vaddr, data_vaddr
                );
            }
        }

        # Determine target buffer, in-buffer offset, and final vaddr.
        site = _resolve_patch_site(
            rela.offset,
            rela.target_sec,
            code_sections,
            rodata_sections,
            data_sections,
            code_bytes,
            rodata_bytes,
            data_bytes,
            text_vaddr,
            rodata_vaddr,
            data_vaddr
        );
        if site is None {
            # The relocation targets a section we do not place in the loadable
            # image (e.g. metadata like .eh_frame, whose relocations are also
            # filtered while parsing). There is nothing in the output to patch,
            # so skip it. The previous fallback wrote into .text at this offset,
            # which would corrupt code if such a relocation were ever applied.
            continue;
        }
        (patch_buf, patch_off, patch_vaddr) = site;

        # Apply via architecture-specific handler. Every relocation that reaches
        # here targets an emitted (loadable) section, so an unhandled type would
        # leave the reference pointing at NULL. Fail loudly instead of emitting a
        # binary that segfaults at process entry (the failure mode of #6366).
        applied = arch.apply_reloc(
            rela.rtype, patch_buf, patch_off, sym_addr, rela.addend, patch_vaddr
        );
        if not applied {
            raise ValueError(
                f"ELF linker: no handler for relocation type {rela.rtype} "
                f"(symbol '{rela.sym_name}', section '{rela.target_sec}', "
                f"e_machine {arch.e_machine}). Refusing to emit a binary with "
                f"an unrelocated reference."
            );
        }
    }

    # ── Find entry point ──────────────────────────────────────────
    entry_vaddr = _find_entry_vaddr(local_sym_map, text_vaddr);

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

    # Populate sym_vaddrs so callers can write a symmap for profiling tools.
    for (sname, place) in local_sym_map.items() {
        va = _resolve_seg_vaddr(
            place[0], place[1], text_vaddr, rodata_vaddr, data_vaddr
        );
        if sname {
            self.sym_vaddrs[sname] = va;
        }
    }

    # ── Debug build: preserve DWARF + emit a .symtab and section headers ──
    # llvmlite emits .debug_* sections and a .symtab only when the IR carries
    # debug metadata (JAC_NATIVE_DEBUG=1). When they are present we append a
    # relocated copy of every .debug_* section, a .symtab carrying final virtual
    # addresses, and a section header table: the three things GDB reads to map
    # addresses to function names and source lines. A normal build has no
    # .debug_* sections and falls through to the lean image returned below
    # unchanged (no section header table, byte-identical to before).
    debug_sec_names: list[str] = [];
    debug_sec_blobs: dict[str, bytearray] = {};
    for dsec in self.sections {
        if dsec.name.startswith(".debug")
        and dsec.typ == SHT_PROGBITS
        and len(dsec.data) > 0 {
            debug_sec_names.append(dsec.name);
            debug_sec_blobs[dsec.name] = bytearray(dsec.data);
        }
    }

    if debug_sec_names {
        # Relocate the .debug_* copies, reusing the loadable path's symbol
        # resolution: a code reference resolves to its final VA; a reference to
        # an unplaced (debug) section resolves to 0, so the field holds just the
        # addend, i.e. the in-section offset DWARF consumers expect.
        _unhandled_debug_relocs: set[tuple[int, str]] = set();
        for d_rela in self.relocations {
            if d_rela.target_sec not in debug_sec_blobs {
                continue;
            }
            d_sym_addr = 0;
            d_local = local_sym_map.get(d_rela.sym_name) if d_rela.sym_name else None;
            if d_local is None {
                d_local = sym_idx_placement.get(d_rela.sym_idx);
            }
            if d_local is not None {
                d_sym_addr = _resolve_seg_vaddr(
                    d_local[0], d_local[1], text_vaddr, rodata_vaddr, data_vaddr
                );
            }
            if not _apply_debug_reloc(
                d_rela.rtype,
                debug_sec_blobs[d_rela.target_sec],
                d_rela.offset,
                d_sym_addr + d_rela.addend
            ) {
                # An unhandled (non-absolute) reloc leaves the field at its
                # placeholder, so that DWARF entry would point at a garbage
                # offset. Surface it rather than silently shipping corrupt debug
                # info — GDB would otherwise show "no source"/wrong locations
                # with no explanation. Report each (type, section) pair once.
                _unhandled_debug_relocs.add((d_rela.rtype, d_rela.target_sec));
            }
        }
        if _unhandled_debug_relocs {
            for (_ut, _usec) in sorted(_unhandled_debug_relocs) {
                sys.stderr.write(
                    f"  Warning: unhandled DWARF relocation type {_ut} in "
                    f"{_usec}; some debug info may be incomplete.\n"
                );
            }
        }

        # Build the section header table. First mirror the loadable layout the
        # program headers already describe (so PT_DYNAMIC has a matching
        # SHT_DYNAMIC, .dynsym/.dynstr are reachable, etc.), then append the
        # .debug_* sections, .symtab, .strtab and .shstrtab as a non-loaded
        # tail. Each spec is a mutable list [name, type, flags, addr, off, size,
        # link_name, info, align, entsize]; the tail offsets/sizes and the
        # .symtab sh_info are patched in once the bytes are placed, and
        # link_name is resolved to a section index at serialisation time.
        sh_specs: list = [["", SHT_NULL, 0, 0, 0, 0, "", 0, 0, 0]];
        sh_specs.append(
            [
                ".interp",
                SHT_PROGBITS,
                SHF_ALLOC,
                interp_vaddr,
                interp_foff,
                len(interp_data),
                "",
                0,
                1,
                0
            ]
        );
        sh_specs.append(
            [
                ".hash",
                SHT_HASH,
                SHF_ALLOC,
                hash_vaddr,
                hash_foff,
                len(hash_data),
                ".dynsym",
                0,
                8,
                4
            ]
        );
        sh_specs.append(
            [
                ".dynsym",
                SHT_DYNSYM,
                SHF_ALLOC,
                dynsym_vaddr,
                dynsym_foff,
                num_dynsyms * 24,
                ".dynstr",
                1,
                8,
                24
            ]
        );
        sh_specs.append(
            [
                ".dynstr",
                SHT_STRTAB,
                SHF_ALLOC,
                dynstr_vaddr,
                dynstr_foff,
                len(dynstr_data),
                "",
                0,
                1,
                0
            ]
        );
        if len(extern_func_syms) > 0 {
            sh_specs.append(
                [
                    ".rela.plt",
                    SHT_RELA,
                    SHF_ALLOC,
                    rela_plt_vaddr,
                    rela_plt_foff,
                    len(extern_func_syms) * 24,
                    ".dynsym",
                    0,
                    8,
                    24
                ]
            );
        }
        if rela_dyn_size > 0 {
            sh_specs.append(
                [
                    ".rela.dyn",
                    SHT_RELA,
                    SHF_ALLOC,
                    rela_dyn_vaddr,
                    rela_dyn_foff,
                    rela_dyn_size,
                    ".dynsym",
                    0,
                    8,
                    24
                ]
            );
        }
        if plt_size > 0 {
            sh_specs.append(
                [
                    ".plt",
                    SHT_PROGBITS,
                    SHF_ALLOC | SHF_EXECINSTR,
                    plt_vaddr,
                    plt_foff,
                    plt_size,
                    "",
                    0,
                    16,
                    16
                ]
            );
        }
        if len(code_data) > 0 {
            sh_specs.append(
                [
                    ".text",
                    SHT_PROGBITS,
                    SHF_ALLOC | SHF_EXECINSTR,
                    text_vaddr,
                    text_foff,
                    len(code_data),
                    "",
                    0,
                    16,
                    0
                ]
            );
        }
        if len(rodata_blob) > 0 {
            sh_specs.append(
                [
                    ".rodata",
                    SHT_PROGBITS,
                    SHF_ALLOC,
                    rodata_vaddr,
                    rodata_foff,
                    len(rodata_blob),
                    "",
                    0,
                    16,
                    0
                ]
            );
        }
        if got_plt_size > 0 {
            sh_specs.append(
                [
                    ".got.plt",
                    SHT_PROGBITS,
                    SHF_WRITE | SHF_ALLOC,
                    got_plt_vaddr,
                    got_plt_foff,
                    got_plt_size,
                    "",
                    0,
                    8,
                    8
                ]
            );
        }
        if data_got_size > 0 {
            sh_specs.append(
                [
                    ".got",
                    SHT_PROGBITS,
                    SHF_WRITE | SHF_ALLOC,
                    data_got_vaddr,
                    data_got_foff,
                    data_got_size,
                    "",
                    0,
                    8,
                    8
                ]
            );
        }
        sh_specs.append(
            [
                ".dynamic",
                SHT_DYNAMIC,
                SHF_WRITE | SHF_ALLOC,
                dynamic_vaddr,
                dynamic_foff,
                len(dynamic_data),
                ".dynstr",
                0,
                8,
                16
            ]
        );
        if len(data_blob) > 0 {
            sh_specs.append(
                [
                    ".data",
                    SHT_PROGBITS,
                    SHF_WRITE | SHF_ALLOC,
                    data_vaddr,
                    data_foff,
                    len(data_blob),
                    "",
                    0,
                    8,
                    0
                ]
            );
        }
        # Non-loaded tail (addr 0); offsets/sizes patched once placed below.
        for dn in debug_sec_names {
            sh_specs.append([dn, SHT_PROGBITS, 0, 0, 0, 0, "", 0, 1, 0]);
        }
        sh_specs.append([".symtab", SHT_SYMTAB, 0, 0, 0, 0, ".strtab", 0, 8, 24]);
        sh_specs.append([".strtab", SHT_STRTAB, 0, 0, 0, 0, "", 0, 1, 0]);
        sh_specs.append([".shstrtab", SHT_STRTAB, 0, 0, 0, 0, "", 0, 1, 0]);

        sh_name_to_idx: dict[str, int] = {};
        for (_si, _sp) in enumerate(sh_specs) {
            sh_name_to_idx[_sp[0]] = _si;
        }
        text_idx = sh_name_to_idx.get(".text", 0);
        seg_shndx: dict[str, int] = {
            "code": text_idx,
            "rodata": sh_name_to_idx.get(".rodata", text_idx),
            "data": sh_name_to_idx.get(".data", text_idx)
        };

        # Build .symtab/.strtab from defined, named symbols with final VAs. ELF
        # requires local symbols before globals; sh_info is the first global.
        sym_locals: list = [];
        sym_globals: list = [];
        for dsym in self.symbols {
            if (not dsym.name)
            or dsym.shndx == SHN_UNDEF
            or dsym.shndx >= len(self.sections) {
                continue;
            }
            dplace = section_placement.get(dsym.shndx);
            if dplace is None {
                continue;
            }
            sva = _resolve_seg_vaddr(
                dplace[0], dplace[1] + dsym.value, text_vaddr, rodata_vaddr, data_vaddr
            );
            styp = STT_FUNC if dplace[0] == "code" else STT_OBJECT;
            entry = (
                dsym.name,
                sva,
                dsym.size,
                dsym.bind,
                styp,
                seg_shndx.get(dplace[0], text_idx)
            );
            if dsym.bind >= STB_GLOBAL {
                sym_globals.append(entry);
            } else {
                sym_locals.append(entry);
            }
        }
        ordered_syms = sym_locals + sym_globals;
        first_global = 1 + len(sym_locals);
        sym_names: list[str] = [];
        for e in ordered_syms {
            sym_names.append(e[0]);
        }
        (strtab_data, strtab_offsets) = _build_strtab(sym_names);
        symtab_data = bytearray();
        symtab_data.extend(struct.pack("<IBBHQQ", 0, 0, 0, 0, 0, 0));
        for e in ordered_syms {
            st_info = (e[3] << 4) | e[4];
            symtab_data.extend(
                struct.pack(
                    "<IBBHQQ", strtab_offsets.get(e[0], 0), st_info, 0, e[5], e[1], e[2]
                )
            );
        }

        # ── Place the non-loaded tail and patch its specs' offsets/sizes ──
        for dn in debug_sec_names {
            _di = sh_name_to_idx[dn];
            sh_specs[_di][4] = len(output);
            sh_specs[_di][5] = len(debug_sec_blobs[dn]);
            output.extend(debug_sec_blobs[dn]);
        }
        _pad = _align(len(output), 8) - len(output);
        if _pad > 0 {
            output.extend(b"\x00" * _pad);
        }
        _sti = sh_name_to_idx[".symtab"];
        sh_specs[_sti][4] = len(output);
        sh_specs[_sti][5] = len(symtab_data);
        sh_specs[_sti][7] = first_global;  # sh_info = first global symbol index
        output.extend(symtab_data);
        _sri = sh_name_to_idx[".strtab"];
        sh_specs[_sri][4] = len(output);
        sh_specs[_sri][5] = len(strtab_data);
        output.extend(strtab_data);

        # ── Serialise .shstrtab + the section header table ──
        sh_name_list: list[str] = [];
        for sp in sh_specs {
            sh_name_list.append(sp[0]);
        }
        (shstr_data, shstr_off) = _build_strtab(sh_name_list);
        _shi = sh_name_to_idx[".shstrtab"];
        sh_specs[_shi][4] = len(output);
        sh_specs[_shi][5] = len(shstr_data);
        output.extend(shstr_data);
        shoff = _align(len(output), 8);
        if shoff > len(output) {
            output.extend(b"\x00" * (shoff - len(output)));
        }
        for sp in sh_specs {
            slink = sh_name_to_idx.get(sp[6], 0) if sp[6] else 0;
            output.extend(
                struct.pack(
                    "<IIQQQQIIQQ",
                    shstr_off.get(sp[0], 0),
                    sp[1],
                    sp[2],
                    sp[3],
                    sp[4],
                    sp[5],
                    slink,
                    sp[7],
                    sp[8],
                    sp[9]
                )
            );
        }
        # Patch the ELF header's section-header fields now that the table exists.
        struct.pack_into("<Q", output, 40, shoff);  # e_shoff
        struct.pack_into("<H", output, 58, 64);  # e_shentsize
        struct.pack_into("<H", output, 60, len(sh_specs));  # e_shnum
        struct.pack_into("<H", output, 62, sh_name_to_idx.get(".shstrtab", 0));
    }

    return bytes(output);
}


# ── Build a shared object (ET_DYN) ───────────────────────────────
"""Link the relocatable object into a position-independent ELF shared object.

Unlike build_executable (a fixed-base ET_EXEC), this emits an ET_DYN image
with base virtual address 0 and no PT_INTERP, so the loader may map it at any
address. Three things make that work:
  * the exported `:pub` symbols are written into .dynsym with a real .hash so
    a C host can resolve them via dlsym;
  * every absolute pointer the image stores into its own data — pointers in
    writable data, GOT slots for defined symbols accessed through the GOT, and
    the DT_INIT_ARRAY entries — becomes an R_*_RELATIVE dynamic relocation that
    the loader fixes up with the load bias (external symbols still bind through
    the PLT/GOT as in the executable path);
  * DT_INIT_ARRAY lists the init functions (e.g. __jac_shared_init) the loader
    runs on dlopen, so module globals are initialised before any export runs.
"""
impl ElfLinker.build_shared_object -> bytes {
    arch = self.arch;
    BASE_VADDR = 0;  # ET_DYN: loader picks the base, everything is bias-relative
    PAGE_SIZE = arch.page_size;

    # ── Collect code/rodata/data sections (identical to build_executable) ──
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
                off = _append_to_blob(code_data, sec.data, sec.align, len(sec.data));
                code_sections[sec.name] = (off, len(sec.data));
                section_placement[sec_idx] = ("code", off);
            }
        } elif sec.typ == SHT_PROGBITS
        and (sec.flags & SHF_ALLOC)
        and not (sec.flags & SHF_WRITE) {
            if len(sec.data) > 0 {
                off = _append_to_blob(rodata_blob, sec.data, sec.align, len(sec.data));
                rodata_sections[sec.name] = (off, len(sec.data));
                section_placement[sec_idx] = ("rodata", off);
            }
        } elif (sec.flags & SHF_WRITE) and (sec.flags & SHF_ALLOC) {
            alloc_size = sec.mem_size;
            if alloc_size > 0 {
                off = _append_to_blob(data_blob, sec.data, sec.align, alloc_size);
                data_sections[sec.name] = (off, alloc_size);
                section_placement[sec_idx] = ("data", off);
            }
        }
        sec_idx += 1;
    }

    # ── Identify external + local symbols (mirrors build_executable) ──
    known_data_syms = {"stdin", "stdout", "stderr", "environ"};
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

    # Defined symbols accessed through the GOT (GOTPCREL to a local definition)
    # each need a private GOT slot fixed up with a RELATIVE relocation.
    local_got_syms: list[str] = [];
    for rela in self.relocations {
        if rela.rtype in arch.gotpcrel_rtypes
        and rela.sym_name
        and rela.sym_name not in extern_func_syms
        and rela.sym_name not in extern_data_syms
        and rela.sym_name in local_sym_map
        and rela.sym_name not in local_got_syms {
            local_got_syms.append(rela.sym_name);
        }
    }

    # Exported symbols: requested names that are actually defined here.
    exports: list[str] = [];
    for nm in self.export_symbols {
        if nm in local_sym_map and nm not in exports {
            exports.append(nm);
        }
    }
    # Init functions that are actually defined (run via DT_INIT_ARRAY).
    inits: list[str] = [];
    for nm in self.init_funcs {
        if nm in local_sym_map and nm not in inits {
            inits.append(nm);
        }
    }
    _soname = self.soname or "lib.so";

    # ── Dynamic string + symbol tables ────────────────────────────
    # dynsym order: [null] + exports + extern_func + extern_data. The .hash
    # and the symbol-index map below must use this exact order.
    dynsym_names: list[str] = [""] + exports + extern_func_syms + extern_data_syms;
    dynstr_strings: list[str] = [""] + exports + extern_func_syms + extern_data_syms + self.needed_libs + [
        _soname,
        "$ORIGIN"
    ];
    (dynstr_data, dynstr_offsets) = _build_strtab(dynstr_strings);
    hash_data = _build_sysv_hash_for_names(dynsym_names);

    # name -> dynsym index
    dynsym_index: dict[str, int] = {};
    _di = 1;
    for nm in (exports + extern_func_syms + extern_data_syms) {
        dynsym_index[nm] = _di;
        _di += 1;
    }
    extern_data_set = set(extern_data_syms);

    # ── Sizes ─────────────────────────────────────────────────────
    plt0_size = arch.plt0_size;
    plt_entry_size = arch.plt_entry_size;
    plt_size = plt0_size + len(extern_func_syms) * plt_entry_size;
    got_plt_entries = 3 + len(extern_func_syms);
    got_plt_size = got_plt_entries * 8;
    data_got_size = len(extern_data_syms) * 8;  # GLOB_DAT slots for extern data
    local_got_size = len(local_got_syms) * 8;  # RELATIVE slots for local defs
    init_arr_size = len(inits) * 8;
    num_dynsyms = len(dynsym_names);

    # ── Layout: code segment (RX/R, file offset == vaddr since BASE 0) ──
    ehdr_size = 64;
    num_phdrs = 4;  # PHDR, LOAD(code), LOAD(data), DYNAMIC — no INTERP
    phdr_size = num_phdrs * 56;
    cur_offset = ehdr_size + phdr_size;
    cur_offset = _align(cur_offset, 8);
    hash_foff = cur_offset;
    cur_offset += len(hash_data);
    cur_offset = _align(cur_offset, 8);
    dynsym_foff = cur_offset;
    cur_offset += num_dynsyms * 24;
    cur_offset = _align(cur_offset, 8);
    dynstr_foff = cur_offset;
    cur_offset += len(dynstr_data);
    cur_offset = _align(cur_offset, 8);
    rela_plt_foff = cur_offset;
    cur_offset += len(extern_func_syms) * 24;
    cur_offset = _align(cur_offset, 8);
    # rela.dyn holds: RELATIVE (data abs64 to defined), RELATIVE (local GOT),
    # RELATIVE (init array), GLOB_DAT (extern data). Built after vaddrs known;
    # count them now to reserve space.
    data_abs_relocs: list[tuple] = [];
    for rela in self.relocations {
        if rela.rtype == arch.abs64_rtype and rela.target_sec in data_sections {
            tgt = local_sym_map.get(rela.sym_name) if rela.sym_name else None;
            if tgt is None {
                tgt = sym_idx_placement.get(rela.sym_idx);
            }
            if tgt is not None {
                data_abs_relocs.append((rela, tgt));
            }
        }
    }
    n_rela_dyn = len(data_abs_relocs) + len(local_got_syms) + len(inits) + len(
        extern_data_syms
    );
    rela_dyn_foff = cur_offset;
    cur_offset += n_rela_dyn * 24;
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

    # ── Layout: data segment (RW) on a fresh page ──
    data_seg_foff = _align(cur_offset, PAGE_SIZE);
    data_seg_vaddr = BASE_VADDR + data_seg_foff;
    got_plt_foff = data_seg_foff;
    cur_offset = got_plt_foff + got_plt_size;
    cur_offset = _align(cur_offset, 8);
    data_got_foff = cur_offset;
    cur_offset += data_got_size;
    cur_offset = _align(cur_offset, 8);
    local_got_foff = cur_offset;
    cur_offset += local_got_size;
    cur_offset = _align(cur_offset, 8);
    init_arr_foff = cur_offset;
    cur_offset += init_arr_size;
    cur_offset = _align(cur_offset, 8);
    dynamic_foff = cur_offset;
    # Dynamic entries (sizes known; address fields patched after vaddrs).
    dyn_entries: list[tuple[int, int]] = [];
    for lib in self.needed_libs {
        dyn_entries.append((DT_NEEDED, dynstr_offsets.get(lib, 0)));
    }
    dyn_entries.append((DT_SONAME, dynstr_offsets.get(_soname, 0)));
    dyn_entries.append((DT_RUNPATH, dynstr_offsets.get("$ORIGIN", 0)));
    dyn_entries.append((DT_HASH, 0));
    dyn_entries.append((DT_STRTAB, 0));
    dyn_entries.append((DT_SYMTAB, 0));
    dyn_entries.append((DT_STRSZ, len(dynstr_data)));
    dyn_entries.append((DT_SYMENT, 24));
    if len(extern_func_syms) > 0 {
        dyn_entries.append((DT_PLTGOT, 0));
        dyn_entries.append((DT_PLTRELSZ, len(extern_func_syms) * 24));
        dyn_entries.append((DT_PLTREL, DT_RELA));
        dyn_entries.append((DT_JMPREL, 0));
    }
    if n_rela_dyn > 0 {
        dyn_entries.append((DT_RELA, 0));
        dyn_entries.append((DT_RELASZ, n_rela_dyn * 24));
        dyn_entries.append((DT_RELAENT, 24));
    }
    if len(inits) > 0 {
        dyn_entries.append((DT_INIT_ARRAY, 0));
        dyn_entries.append((DT_INIT_ARRAYSZ, init_arr_size));
    }
    dyn_entries.append((DT_NULL, 0));
    dynamic_size = len(dyn_entries) * 16;
    cur_offset = dynamic_foff + dynamic_size;
    cur_offset = _align(cur_offset, 8);
    data_foff = cur_offset;
    cur_offset += len(data_blob);
    data_seg_size = cur_offset - data_seg_foff;
    total_file_size = data_seg_foff + data_seg_size;

    # ── Virtual addresses (BASE 0, so vaddr == file offset) ──
    hash_vaddr = BASE_VADDR + hash_foff;
    dynsym_vaddr = BASE_VADDR + dynsym_foff;
    dynstr_vaddr = BASE_VADDR + dynstr_foff;
    rela_plt_vaddr = BASE_VADDR + rela_plt_foff;
    rela_dyn_vaddr = BASE_VADDR + rela_dyn_foff;
    plt_vaddr = BASE_VADDR + plt_foff;
    text_vaddr = BASE_VADDR + text_foff;
    rodata_vaddr = BASE_VADDR + rodata_foff;
    got_plt_vaddr = BASE_VADDR + got_plt_foff;
    data_got_vaddr = BASE_VADDR + data_got_foff;
    local_got_vaddr = BASE_VADDR + local_got_foff;
    init_arr_vaddr = BASE_VADDR + init_arr_foff;
    dynamic_vaddr = BASE_VADDR + dynamic_foff;
    data_vaddr = BASE_VADDR + data_foff;

    local_got_slot: dict[str, int] = {};
    for (gi, gnm) in enumerate(local_got_syms) {
        local_got_slot[gnm] = local_got_vaddr + gi * 8;
    }
    extern_data_slot: dict[str, int] = {};
    for (gi, gnm) in enumerate(extern_data_syms) {
        extern_data_slot[gnm] = data_got_vaddr + gi * 8;
    }

    # ── Section-header specs ──────────────────────────────────────
    # The runtime loader only needs PT_DYNAMIC, but `ld -lfoo`, readelf
    # --dyn-syms and nm -D read the section header table. Each spec is
    # (name, type, flags, addr, offset, size, link_name, info, align, entsize);
    # link_name is resolved to a section index after the list is built. The
    # .shstrtab offset/size are filled in when the table is serialised.
    PF_NONE = 0;
    sh_specs: list = [("", SHT_NULL, 0, 0, 0, 0, "", 0, 0, 0)];
    sh_specs.append(
        (
            ".hash",
            SHT_HASH,
            SHF_ALLOC,
            hash_vaddr,
            hash_foff,
            len(hash_data),
            ".dynsym",
            0,
            8,
            4
        )
    );
    sh_specs.append(
        (
            ".dynsym",
            SHT_DYNSYM,
            SHF_ALLOC,
            dynsym_vaddr,
            dynsym_foff,
            num_dynsyms * 24,
            ".dynstr",
            1,
            8,
            24
        )
    );
    sh_specs.append(
        (
            ".dynstr",
            SHT_STRTAB,
            SHF_ALLOC,
            dynstr_vaddr,
            dynstr_foff,
            len(dynstr_data),
            "",
            0,
            1,
            0
        )
    );
    if len(extern_func_syms) > 0 {
        sh_specs.append(
            (
                ".rela.plt",
                SHT_RELA,
                SHF_ALLOC,
                rela_plt_vaddr,
                rela_plt_foff,
                len(extern_func_syms) * 24,
                ".dynsym",
                0,
                8,
                24
            )
        );
    }
    if n_rela_dyn > 0 {
        sh_specs.append(
            (
                ".rela.dyn",
                SHT_RELA,
                SHF_ALLOC,
                rela_dyn_vaddr,
                rela_dyn_foff,
                n_rela_dyn * 24,
                ".dynsym",
                0,
                8,
                24
            )
        );
    }
    if plt_size > 0 {
        sh_specs.append(
            (
                ".plt",
                SHT_PROGBITS,
                SHF_ALLOC | SHF_EXECINSTR,
                plt_vaddr,
                plt_foff,
                plt_size,
                "",
                0,
                16,
                16
            )
        );
    }
    if len(code_data) > 0 {
        sh_specs.append(
            (
                ".text",
                SHT_PROGBITS,
                SHF_ALLOC | SHF_EXECINSTR,
                text_vaddr,
                text_foff,
                len(code_data),
                "",
                0,
                16,
                0
            )
        );
    }
    if len(rodata_blob) > 0 {
        sh_specs.append(
            (
                ".rodata",
                SHT_PROGBITS,
                SHF_ALLOC,
                rodata_vaddr,
                rodata_foff,
                len(rodata_blob),
                "",
                0,
                16,
                0
            )
        );
    }
    if got_plt_size > 0 {
        sh_specs.append(
            (
                ".got.plt",
                SHT_PROGBITS,
                SHF_WRITE | SHF_ALLOC,
                got_plt_vaddr,
                got_plt_foff,
                got_plt_size,
                "",
                0,
                8,
                8
            )
        );
    }
    if data_got_size > 0 {
        sh_specs.append(
            (
                ".got",
                SHT_PROGBITS,
                SHF_WRITE | SHF_ALLOC,
                data_got_vaddr,
                data_got_foff,
                data_got_size,
                "",
                0,
                8,
                8
            )
        );
    }
    if local_got_size > 0 {
        sh_specs.append(
            (
                ".got.jac",
                SHT_PROGBITS,
                SHF_WRITE | SHF_ALLOC,
                local_got_vaddr,
                local_got_foff,
                local_got_size,
                "",
                0,
                8,
                8
            )
        );
    }
    if init_arr_size > 0 {
        sh_specs.append(
            (
                ".init_array",
                SHT_INIT_ARRAY,
                SHF_WRITE | SHF_ALLOC,
                init_arr_vaddr,
                init_arr_foff,
                init_arr_size,
                "",
                0,
                8,
                8
            )
        );
    }
    sh_specs.append(
        (
            ".dynamic",
            SHT_DYNAMIC,
            SHF_WRITE | SHF_ALLOC,
            dynamic_vaddr,
            dynamic_foff,
            dynamic_size,
            ".dynstr",
            0,
            8,
            16
        )
    );
    if len(data_blob) > 0 {
        sh_specs.append(
            (
                ".data",
                SHT_PROGBITS,
                SHF_WRITE | SHF_ALLOC,
                data_vaddr,
                data_foff,
                len(data_blob),
                "",
                0,
                8,
                0
            )
        );
    }
    sh_specs.append((".shstrtab", SHT_STRTAB, 0, 0, 0, 0, "", 0, 1, 0));
    sh_name_to_idx: dict[str, int] = {};
    for (_si, _spec) in enumerate(sh_specs) {
        sh_name_to_idx[_spec[0]] = _si;
    }
    # Map a blob segment to the section index a defined symbol lives in, so its
    # .dynsym entry carries a valid st_shndx (the loader still adds the load
    # bias; ld needs a real index, not the SHN_ABS placeholder).
    seg_shndx: dict[str, int] = {
        "code": sh_name_to_idx.get(".text", 1),
        "rodata": sh_name_to_idx.get(".rodata", sh_name_to_idx.get(".text", 1)),
        "data": sh_name_to_idx.get(".data", sh_name_to_idx.get(".dynamic", 1))
    };

    # ── Patch + serialise the dynamic section ──
    dynamic_data = bytearray();
    for (tag, val) in dyn_entries {
        _v = val;
        if tag == DT_HASH {
            _v = hash_vaddr;
        } elif tag == DT_STRTAB {
            _v = dynstr_vaddr;
        } elif tag == DT_SYMTAB {
            _v = dynsym_vaddr;
        } elif tag == DT_PLTGOT {
            _v = got_plt_vaddr;
        } elif tag == DT_JMPREL {
            _v = rela_plt_vaddr;
        } elif tag == DT_RELA {
            _v = rela_dyn_vaddr;
        } elif tag == DT_INIT_ARRAY {
            _v = init_arr_vaddr;
        }
        dynamic_data.extend(struct.pack("<qQ", tag, _v));
    }

    # ── .dynsym ───────────────────────────────────────────────────
    dynsym_data = bytearray();
    dynsym_data.extend(struct.pack("<IBBHQQ", 0, 0, 0, 0, 0, 0));
    for nm in exports {
        (seg, off) = local_sym_map[nm];
        va = _resolve_seg_vaddr(seg, off, text_vaddr, rodata_vaddr, data_vaddr);
        styp = STT_FUNC if seg == "code" else STT_OBJECT;
        st_info = (STB_GLOBAL << 4) | styp;
        # st_shndx points at the real defining section so `ld` accepts the
        # symbol; the loader still relocates st_value by the load bias.
        st_shndx = seg_shndx.get(seg, 1);
        dynsym_data.extend(
            struct.pack(
                "<IBBHQQ", dynstr_offsets.get(nm, 0), st_info, 0, st_shndx, va, 0
            )
        );
    }
    for nm in extern_func_syms {
        st_info = (STB_GLOBAL << 4) | STT_FUNC;
        dynsym_data.extend(
            struct.pack(
                "<IBBHQQ", dynstr_offsets.get(nm, 0), st_info, 0, SHN_UNDEF, 0, 0
            )
        );
    }
    for nm in extern_data_syms {
        st_info = (STB_GLOBAL << 4) | STT_OBJECT;
        dynsym_data.extend(
            struct.pack(
                "<IBBHQQ", dynstr_offsets.get(nm, 0), st_info, 0, SHN_UNDEF, 0, 0
            )
        );
    }

    # ── PLT + GOT.PLT + .rela.plt (extern functions) ──
    plt_data = bytearray();
    plt_data.extend(arch.build_plt0(got_plt_vaddr, plt_vaddr));
    for idx in range(len(extern_func_syms)) {
        entry_vaddr = plt_vaddr + plt0_size + idx * plt_entry_size;
        got_entry_vaddr = got_plt_vaddr + (3 + idx) * 8;
        plt_data.extend(
            arch.build_plt_entry(entry_vaddr, got_entry_vaddr, idx, plt_vaddr)
        );
    }
    got_plt_data = bytearray();
    got_plt_data.extend(struct.pack("<Q", dynamic_vaddr));
    got_plt_data.extend(struct.pack("<Q", 0));
    got_plt_data.extend(struct.pack("<Q", 0));
    for idx in range(len(extern_func_syms)) {
        lazy_addr = arch.get_lazy_bind_addr(plt_vaddr, plt0_size, idx, plt_entry_size);
        got_plt_data.extend(struct.pack("<Q", lazy_addr));
    }
    rela_plt_data = bytearray();
    for nm in extern_func_syms {
        r_offset = got_plt_vaddr + (3 + extern_func_syms.index(nm)) * 8;
        r_info = (dynsym_index[nm] << 32) | arch.jump_slot_rtype;
        rela_plt_data.extend(struct.pack("<QQq", r_offset, r_info, 0));
    }

    # ── .rela.dyn: RELATIVE (local GOT, init array, data pointers) +
    #    GLOB_DAT (extern data). Build the GOT/init blobs alongside. ──
    rela_dyn_data = bytearray();
    local_got_data = bytearray();
    for nm in local_got_syms {
        (seg, off) = local_sym_map[nm];
        va = _resolve_seg_vaddr(seg, off, text_vaddr, rodata_vaddr, data_vaddr);
        local_got_data.extend(struct.pack("<Q", va));
        rela_dyn_data.extend(
            struct.pack("<QQq", local_got_slot[nm], arch.relative_rtype, va)
        );
    }
    init_arr_data = bytearray();
    for nm in inits {
        (seg, off) = local_sym_map[nm];
        va = _resolve_seg_vaddr(seg, off, text_vaddr, rodata_vaddr, data_vaddr);
        slot_va = init_arr_vaddr + len(init_arr_data);
        init_arr_data.extend(struct.pack("<Q", va));
        rela_dyn_data.extend(struct.pack("<QQq", slot_va, arch.relative_rtype, va));
    }
    data_got_data = bytearray(b"\x00" * data_got_size);
    for nm in extern_data_syms {
        slot = extern_data_slot[nm];
        r_info = (dynsym_index[nm] << 32) | arch.glob_dat_rtype;
        rela_dyn_data.extend(struct.pack("<QQq", slot, r_info, 0));
    }
    # Absolute 64-bit pointers stored in writable data (vtables, function-pointer
    # tables, a global holding &other) → RELATIVE: the loader writes
    # (load_bias + target offset). The slot is not patched statically — a RELA
    # RELATIVE ignores the existing field and uses the addend.
    for (rela, tgt) in data_abs_relocs {
        _dsec = data_sections.get(rela.target_sec);
        if _dsec is None {
            continue;
        }
        slot_vaddr = data_vaddr + _dsec[0] + rela.offset;
        tva = _resolve_seg_vaddr(tgt[0], tgt[1], text_vaddr, rodata_vaddr, data_vaddr);
        rela_dyn_data.extend(
            struct.pack("<QQq", slot_vaddr, arch.relative_rtype, tva + rela.addend)
        );
    }

    # ── Apply non-RELATIVE relocations into the code/rodata/data blobs ──
    code_bytes = bytearray(code_data);
    rodata_bytes = bytearray(rodata_blob);
    data_bytes = bytearray(data_blob);
    extern_plt_addr: dict[str, int] = {};
    for plt_idx in range(len(extern_func_syms)) {
        extern_plt_addr[extern_func_syms[plt_idx]] = plt_vaddr + plt0_size + plt_idx * plt_entry_size;
    }

    for rela in self.relocations {
        # abs64 pointers in writable data are emitted as RELATIVE dynamic
        # relocations (loader adds the load bias); nothing to patch statically.
        if rela.rtype == arch.abs64_rtype and rela.target_sec in data_sections {
            continue;
        }
        site = _resolve_patch_site(
            rela.offset,
            rela.target_sec,
            code_sections,
            rodata_sections,
            data_sections,
            code_bytes,
            rodata_bytes,
            data_bytes,
            text_vaddr,
            rodata_vaddr,
            data_vaddr
        );
        if site is None {
            continue;
        }
        (patch_buf, patch_off, patch_vaddr) = site;
        sym_addr = 0;
        if rela.rtype in arch.gotpcrel_rtypes {
            # GOT-directed: resolve to the GOT slot holding the target address.
            if rela.sym_name in extern_data_slot {
                sym_addr = extern_data_slot[rela.sym_name];
            } elif rela.sym_name in extern_plt_addr {
                func_idx = extern_func_syms.index(rela.sym_name);
                sym_addr = got_plt_vaddr + (3 + func_idx) * 8;
            } elif rela.sym_name in local_got_slot {
                sym_addr = local_got_slot[rela.sym_name];
            } else {
                sym_addr = 0;
            }
        } elif rela.sym_name in extern_plt_addr {
            sym_addr = extern_plt_addr[rela.sym_name];
        } else {
            local = local_sym_map.get(rela.sym_name) if rela.sym_name else None;
            if local is None {
                local = sym_idx_placement.get(rela.sym_idx);
            }
            if local is not None {
                sym_addr = _resolve_seg_vaddr(
                    local[0], local[1], text_vaddr, rodata_vaddr, data_vaddr
                );
            } elif rela.rtype == arch.abs64_rtype {
                # An absolute pointer into a non-writable section referencing an
                # unresolved symbol cannot be fixed up at load: refuse rather
                # than emit a binary that faults during relocation.
                raise ValueError(
                    f"ELF shared linker: unrelocatable absolute reference to "
                    f"'{rela.sym_name}' in section '{rela.target_sec}'."
                );
            }
        }
        applied = arch.apply_reloc(
            rela.rtype, patch_buf, patch_off, sym_addr, rela.addend, patch_vaddr
        );
        if not applied {
            raise ValueError(
                f"ELF shared linker: no handler for relocation type {rela.rtype} "
                f"(symbol '{rela.sym_name}', section '{rela.target_sec}', "
                f"e_machine {arch.e_machine})."
            );
        }
    }

    # ── Assemble the ELF image ────────────────────────────────────
    output = bytearray(total_file_size);
    ident = bytearray(16);
    ident[0:4] = ELFMAG;
    ident[4] = ELFCLASS64;
    ident[5] = ELFDATA2LSB;
    ident[6] = 1;
    ident[7] = 0;
    struct.pack_into("16s", output, 0, bytes(ident));
    struct.pack_into(
        "<HHIQQQIHHHHHH",
        output,
        16,
        ET_DYN,
        arch.e_machine,
        1,
        0,  # e_entry: a library has no entry point
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
        dynamic_size,
        dynamic_size,
        8
    );

    # ── Write all the pieces ──
    output[hash_foff:hash_foff + len(hash_data)] = hash_data;
    output[dynsym_foff:dynsym_foff + len(dynsym_data)] = bytes(dynsym_data);
    output[dynstr_foff:dynstr_foff + len(dynstr_data)] = dynstr_data;
    if len(rela_plt_data) > 0 {
        output[rela_plt_foff:rela_plt_foff + len(rela_plt_data)] = bytes(rela_plt_data);
    }
    if len(rela_dyn_data) > 0 {
        output[rela_dyn_foff:rela_dyn_foff + len(rela_dyn_data)] = bytes(rela_dyn_data);
    }
    if len(plt_data) > 0 {
        output[plt_foff:plt_foff + len(plt_data)] = bytes(plt_data);
    }
    output[text_foff:text_foff + len(code_bytes)] = bytes(code_bytes);
    if len(rodata_bytes) > 0 {
        output[rodata_foff:rodata_foff + len(rodata_bytes)] = bytes(rodata_bytes);
    }
    output[got_plt_foff:got_plt_foff + len(got_plt_data)] = bytes(got_plt_data);
    if data_got_size > 0 {
        output[data_got_foff:data_got_foff + data_got_size] = bytes(data_got_data);
    }
    if local_got_size > 0 {
        output[local_got_foff:local_got_foff + len(local_got_data)] = bytes(
            local_got_data
        );
    }
    if init_arr_size > 0 {
        output[init_arr_foff:init_arr_foff + len(init_arr_data)] = bytes(init_arr_data);
    }
    output[dynamic_foff:dynamic_foff + len(dynamic_data)] = bytes(dynamic_data);
    if len(data_bytes) > 0 {
        output[data_foff:data_foff + len(data_bytes)] = bytes(data_bytes);
    }

    # ── Append .shstrtab + the section header table (non-loaded tail) ──
    sh_names: list[str] = [];
    for _spec in sh_specs {
        sh_names.append(_spec[0]);
    }
    (shstrtab_data, shstrtab_name_off) = _build_strtab(sh_names);
    shstrtab_foff = len(output);
    output.extend(shstrtab_data);
    shoff = _align(len(output), 8);
    output.extend(b"\x00" * (shoff - len(output)));
    for _spec in sh_specs {
        (snm, styp, sflags, saddr, soff, ssize, slink_name, sinfo, salign, sentsize) = _spec;
        if snm == ".shstrtab" {
            soff = shstrtab_foff;
            ssize = len(shstrtab_data);
        }
        slink = sh_name_to_idx.get(slink_name, 0) if slink_name else 0;
        output.extend(
            struct.pack(
                "<IIQQQQIIQQ",
                shstrtab_name_off.get(snm, 0),
                styp,
                sflags,
                saddr,
                soff,
                ssize,
                slink,
                sinfo,
                salign,
                sentsize
            )
        );
    }
    # Patch the ELF header's section-header fields now that the table exists.
    struct.pack_into("<Q", output, 40, shoff);  # e_shoff
    struct.pack_into("<H", output, 58, 64);  # e_shentsize
    struct.pack_into("<H", output, 60, len(sh_specs));  # e_shnum
    struct.pack_into(
        "<H", output, 62, sh_name_to_idx.get(".shstrtab", 0)
    );  # e_shstrndx

    for (sname, place) in local_sym_map.items() {
        va = _resolve_seg_vaddr(
            place[0], place[1], text_vaddr, rodata_vaddr, data_vaddr
        );
        if sname {
            self.sym_vaddrs[sname] = va;
        }
    }
    return bytes(output);
}


# ── Merge a CRT object file's sections/symbols/relocs into self ──
"""Parse a CRT object and merge its sections, symbols, and relocations
into the linker's existing parsed state.

When a CRT section has the same name as an existing section (e.g. .text),
the CRT data is appended to the existing section. Symbol values and
relocation offsets are adjusted by the merge offset.
"""
def _merge_crt_object(linker: ElfLinker, crt_bytes: bytes) -> bool {
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
    crt_objects: list[bytes] = [],
    shared: bool = False,
    export_symbols: list[str] = [],
    init_funcs: list[str] = [],
    soname: str = "",
    archive_members: list[bytes] = []
) -> bool {
    linker = ElfLinker(
        obj_data=obj_bytes,
        sections=[],
        symbols=[],
        relocations=[],
        needed_libs=needed_libs,
        shared=shared,
        export_symbols=export_symbols,
        init_funcs=init_funcs,
        soname=soname
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

    # Merge selected static-archive members (#6978 Phase 0.1a). An ar member is
    # just a relocatable object, so it folds in through the same path as a CRT
    # object: _merge_crt_object upgrades a currently-undefined symbol to its
    # in-member definition in place, so a member symbol referenced by the main
    # object (or an earlier member) resolves locally instead of being emitted as
    # a libc.so dynamic import. This is why ELF needs no separate crossref pass
    # like Mach-O's _resolve_crossrefs -- build_executable only imports symbols
    # still left at SHN_UNDEF after all merges.
    for member in archive_members {
        if not _merge_crt_object(linker, member) {
            return False;
        }
    }

    exe_bytes = linker.build_shared_object() if shared else linker.build_executable();
    if not exe_bytes {
        return False;
    }
    with open(output_path, "wb") as f {
        f.write(exe_bytes);
    }
    os.chmod(output_path, 0o755);

    # Write a <binary>.symmap alongside the binary when JAC_SYMMAP=1 so that
    # profiling post-processors (e.g. scripts/cg-annotate) can map raw
    # callgrind addresses to real function names.
    if os.environ.get("JAC_SYMMAP", "") {
        symmap_path = output_path + ".symmap";
        with open(symmap_path, "w") as smf {
            for (sname, va) in sorted(
                linker.sym_vaddrs.items(), key=lambda kv : kv[1]
            ) {
                smf.write(f"{sname} 0x{va:016x}\n");
            }
        }
    }

    return True;
}
