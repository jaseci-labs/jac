obj Info {
    has name: str,
        semstr: (str | None);
}

obj TypeForm {
    has head: str,
        args: list[(ClassInfo | EnumInfo | TypeForm | str | None)] = [];
}

obj VarInfo(Info) {
    has type_info: (ClassInfo | EnumInfo | TypeForm | str | None) = None;
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

    def postinit -> object;
}

obj FunctionInfo(Info) {
    has params: (list[ParamInfo] | None) = None,
        return_type: (ClassInfo | EnumInfo | TypeForm | str | None) = None,
        tools: (list[FunctionInfo] | None) = None,
        by_call: bool = False;

    def postinit -> object;
}

obj MethodInfo(FunctionInfo) {
    has parent_class: (ClassInfo | None) = None;
}

def mk_form(
    head: str, args: list[(ClassInfo | EnumInfo | TypeForm | str | None)]
) -> TypeForm {
    return TypeForm(head=head, args=list(args));
}

def mk_list(inner: (ClassInfo | EnumInfo | TypeForm | str | None)) -> TypeForm {
    return TypeForm(head='list', args=[inner]);
}

def mk_dict(
    key: (ClassInfo | EnumInfo | TypeForm | str | None),
    val: (ClassInfo | EnumInfo | TypeForm | str | None)
) -> TypeForm {
    return TypeForm(head='dict', args=[key, val]);
}

def type_to_str(t: (Info | TypeForm | str | None)) -> str {
    if t is None {
        return 'None';
    }
    if isinstance(t, str) {
        return t;
    }
    if isinstance(t, TypeForm) {
        parts: list[str] = [];
        for arg in t.args {
            parts.append(type_to_str(arg));
        }
        if t.head == 'union' {
            return '|'.join(parts);
        }
        return f"{t.head}[{','.join(parts)}]";
    }
    return t.name;
}
