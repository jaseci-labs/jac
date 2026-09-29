import jaclang.compiler.frontend.unitree as uni;

def call_target_symbol(call: uni.FuncCall) -> (uni.Symbol | None) {
    if isinstance(call.target, uni.Name) {
        sym = call.target.sym;
        if not sym and call.target.sym_tab {
            sym = call.target.sym_tab.lookup(call.target.sym_name, deep=True);
        }
        return sym;
    }

    if isinstance(call.target, uni.AtomTrailer) {
        attrs = call.target.as_attr_list;
        if attrs {
            last = attrs[-1];
            if isinstance(last, uni.AstSymbolNode) and last.sym {
                return last.sym;
            }
        }
    }
    return None;
}

def symbol_ability(sym: (uni.Symbol | None)) -> (uni.Ability | None) {
    if not sym or not sym.defn {
        return None;
    }
    defn_node = sym.defn[0];
    if isinstance(defn_node, uni.Ability) {
        return defn_node;
    }
    if defn_node.parent and isinstance(defn_node.parent, uni.Ability) {
        return defn_node.parent;
    }
    return None;
}

def symbol_archetype(sym: (uni.Symbol | None)) -> (uni.Archetype | None) {
    if not sym or not sym.defn {
        return None;
    }
    defn_node = sym.defn[0];
    if isinstance(defn_node, uni.Archetype) {
        return defn_node;
    }
    if defn_node.parent and isinstance(defn_node.parent, uni.Archetype) {
        return defn_node.parent;
    }
    return None;
}
