"""Pure Python Mach-O linker for native Jac compilation on macOS.

Takes raw object code bytes from llvmlite's emit_object() and produces
a runnable Mach-O executable using only Python's struct and hashlib modules.
No external linker (ld, cc) required.

Supports Mach-O 64-bit with dynamic linking against libSystem.
Architecture support: arm64, x86_64.
"""

"""Parsed Mach-O section."""
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

"""Parsed Mach-O relocation."""
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

"""Parsed Mach-O symbol (nlist_64)."""
obj MachOSymbol {
    has name: str,
        n_type: int,
        n_sect: int,
        n_desc: int,
        n_value: int;
}

"""Main Mach-O linker class.

Parses a Mach-O .o file and produces a dynamically-linked Mach-O executable.
Architecture is auto-detected from the object file's cputype field.
"""
obj MachOLinker {
    has obj_data: bytes,
        sections: list[MachOSection],
        symbols: list[MachOSymbol],
        relocations: list[MachOReloc],
        needed_libs: list[str],
        cpu_type: int = 0,
        cpu_subtype: int = 0,
        # Maps an undefined symbol's C name (no leading underscore) to the
        # `needed_libs` entry that exports it, e.g. "InitWindow" ->
        # "libraylib.dylib". Drives the per-symbol dylib ordinal emitted in the
        # two-level-namespace bind table; symbols absent from the map bind to
        # libSystem (ordinal 1), which covers all compiler-emitted libc calls.
        symbol_lib_map: dict[str, str] = {},
        # Shared-object (.dylib) build state. When `shared` is True, link() calls
        # build_shared_object(): an MH_DYLIB with base vmaddr 0, no __PAGEZERO,
        # an export trie listing the `:pub` symbols, a __mod_init_func vector of
        # init functions run on load, and LC_ID_DYLIB instead of LC_MAIN.
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
        soname: str = ""
    ) -> bool;

    def parse_object -> bool;
    def build_executable -> bytes;
    def build_shared_object -> bytes;
}
