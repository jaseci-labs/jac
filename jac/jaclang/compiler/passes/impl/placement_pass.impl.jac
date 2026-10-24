impl _reference_targets(nm: Name) -> list[UniNode] {
    sym = nm.sym;
    if sym is None or sym.decl is None {
        return [];
    }
    declared = sym.decl.name_of;
    if isinstance(declared, Ability) {
        return [declared];
    }
    if isinstance(declared, Archetype) {
        found: list[UniNode] = [];
        body = ModuleFacts.unwrap_body(declared);
        if body is not None {
            for member in body {
                if isinstance(member, Ability)
                    and member.name_ref is not None
                    and member.name_ref.sym_name in ("init", "postinit", "__init__") {
                    found.append(member);
                }
            }
        }
        return found;
    }
    return [];
}

impl unmet_label(need: NativeRefusal) -> tuple[str, str] {
    site = need.site;
    if isinstance(site, Name) {
        return ("this use of native-only builtin", site.value);
    }
    return ("native-only construct", need.name);
}
