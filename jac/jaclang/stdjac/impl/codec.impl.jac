impl encode(value: any) -> any {
    if isinstance(value, enum.Enum) {
        return value.name;
    }
    if value is None or isinstance(value, (bool, int, float, str)) {
        return value;
    }
    if isinstance(value, (bytes, bytearray)) {
        return bytes(value).hex();
    }
    if isinstance(value, complex) {
        return [value.real, value.imag];
    }
    if isinstance(value, dict) {
        if all([isinstance(k, str) for k in value.keys()]) {
            return {k: encode(v) for (k, v) in value.items()};
        }
        return [[encode(k), encode(v)] for (k, v) in value.items()];
    }
    if isinstance(value, (list, tuple, set, frozenset)) {
        return [encode(v) for v in value];
    }
    fields = _fields_of(value);
    if fields is not None {
        out = {name: encode(v) for (name, v) in fields};
        if isinstance(value, (NodeArchetype, EdgeArchetype)) {
            out["__jid"] = str(jid(value));
        }
        return out;
    }
    return str(value);
}

impl _fields_of(value: any) -> list[tuple[str, any]] | None {
    names: list[str] = [];
    for cls in reversed(getattr(type(value), "__mro__", (type(value), ))) {
        annotations = cls.__dict__.get("__annotations__");
        if isinstance(annotations, dict) {
            names.extend(
                [
                    n
                    for n in annotations.keys()
                    if not n.startswith("_") and n not in names
                ]
            );
        }
    }
    if not names {
        held = value?.__dict__;
        if not isinstance(held, dict) {
            return None;
        }
        names = [
            n
            for n in held.keys()
            if not n.startswith("_")
        ];
    }
    return [
        (n, getattr(value, n, None))
        for n in names
        if hasattr(value, n)
    ];
}
