import from enum { IntEnum }

enum Kind(IntEnum) { Unbound, Unknown, Any, Class }

node TBase {
    static has CATEGORY: Kind;
    has category: Kind { getter; }

    def is_any -> bool {
        return self.category == Kind.Any;
    }
}

node TClass(TBase) {
    static has CATEGORY: Kind = Kind.Class;
}

node TAny(TBase) {
    static has CATEGORY: Kind = Kind.Any;
}

impl TBase.category.getter -> Kind {
    return self.CATEGORY;
}

def make(n: int) -> TBase {
    if n == 1 {
        return TClass();
    }
    return TAny();
}

def member_values -> int {
    return Kind.Unbound.value * 1000
        + Kind.Unknown.value * 100
        + Kind.Any.value * 10
        + Kind.Class.value;
}

def class_is_any -> int {
    return 1 if make(1).is_any() else 0;
}

def any_is_any -> int {
    return 1 if make(2).is_any() else 0;
}

def class_category -> int {
    return make(1).category.value;
}
