impl Arg.create(
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
) -> Arg {
    auto_short = short;
    if auto_short is None and len(name) > 0 and kind != ArgKind.POSITIONAL {
        auto_short = name[0];
    }

    if kind == ArgKind.POSITIONAL and `default is None {
        required = True;
    }
    return Arg(
        name=name,
        kind=kind,
        typ=typ,
        `default=`default,
        help=help,
        short=auto_short,
        choices=choices,
        required=required,
        metavar=metavar,
        dest=dest,
        config_key=config_key
    );
}

impl CommandSpec.get_all_args -> list[Arg] {
    return self.args;
}

impl resolve_arg_typ(name: any) -> any {
    if isinstance(name, str) {
        return ARG_TYPES.get(name, str);
    }
    return name if name is not None else str;
}

impl arg_typ_name(typ: any) -> str {
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

impl arg_consumes_value(kind: ArgKind, typ: any) -> bool {
    if kind in (ArgKind.POSITIONAL, ArgKind.MULTI_POSITIONAL, ArgKind.REMAINDER) {
        return False;
    }
    typ_name = typ if isinstance(typ, str) else arg_typ_name(typ);
    return kind != ArgKind.FLAG and typ_name != "bool";
}
