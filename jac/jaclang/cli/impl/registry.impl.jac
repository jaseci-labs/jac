import argparse;
import from jaclang.cli.banners { JAC_GITHUB_URL }

impl CommandRegistry.init -> None {
    self.commands = {};
    self._pending_extensions = {};
    self._finalized = False;
    self.parser = argparse.ArgumentParser(
        prog='jac',
        description='Jac Programming Language CLI',
        epilog=f'For more information, visit: {JAC_GITHUB_URL}',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        add_help=False
    );
    self.parser.add_argument(
        '-h',
        '--help',
        action='store_true',
        dest='help',
        help='Show all commands and exit'
    );
    self.parser.add_argument(
        '-V',
        '--version',
        action='store_true',
        help='Show the Jac version and installation path'
    );
    self.sub_parsers = self.parser.add_subparsers(
        title='commands',
        dest='command',
        description='Available commands:',
        metavar='COMMAND'
    );
}

impl CommandRegistry.command(
    name: str,
    help: str,
    args: list[Arg] | None = None,
    examples: list[tuple[str, str]] | None = None,
    group: str = "general",
    tier: str = "",
    priority: CommandPriority = CommandPriority.CORE,
    source: str = "jaclang"
) -> Callable[[Callable], Callable] {
    import from jaclang.cli.command { Arg, CommandSpec, CommandPriority }
    def decorator(func: Callable) -> Callable {
        spec = CommandSpec(
            name=name,
            help=help,
            description=func.__doc__ or "",
            args=args or [],
            examples=examples or [],
            group=group,
            tier=tier,
            priority=priority,
            source=source,
            handler=func
        );

        if name in self.commands {
            existing = self.commands[name];

            if priority.value > existing.priority.value {
                spec.pre_hooks = list(existing.pre_hooks) + spec.pre_hooks;
                spec.post_hooks = list(existing.post_hooks) + spec.post_hooks;
                spec.extra_args = list(existing.extra_args) + spec.extra_args;
                self.commands[name] = spec;
            }
        } else {
            self.commands[name] = spec;
        }

        self._apply_pending_extensions(name);

        return func;
    }
    return decorator;
}

impl CommandRegistry.extend_command(
    command_name: str,
    args: list[Arg] | None = None,
    pre_hook: Callable[[HookContext], None] | None = None,
    post_hook: Callable[[HookContext, int], int] | None = None,
    source: str = "unknown"
) -> None {
    import from jaclang.cli.command { Arg, HookContext }

    if command_name in self.commands {
        spec = self.commands[command_name];
        if args {
            for arg in args {
                spec.add_extension_arg(arg, source);
            }
        }
        if pre_hook {
            spec.add_pre_hook(pre_hook, source);
        }
        if post_hook {
            spec.add_post_hook(post_hook, source);
        }
    } else {
        if command_name not in self._pending_extensions {
            self._pending_extensions[command_name] = [];
        }
        self._pending_extensions[command_name].append(
            (args, pre_hook, post_hook, source)
        );
    }
}

impl CommandRegistry.get(name: str) -> CommandSpec | None {
    import from jaclang.cli.command { CommandSpec }
    return self.commands.get(name);
}

impl CommandRegistry.has_command(name: str) -> bool {
    return name in self.commands;
}

impl CommandRegistry.get_all(group: str | None = None) -> list[CommandSpec] {
    import from jaclang.cli.command { CommandSpec }
    if group is None {
        return list(self.commands.values());
    }
    return [
        spec
        for spec in self.commands.values()
        if spec.group == group
    ];
}

impl CommandRegistry.get_groups -> list[str] {
    groups = set();
    for spec in self.commands.values() {
        groups.add(spec.group);
    }
    return sorted(list(groups));
}

impl CommandRegistry.finalize -> argparse.ArgumentParser {
    if self._finalized {
        return self.parser;
    }

    for (name, spec) in self.commands.items() {
        self._build_subparser(self.sub_parsers, spec);
    }
    self._finalized = True;
    return self.parser;
}

