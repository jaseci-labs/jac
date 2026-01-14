"""Connect sem strings from source symbol table to declarations in target symbol table.

When source_sym_tab and target_sym_tab are the same, this connects within the same module.
When different, it connects implementations from impl_mod to declarations in the main module.
"""
impl SemDefMatchPass.connect_sems(
    source_sym_tab: UniScopeNode, target_sym_tab: UniScopeNode
) -> None {
    for sym in source_sym_tab.names_in_scope.values() {
        if not isinstance(sym.decl.name_of, uni.SemDef) {
            continue;
        }
        semdef = sym.decl.name_of;
        target_sym = self.find_symbol_from_dotted_name(sym.sym_name, target_sym_tab);
        if (target_sym is not None) {
            target_sym.decl.name_of.semstr = semdef.value.lit_value;
            target_sym.semstr = semdef.value.lit_value;
        }
    }
}

"""Find a symbol in the target symbol table by its dotted name.

Example:
"Foo.bar.baz" will do the following lookups:
target_sym_tab.lookup("Foo").lookup("bar").lookup("baz")
"""
impl SemDefMatchPass.find_symbol_from_dotted_name(
    dotted_name: str, target_sym_tab: UniScopeNode
) -> (Symbol | None) {
    parts = dotted_name.lstrip('sem.').split('.');
    current_sym_tab: (UniScopeNode | None) = target_sym_tab;
    sym: (uni.Symbol | None) = None;
    for part in parts {
        if (current_sym_tab is None) {
            return None;
        }
        sym = current_sym_tab.lookup(part, deep=False);
        if (sym is None) {
            return None;
        }
        current_sym_tab = sym.symbol_table;
    }
    return sym;
}

"""Connect Decls and Defs."""
impl SemDefMatchPass.transform(ir_in: uni.Module) -> uni.Module {
    self.cur_node = ir_in;
    self.connect_sems(ir_in.sym_tab, ir_in.sym_tab);
    for impl_module in ir_in.impl_mod {
        self.connect_sems(impl_module.sym_tab, ir_in.sym_tab);
    }
    return ir_in;
}

"""Initialize SemDefMatchPass."""
impl SemDefMatchPass.init(
    ir_in: uni.Module, prog: Any, cancel_token: Any = None
) -> None {
    super.init(ir_in, prog, cancel_token);
}
