import from jaclang.compiler.frontend.unitree {
    EmptyToken,
    Import,
    Module,
    ModuleItem,
    ModulePath,
    UniNode
}
import from jaclang.compiler.frontend.roles { BodyRole, Kid }

obj WovenAnnex {
    has source: str,
        path: str,
        consumer: str = "";
}

def merge_annex_into(nd: Module, annex_mod: Module) -> None {
    stmts = list(annex_mod.body);
    if not stmts {
        return;
    }
    nd.add_kids_right(stmts, pos_update=False, parent_update=True, role=BodyRole);
    for sub in annex_mod._in_mod_nodes {
        if sub is not annex_mod {
            nd._in_mod_nodes.append(sub);
        }
    }
}

def import_form(
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

def import_items(stmt: Import) -> list[tuple[tuple[str, str, str, str], UniNode]] {
    from_loc = stmt.from_loc;
    form = import_form(
        stmt.is_absorb, stmt.is_typed, stmt.is_comptime, from_loc is not None
    );
    out: list[tuple[tuple[str, str, str, str], UniNode]] = [];
    for item in stmt.items {
        alias = item.alias.value if item.alias is not None else "";
        if isinstance(item, ModuleItem) and from_loc is not None {
            out.append(((from_loc.dot_path_str, form, item.name.value, alias), item));
        } elif isinstance(item, ModulePath) {
            out.append(((item.dot_path_str, form, "", alias), item));
        }
    }
    return out;
}

def import_keys(stmt: Import) -> set[tuple[str, str, str, str]] {
    return {key for (key, _item) in import_items(stmt)};
}

def relative_twin(
    key: tuple[str, str, str, str], consumer: str
) -> tuple[str, str, str, str] {
    (provider, form, name, alias) = key;
    if "." not in consumer {
        return key;
    }
    package = consumer.rsplit(".", 1)[0] + ".";
    if provider.startswith(package) {
        return ("." + provider[len(package):], form, name, alias);
    }
    return key;
}

def prune_generated_imports(mod: Module, generated_path: str, consumer: str) -> None {
    written: set[tuple[str, str, str, str]] = set();
    generated: list[Import] = [];
    for stmt in mod.body {
        if not isinstance(stmt, Import) {
            continue;
        }
        if stmt.loc.mod_path == generated_path {
            generated.append(stmt);
            continue;
        }
        written |= import_keys(stmt);
    }
    if not generated or not written {
        return;
    }
    removed: set[int] = set();
    for stmt in generated {
        doomed: set[int] = set();
        for (key, item) in import_items(stmt) {
            if key in written or relative_twin(key, consumer) in written {
                doomed.add(id(item));
            }
        }
        if doomed and stmt.prune_items(doomed) {
            removed.add(id(stmt));
        }
    }
    if removed {
        mod._role_set(
            BodyRole,
            [
                s
                for s in mod.body
                if id(s) not in removed
            ]
        );
        mod.set_kids(
            nodes=[
                k
                for k in [mod->:Kid:->]
                if id(k) not in removed
            ]
                or [EmptyToken()]
        );
        mod._invalidate_sub_node_tab();
    }
}
