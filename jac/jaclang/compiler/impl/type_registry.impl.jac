impl JacTypeEntry.size_bytes -> int {
    return max(1, self.width // 8);
}

impl JacTypeEntry.align -> int {
    return self.size_bytes();
}

impl JacTypeEntry.is_int_kind -> bool {
    return self.numeric_kind == NumericKind.IntKind;
}

impl JacTypeEntry.is_float_kind -> bool {
    return self.numeric_kind == NumericKind.FloatKind;
}

impl _numeric_entry(shape: ScalarShape, emitter_suffix: str) -> JacTypeEntry {
    return JacTypeEntry(
        name=shape.name,
        emitter_suffix=emitter_suffix,
        numeric_kind=NumericKind.FloatKind if shape.is_float else NumericKind.IntKind,
        width=shape.width,
        signed=shape.signed,
        is_float=shape.is_float,
        sized=shape.sized
    );
}

impl _registry_entries -> dict[str, JacTypeEntry] {
    out: dict[str, JacTypeEntry] = {};
    for shape in numeric_shapes() {
        suffix = "BoolEmitter"
            if shape.name == "bool"
            else ("FloatEmitter" if shape.is_float else "IntEmitter");
        out[shape.name] = _numeric_entry(shape, suffix);
    }
    out["complex"] = JacTypeEntry(name="complex", emitter_suffix="ComplexEmitter");
    out["str"] = JacTypeEntry(name="str", emitter_suffix="StrEmitter", width=64);
    out["bytes"] = JacTypeEntry(name="bytes", emitter_suffix="BytesEmitter");
    out["list"] = JacTypeEntry(name="list", emitter_suffix="ListEmitter");
    out["dict"] = JacTypeEntry(name="dict", emitter_suffix="DictEmitter");
    out["set"] = JacTypeEntry(name="set", emitter_suffix="SetEmitter");
    out["frozenset"] = JacTypeEntry(
        name="frozenset", emitter_suffix="FrozensetEmitter"
    );
    out["tuple"] = JacTypeEntry(name="tuple", emitter_suffix="TupleEmitter");
    out["range"] = JacTypeEntry(name="range", emitter_suffix="RangeEmitter");
    return out;
}

impl JacTypeRegistry.is_non_retaining_builtin(name: str) -> bool {
    return name in self._non_retaining_builtins;
}

impl JacTypeRegistry.shape_of(name: str) -> ScalarShape | None {
    return self._shapes.get(name, None);
}

impl JacTypeRegistry.get(name: str) -> JacTypeEntry | None {
    return self._entries.get(name, None);
}

impl JacTypeRegistry.primitive_names -> set[str] {
    return set(self._entries.keys());
}

impl JacTypeRegistry.is_primitive(name: str) -> bool {
    return name in self._entries;
}

impl JacTypeRegistry.emitter_items -> list[tuple[str, str]] {
    return [(e.name, e.emitter_suffix) for e in self._entries.values()];
}

impl JacTypeRegistry.scalar_entries -> list[JacTypeEntry] {
    return [
        e
        for e in self._entries.values()
        if e.width > 0
    ];
}

impl JacTypeRegistry.builtin_names -> set[str] {
    return set(self._builtin_names);
}

impl JacTypeRegistry.is_builtin(name: str) -> bool {
    return name in self._builtin_names;
}

impl JacTypeRegistry.numeric_kind_of(name: str) -> NumericKind {
    `entry = self._entries.get(name, None);
    if `entry is None {
        return NumericKind.NotNumeric;
    }
    return `entry.numeric_kind;
}

impl JacTypeRegistry.is_numeric(name: str) -> bool {
    return self.numeric_kind_of(name) != NumericKind.NotNumeric;
}

impl JacTypeRegistry.is_sized(name: str) -> bool {
    shape = self._shapes.get(name, None);
    return shape is not None and shape.sized;
}

impl JacTypeRegistry.sized_int_names -> list[str] {
    return [
        s.name
        for s in self._shapes.values()
        if s.sized and not s.is_float
    ];
}

impl JacTypeRegistry.sized_float_names -> list[str] {
    return [
        s.name
        for s in self._shapes.values()
        if s.sized and s.is_float
    ];
}

impl JacTypeRegistry.sized_scalar_names -> list[str] {
    return [
        s.name
        for s in self._shapes.values()
        if s.sized
    ];
}

impl JacTypeRegistry.range_of(name: str) -> tuple[int, int] {
    shape = self._shapes.get(name, None);
    if shape is None {
        raise KeyError(name);
    }
    return shape_range(shape);
}

impl JacTypeRegistry.literal_fits(name: str, value: int | float) -> bool {
    shape = self._shapes.get(name, None);
    return shape is not None and shape_literal_fits(shape, value);
}

impl JacTypeRegistry.widens_to(src: str, dst: str) -> bool {
    if src == dst {
        return True;
    }
    s = self._shapes.get(src, None);
    d = self._shapes.get(dst, None);
    return s is not None and d is not None and shapes_widen_to(s, d);
}

impl JacTypeRegistry.unify(a: str, b: str) -> str | None {
    s = self._shapes.get(a, None);
    d = self._shapes.get(b, None);
    if s is None or d is None {
        return None;
    }
    out = shapes_unify(s, d);
    return None if out is None else out.name;
}

impl JacTypeRegistry.is_exception(name: str) -> bool {
    return name in self._exception_parents;
}

impl JacTypeRegistry.exception_entries -> list[tuple[str, str | None]] {
    return [(name, parent) for (name, parent) in self._exception_parents.items()];
}

impl JacTypeRegistry.exception_type_id(name: str) -> int {
    if name == "Exception" {
        return 0;
    }
    idx = 0;
    for n in self._exception_parents.keys() {
        idx += 1;
        if n == name {
            return idx;
        }
    }
    import hashlib;
    digest = hashlib.sha256(name.encode("utf-8")).hexdigest();
    return 0x40000000 + (int(digest[:8], 16) % 0x3FFFFFFF);
}

impl JacTypeRegistry.exception_descendants(type_name: str) -> list[str] {
    descendants: list[str] = [];
    for child in self._exception_parents.keys() {
        cur = self._exception_parents[child];
        while cur is not None {
            if cur == type_name {
                descendants.append(child);
                break;
            }
            cur = self._exception_parents.get(cur, None);
        }
    }
    return descendants;
}

impl _non_retaining_builtin_set -> frozenset[str] {
    return frozenset(
        {
            "print",
            "len",
            "repr",
            "str",
            "int",
            "float",
            "bool",
            "isinstance",
            "type",
            "id",
            "hash",
            "region_of"
        }
    );
}

impl _builtin_name_set -> frozenset[str] {
    names: set[str] = {
        "wrapping_add",
        "wrapping_sub",
        "wrapping_mul",
        "wrapping_shl",
        "wrapping_neg",
        "print",
        "input",
        "len",
        "abs",
        "round",
        "min",
        "max",
        "sum",
        "sorted",
        "reversed",
        "enumerate",
        "zip",
        "map",
        "filter",
        "any",
        "all",
        "isinstance",
        "issubclass",
        "type",
        "callable",
        "id",
        "hash",
        "jid",
        "new",
        "unsafe_html",
        "managed",
        "take",
        "swap",
        "Region",
        "region_of",
        "repr",
        "format",
        "ascii",
        "chr",
        "ord",
        "hex",
        "oct",
        "bin",
        "pow",
        "divmod",
        "iter",
        "next",
        "getattr",
        "setattr",
        "hasattr",
        "delattr",
        "vars",
        "dir",
        "open",
        "str",
        "int",
        "float",
        "bool",
        "list",
        "dict",
        "set",
        "tuple",
        "frozenset",
        "bytes",
        "complex",
        "range",
        "slice",
        "bytearray"
    };
    for sized in sized_scalar_names() {
        names.add(sized);
    }
    return frozenset(names);
}

impl _shape_table -> dict[str, ScalarShape] {
    out: dict[str, ScalarShape] = {};
    for shape in numeric_shapes() {
        out[shape.name] = shape;
    }
    return out;
}
