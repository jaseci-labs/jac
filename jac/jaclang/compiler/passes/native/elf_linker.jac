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
    def build_executable -> bytes;
    def build_static_executable -> bytes;
    def build_shared_object -> bytes;
}
