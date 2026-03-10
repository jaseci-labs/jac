"""Meaning Typed Programming constructs for Jac Language."""
import from collections.abc { Callable }

"""Runtime context for Meaning Typed Programming."""
obj MTRuntime {
    has caller: Callable[(..., object)],
        args: dict[((int | str), object)],
        call_params: dict[(str, object)],
        mtir: (MTIR | None);

    """Create a new MTRuntime instance."""
    static def factory(
        caller: Callable[(..., object)],
        args: dict[((int | str), object)],
        call_params: dict[(str, object)],
        mtir: (MTIR | None) = None
    ) -> MTRuntime {
        return MTRuntime(caller=caller, args=args, call_params=call_params, mtir=mtir);
    }
}

"""Intermediate Representation for Meaning Typed Programming."""
obj MTIR {
    has caller: Callable[(..., object)],
        args: dict[((int | str), object)],
        call_params: dict[(str, object)],
        ir_info: (Info | None) = None;

    """Convert to runtime context."""
    @property
    def runtime(self: MTIR) -> MTRuntime;
}

obj Info {
    has name: str,
        semstr: (str | None);
}

obj VarInfo(Info) {
    has type_info: (ClassInfo | str | tuple | None) = None;
}

obj ParamInfo(VarInfo) {}

obj FieldInfo(VarInfo) {}

obj EnumInfo(Info) {
    has members: list[FieldInfo];
}

obj ClassInfo(Info) {
    has fields: list[FieldInfo],
        base_classes: list[ClassInfo],
        methods: list[MethodInfo];

    def postinit(self: ClassInfo) -> object;
}

obj FunctionInfo(Info) {
    has params: (list[ParamInfo] | None) = None,
        return_type: (str | ClassInfo | tuple | None) = None,
        tools: (list[MethodInfo] | None) = None,
        by_call: bool = False;

    def postinit(self: FunctionInfo) -> object;
}

obj MethodInfo(FunctionInfo) {
    has parent_class: (ClassInfo | None) = None;
}

def mk_list(inner: object) -> tuple {
    return ('list', inner);
}

def mk_dict(key: object, val: object) -> tuple {
    return ('dict', key, val);
}

def mk_tuple(*types: object) -> tuple {
    return (('tuple', ) + `tuple(types));
}

def mk_union(*types: object) -> tuple {
    return (('union', ) + `tuple(types));
}

def is_list_type(t: object) -> bool {
    return (isinstance(t, `tuple) and (len(t) >= 2) and (t[0] == 'list'));
}

def is_dict_type(t: object) -> bool {
    return (isinstance(t, `tuple) and (len(t) == 3) and (t[0] == 'dict'));
}

def is_tuple_type(t: object) -> bool {
    return (isinstance(t, `tuple) and (len(t) >= 2) and (t[0] == 'tuple'));
}

def is_union_type(t: object) -> bool {
    return (isinstance(t, `tuple) and (len(t) >= 2) and (t[0] == 'union'));
}

def inner_types(t: object) -> tuple {
    if (isinstance(t, `tuple) and (len(t) >= 2)) {
        return t[1:];
    }
    return ();
}

"""Pretty-print a type-info value (primitive, ClassInfo, or tuple generic)."""
def type_to_str(t: object) -> str {
    if (t is None) {
        return 'None';
    }
    if isinstance(t, str) {
        return t;
    }
    try {
        import from dataclasses { is_dataclass }
        if (is_dataclass(t) and t?.name) {
            return t.name;
        }
    } except Exception {
        ;
    }
    if isinstance(t, `tuple) {
        head = t[0];
        if (head == 'list') {
            return f"list[{type_to_str(t[1])}]";
        }
        if (head == 'dict') {
            return f"dict[{type_to_str(t[1])},{type_to_str(t[2])}]";
        }
        if (head == 'tuple') {
            return 'tuple[' + ','.join(type_to_str(x) for x in t[1:]) + ']';
        }
        if (head == 'union') {
            return '|'.join(type_to_str(x) for x in t[1:]);
        }
        return (head + '[' + ','.join(type_to_str(x) for x in t[1:]) + ']');
    }
    return str(t);
}
