import struct;

glob MAGIC = b"JACBRDG1",
     TAG_VOID = 0xFFFFFFFF,
     TAG_BOOL = 1,
     TAG_STR = 4,
     TAG_REF_BIT = 0x80000000,
     KIND_OPAQUE = 0,
     KIND_ERROR = 3,
     FN_CTOR = 0,
     FN_METHOD = 1;


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
        params: list = None
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
        types: list = None,
        fns: list = None
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

    def sref(off: int) -> str {
        a = u32(off);
        n = u32(off + 4);
        return blob[a:a + n].decode("utf-8");
    }

    abi = u32(8);
    mod = sref(24);
    t_off = u32(40);
    t_cnt = u32(44);
    f_off = u32(48);
    f_cnt = u32(52);

    types = [];
    off = t_off;
    for i in range(t_cnt) {
        dsz = u32(off);
        kind = u8(off + 4);
        name = sref(off + 8);
        drop = sref(off + 16);
        types.append(TypeDesc(index=i, kind=kind, name=name, drop_sym=drop));
        off = off + dsz;
    }

    fns = [];
    off = f_off;
    for i in range(f_cnt) {
        dsz = u32(off);
        fname = sref(off + 4);
        sym = sref(off + 12);
        self_type = u32(off + 20);
        kind = u8(off + 24);
        throws = u32(off + 28);
        ret = u32(off + 32);
        p_off = u32(off + 36);
        p_cnt = u32(off + 40);
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