impl CommandRegistry._apply_pending_extensions(name: str) -> None {
    if name not in self._pending_extensions {
        return;
    }
    spec = self.commands.get(name);
    if spec is None {
        return;
    }
    for (args, pre_hook, post_hook, source) in self._pending_extensions[name] {
        if args {
            for arg in args {
                spec.add_extension_arg(arg, source);
            }
        }
        if pre_hook {
            spec.add_pre_hook(pre_hook, source);
        }
        if post_hook {
            spec.add_post_hook(post_hook, source);
        }
    }

    del self._pending_extensions[name];
}

impl CommandRegistry._build_subparser(
    subparsers: any, spec: CommandSpec
) -> argparse.ArgumentParser {
    import from jaclang.cli.command { CommandSpec }

    description = spec.description or spec.help;
    if spec.examples {
        description += "\n\nExamples:\n";
        for (cmd, desc) in spec.examples {
            description += f"  {cmd}\n";
            if desc {
                description += f"      {desc}\n";
            }
        }
    }
    cmd_parser = subparsers.add_parser(
        spec.name,
        description=description,
        help=spec.help,
        formatter_class=argparse.RawDescriptionHelpFormatter
    );

    for arg in spec.args {
        self._add_argument(cmd_parser, arg);
    }

    if spec.extra_args {
        sources: dict[str, list] = {};
        for arg in spec.extra_args {
            src = arg.source or "plugin";
            if src not in sources {
                sources[src] = [];
            }
            sources[src].append(arg);
        }
        for (src, args) in sources.items() {
            group = cmd_parser.add_argument_group(f"Options from {src}");
            for arg in args {
                self._add_argument(group, arg);
            }
        }
    }
    return cmd_parser;
}

impl CommandRegistry._add_argument(parser: argparse.ArgumentParser, arg: Arg) -> None {
    import from jaclang.cli.command { Arg, ArgKind }
    kwargs: dict = {"help": arg.help};
    if arg.choices {
        kwargs["choices"] = arg.choices;
    }
    if arg.metavar {
        kwargs["metavar"] = arg.metavar;
    }
    if arg.dest {
        kwargs["dest"] = arg.dest;
    }

    if arg.kind == ArgKind.POSITIONAL {
        if arg.default is not None {
            kwargs["nargs"] = "?";
            kwargs["default"] = arg.default;
        }

        parser.add_argument(arg.name, **kwargs);
    } elif arg.kind == ArgKind.MULTI {
        if arg.name in ("paths", "packages", "names") {
            kwargs["nargs"] = "+";
            if arg.default is not None {
                kwargs["default"] = arg.default;
                kwargs["nargs"] = "*";
            }
            parser.add_argument(arg.name, **kwargs);
        } else {
            kwargs["nargs"] = "*";
            if arg.default is not None {
                kwargs["default"] = arg.default;
            }
            if arg.short {
                parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
            } else {
                parser.add_argument(f"--{arg.name}", **kwargs);
            }
        }
    } elif arg.kind == ArgKind.APPEND {
        kwargs["action"] = "append";
        kwargs["nargs"] = "+";
        kwargs["default"] = None;
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
    } elif arg.kind == ArgKind.REMAINDER {
        kwargs["nargs"] = argparse.REMAINDER;
        parser.add_argument(arg.name, **kwargs);
    } elif arg.kind == ArgKind.FLAG or arg.typ == bool {
        kwargs["action"] = "store_true";
        kwargs["default"] = arg.default if arg.default is not None else False;
        shared_dest: str = kwargs.get("dest") or arg.name.replace("-", "_");
        kwargs["dest"] = shared_dest;
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
        no_kwargs = {
            "action": "store_false",
            "dest": shared_dest,
            "help": f"Disable {arg.name}"
        };
        parser.add_argument(f"--no-{arg.name}", **no_kwargs);
    } else {
        kwargs["type"] = arg.typ;
        kwargs["default"] = arg.default;
        if arg.required {
            kwargs["required"] = True;
        }
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
    }
}

impl get_registry -> CommandRegistry {
    import from jaclang.cli.registry { CommandRegistry }
    global _registry;
    if _registry is None {
        _registry = CommandRegistry();
    }
    return _registry;
}
