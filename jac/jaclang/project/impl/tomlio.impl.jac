impl MalformedJacTomlError.__str__ -> str {
    return f"jac.toml is malformed at {self.file_path}: {self.original}";
}

impl JacTomlError.__str__ -> str {
    location = f"[{self.where}]" if self.where else "(top level)";
    return f"{self.origin}: {location} {self.detail}";
}

impl read_toml_with_encoding(file_path: str) -> dict[str, any] {
    try {
        return tomllib.loads(read_file_with_encoding(file_path));
    } except tomllib.TOMLDecodeError as exc {
        raise MalformedJacTomlError(file_path=file_path, original=exc);
    }
}

impl toml_kind(value: any) -> str {
    if isinstance(value, bool) {
        return "a boolean";
    }
    if isinstance(value, int) {
        return "an integer";
    }
    if isinstance(value, float) {
        return "a float";
    }
    if isinstance(value, str) {
        return "a string";
    }
    if isinstance(value, list) {
        return "an array";
    }
    if isinstance(value, dict) {
        return "a table";
    }
    return "a date or time";
}

impl TomlTable.error(key: str, detail: str) -> JacTomlError {
    return JacTomlError(
        origin=self.origin or "jac.toml", where=self.where, detail=f"{key} {detail}"
    );
}

impl TomlTable.keys -> list[str] {
    return [str(k) for k in self.data.keys()];
}

impl TomlTable.has_key(key: str) -> bool {
    return key in self.data;
}

impl TomlTable.child_where(key: str) -> str {
    return f"{self.where}.{key}" if self.where else key;
}

impl TomlTable.text(key: str) -> str {
    value = self.data[key];
    if not isinstance(value, str) {
        raise self.error(key, f"must be a string, got {value!r}");
    }
    return value;
}

impl TomlTable.scalar_text(key: str) -> str {
    value = self.data[key];
    if isinstance(value, bool) {
        return "true" if value else "false";
    }
    if isinstance(value, str) or isinstance(value, int) or isinstance(value, float) {
        return str(value);
    }
    raise self.error(key, f"must be a string or a number, got {value!r}");
}

impl TomlTable.optional_text(key: str) -> (str | None) {
    value = self.data[key];
    if value is None {
        return None;
    }
    return self.text(key);
}

impl TomlTable.flag(key: str) -> bool {
    value = self.data[key];
    if not isinstance(value, bool) {
        raise self.error(key, f"must be true or false, got {value!r}");
    }
    return value;
}

impl TomlTable.integer(key: str) -> int {
    value = self.data[key];
    if isinstance(value, bool) or not isinstance(value, int) {
        raise self.error(key, f"must be an integer, got {value!r}");
    }
    return value;
}

impl TomlTable.number(key: str) -> float {
    value = self.data[key];
    if isinstance(value, bool) {
        raise self.error(key, f"must be a number, got {value!r}");
    }
    if isinstance(value, int) {
        return float(value);
    }
    if not isinstance(value, float) {
        raise self.error(key, f"must be a number, got {value!r}");
    }
    return value;
}

impl TomlTable.texts(key: str) -> list[str] {
    value = self.data[key];
    if not isinstance(value, list) {
        raise self.error(key, f"must be a list of strings, got {value!r}");
    }
    out: list[str] = [];
    for item in value {
        if not isinstance(item, str) {
            raise self.error(key, f"must be a list of strings, got {value!r}");
        }
        out.append(item);
    }
    return out;
}

impl TomlTable.text_or_texts(key: str) -> list[str] {
    value = self.data[key];
    if isinstance(value, str) {
        return [value];
    }
    return self.texts(key);
}

impl TomlTable.text_map(key: str) -> dict[str, str] {
    inner = self.table(key);
    out: dict[str, str] = {};
    for name in inner.keys() {
        out[name] = inner.text(name);
    }
    return out;
}

impl TomlTable.text_list_map(key: str) -> dict[str, list[str]] {
    inner = self.table(key);
    out: dict[str, list[str]] = {};
    for name in inner.keys() {
        out[name] = inner.texts(name);
    }
    return out;
}

impl TomlTable.raw_table(key: str) -> dict[str, any] {
    value = self.data[key];
    if not isinstance(value, dict) {
        raise JacTomlError(
            origin=self.origin or "jac.toml",
            where=self.child_where(key),
            detail="must be a table"
        );
    }
    return value;
}

impl TomlTable.table(key: str) -> TomlTable {
    return TomlTable(
        data=self.raw_table(key),
        where=self.child_where(key),
        origin=self.origin,
        strict=self.strict
    );
}

impl TomlTable.strictly -> TomlTable {
    return TomlTable(data=self.data, where=self.where, origin=self.origin, strict=True);
}

impl TomlTable.unknown(key: str, known: list[str]) {
    if not self.strict {
        return;
    }
    matches = get_close_matches(key, known, n=1, cutoff=0.6);
    hint = f"; did you mean '{matches[0]}'?" if matches else "";
    raise JacTomlError(
        origin=self.origin or "jac.toml",
        where=self.where,
        detail=f"has no key {key!r}{hint}; its keys are {', '.join(known)}"
    );
}

impl TomlTable.moved(key: str, target: str) -> JacTomlError {
    return self.error(key, f"has moved to {target}");
}
