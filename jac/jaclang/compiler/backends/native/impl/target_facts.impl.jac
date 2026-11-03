impl target_layout(triple: str) -> TargetLayout {
    held = _TARGETS.get(triple);
    if held is not None {
        return held;
    }
    if triple {
        llvm.initialize_all_targets();
        llvm.initialize_all_asmprinters();
        found = llvm.Target.from_triple(triple);
    } else {
        llvm.initialize_native_target();
        found = llvm.Target.from_default_triple();
    }
    machine = found.create_target_machine(reloc="pic", codemodel="small");
    data = machine.target_data;
    layout = TargetLayout(data_layout=str(data), triple=machine.triple);
    data.close();
    machine.close();
    _TARGETS[triple] = layout;
    return layout;
}

impl target_fact_text(triple: str) -> str {
    layout = target_layout(triple);
    return layout.data_layout + FACT_SEP + layout.triple;
}

impl measure_struct_layouts(
    data_layout: str, probe_ir: str, counts: dict[str, int]
) -> dict[str, tuple[list[int], int]] {
    context = llvm.create_context();
    probe = llvm.parse_assembly(probe_ir, context);
    data = llvm.create_target_data(data_layout);
    layouts: dict[str, tuple[list[int], int]] = {};
    for value in probe.global_variables {
        name = value.name;
        if name not in counts {
            raise ValueError(f"the layout probe defines {name}, which was not asked for");
        }
        layouts[name] = data.get_global_struct_layout(value, counts[name]);
    }
    data.close();
    probe.close();
    context.close();
    for name in counts {
        if name not in layouts {
            raise ValueError(f"the layout probe has no global for {name}");
        }
    }
    return layouts;
}
