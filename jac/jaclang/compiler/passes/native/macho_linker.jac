"""Pure Python Mach-O linker for native Jac compilation on macOS.

Takes raw object code bytes from llvmlite's emit_object() and produces
a runnable Mach-O executable using only Python's struct and hashlib modules.
No external linker (ld, cc) required.

Supports Mach-O 64-bit with dynamic linking against libSystem.
Architecture support: arm64, x86_64.
"""

import from typing { Any }

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
        cpu_subtype: int = 0;

    """Parse a relocatable Mach-O object and link into an executable."""
    static def link(
        obj_bytes: bytes,
        output_path: str,
        needed_libs: list[str] = ["/usr/lib/libSystem.B.dylib"]
    ) -> bool;

    """Parse the Mach-O relocatable object file."""
    def parse_object -> bool;

    """Build the final Mach-O executable bytes."""
    def build_executable -> bytes;
}
