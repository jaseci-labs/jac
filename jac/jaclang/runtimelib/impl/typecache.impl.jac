"""Cached dataclass field-type introspection — implementation."""

import from dataclasses { fields, is_dataclass }
import from typing { get_type_hints }

glob _cache: dict[type, dict[str, object]] = {};

impl get_field_types(cls: type) -> dict[str, object] {
    if (cached := _cache.get(cls)) is not None {
        return cached;
    }
    if not is_dataclass(cls) {
        _cache[cls] = {};
        return {};
    }
    try {
        hints = get_type_hints(cls);
    } except Exception {
        hints = getattr(cls, '__annotations__', {}) or {};
    }
    out: dict[str, object] = {};
    for f in fields(cls) {
        if f.name in hints {
            out[f.name] = hints[f.name];
        }
    }
    _cache[cls] = out;
    return out;
}

impl invalidate(cls: type) -> None {
    _cache.pop(cls, None);
}

impl clear -> None {
    _cache.clear();
}
