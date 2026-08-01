"""Pure markerless helper module: no JSX, no npm imports, no OSP.

Client placement is invisible from the inside — only an importing client
module reveals it. Access-less elements are shared logic; the def:pub is a
server endpoint and must stay one.
"""

glob _tags: list = [];

def register(tag: str) {
    _tags.append(tag);
}

def tag_count -> int {
    return len(_tags);
}

def:pub server_ping(payload: str) -> str {
    return payload;
}
