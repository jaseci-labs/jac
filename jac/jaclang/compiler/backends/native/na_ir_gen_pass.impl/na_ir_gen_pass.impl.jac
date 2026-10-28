impl _jc_optional_payload(semantic: (TypeBase | None)) -> (TypeBase | None) {
    if not isinstance(semantic, UnionType) {
        return semantic;
    }
    present = [
        member
        for member in semantic.types
        if not (
            isinstance(member, ClassType) and member.shared.class_name == "NoneType"
        )
    ];
    return present[0] if len(present) == 1 else None;
}

impl ImportedFunctions.provides(name: str) -> bool {
    return name in self.by_name;
}

impl ImportedFunctions.resolve(name: str) -> (ir.Function | None) {
    pending = self.by_name.get(name);
    if pending is None {
        return None;
    }
    return self.lowering._declare_import(pending);
}

impl ImportedFunctions.forget(pending: PendingImport, owner_name: str) {
    name = pending.module_key[1];
    for key in [name, f"{owner_name}.{name}"] {
        if self.by_name.get(key) is pending {
            del self.by_name[key];
        }
    }
    self.by_key.pop(pending.module_key, None);
}
