import from jaclang.jac0core.unitree { Module }

def merge_annex_into(nd: Module, annex_mod: Module) -> None {
    stmts = list(annex_mod.body);
    if not stmts {
        return;
    }
    nd.body = [*nd.body, *stmts];
    nd.add_kids_right(stmts, pos_update=False, parent_update=True);
    for sub in annex_mod._in_mod_nodes {
        if sub is not annex_mod {
            nd._in_mod_nodes.append(sub);
        }
    }
}
