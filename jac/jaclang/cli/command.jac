glob ARG_TYPES: dict[str, type] = {
         "str": str,
         "int": int,
         "bool": bool,
         "float": float,

     };

def resolve_arg_typ(name: any) -> any {
    if isinstance(name, str) {
        return ARG_TYPES.get(name, str);
    }
    return name if name is not None else str;
}

def arg_typ_name(typ: any) -> str {
    for (name, registered) in ARG_TYPES.items() {
        if typ is registered {
            return name;
        }
    }
    type_name = typ?.__name__;
    if isinstance(type_name, str) and type_name {
        return type_name;
    }
    return "str";
}

enum ArgKind {
    POSITIONAL = 1,
    OPTION = 2,
    FLAG = 3,
    REMAINDER = 5,
    APPEND = 6,
    MULTI_POSITIONAL = 7,
    MULTI_OPTION = 8,
}

def arg_consumes_value(kind: ArgKind, typ: any) -> bool {
    if kind in (ArgKind.POSITIONAL, ArgKind.MULTI_POSITIONAL, ArgKind.REMAINDER) {
        return False;
    }
    typ_name = typ if isinstance(typ, str) else arg_typ_name(typ);
    return kind != ArgKind.FLAG and typ_name != "bool";
}

obj Arg {
    has name: str,
        kind: ArgKind = ArgKind.OPTION,
        typ: any = str,
        `default: any = None,
        help: str = "",
        short: str | None = None,
        choices: list[str] | None = None,
        required: bool = False,
        dest: str | None = None,
        metavar: str | None = None,
        config_key: str | None = None;

    static def create(
        name: str,
        kind: ArgKind = ArgKind.OPTION,
        typ: any = str,
        `default: any = None,
        help: str = "",
        short: str | None = None,
        choices: list[str] | None = None,
        required: bool = False,
        metavar: str | None = None,
        dest: str | None = None,
        config_key: str | None = None
    ) -> Arg;
}

obj CommandSpec {
    has name: str,
        help: str,
        description: str = "",
        args: list[Arg] = [],
        examples: list[tuple[str, str]] = [],
        group: str = "general",
        tier: str = "",
        hidden: bool = False,
        handler: Callable | None = None,
        handler_module: str = "",
        handler_name: str = "";

    def get_all_args -> list[Arg];
}
