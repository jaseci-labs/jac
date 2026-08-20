"""Pure markerless helper: client placement only visible via importer."""

glob _seen: list = [];

def note(tag: str) {
    _seen.append(tag);
}

def:pub ping(payload: str) -> str {
    return payload;
}
