impl host_native_fact(kind: str, key: str) -> str {
    if kind == FACT_STRUCT_LAYOUTS {
        return struct_layouts_fact(key);
    }
    if kind != FACT_TARGET {
        return kernel_native_fact(kind, key);
    }
    tag = kind + FACT_SEP + key;
    held = _HELD.get(tag);
    if held is None {
        held = target_fact(key);
        _HELD[tag] = held;
    }
    return held;
}

impl target_fact(target: str) -> str {
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

impl struct_layouts_fact(key: str) -> str {
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
