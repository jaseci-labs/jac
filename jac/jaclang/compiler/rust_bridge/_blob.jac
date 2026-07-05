import struct;

glob MAGIC = b"JACBRDG1",
     SUPPORTED_ABI = 1,
     TAG_VOID = 0xFFFFFFFF,
     TAG_BOOL = 1,
     TAG_INT = 2,
     TAG_UINT = 3,
     TAG_STR = 4,
     TAG_FN = 5,
     TAG_REF_BIT = 0x80000000,
     TAG_OPT_BIT = 0x40000000,
     TAG_MAP_BIT = 0x20000000,
     TAG_LIST_BIT = 0x10000000,
     KIND_OPAQUE = 0,
     KIND_ERROR = 3,
     FN_CTOR = 0,
     FN_METHOD = 1;


def tag_base(tag: int) -> int {
    return tag & ~TAG_OPT_BIT;
}


def tag_is_opt(tag: int) -> bool {
    return bool(tag & TAG_OPT_BIT);
}


def tag_is_ref(tag: int) -> bool {
    base = tag_base(tag);
    return bool(base & TAG_REF_BIT) and base != TAG_VOID;
}


def tag_ref_index(tag: int) -> int {
    return tag_base(tag) & ~TAG_REF_BIT;
}


def tag_is_map(tag: int) -> bool {
    return bool(tag & TAG_MAP_BIT);
}


def tag_map_value(tag: int) -> int {
    return tag & ~TAG_MAP_BIT;
}


def tag_is_list(tag: int) -> bool {
    return bool(tag & TAG_LIST_BIT);
}


def tag_list_value(tag: int) -> int {
    return tag & ~TAG_LIST_BIT;
}


class ParamDesc {
    def init(self: ParamDesc, name: str, tag: int) {
        self.name = name;
        self.tag = tag;
    }
}


class FnDesc {
    def init(
        self: FnDesc,
        index: int,
        name: str,
        sym: str,
        self_type: int,
        kind: int,
        throws: int,
        ret: int,
        params: list[ParamDesc] | None = None
    ) {
        self.index = index;
        self.name = name;
        self.sym = sym;
        self.self_type = self_type;
        self.kind = kind;
        self.throws = throws;
        self.ret = ret;
        self.params = params if params is not None else [];
    }
}


class TypeDesc {
    def init(self: TypeDesc, index: int, kind: int, name: str, drop_sym: str) {
        self.index = index;
        self.kind = kind;
        self.name = name;
        self.drop_sym = drop_sym;
    }
}


class BridgeMeta {
    def init(
        self: BridgeMeta,
        abi_version: int,
        module_name: str,
        types: list[TypeDesc] | None = None,
        fns: list[FnDesc] | None = None
    ) {
        self.abi_version = abi_version;
        self.module_name = module_name;
        self.types = types if types is not None else [];
        self.fns = fns if fns is not None else [];
    }
}


def parse(blob: bytes) -> BridgeMeta {
    if len(blob) < 56 {
        raise ValueError(f"D2 blob too short ({len(blob)} B; need 56)");
    }
    if blob[:8] != MAGIC {
        raise ValueError(f"bad magic {blob[:8]!r}");
    }

    def u32(off: int) -> int {
        return struct.unpack_from("<I", blob, off)[0];
    }

    def u8(off: int) -> int {
        return blob[off];
    }

    abi = u32(8);
    if abi != SUPPORTED_ABI {
        raise ValueError(f"unsupported ABI version {abi} (expected {SUPPORTED_ABI})");
    }

    blob_len = u32(16);
    if len(blob) < blob_len {
        raise ValueError(f"blob truncated: have {len(blob)} B, header says {blob_len}");
    }

    def sref(off: int) -> str {
        a = u32(off);
        n = u32(off + 4);
        if a + n > blob_len {
            raise ValueError(
                f"string ref [{a}:{a + n}] out of bounds (blob_len={blob_len})"
            );
        }
        return blob[a:a + n].decode("utf-8");
    }

    mod = sref(24);
    t_off = u32(40);
    t_cnt = u32(44);
    f_off = u32(48);
    f_cnt = u32(52);

    if t_off < 56 or t_off > blob_len {
        raise ValueError(f"type section offset {t_off} out of range");
    }
    if f_off > blob_len {
        raise ValueError(f"function section offset {f_off} out of range");
    }

    types = [];
    off = t_off;
    for i in range(t_cnt) {
        if off + 4 > blob_len {
            raise ValueError(f"TypeDesc[{i}] descriptor truncated at {off}");
        }
        dsz = u32(off);
        if dsz < 24 or off + dsz > blob_len {
            raise ValueError(f"TypeDesc[{i}] invalid descriptor size {dsz} at {off}");
        }
        kind = u8(off + 4);
        name = sref(off + 8);
        drop = sref(off + 16);
        types.append(TypeDesc(index=i, kind=kind, name=name, drop_sym=drop));
        off = off + dsz;
    }

    fns = [];
    off = f_off;
    for i in range(f_cnt) {
        if off + 4 > blob_len {
            raise ValueError(f"FnDesc[{i}] descriptor truncated at {off}");
        }
        dsz = u32(off);
        if dsz < 44 or off + dsz > blob_len {
            raise ValueError(f"FnDesc[{i}] invalid descriptor size {dsz} at {off}");
        }
        fname = sref(off + 4);
        sym = sref(off + 12);
        self_type = u32(off + 20);
        kind = u8(off + 24);
        throws = u32(off + 28);
        ret = u32(off + 32);
        p_off = u32(off + 36);
        p_cnt = u32(off + 40);
        if p_cnt > 0 and (p_off < 56 or p_off + p_cnt * 12 > blob_len) {
            raise ValueError(
                f"FnDesc[{i}] param section [{p_off}:{p_off + p_cnt * 12}] " + f"out of bounds (blob_len={blob_len})"
            );
        }
        params = [];
        poff = p_off;
        for _ in range(p_cnt) {
            pname = sref(poff);
            ptag = u32(poff + 8);
            params.append(ParamDesc(name=pname, tag=ptag));
            poff = poff + 12;
        }
        fns.append(
            FnDesc(
                index=i,
                name=fname,
                sym=sym,
                self_type=self_type,
                kind=kind,
                throws=throws,
                ret=ret,
                params=params
            )
        );
        off = off + dsz;
    }

    return BridgeMeta(abi_version=abi, module_name=mod, types=types, fns=fns);
}
