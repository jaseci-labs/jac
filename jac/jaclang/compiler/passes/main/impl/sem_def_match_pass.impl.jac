impl SemDefMatchPass.connect_sems(
    source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
) -> None {
    for sym in source_sym_tab.names_in_scope.values() {
        if not isinstance(sym.decl.name_of, uni.SemDef) {
            continue;
        }
        semdef = sym.decl.name_of;
        target_sym = self.resolve_sem_target(semdef, target_sym_tab);

        if (target_sym is not None) {
            sem_value = semdef.value.lit_value;
            if (isinstance(sem_value, str)) {
                target_sym.decl.name_of.semstr = sem_value;
                target_sym.semstr = sem_value;
            }
        }
    }
}

impl SemDefMatchPass.resolve_sem_target(
    semdef: uni.SemDef, target_sym_tab: UniScopeNode
) -> (Symbol | None) {
    current_sym_tab: (UniScopeNode | None) = target_sym_tab;
    sym: (uni.Symbol | None) = None;
    for part_node in semdef.target {
        if (current_sym_tab is None) {
            return None;
        }
        sym = current_sym_tab.lookup(part_node.sym_name, deep=False);
        if (sym is None) {
            return None;
        }

        if part_node.sym is None {
            sym.add_use(part_node);
        }
        current_sym_tab = sym.symbol_table;
    }
    return sym;
}

impl SemDefMatchPass.transform(ir_in: uni.Module) -> uni.Module {
    self.cur_node = ir_in;

    self.connect_sems(ir_in.sym_tab, ir_in.sym_tab);
    return ir_in;
}
