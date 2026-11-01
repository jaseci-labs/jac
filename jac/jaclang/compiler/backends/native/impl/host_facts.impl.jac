impl host_native_fact(kind: str, key: str) -> str {
    if kind == FACT_IMPORT_PATHS {
        import sys;
        import os;
        return FACT_SEP.join(
            p
            for p in sys.path
            if p and os.path.isabs(p)
        );
    }
    if kind == FACT_PACKAGE_STORE {
        import from jaclang.project.package_scope { store_root }
        return str(store_root());
    }
    tag = kind + FACT_SEP + key;
    held = _HELD.get(tag);
    if held is None {
        held = compute_fact(kind, key);
        _HELD[tag] = held;
    }
    return held;
}

impl compute_fact(kind: str, key: str) -> str {
    if kind == FACT_CODEC_TABLES {
        return codec_tables_fact();
    }
    if kind == FACT_CODEC_NAME {
        import codecs;
        try {
            return codecs.lookup(key).name;
        } except LookupError {
            return "";
        }
    }
    if kind == FACT_PRIMITIVE_METHODS {
        return primitive_methods_fact(key);
    }
    if kind == FACT_SEALED_RUNTIME {
        try {
            import from jaclang.jac0core { sealed }
            return "1" if sealed._jaclang_image() is not None else "";
        } except Exception {
            return "";
        }
    }
    raise ValueError(f"unknown native host fact {kind!r}");
}

impl codec_tables_fact -> str {
    import encodings;
    import encodings.aliases;
    import pkgutil;
    supported = {"utf_8": 1, "latin_1": 2, "ascii": 3};
    aliases = encodings.aliases.aliases;
    alias_rows = bytearray();
    for key in sorted(aliases) {
        alias_rows += bytes([supported.get(aliases[key], 4)]) + key.encode() + b"\x00";
    }
    module_rows = bytearray();
    for mod in sorted(m.name for m in pkgutil.iter_modules(encodings.__path__)) {
        if mod != "aliases" and mod not in aliases {
            module_rows += bytes([supported.get(mod, 4)]) + mod.encode() + b"\x00";
        }
    }
    return bytes(alias_rows).hex() + FACT_SEP + bytes(module_rows).hex();
}

impl primitive_methods_fact(type_name: str) -> str {
    return ",".join(sorted(MIR_PRIMITIVE_METHODS.get(type_name, [])));
}
