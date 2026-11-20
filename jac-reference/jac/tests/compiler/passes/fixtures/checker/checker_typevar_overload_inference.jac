"""B2c fix: Method-level TypeVar inference in overload resolution.

When an overload has method-level TypeVars (not class-level), the constraint
solver infers bindings from call arguments and specializes the return type.
For example, ContextVar[MyObj].get(None) matches overload:
  get(self, default: _D) -> _D | _T
where _T=MyObj (from class), _D=NoneType (inferred from arg None).
"""
import from contextvars { ContextVar }

obj MyObj {
    has x: int = 0;
}

with entry {
    # Infer _D=NoneType from argument: cv.get(None) -> NoneType | MyObj
    cv: ContextVar[MyObj] = ContextVar('cv');
    v1 = cv.get(None);
    if v1 {
        print(v1.x);  # narrowed to MyObj, should access .x
    }

    # dict.get with explicit default: d.get("key", 0)
    # overload 2: get(key: _KT, default: _VT) -> _VT (class-level TypeVar)
    d: dict[str, int] = {};
    v3 = d.get("key", 0);
    y3: int = v3;
}
