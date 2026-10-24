impl kind_spec(kind: str) -> KindSpec | None {
    return KIND_SPECS.get(kind);
}

impl kind_entry(kind: str) -> str {
    spec = KIND_SPECS.get(kind);
    return spec.`entry if spec else "main";
}

impl is_valid_kind(kind: str) -> bool {
    return kind in KIND_SPECS;
}

impl kind_ui(kind: str) -> str {
    spec = KIND_SPECS.get(kind);
    return spec.ui if spec else "";
}

impl kind_has_client(kind: str) -> bool {
    return bool(kind_ui(kind));
}

impl kind_is_mobui(kind: str) -> bool {
    return kind_ui(kind) == UI_MOBUI;
}

impl kind_codespace(kind: str) -> str {
    spec = KIND_SPECS.get(kind);
    return spec.codespace if spec else '';
}

impl kind_has_server(kind: str) -> bool {
    spec = KIND_SPECS.get(kind);
    return spec.has_server if spec else kind == '';
}
