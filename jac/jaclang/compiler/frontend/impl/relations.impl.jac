impl codespace_node(kind: str) -> Codespace {
    found = _CODESPACES.get(kind);
    if found is None {
        found = Codespace(kind=kind);
        _CODESPACES[kind] = found;
    }
    return found;
}
