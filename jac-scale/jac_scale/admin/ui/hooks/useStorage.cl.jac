"""LocalStorage helper functions."""

cl {
    def:pub getStorage(key: str) -> str {
        storage = globalThis.localStorage;
        if storage {
            val = storage.getItem(key);
            return val or "";
        }
        return "";
    }

    def:pub setStorage(key: str, value: str) -> None {
        storage = globalThis.localStorage;
        if storage {
            storage.setItem(key, value);
        }
    }

    def:pub removeStorage(key: str) -> None {
        storage = globalThis.localStorage;
        if storage {
            storage.removeItem(key);
        }
    }
}
