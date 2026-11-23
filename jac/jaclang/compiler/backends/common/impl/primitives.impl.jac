impl interface_emit_names(cls: type, arity: int) -> list[str] {
    return _emit_names_entry(cls, arity)[0];
}

impl emit_name_set(cls: type, arity: int) -> frozenset[str] {
    return _emit_names_entry(cls, arity)[1];
}

impl _emit_names_entry(cls: type, arity: int) -> tuple[list[str], frozenset[str]] {
    import inspect;

    key = (cls, arity);
    if key not in _EMIT_NAMES {
        found: set[str] = set();
        for klass in cls.__mro__ {
            if klass.__module__ != PrimitiveEmitter.__module__ {
                continue;
            }
            for (attr, member) in vars(klass).items() {
                if attr.startswith("emit_")
                    and inspect.isfunction(member)
                    and len(inspect.signature(member).parameters) == arity {
                    found.add(attr.removeprefix("emit_"));
                }
            }
        }
        _EMIT_NAMES[key] = (sorted(found), frozenset(found));
    }
    return _EMIT_NAMES[key];
}

impl PrimitiveEmitter.method_names(self: PrimitiveEmitter) -> list[str] {
    return interface_emit_names(type(self), 4);
}

impl PrimitiveEmitter.static_names(self: PrimitiveEmitter) -> list[str] {
    return interface_emit_names(type(self), 3);
}

impl PrimitiveEmitter.dispatch(
    self: PrimitiveEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name not in emit_name_set(type(self), 4) {
        return None;
    }
    return getattr(self, "emit_" + name)(ctx, target, args);
}

impl PrimitiveEmitter.dispatch_static(
    self: PrimitiveEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    if name not in emit_name_set(type(self), 3)
        and name not in self.static_names() {
        return None;
    }
    return getattr(self, "emit_" + name)(ctx, args);
}
