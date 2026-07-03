"""Parse the D2 binary metadata blob produced by jac-bridge crates.

Ported verbatim from the CPython-side loader (bridges/jac-bridge-loader); the
na compiler step and the CPython meta-importer share one parser (D1: "the na
compiler and the importer use the same code").
"""

import struct
from dataclasses import dataclass, field

MAGIC = b"JACBRDG1"
TAG_VOID = 0xFFFF_FFFF
TAG_BOOL = 1
TAG_STR = 4
TAG_REF_BIT = 0x8000_0000
KIND_OPAQUE = 0
KIND_ERROR = 3
FN_CTOR = 0
FN_METHOD = 1


@dataclass
class ParamDesc:
    name: str
    tag: int


@dataclass
class FnDesc:
    index: int
    name: str
    sym: str
    self_type: int  # TAG_VOID=none, else type index
    kind: int  # 0=ctor 1=method
    throws: int  # TAG_VOID=none, else type index
    ret: int  # type tag
    params: list["ParamDesc"] = field(default_factory=list)


@dataclass
class TypeDesc:
    index: int
    kind: int  # 0=opaque 3=error
    name: str
    drop_sym: str


@dataclass
class BridgeMeta:
    abi_version: int
    module_name: str
    types: list[TypeDesc] = field(default_factory=list)
    fns: list[FnDesc] = field(default_factory=list)


def parse(blob: bytes | bytearray) -> BridgeMeta:
    if len(blob) < 56:
        raise ValueError(f"D2 blob too short ({len(blob)} B; need 56)")
    if blob[:8] != MAGIC:
        raise ValueError(f"bad magic {blob[:8]!r}")

    def u32(off: int) -> int:
        return struct.unpack_from("<I", blob, off)[0]

    def u8(off: int) -> int:
        return blob[off]

    def sref(off: int) -> str:
        a, n = u32(off), u32(off + 4)
        return blob[a : a + n].decode("utf-8")

    abi = u32(8)
    mod = sref(24)
    t_off, t_cnt = u32(40), u32(44)
    f_off, f_cnt = u32(48), u32(52)

    types: list[TypeDesc] = []
    off = t_off
    for i in range(t_cnt):
        dsz = u32(off)
        kind = u8(off + 4)
        name = sref(off + 8)
        drop = sref(off + 16)
        types.append(TypeDesc(i, kind, name, drop))
        off += dsz

    fns: list[FnDesc] = []
    off = f_off
    for i in range(f_cnt):
        dsz = u32(off)
        fname = sref(off + 4)
        sym = sref(off + 12)
        self_type = u32(off + 20)
        kind = u8(off + 24)
        throws = u32(off + 28)
        ret = u32(off + 32)
        p_off = u32(off + 36)
        p_cnt = u32(off + 40)
        params = []
        poff = p_off
        for _ in range(p_cnt):
            pname = sref(poff)
            ptag = u32(poff + 8)
            params.append(ParamDesc(pname, ptag))
            poff += 12
        fns.append(FnDesc(i, fname, sym, self_type, kind, throws, ret, params))
        off += dsz

    return BridgeMeta(abi, mod, types, fns)
