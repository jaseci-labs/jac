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
    return self.args + self.extra_args;
}

impl CommandSpec.add_extension_arg(arg: Arg, source: str) -> None {
    existing_names = {a.name for a in self.args} | {a.name for a in self.extra_args};
    if arg.name in existing_names {
        return;
    }
    arg.source = source;
    self.extra_args.append(arg);
}

impl CommandSpec.add_pre_hook(hook: Callable, source: str) -> None {
    self.pre_hooks.append((hook, source));
}

impl CommandSpec.add_post_hook(hook: Callable, source: str) -> None {
    self.post_hooks.append((hook, source));
}

impl HookContext.get_arg(name: str, `default: any = None) -> any {
    if name in self.args {
        return self.args[name];
    }
    return self.args.get(name.replace("-", "_"), `default);
}

impl HookContext.set_data(key: str, value: any) -> None {
    self.data[key] = value;
}

impl HookContext.get_data(key: str, `default: any = None) -> any {
    return self.data.get(key, `default);
}
