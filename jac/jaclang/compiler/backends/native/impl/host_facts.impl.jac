impl target_layout(target: str) -> tuple[str, str] {
    held = _TARGETS.get(target);
    if held is not None {
        return held;
    }
    if target {
        llvm.initialize_all_targets();
        llvm.initialize_all_asmprinters();
        found = llvm.Target.from_triple(target);
    } else {
        llvm.initialize_native_target();
        found = llvm.Target.from_default_triple();
    }
    machine = found.create_target_machine(reloc="pic", codemodel="small");
    held = (str(machine.target_data), str(machine.triple));
    _TARGETS[target] = held;
    return held;
}

impl struct_layouts_of(
    data_layout: str, counts: dict[str, int], probe_ir: str
) -> dict[str, tuple[list[int], int]] {
    layouts: dict[str, tuple[list[int], int]] = {};
    with llvm.parse_assembly(probe_ir) as bound, llvm.create_target_data(
        data_layout
    ) as target_data {
        for value in bound.global_variables {
            (offsets, size) = target_data.get_global_struct_layout(
                value, counts[value.name]
            );
            layouts[value.name] = ([int(offset) for offset in offsets], int(size));
        }
    }
    return layouts;
}

impl codec_tables -> tuple[bytes, bytes] {
    if _CODEC_TABLES {
        return _CODEC_TABLES[0];
    }
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
    _CODEC_TABLES.append((bytes(alias_rows), bytes(module_rows)));
    return _CODEC_TABLES[0];
}

impl canonical_codec_name(encoding: str) -> str {
    import codecs;
    try {
        return codecs.lookup(encoding).name;
    } except LookupError {
        return "";
    }
}

impl primitive_method_names(type_name: str) -> set[str] {
    held = _PRIMITIVE_METHODS.get(type_name);
    if held is not None {
        return held;
    }
    import inspect;

    found: any = None;
    for (name_of_type, suffix) in JAC_TYPE_REGISTRY.emitter_items() {
        if name_of_type == type_name {
            found = getattr(emitters, "Native" + suffix, None);
        }
    }
    names: set[str] = set();
    if found is not None {
        emitter = found();
        for name in dir(emitter) {
            if name.startswith("emit_") and not name.startswith("emit_op_") {
                if len(inspect.signature(getattr(emitter, name)).parameters) >= 3 {
                    names.add(name.removeprefix("emit_"));
                }
            }
        }
    }
    _PRIMITIVE_METHODS[type_name] = names;
    return names;
}

impl sealed_runtime_active -> bool {
    if not _SEALED_RUNTIME {
        try {
            import from jaclang.jac0core { sealed }
            _SEALED_RUNTIME.append(sealed._jaclang_image() is not None);
        } except Exception {
            _SEALED_RUNTIME.append(False);
        }
    }
    return _SEALED_RUNTIME[0];
}

impl import_search_dirs -> list[str] {
    import os;
    import sys;
    return [
        p
        for p in sys.path
        if p and os.path.isabs(p)
    ];
}

impl package_store_dir -> str {
    return str(store_root());
}
