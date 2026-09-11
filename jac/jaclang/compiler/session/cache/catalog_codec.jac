import struct;
import from jaclang.compiler.session.cache.catalog_format {
    Header,
    HEADER_SIZE,
    pack_header
}

obj PreparedCatalog {
    has strings: tuple[str, ...],
        modules: tuple[bytes | None, ...],
        scopes: tuple[bytes | None, ...],
        symbols: tuple[bytes | None, ...],
        types: tuple[bytes | None, ...],
        shared: tuple[bytes | None, ...],
        key_sid: int,
        ambient_sid: int;
}

def encode_catalog(prepared: PreparedCatalog) -> bytes {
    recblob = bytearray();
    def lay(recs: tuple[bytes | None, ...]) -> bytes {
        offsets: list[bytes] = [];
        for r in recs {
            offsets.append(len(recblob).to_bytes(4, "little"));
            recblob.extend(r if r is not None else b"\x00");
        }
        return b"".join(offsets);
    }
    modtab = lay(prepared.modules);
    scopetab = lay(prepared.scopes);
    symtab = lay(prepared.symbols);
    typetab = lay(prepared.types);
    sharedtab = lay(prepared.shared);

    strblob = bytearray();
    strtab_parts: list[bytes] = [];
    for s in prepared.strings {
        encoded = s.encode("utf-8");
        strtab_parts.append(struct.pack("<II", len(strblob), len(encoded)));
        strblob.extend(encoded);
    }
    strtab = b"".join(strtab_parts);

    h = Header();
    h.n_strings = len(prepared.strings);
    h.n_modules = len(prepared.modules);
    h.n_scopes = len(prepared.scopes);
    h.n_symbols = len(prepared.symbols);
    h.n_types = len(prepared.types);
    h.n_shared = len(prepared.shared);
    h.key_sid = prepared.key_sid;
    h.ambient_sid = prepared.ambient_sid;
    pos = HEADER_SIZE;
    h.off_strtab = pos;
    pos += len(strtab);
    h.off_strblob = pos;
    pos += len(strblob);
    h.off_modtab = pos;
    pos += len(modtab);
    h.off_scopetab = pos;
    pos += len(scopetab);
    h.off_symtab = pos;
    pos += len(symtab);
    h.off_typetab = pos;
    pos += len(typetab);
    h.off_sharedtab = pos;
    pos += len(sharedtab);
    h.off_recblob = pos;
    return b"".join(
        [
            pack_header(h),
            strtab,
            bytes(strblob),
            modtab,
            scopetab,
            symtab,
            typetab,
            sharedtab,
            bytes(recblob)
        ]
    );
}
