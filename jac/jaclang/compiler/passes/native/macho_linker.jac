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
        soname: str = "";

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

    def _resolve_crossrefs -> None;
    def build_executable -> bytes;
    def build_shared_object -> bytes;
}
