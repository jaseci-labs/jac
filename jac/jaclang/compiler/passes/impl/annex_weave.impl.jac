impl merge_annex_into(nd: Module, annex_mod: Module) -> None {
    stmts = list(annex_mod.body);
    if not stmts {
        return;
    }
    nd.add_kids_right(stmts, pos_update=False, parent_update=True, role=BodyRole);
    held = nd._in_mod_nodes;
    if held is None {
        held = [];
        nd._in_mod_nodes = held;
    }
    for sub in annex_mod._in_mod_nodes or [] {
        if sub is not annex_mod {
            held.append(sub);
        }
    }
}

impl import_form(
    is_absorb: bool, is_typed: bool, is_comptime: bool, from_form: bool
) -> str {
    words: list[str] = [];
    if is_comptime {
        words.append("comptime");
    }
    words.append("include" if is_absorb else "import");
    if is_typed {
        words.append("type");
    }
    if from_form {
        words.append("from");
    }
    return " ".join(words);
}
