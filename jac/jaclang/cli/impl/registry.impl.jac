impl CommandRegistry.init -> None {
    self.commands = {};
}

impl CommandRegistry.command(
    name: str,
    help: str,
    args: list[Arg] | None = None,
    examples: list[tuple[str, str]] | None = None,
    group: str = "general",
    tier: str = "",
    hidden: bool = False
) -> Callable[[Callable], Callable] {
    import from jaclang.cli.command { Arg, CommandSpec }
    def decorator(func: Callable) -> Callable {
        self.commands[name] = CommandSpec(
            name=name,
            help=help,
            description=func.__doc__ or "",
            args=args or [],
            examples=examples or [],
            group=group,
            tier=tier,
            hidden=hidden,
            handler=func
        );
        return func;
    }
    return decorator;
}

impl CommandRegistry.get(name: str) -> CommandSpec | None {
    import from jaclang.cli.command { CommandSpec }
    return self.commands.get(name);
}

impl CommandRegistry.has_command(name: str) -> bool {
    return name in self.commands;
}

impl CommandRegistry.get_all(
    group: str | None = None, include_hidden: bool = False
) -> list[CommandSpec] {
    import from jaclang.cli.command { CommandSpec }
    return [
        spec
        for spec in self.commands.values()
        if (include_hidden or not spec.hidden)
            and (group is None or spec.group == group)
    ];
}

impl CommandRegistry.get_groups -> list[str] {
    groups = set();
    for spec in self.commands.values() {
        groups.add(spec.group);
    }
    return sorted(list(groups));
}

impl get_registry -> CommandRegistry {
    import from jaclang.cli.registry { CommandRegistry }
    if _registry is None {
        _registry = CommandRegistry();
    }
    return _registry;
}
