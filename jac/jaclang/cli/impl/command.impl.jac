impl Arg.create(
    name: str,
    kind: ArgKind = ArgKind.OPTION,
    typ: any = str,
    `default: any = None,
    help: str = "",
    short: str | None = None,
    choices: list[any] | None = None,
    required: bool = False,
    metavar: str | None = None,
    dest: str | None = None
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
        dest=dest
    );
}

impl CommandSpec.get_all_args -> list[Arg] {
    return self.args;
}
