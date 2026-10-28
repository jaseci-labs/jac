impl ContextVar.get(fallback: (T | _NoDefault) = _NO_DEFAULT) -> T {
    if self._is_set {
        return self._value as T;
    }
    if fallback is not _NO_DEFAULT {
        return fallback as T;
    }
    if self.`default is not _NO_DEFAULT {
        return self.`default as T;
    }
    raise LookupError(self.name);
}

impl ContextVar.set(value: T) -> ContextVarToken[T] {
    token = ContextVarToken[T](
        var=self, old_value=self._value, _had_value=self._is_set
    );
    self._value = value;
    self._is_set = True;
    return token;
}

impl ContextVar.reset(token: ContextVarToken[T]) {
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

impl ContextVarToken.__enter__ -> ContextVarToken[T] {
    return self;
}

impl ContextVarToken.__exit__(exc_type: any, exc_value: any, traceback: any) {
    self.var.reset(self);
}
