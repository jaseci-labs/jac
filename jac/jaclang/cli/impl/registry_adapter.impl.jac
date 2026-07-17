impl manifest_to_spec(
    meta: CommandMeta, handler: Callable | None = None
) -> CommandSpec {
    import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
    import from jaclang.cli.loader { load_handler }

    if handler is None {
        handler = load_handler(meta.name);
    }

    args: list[Arg] = [];
    for a in meta.args {
        typ = int if a.typ == 'int' else str;
        args.append(
            Arg(
                name=a.name,
                kind=ArgKind(a.kind.value),
                typ=typ,
                `default=a.default,
                help=a.help,
                short=a.short,
                choices=list(a.choices) if a.choices else None,
                required=a.required,
                dest=a.dest,
                metavar=a.metavar
            )
        );
    }
    return CommandSpec(
        name=meta.name,
        help=meta.help,
        description=meta.description,
        args=args,
        examples=list(meta.examples),
        group=meta.group,
        tier=meta.tier,
        hidden=meta.hidden,
        handler=handler
    );
}

impl materialize_all_specs(include_hidden: bool = False) -> list[CommandSpec] {
    import from jaclang.cli.manifest { iter_command_meta }

    return [
        manifest_to_spec(meta)
        for meta in iter_command_meta(include_hidden=include_hidden)
    ];
}
