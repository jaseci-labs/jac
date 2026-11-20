impl LazyRef.__call__(*args: any, **kwargs: any) -> any {
    return self.resolved(*args, **kwargs);
}

impl LazyRef.__getattr__(name: str) -> any {
    return getattr(self.resolved, name);
}

impl LazyRef.__repr__ -> str {
    return f"LazyRef({self.module}.{self.qualname})";
}

impl _host_os -> str {
    if sys.platform.startswith("win") {
        return "windows";
    }
    if sys.platform == "darwin" {
        return "darwin";
    }
    return "linux";
}

impl __ct_ref(module: str, qualname: str) -> any {
    return LazyRef(module=module, qualname=qualname).resolved;
}

impl __ct_lazy(module: str, qualname: str) -> LazyRef {
    return LazyRef(module=module, qualname=qualname);
}

impl typeof(x: any) -> type {
    return `type(x);
}

impl name(t: any) -> str {
    got = t?.__name__;
    if isinstance(got, str) {
        return got;
    }
    return str(t);
}

impl module_of(t: any) -> str {
    got = t?.__module__;
    if isinstance(got, str) {
        return got;
    }
    return "";
}

impl is_subtype(t: type, u: type) -> bool {
    try {
        return issubclass(t, u);
    } except TypeError {
        return False;
    }
}

impl _semstr_of(target: any) -> (str | None) {
    got = target?._jac_semstr;
    if isinstance(got, str) and got {
        return got;
    }
    return None;
}

impl semstr(t: any, field: str = "") -> (str | None) {
    if not field {
        return _semstr_of(t);
    }
    inner = t?._jac_semstr_inner;
    if isinstance(inner, dict) {
        got = inner.get(field);
        if isinstance(got, str) and got {
            return got;
        }
    }
    return None;
}

impl fields(t: type) -> list[FieldInfo] {
    out: list[FieldInfo] = [];
    if not _is_record(t) {
        return out;
    }
    try {
        hints = _get_type_hints(t);
    } except Exception {
        hints = {};
    }
    inner = t?._jac_semstr_inner;
    sems: dict[str, any] = inner if isinstance(inner, dict) else {};
    for f in _record_fields(t) {
        if f.name.startswith("_") {
            continue;
        }
        plain = f.`default;
        factory = f.default_factory;
        has_dflt = plain is not _MISSING or factory is not None;
        dflt: any = plain if plain is not _MISSING else None;
        out.append(
            FieldInfo(
                name=f.name,
                `type=hints.get(f.name, f.`type),
                has_default=has_dflt,
                `default=dflt,
                semstr=sems.get(f.name)
            )
        );
    }
    return out;
}

impl has_field(t: type, field: str) -> bool {
    if _is_record(t) {
        for f in _record_fields(t) {
            if f.name == field {
                return True;
            }
        }
        return False;
    }
    return hasattr(t, field);
}

impl get_field(target: any, field: str) -> any {
    return getattr(target, field);
}

impl set_field(target: any, field: str, value: any) {
    setattr(target, field, value);
}

impl members(e: type) -> list[any] {
    if isinstance(e, `type) and issubclass(e, _PyEnum) {
        return `list(e);
    }
    return [];
}

impl set_fuel(n: int) -> None {
    return None;
}

impl embed_file(path: str) -> str {
    with open(path, "r", encoding="utf-8") as fh {
        return fh.read();
    }
}

impl embed_bytes(path: str) -> bytes {
    with open(path, "rb") as fh {
        return fh.read();
    }
}

impl _scalar_size_align(t: any) -> (tuple[int, int] | None) {
    name = t?.__name__ if isinstance(t, `type) else str(t);
    if name == "bool" {
        return (1, 1, );
    }
    if name in ("int", "float") {
        return (8, 8, );
    }
    shape = shape_of(str(name)) if name else None;
    if shape is not None {
        n = shape.size_bytes();
        return (n, n, );
    }
    return None;
}

impl _size_align(t: any) -> tuple[int, int] {
    scalar = _scalar_size_align(t);
    if scalar is not None {
        return scalar;
    }
    if not _is_record(t) {
        return (8, 8, );
    }
    try {
        hints = _get_type_hints(t);
    } except Exception {
        hints = {};
    }
    off = 0;
    top = 1;
    for f in _record_fields(t) {
        ft = hints.get(f.name, f.`type);
        inner = _scalar_size_align(ft) or (8, 8, );
        (sz, al) = inner;
        off = (off + al - 1) // al * al + sz;
        top = max(top, al);
    }
    return ((off + top - 1) // top * top, top, );
}

impl sizeof(t: any) -> int {
    return _size_align(t)[0];
}

impl alignof(t: any) -> int {
    return _size_align(t)[1];
}

impl record(cls: type, **fields: any) -> any {
    inst = getattr(cls, "__new__")(cls);
    for (k, v) in fields.items() {
        setattr(inst, k, v);
    }
    return inst;
}

impl specialize(cls: type, **ct: any) -> type {
    import copy as _copy;
    key = (cls, tuple(sorted(ct.items(), key=_ct_sort_key)), );
    hit = _SPECIALIZED.get(key);
    if hit is not None {
        return hit;
    }
    annotations: dict[str, any] = {};
    ns: dict[str, any] = {"__annotations__": annotations, "__ct_args__": dict(ct)};
    for (k, v) in ct.items() {
        annotations[k] = `type(v);
        if isinstance(v, (list, dict, set)) {
            def copy_default(value: object = v) -> object {
                return _copy.copy(value);
            }
            ns[k] = _field(default_factory=copy_default, kw_only=True);
        } else {
            ns[k] = _field(`default=v, kw_only=True);
        }
    }
    made = `type(cls.__name__, (cls, ), ns);
    _SPECIALIZED[key] = made;
    return made;
}

impl _ct_sort_key(item: tuple[str, any]) -> str {
    return str(item[0]);
}

impl Codespace.is_server.getter -> bool {
    return self.value == "server";
}

impl Codespace.is_client.getter -> bool {
    return self.value == "client";
}

impl Codespace.is_native.getter -> bool {
    return self.value == "native";
}

impl LazyRef.resolved.getter -> any {
    cur: any = _import_module(self.module);
    for part in self.qualname.split(".") {
        cur = getattr(cur, part);
    }
    return cur;
}
