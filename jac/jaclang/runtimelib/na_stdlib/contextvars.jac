obj:pub ContextVar[T] {
    has name: str,
        `default: (T | None) = None,
        _value: (T | None) = None;

    def get(fallback: (T | None) = None) -> T {
        if self._value is not None {
            return self._value;
        }
        if fallback is not None {
            return fallback;
        }
        if self.`default is not None {
            return self.`default;
        }
        raise LookupError(self.name);
    }

    def set(value: T) {
        self._value = value;
    }
}
