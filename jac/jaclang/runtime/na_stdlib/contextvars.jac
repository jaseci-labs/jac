obj:pub ContextVar[T] {
    has name: str,
        `default: (T | None) = None,
        _value: (T | None) = None,
        _is_set: bool = False;

    def get(fallback: (T | None) = None) -> T {
        if self._is_set {
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

    def set(value: T) -> Token[T] {
        token = Token[T](var=self, old_value=self._value, _had_value=self._is_set);
        self._value = value;
        self._is_set = True;
        return token;
    }

    def reset(token: Token[T]) {
        if token._used {
            raise RuntimeError(
                f"<Token used var=<ContextVar name='{self.name}'>> has already been used once"
            );
        }
        if token.var is not self {
            raise ValueError(
                f"<Token var=<ContextVar name='{token.var.name}'>> was created by a different ContextVar"
            );
        }
        self._value = token.old_value;
        self._is_set = token._had_value;
        token._used = True;
    }
}

obj:pub Token[T] {
    has var: ContextVar[T],
        old_value: (T | None) = None,
        _had_value: bool = False,
        _used: bool = False;

    def __enter__ -> Token[T] {
        return self;
    }

    def __exit__(exc_type: any, exc_value: any, traceback: any) {
        self.var.reset(self);
    }
}
