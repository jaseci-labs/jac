"""LocalStorage helper functions."""

def:pub getStorage(key: str) -> str {
    storage: Storage = localStorage;
    if storage {
        val = storage.getItem(key);
        return val or "";
    }
    return "";
}

def:pub setStorage(key: str, value: str) {
    storage: Storage = localStorage;
    if storage {
        storage.setItem(key, value);
    }
}

def:pub removeStorage(key: str) {
    storage: Storage = localStorage;
    if storage {
        storage.removeItem(key);
    }
}
