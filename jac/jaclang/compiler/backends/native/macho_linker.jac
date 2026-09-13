import struct;
import os;
import hashlib;
import from jaclang.compiler.backends.native.linker_common {
    encode_uleb128,
    _align,
    _build_strtab,
    _append_to_blob,
    _resolve_seg_vaddr,
    _resolve_patch_site,
    _find_entry_vaddr
}

obj MachOSection {
    has name: str,
        segname: str,
        addr: int,
        size: int,
        data: bytes,
        align: int,
        flags: int,
        reserved1: int,
        reserved2: int;
}

obj MachOReloc {
    has address: int,
        symbolnum: int,
        pcrel: int,
        length: int,
        extern: int,
        rtype: int,
        target_sec: str,
        addend: int;
}

obj MachOSymbol {
    has name: str,
        n_type: int,
        n_sect: int,
        n_desc: int,
        n_value: int;
}

obj MachOLinker {
    has obj_data: bytes,
        sections: list[MachOSection],
        symbols: list[MachOSymbol],
        relocations: list[MachOReloc],
        needed_libs: list[str],
        cpu_type: int = 0,
        cpu_subtype: int = 0,
        symbol_lib_map: dict[str, str] = {},
        shared: bool = False,
        export_symbols: list[str] = [],
        init_funcs: list[str] = [],
        soname: str = "",
        _commons: dict[str, tuple[(int, int)]] = {};

    static def link(
        obj_bytes: bytes,
        output_path: str,
        needed_libs: list[str] = ["/usr/lib/libSystem.B.dylib"],
        symbol_lib_map: dict[str, str] = {},
        shared: bool = False,
        export_symbols: list[str] = [],
        init_funcs: list[str] = [],
        soname: str = "",
        archive_members: list[bytes] = []
    ) -> bool;

    def parse_object -> bool;
    def _merge_member(raw: bytes) -> bool;
    def _consolidate(
        secs: list[MachOSection], syms: list[MachOSymbol], relocs: list[MachOReloc]
    ) -> None;

    def _allocate_commons -> None;
    def _resolve_crossrefs -> None;
    def build_executable -> bytes;
    def build_shared_object -> bytes;
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
     BIND_OPCODE_SET_DYLIB_SPECIAL_IMM = 0x30,
     BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM = 0x40,
     BIND_OPCODE_SET_TYPE_IMM = 0x50,
     BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB = 0x70,
     BIND_OPCODE_DO_BIND = 0x90,
     BIND_TYPE_POINTER = 1,
     BIND_SPECIAL_FLAT_LOOKUP_IMM = 0x0E,
     PROCESS_LOOKUP_LIB = "@process";

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

glob ARM64_STUB_SIZE = 12;

glob X86_64_STUB_SIZE = 6;
