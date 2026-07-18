obj CoffSection {
    has name: str,
        characteristics: int,
        data: bytes,
        vsize: int;
}

obj CoffReloc {
    has offset: int,
        sym_idx: int,
        rtype: int,
        target_sec: int;
}

obj CoffSymbol {
    has name: str,
        value: int,
        sec_num: int,
        storage_class: int,
        weak_tag: int = -1;
}

obj PeLinker {
    has obj_data: bytes,
        symbols: list[CoffSymbol | None],
        sections: list[CoffSection],
        relocations: list[CoffReloc],
        needed_libs: list[str],
        symbol_lib_map: dict[str, str] = {},
        shared: bool = False,
        export_symbols: list[str] = [],
        init_funcs: list[str] = [],
        soname: str = "";

    static def link(
        obj_bytes: bytes,
        output_path: str,
        needed_libs: list[str] = ["msvcrt.dll"],
        symbol_lib_map: dict[str, str] = {},
        shared: bool = False,
        export_symbols: list[str] = [],
        init_funcs: list[str] = [],
        soname: str = ""
    ) -> bool;

    def parse_object -> bool;
    def build_executable -> bytes;
    def build_shared_object -> bytes;
}
