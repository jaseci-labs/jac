"""Pure Python ELF linker for native Jac compilation.

Takes raw object code bytes from llvmlite's emit_object() and produces
a runnable ELF executable using only Python's struct module. No external
linker (ld, cc) required.

Supports ELF64 with dynamic linking against libc.
Architecture support: x86_64, aarch64.
"""

import from typing { Any }

"""Parsed ELF section."""
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

"""Parsed ELF relocation."""
obj ElfRela {
    has offset: int,
        sym_idx: int,
        rtype: int,
        addend: int,
        sym_name: str,
        target_sec: str;
}

"""Parsed ELF symbol."""
obj ElfSymbol {
    has name: str,
        value: int,
        size: int,
        bind: int,
        typ: int,
        shndx: int;
}

"""Architecture-specific ELF configuration.

Each supported architecture provides an ArchConfig that encapsulates
all ISA-specific details: relocation handling, PLT stub generation,
ELF constants, and interpreter paths.
"""
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
        gotpcrel_rtypes: set[int];

    """Generate PLT[0] stub bytes (resolver trampoline)."""
    def build_plt0(got_plt_vaddr: int, plt_vaddr: int) -> bytes;

    """Generate a single PLT[n] entry for an external function."""
    def build_plt_entry(
        entry_vaddr: int, got_entry_vaddr: int, idx: int, plt_vaddr: int
    ) -> bytes;

    """Apply a relocation to the given buffer. Returns True if handled."""
    def apply_reloc(
        rtype: int,
        patch_buf: bytearray,
        patch_off: int,
        sym_addr: int,
        addend: int,
        patch_vaddr: int
    ) -> bool;

    """Get the initial GOT.PLT entry address for lazy binding of PLT[idx]."""
    def get_lazy_bind_addr(
        plt_vaddr: int, plt0_size: int, idx: int, plt_entry_size: int
    ) -> int;

    """Create an ArchConfig for the given ELF e_machine value, or None if unsupported."""
    static def from_e_machine(e_machine: int) -> (ArchConfig | None);
}

"""Main ELF linker class.

Parses a .o file and produces a dynamically-linked ELF executable.
Architecture is auto-detected from the object file's e_machine field.
"""
obj ElfLinker {
    has obj_data: bytes,
        sections: list[ElfSection],
        symbols: list[ElfSymbol],
        relocations: list[ElfRela],
        needed_libs: list[str],
        arch: (ArchConfig | None) = None;

    """Parse a relocatable ELF object and link into an executable."""
    static def link(
        obj_bytes: bytes,
        output_path: str,
        needed_libs: list[str] = ["libc.so.6"],
        crt_objects: list[bytes] = []
    ) -> bool;

    """Parse the ELF relocatable object file."""
    def parse_object -> bool;

    """Build the final ELF executable bytes."""
    def build_executable -> bytes;
}
