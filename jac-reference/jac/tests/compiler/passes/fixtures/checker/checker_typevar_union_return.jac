"""B2 fix: TypeVar | unions in return type annotations resolve correctly.

Before this fix, return types like `_VT | None` in typeshed stubs resolved to
Unknown because TypeVarType.is_any_type() returned True, short-circuiting the
`|` operator to UnknownType before the union could be created.
"""
import from contextvars { ContextVar }

obj MyObj {
    has x: int = 0;
}

with entry {
    # dict.get() overload 1: get(key, default=None) -> _VT | None
    d: dict[str, MyObj] = {};
    v1 = d.get("key");
    y1: MyObj | None = v1;

    # ContextVar.get() overload 1: get() -> _T
    cv: ContextVar[MyObj] = ContextVar('cv');
    v2: MyObj = cv.get();

    # dict.get() with builtin value type (baseline)
    d2: dict[str, int] = {};
    v3 = d2.get("key");
    y3: int | None = v3;
}
