obj _NoDefault {}

glob _NO_DEFAULT: _NoDefault = _NoDefault();

obj:pub ContextVar[T] {
    has name: str,
        `default: (T | _NoDefault) = _NO_DEFAULT,
        _value: (T | None) = None,
        _is_set: bool = False;

    def get(fallback: (T | _NoDefault) = _NO_DEFAULT) -> T;
    def set(value: T) -> ContextVarToken[T];
    def reset(token: ContextVarToken[T]);
}

obj ContextVarToken[T] {
    has var: ContextVar[T],
        old_value: (T | None) = None,
        _had_value: bool = False,
        _used: bool = False;

    def __enter__ -> ContextVarToken[T];
    def __exit__(exc_type: any, exc_value: any, traceback: any);
}

type Token[T] = ContextVarToken[T];
