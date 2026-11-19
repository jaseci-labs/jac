"""A `with` block always runs to its end, so what its body narrows holds after it."""

import threading;
import from contextlib { suppress }

obj Finding {
    has id: str = "";
}

glob _lock: threading.Lock = threading.Lock();

def find(key: str) -> Finding | None {
    return Finding(id=key) if key else None;
}

def set_status(key: str, status: str) -> Finding | None {
    with _lock {
        f = find(key);
        if f is None or status not in ("open", "resolved") {
            return None;
        }
        f.id = status;
    }
    return Finding(id=f.id);  # Ok: f is a Finding after the block
}

def first(key: str) -> str {
    with _lock {
        f = find(key);
        if f is None {
            return "";
        }
    }
    return f.id;  # Ok
}

def guarded(key: str) -> str {
    with suppress(ValueError) {
        f = find(key);
        if f is None {
            return "";
        }
    }
    return f.id;  # Warn: a raise inside suppress leaves the block before the guard
}
