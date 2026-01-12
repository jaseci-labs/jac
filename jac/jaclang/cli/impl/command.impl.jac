"""Implementation of core CLI command types."""

# ===============================================================================
# Arg Implementation
# ===============================================================================
"""Create argument with auto-generated short flag."""
impl Arg.create(
    name: str,
    kind: ArgKind = ArgKind.OPTION,
    typ: Any = str,
    default: Any = None,
    help: str = "",
    short: str | None = None,
    choices: list[Any] | None = None,
    required: bool = False,
    metavar: str | None = None
) -> Arg {
    # Auto-generate short flag from first character if not provided
    auto_short = short;
    if auto_short is None and len(name) > 0 and kind != ArgKind.POSITIONAL {
        auto_short = name[0];
    }
    return Arg(
        name=name,
        kind=kind,
        typ=typ,
        default=default,
        help=help,
        short=auto_short,
        choices=choices,
        required=required,
        metavar=metavar
    );
}

# ===============================================================================
# CommandSpec Implementation
# ===============================================================================
"""Get all arguments (base + plugin-extended)."""
impl CommandSpec.get_all_args -> list[Arg] {
    return self.args + self.extra_args;
}

"""Add an extension argument from a plugin."""
impl CommandSpec.add_extension_arg(arg: Arg, source: str) -> None {
    # Set the source on the arg
    arg.source = source;
    self.extra_args.append(arg);
}

"""Add a pre-execution hook from a plugin."""
impl CommandSpec.add_pre_hook(hook: Callable, source: str) -> None {
    self.pre_hooks.append((hook, source));
}

"""Add a post-execution hook from a plugin."""
impl CommandSpec.add_post_hook(hook: Callable, source: str) -> None {
    self.post_hooks.append((hook, source));
}

# ===============================================================================
# HookContext Implementation
# ===============================================================================
"""Get an argument value with optional default."""
impl HookContext.get_arg(name: str, default: Any = None) -> Any {
    return self.args.get(name, default);
}

"""Set a value in the hook data context."""
impl HookContext.set_data(key: str, value: Any) -> None {
    self.data[key] = value;
}

"""Get a value from the hook data context."""
impl HookContext.get_data(key: str, default: Any = None) -> Any {
    return self.data.get(key, default);
}
