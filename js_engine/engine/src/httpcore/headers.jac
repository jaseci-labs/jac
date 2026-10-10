"""HTTP header container for js_engine.

Implements a small Fetch/Node-compatible header store with case-insensitive
lookup and mutation. Header names are compared case-insensitively but the most
recent spelling passed to `headers_append()` / `headers_set()` is preserved for
serialisation.

Public API
----------
  headers_create()            -> Headers
  headers_append(h, n, v)     -> None
  headers_set(h, n, v)        -> None
  headers_get(h, n)           -> str
  headers_has(h, n)           -> bool
  headers_delete(h, n)        -> None
  headers_entries(h)          -> list[list[str]]
  headers_from_dict(d)        -> Headers
  headers_to_raw(h)           -> str
"""

# `\r` is broken in Jac native, so CRLF must be built manually.
glob _HDR_CRLF: str = chr(13) + "\n";

glob:pub HEADERS_GUARD_NONE: str = "none",
     HEADERS_GUARD_REQUEST: str = "request",
     HEADERS_GUARD_RESPONSE: str = "response",
     HEADERS_GUARD_IMMUTABLE: str = "immutable";

obj:pub Headers {
    has entries: list[list[str]] = [],
        guard: str = "none";
}

def _headers_norm_name(name: str) -> str {
    return name.strip().lower();
}

def _headers_can_mutate(h: Headers) -> bool {
    return h.guard != HEADERS_GUARD_IMMUTABLE;
}

def:pub headers_create -> Headers {
    return Headers();
}

def:pub headers_append(h: Headers, name: str, value: str) -> None {
    if not _headers_can_mutate(h) {
        return;
    }
    raw_name: str = name.strip();
    if raw_name == "" {
        return;
    }
    h.entries.append([raw_name, value]);
}

def:pub headers_set(h: Headers, name: str, value: str) -> None {
    if not _headers_can_mutate(h) {
        return;
    }
    norm: str = _headers_norm_name(name);
    if norm == "" {
        return;
    }
    kept: list[list[str]] = [];
    for pair in h.entries {
        if len(pair) < 2 {
            continue;
        }
        if _headers_norm_name(pair[0]) != norm {
            kept.append([pair[0], pair[1]]);
        }
    }
    h.entries = kept;
    h.entries.append([name.strip(), value]);
}

def:pub headers_get(h: Headers, name: str) -> str {
    norm: str = _headers_norm_name(name);
    for pair in h.entries {
        if len(pair) < 2 {
            continue;
        }
        if _headers_norm_name(pair[0]) == norm {
            return pair[1];
        }
    }
    return "";
}

def:pub headers_has(h: Headers, name: str) -> bool {
    norm: str = _headers_norm_name(name);
    for pair in h.entries {
        if len(pair) < 2 {
            continue;
        }
        if _headers_norm_name(pair[0]) == norm {
            return True;
        }
    }
    return False;
}

def:pub headers_delete(h: Headers, name: str) -> None {
    if not _headers_can_mutate(h) {
        return;
    }
    norm: str = _headers_norm_name(name);
    kept: list[list[str]] = [];
    for pair in h.entries {
        if len(pair) < 2 {
            continue;
        }
        if _headers_norm_name(pair[0]) != norm {
            kept.append([pair[0], pair[1]]);
        }
    }
    h.entries = kept;
}

def:pub headers_entries(h: Headers) -> list[list[str]] {
    out: list[list[str]] = [];
    for pair in h.entries {
        if len(pair) < 2 {
            continue;
        }
        out.append([pair[0], pair[1]]);
    }
    return out;
}

def:pub headers_from_dict(d: dict[str, str]) -> Headers {
    h: Headers = Headers();
    for key in d {
        headers_append(h, key, d[key]);
    }
    return h;
}

def:pub headers_to_raw(h: Headers) -> str {
    raw: str = "";
    for pair in h.entries {
        if len(pair) < 2 {
            continue;
        }
        raw = raw + pair[0] + ": " + pair[1] + _HDR_CRLF;
    }
    return raw;
}
