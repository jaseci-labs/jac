import json;

import from jaclang.compiler.backends.native.na_constants {
    FACT_CODEC_NAME,
    FACT_CODEC_TABLES,
    FACT_OS,
    FACT_PRIMITIVE_METHODS,
    FACT_SEALED_RUNTIME,
    FACT_SEP,
    FACT_STRUCT_LAYOUTS,
    FACT_TARGET
}

glob _HELD: dict[str, str] = {};

def host_native_fact(kind: str, key: str) -> str {
    if kind == FACT_STRUCT_LAYOUTS {
        return struct_layouts_fact(key);
    }
    tag = kind + FACT_SEP + key;
    held = _HELD.get(tag);
    if held is None {
        held = compute_fact(kind, key);
        _HELD[tag] = held;
    }
    return held;
}

def compute_fact(kind: str, key: str) -> str {
    if kind == FACT_TARGET {
        return target_fact(key);
    }
    if kind == FACT_OS {
        import platform;
        return platform.system();
    }
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

def target_fact(target: str) -> str {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    if target {
        llvm.initialize_all_targets();
        llvm.initialize_all_asmprinters();
        found = llvm.Target.from_triple(target);
    } else {
        llvm.initialize_native_target();
        found = llvm.Target.from_default_triple();
    }
    machine = found.create_target_machine(reloc="pic", codemodel="small");
    return str(machine.target_data) + FACT_SEP + str(machine.triple);
}

def struct_layouts_fact(key: str) -> str {
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    (data_layout, _, probe) = key.partition(FACT_SEP);
    (counts_text, _, probe_ir) = probe.partition(FACT_SEP);
    counts: dict[str, int] = json.loads(counts_text);
    rows: list[str] = [];
    with llvm.parse_assembly(probe_ir) as bound, llvm.create_target_data(
        data_layout
    ) as target_data {
        for value in bound.global_variables {
            (offsets, size) = target_data.get_global_struct_layout(
                value, counts[value.name]
            );
            rows.append(
                f"{value.name}\t{size}\t" + ",".join(str(offset) for offset in offsets)
            );
        }
    }
    return "\n".join(rows);
}

def codec_tables_fact -> str {
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

def primitive_methods_fact(type_name: str) -> str {
    import inspect;
    import jaclang.compiler.backends.native.primitives_native as emitters;
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    found: any = None;
    for (name_of_type, suffix) in JAC_TYPE_REGISTRY.emitter_items() {
        if name_of_type == type_name {
            found = getattr(emitters, "Native" + suffix, None);
        }
    }
    if found is None {
        return "";
    }
    emitter = found();
    names: list[str] = [];
    for name in dir(emitter) {
        if name.startswith("emit_") and not name.startswith("emit_op_") {
            if len(inspect.signature(getattr(emitter, name)).parameters) >= 3 {
                names.append(name.removeprefix("emit_"));
            }
        }
    }
    return ",".join(sorted(names));
}
