"""Minimal ELF64 section reader for the .jac_bridge metadata blob."""

import struct

_NAMES = (".jac_bridge", "__jac_bridge", ".jacbrdg")


def read_jac_bridge_section(path: str) -> bytes:
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] == b"\x7fELF":
        return _from_elf(data, path)
    raise ValueError(f"{path!r}: only ELF binaries are supported on this platform")


def _from_elf(data: bytes, path: str) -> bytes:
    ei_class = data[4]
    ei_data = data[5]
    if ei_class != 2:
        raise ValueError(f"{path}: only ELF64 supported (class={ei_class})")
    e = "<" if ei_data == 1 else ">"

    e_shoff = struct.unpack_from(f"{e}Q", data, 40)[0]
    e_shentsize = struct.unpack_from(f"{e}H", data, 58)[0]
    e_shnum = struct.unpack_from(f"{e}H", data, 60)[0]
    e_shstrndx = struct.unpack_from(f"{e}H", data, 62)[0]

    shstr_sh = e_shoff + e_shstrndx * e_shentsize
    shstr_off = struct.unpack_from(f"{e}Q", data, shstr_sh + 24)[0]
    shstr_size = struct.unpack_from(f"{e}Q", data, shstr_sh + 32)[0]
    strtab = data[shstr_off : shstr_off + shstr_size]

    for i in range(e_shnum):
        sh = e_shoff + i * e_shentsize
        noff = struct.unpack_from(f"{e}I", data, sh)[0]
        nend = strtab.index(b"\x00", noff)
        name = strtab[noff:nend].decode("ascii", errors="replace")
        if name in _NAMES:
            off = struct.unpack_from(f"{e}Q", data, sh + 24)[0]
            size = struct.unpack_from(f"{e}Q", data, sh + 32)[0]
            return data[off : off + size]

    raise ValueError(f"{path}: no .jac_bridge section found (searched {_NAMES})")
