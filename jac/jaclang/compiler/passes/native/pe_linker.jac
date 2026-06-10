"""Pure Python PE/COFF linker for native Jac compilation on Windows.

Takes raw object code bytes from llvmlite's emit_object() (a relocatable
COFF object for a `*-pc-windows-*` triple) and produces a runnable PE32+
executable using only Python's struct module. No external linker
(link.exe, lld-link, ld) required.

Mirrors the structure of the ELF and Mach-O linkers: parse the relocatable
object, lay out loadable segments at a fixed ImageBase (no ASLR / .reloc),
build the PE import directory so DLL imports resolve at load, apply
relocations, and inject the entry point.

Architecture support: x86_64 (dynamic-link against msvcrt.dll by default).
"""

"""Parsed COFF section."""
obj CoffSection {
    has name: str,
        characteristics: int,
        data: bytes,
        vsize: int;
}

"""Parsed COFF relocation (REL-style: implicit addend lives in the field)."""
obj CoffReloc {
    has offset: int,
        sym_idx: int,
        rtype: int,
        target_sec: int;
}

"""Parsed COFF symbol.

`weak_tag` is the symbol-table index of the default symbol for a weak
external (-1 when not weak); after parsing, a weak external's `sec_num`
and `value` are copied from its default so it resolves like a normal
defined symbol rather than being mistaken for a DLL import.
"""
obj CoffSymbol {
    has name: str,
        value: int,
        sec_num: int,
        storage_class: int,
        weak_tag: int = -1;
}

"""Main PE/COFF linker class.

Parses a relocatable COFF .o and produces a dynamically-linked PE32+
executable. Architecture is auto-detected from the object's Machine field.
"""
obj PeLinker {
    has obj_data: bytes,
        # Indexed by raw COFF symbol index; auxiliary records are None so
        # relocation symbol indices line up with this list.
        symbols: list[CoffSymbol | None],
        sections: list[CoffSection],
        relocations: list[CoffReloc],
        # The DLL undefined externals bind to when not named explicitly in
        # symbol_lib_map. First entry of needed_libs, or "msvcrt.dll".
        needed_libs: list[str],
        # Maps an undefined symbol's C name to the DLL that exports it, e.g.
        # "InitWindow" -> "raylib.dll". Drives per-DLL import descriptor
        # grouping; symbols absent from the map bind to the default DLL.
        symbol_lib_map: dict[str, str] = {},
        # Shared-object (.dll) build state. When `shared` is True, link() calls
        # build_shared_object(): an IMAGE_FILE_DLL with an export directory for
        # the `:pub` symbols, a .reloc base-relocation table (so the loader may
        # rebase it), and a DllMain that runs the init functions on attach.
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
