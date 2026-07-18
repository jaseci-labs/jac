import sys;
import from dataclasses { fields, is_dataclass }
import from typing { cast }

glob _cache: dict[type, dict[str, object]] = {};

def _resolve_hints(cls: type) -> dict[str, object] {
    hints: dict[str, object] = {};
    for base in reversed(cls.__mro__) {
        ann = cast(dict[str, object], getattr(base, '__annotations__', {}) or {});
        if not ann {
            continue;
        }
        mod = sys.modules.get(base.__module__);
        globalns = cast(dict[str, object], mod?.__dict__ or {});
        localns = cast(dict[str, object], dict(vars(base)));
        for (name, value) in ann.items() {
            if isinstance(value, str) {
                try {
                    value = eval(value, globalns, localns);
                } except Exception {
                    ;
                }
            }
            hints[name] = value;
        }
    }
    return hints;
}

def _collect(cls: type) -> dict[str, object] {
    hints = _resolve_hints(cls);
    out: dict[str, object] = {};
    for f in fields(cls) {
        if f.name in hints {
            out[f.name] = hints[f.name];
        }
    }
    return out;
}

def _is_complete(cls: type, out: dict[str, object]) -> bool {
    for f in fields(cls) {
        if f.name not in out or isinstance(out.get(f.name), str) {
            return False;
        }
    }
    return True;
}

impl get_field_types(cls: type) -> dict[str, object] {
    if (cached := _cache.get(cls)) is not None {
        return cached;
    }
    if not is_dataclass(cls) {
        _cache[cls] = {};
        return {};
    }
    out = _collect(cls);
    if _is_complete(cls, out) {
        _cache[cls] = out;
    }
    return out;
}

impl warm(cls: type) -> None {
    if cls in _cache or not is_dataclass(cls) {
        return;
    }
    out = _collect(cls);
    if _is_complete(cls, out) {
        _cache[cls] = out;
    }
}

impl invalidate(cls: type) -> None {
    _cache.pop(cls, None);
}

impl clear -> None {
    _cache.clear();
}
