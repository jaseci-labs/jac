glob MAGIC: bytes = b"JSCAT006",
     FORMAT_VERSION: int = 6,
     HEADER_SIZE: int = 108,
     IFACE_HASH_LEN: int = 64,
     TY_UNKNOWN: int = 0,
     TY_NEVER: int = 1,
     TY_ANY: int = 2,
     TY_MODULE: int = 3,
     TY_TYPEVAR: int = 4,
     TY_CLASS: int = 5,
     TY_FUNCTION: int = 6,
     TY_OVERLOAD: int = 7,
     TY_UNION: int = 8,
     TY_ENUM_MEMBER: int = 9,
     SC_MODULE: int = 0,
     SC_CLASS: int = 1,
     SC_FUNCTION: int = 2,
     SC_OTHER: int = 3,
     ARCH_NONE: int = 0,
     ARCH_CLASS: int = 1,
     ARCH_OBJ: int = 2,
     ARCH_ENUM: int = 3,
     MOD_TYPESHED: int = 1,
     MOD_JAC_INTERNAL: int = 2,
     MOD_EXTERNAL: int = 4,
     LIT_NONE: int = 0,
     LIT_STR: int = 1,
     LIT_INT: int = 2,
     LIT_BOOL: int = 3,
     SH_BUILTIN: int = 1,
     SH_STDLIB: int = 2,
     SH_DATACLASS: int = 4,
     SH_NAMEDTUPLE: int = 8,
     SH_TYPEDDICT: int = 16,
     SH_ROOT: int = 32,
     SH_ENUM: int = 64,
     SH_XREF: int = 128,
     SH_EXTERN: int = 256,
     TV_COVARIANT: int = 1,
     TV_CONTRAVARIANT: int = 2,
     TV_SELF: int = 4,
     TV_PARAM_SPEC: int = 8,
     TV_CLASS_PARAM: int = 16,
     PM_SELF: int = 1,
     PM_CLS: int = 2,
     PM_HAS_DEFAULT: int = 4,
     PM_COMPTIME: int = 8,
     ACCESS_PUBLIC: int = 0,
     ACCESS_PRIVATE: int = 1,
     ACCESS_PROTECTED: int = 2,
     SYMF_PARAM_REBOUND: int = 1,
     SYMF_NA_ESCAPES: int = 2,
     SYMF_NA_REGION_HANDLE: int = 4,
     SYMF_NA_STACK_OK: int = 8,
     SYMF_HAS_DEFAULT: int = 16,
     SYMF_DEFER: int = 32,
     SYMF_INSTANCE_METHOD: int = 64,
     SYMF_FINAL: int = 128,
     SYMF_READONLY: int = 256;

obj Header {
    has n_strings: int = 0,
        n_modules: int = 0,
        n_scopes: int = 0,
        n_symbols: int = 0,
        n_types: int = 0,
        n_shared: int = 0,
        off_strtab: int = 0,
        off_strblob: int = 0,
        off_modtab: int = 0,
        off_scopetab: int = 0,
        off_symtab: int = 0,
        off_typetab: int = 0,
        off_sharedtab: int = 0,
        off_recblob: int = 0,
        key_sid: int = 0,
        ambient_sid: int = 0;
}

def put_u32(out: bytearray, value: int);

def put_u64(out: bytearray, value: int);

def u32_at(buf: bytes, pos: int) -> int;

def u64_at(buf: bytes, pos: int) -> int;

def pack_header(h: Header) -> bytes;

def unpack_header(buf: bytes) -> (Header | None);

def put_uvar(out: bytearray, value: int);

def put_ref(out: bytearray, ref: int);

def put_svar(out: bytearray, value: int);

def put_refs(out: bytearray, refs: list[int]);

obj Cursor {
    has buf: bytes,
        pos: int = 0;

    def u -> int;
    def ref -> int;
    def s -> int;
    def refs -> list[int];
}
