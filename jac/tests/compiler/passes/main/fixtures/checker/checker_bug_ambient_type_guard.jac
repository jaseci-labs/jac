"""An ambient `TypeGuard` narrows without an import from typing."""

obj Base {
    has tag: str = "base";
}

obj Sub(Base) {
    has extra: int = 0;
}

def looks_like_sub(nd: (Base | None)) -> TypeGuard[Sub] {
    return isinstance(nd, Sub);
}

obj Holder {
    static def looks_static(nd: (Base | None)) -> TypeGuard[Sub] {
        return isinstance(nd, Sub);
    }
}

with entry {
    nd: (Base | None) = Sub();
    if looks_like_sub(nd) {
        print(nd.extra);
    }
    other: (Base | None) = Base();
    if Holder.looks_static(other) {
        print(other.extra);
    }
}
