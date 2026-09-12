import struct;
import os;
import from jaclang.cli.console { console }
import from jaclang.compiler.backends.native.linker_common {
    _align,
    _build_strtab,
    _append_to_blob,
    _resolve_seg_vaddr,
    _resolve_patch_site,
    _find_entry_vaddr
}

obj ElfSection {
    has name: str,
        typ: int,
        flags: int,
        addr: int,
        data: bytes,
        mem_size: int,
        align: int,
        link: int,
        info: int,
        entsize: int;
}

obj ElfRela {
    has offset: int,
        sym_idx: int,
        rtype: int,
        addend: int,
        sym_name: str,
        target_sec: str;
}

obj ElfSymbol {
    has name: str,
        value: int,
        size: int,
        bind: int,
        typ: int,
        shndx: int;
}

obj ArchConfig {
    has e_machine: int,
        base_vaddr: int,
        page_size: int,
        interp_paths: list[str],
        plt0_size: int,
        plt_entry_size: int,
        jump_slot_rtype: int,
        copy_rtype: int,
        glob_dat_rtype: int,
        gotpcrel_rtypes: set[int],
        relative_rtype: int,
        abs64_rtype: int;

    def build_plt0(got_plt_vaddr: int, plt_vaddr: int) -> bytes;
    def build_plt_entry(
        entry_vaddr: int, got_entry_vaddr: int, idx: int, plt_vaddr: int
    ) -> bytes;

    def apply_reloc(
        rtype: int,
        patch_buf: bytearray,
        patch_off: int,
        sym_addr: int,
        addend: int,
        patch_vaddr: int
    ) -> bool;

    def get_lazy_bind_addr(
        plt_vaddr: int, plt0_size: int, idx: int, plt_entry_size: int
    ) -> int;

    static def from_e_machine(e_machine: int) -> (ArchConfig | None);
}

obj ElfLinker {
    has obj_data: bytes,
        sections: list[ElfSection],
        symbols: list[ElfSymbol],
        relocations: list[ElfRela],
        needed_libs: list[str],
        arch: (ArchConfig | None) = None,
        sym_vaddrs: dict[str, int] = {},
        shared: bool = False,
        export_symbols: list[str] = [],
        init_funcs: list[str] = [],
        soname: str = "";

    static def link(
        obj_bytes: bytes,
        output_path: str,
        needed_libs: list[str] = [],
        crt_objects: list[bytes] = [],
        shared: bool = False,
        export_symbols: list[str] = [],
        init_funcs: list[str] = [],
        soname: str = "",
        archive_members: list[bytes] = [],
        static_link: bool = False
    ) -> bool;

    def parse_object -> bool;
    def _undefined_bindings -> dict[str, int];
    def build_executable -> bytes;
    def build_static_executable -> bytes;
    def build_shared_object -> bytes;
}

glob ELFMAG = b"\x7fELF",
     ELFCLASS64 = 2,
     ELFDATA2LSB = 1,
     ET_EXEC = 2;

glob EM_X86_64 = 62,
     EM_AARCH64 = 183;

glob SHT_NULL = 0,
     SHT_PROGBITS = 1,
     SHT_SYMTAB = 2,
     SHT_STRTAB = 3,
     SHT_RELA = 4,
     SHT_HASH = 5,
     SHT_DYNAMIC = 6,
     SHT_NOBITS = 8,
     SHT_DYNSYM = 11,
     SHT_INIT_ARRAY = 14;

glob SHF_WRITE = 0x1,
     SHF_ALLOC = 0x2,
     SHF_EXECINSTR = 0x4;

glob PT_NULL = 0,
     PT_LOAD = 1,
     PT_DYNAMIC = 2,
     PT_INTERP = 3,
     PT_PHDR = 6,
     PT_GNU_STACK = 0x6474e551;

glob PF_X = 0x1,
     PF_W = 0x2,
     PF_R = 0x4;

glob DT_NULL = 0,
     DT_NEEDED = 1,
     DT_HASH = 4,
     DT_STRTAB = 5,
     DT_SYMTAB = 6,
     DT_STRSZ = 10,
     DT_SYMENT = 11,
     DT_DEBUG = 21,
     DT_BIND_NOW = 24,
     DT_PLTGOT = 3,
     DT_PLTRELSZ = 2,
     DT_PLTREL = 20,
     DT_JMPREL = 23,
     DT_RELA = 7,
     DT_RELASZ = 8,
     DT_RELAENT = 9,
     DT_RUNPATH = 29,
     DT_SONAME = 14,
     DT_INIT_ARRAY = 25,
     DT_INIT_ARRAYSZ = 27;

glob ET_DYN = 3;

glob STB_LOCAL = 0,
     STB_GLOBAL = 1,
     STB_WEAK = 2,
     STT_NOTYPE = 0,
     STT_OBJECT = 1,
     STT_FUNC = 2,
     SHN_UNDEF = 0,
     SHN_COMMON = 0xfff2;

glob R_X86_64_64 = 1,
     R_X86_64_PC32 = 2,
     R_X86_64_PLT32 = 4,
     R_X86_64_COPY = 5,
     R_X86_64_GLOB_DAT = 6,
     R_X86_64_JUMP_SLOT = 7,
     R_X86_64_RELATIVE = 8,
     R_X86_64_GOTPCREL = 9,
     R_X86_64_32 = 10,
     R_X86_64_32S = 11,
     R_X86_64_TPOFF32 = 23,
     R_X86_64_REX_GOTPCRELX = 42;

glob R_AARCH64_PREL32 = 261,
     R_AARCH64_LD_PREL_LO19 = 273,
     R_AARCH64_ADR_PREL_LO21 = 274,
     R_AARCH64_ADR_PREL_PG_HI21 = 275,
     R_AARCH64_ADR_PREL_PG_HI21_NC = 276,
     R_AARCH64_TSTBR14 = 279,
     R_AARCH64_CONDBR19 = 280,
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
     R_AARCH64_MOVW_UABS_G0 = 263,
     R_AARCH64_MOVW_UABS_G0_NC = 264,
     R_AARCH64_MOVW_UABS_G1 = 265,
     R_AARCH64_MOVW_UABS_G1_NC = 266,
     R_AARCH64_MOVW_UABS_G2 = 267,
     R_AARCH64_MOVW_UABS_G2_NC = 268,
     R_AARCH64_MOVW_UABS_G3 = 269,
     R_AARCH64_ABS32 = 258,
     R_AARCH64_RELATIVE = 1027,
     R_AARCH64_TLSLE_ADD_TPREL_HI12 = 549,
     R_AARCH64_TLSLE_ADD_TPREL_LO12 = 550,
     R_AARCH64_TLSLE_ADD_TPREL_LO12_NC = 551;
