import type from jaclang.compiler.ir.schema { Ability }
import type from jaclang.compiler.ir.types.nodes { ClassType, TypeBase }

obj CtDeferred {
    def __repr__ -> str {
        return "<comptime deferred>";
    }
}

glob CT_DEFERRED: CtDeferred = CtDeferred();

obj CtEnumMember {
    has enum_name: str,
        member: str,
        value: any = None,
        module: str = "",
        enum_type: (ClassType | None) = None;

    def __eq__(other: any) -> bool {
        return (
            isinstance(other, CtEnumMember)
            and other.enum_name == self.enum_name
            and other.member == self.member
        );
    }

    def __hash__ -> int {
        return hash((self.enum_name, self.member));
    }

    def __repr__ -> str {
        return f"{self.enum_name}.{self.member}";
    }
}

obj CtType {
    has name: str,
        module: str = "",
        typ: (TypeBase | None) = None,
        ct_args: (dict[str, any] | None) = None;

    def __eq__(other: any) -> bool {
        return (
            isinstance(other, CtType)
            and other.name == self.name
            and other.module == self.module
        );
    }

    def __hash__ -> int {
        return hash((self.module, self.name));
    }

    def __repr__ -> str {
        return f"<type {self.name}>";
    }
}

obj CtFunc {
    has qualname: str,
        module: str = "",
        ability: (Ability | None) = None,
        lazy: bool = False;

    def __eq__(other: any) -> bool {
        return (
            isinstance(other, CtFunc)
            and other.qualname == self.qualname
            and other.module == self.module
        );
    }

    def __hash__ -> int {
        return hash((self.module, self.qualname));
    }

    def __repr__ -> str {
        return f"<function {self.module}.{self.qualname}>";
    }
}

obj CtRecord {
    has class_name: str,
        module: str = "",
        fields: dict[str, any] = {},
        class_type: (ClassType | None) = None,
        home: str = "",
        ct_args: (dict[str, any] | None) = None;

    def __getattr__(name: str) -> any {
        flds: dict[str, any] = object.__getattribute__(self, "fields");
        if name in flds {
            return flds[name];
        }
        raise AttributeError(name);
    }

    def __eq__(other: any) -> bool {
        return (
            isinstance(other, CtRecord)
            and other.class_name == self.class_name
            and other.fields == self.fields
        );
    }

    def __repr__ -> str {
        inner = ", ".join([f"{k}={v!r}" for (k, v) in self.fields.items()]);
        return f"{self.class_name}({inner})";
    }
}

obj CtValue {
    has v: any = None;
    has is_deferred: bool { getter; }

    def __repr__ -> str {
        return f"CtValue({self.v!r})";
    }
}

impl CtValue.is_deferred.getter -> bool {
    return isinstance(self.v, CtDeferred);
}

def ct_box(v: any) -> CtValue {
    return CtValue(v=v);
}

def ct_is_scalar(v: any) -> bool {
    return v is None or isinstance(v, (bool, int, float, str, bytes));
}

def ct_is_materializable(v: any) -> bool {
    if ct_is_scalar(v) {
        return True;
    }
    if isinstance(v, (CtEnumMember, CtType, CtFunc)) {
        return True;
    }
    if isinstance(v, (list, tuple, set, frozenset)) {
        for item in v {
            if not ct_is_materializable(item) {
                return False;
            }
        }
        return True;
    }
    if isinstance(v, dict) {
        for (k, item) in v.items() {
            if not ct_is_materializable(k) or not ct_is_materializable(item) {
                return False;
            }
        }
        return True;
    }
    if isinstance(v, CtRecord) {
        for item in v.fields.values() {
            if not ct_is_materializable(item) {
                return False;
            }
        }
        return True;
    }
    return False;
}

def ct_mangle(v: any) -> str {
    if isinstance(v, bool) {
        return "b1" if v else "b0";
    }
    if isinstance(v, int) {
        return f"i{v}" if v >= 0 else f"n{-v}";
    }
    if isinstance(v, float) {
        return "f" + repr(v).replace(".", "_").replace("-", "n").replace("+", "");
    }
    if isinstance(v, str) {
        return "s" + "".join([c if c.isalnum() else f"_{ord(c)}_" for c in v]);
    }
    if v is None {
        return "N";
    }
    if isinstance(v, CtEnumMember) {
        return f"e{v.enum_name}_{v.member}";
    }
    if isinstance(v, CtType) {
        return f"t{v.name}";
    }
    if isinstance(v, CtFunc) {
        return f"fn{v.qualname}";
    }
    if isinstance(v, (list, tuple)) {
        return "L" + "_".join([ct_mangle(x) for x in v]) + "_";
    }
    import hashlib;
    return "x" + hashlib.sha256(repr(v).encode("utf-8")).hexdigest()[:16];
}
