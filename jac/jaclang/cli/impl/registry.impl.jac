"""Implementation of command registry."""

import argparse;

# ===============================================================================
# CommandRegistry Implementation
# ===============================================================================
"""Initialize the command registry."""
impl CommandRegistry.init -> None {
    self.commands = {};
    self._pending_extensions = {};
    self._finalized = False;
    self.parser = argparse.ArgumentParser(
        prog='jac',
        description='Jac Programming Language CLI',
        epilog='For more information, visit: https://github.com/Jaseci-Labs/jaseci',
        formatter_class=argparse.RawDescriptionHelpFormatter
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

"""Register a new command with metadata."""
impl CommandRegistry.command(
    name: str,
    help: str,
    args: list[Arg] | None = None,
    examples: list[tuple[str, str]] | None = None,
    group: str = "general",
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
            priority=priority,
            source=source,
            handler=func
        );

        # Check for existing command with same name
        if name in self.commands {
            existing = self.commands[name];
            # Higher priority wins
            if priority.value > existing.priority.value {
                self.commands[name] = spec;
            }
            # Same or lower priority - keep existing
        } else {
            self.commands[name] = spec;
        }

        # Apply any pending extensions for this command
        self._apply_pending_extensions(name);

        return func;
    }
    return decorator;
}

"""Extend an existing command with additional arguments or hooks."""
impl CommandRegistry.extend_command(
    command_name: str,
    args: list[Arg] | None = None,
    pre_hook: Callable[[HookContext], None] | None = None,
    post_hook: Callable[[HookContext, int], int] | None = None,
    source: str = "unknown"
) -> None {
    import from jaclang.cli.command { Arg, HookContext }
    # If command already exists, apply extension directly
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
        # Store for later when command is registered
        if command_name not in self._pending_extensions {
            self._pending_extensions[command_name] = [];
        }
        self._pending_extensions[command_name].append(
            (args, pre_hook, post_hook, source)
        );
    }
}

"""Get a command by name."""
impl CommandRegistry.get(name: str) -> CommandSpec | None {
    import from jaclang.cli.command { CommandSpec }
    return self.commands.get(name);
}

"""Check if a command exists."""
impl CommandRegistry.has_command(name: str) -> bool {
    return name in self.commands;
}

"""Get all commands, optionally filtered by group."""
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

"""Get all command group names."""
impl CommandRegistry.get_groups -> list[str] {
    groups = set();
    for spec in self.commands.values() {
        groups.add(spec.group);
    }
    return sorted(list(groups));
}

"""Finalize the registry and build argparse parser."""
impl CommandRegistry.finalize -> argparse.ArgumentParser {
    if self._finalized {
        return self.parser;
    }
    # Build subparsers for all commands
    for (name, spec) in self.commands.items() {
        self._build_subparser(self.sub_parsers, spec);
    }
    self._finalized = True;
    return self.parser;
}

"""Apply any pending extensions to a command."""
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
    # Clear pending extensions for this command
    del self._pending_extensions[name] ;
}

"""Build argparse subparser for a command."""
impl CommandRegistry._build_subparser(
    subparsers: Any, spec: CommandSpec
) -> argparse.ArgumentParser {
    import from jaclang.cli.command { CommandSpec }
    # Build description with examples
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
    # Add base arguments
    for arg in spec.args {
        self._add_argument(cmd_parser, arg);
    }
    # Add plugin-extended arguments
    if spec.extra_args {
        # Group by source for display
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

"""Add an argument to an argparse parser."""
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
    # Handle different argument kinds
    if arg.kind == ArgKind.POSITIONAL {
        # Positional argument
        if arg.default is not None {
            kwargs["nargs"] = "?";
            kwargs["default"] = arg.default;
        } elif not arg.required {
            kwargs["nargs"] = "?";
        }
        parser.add_argument(arg.name, **kwargs);
    } elif arg.kind == ArgKind.MULTI {
        # Multiple positional arguments
        kwargs["nargs"] = "+";
        if arg.default is not None {
            kwargs["default"] = arg.default;
            kwargs["nargs"] = "*";
        }
        parser.add_argument(arg.name, **kwargs);
    } elif arg.kind == ArgKind.REMAINDER {
        # Remaining arguments
        kwargs["nargs"] = argparse.REMAINDER;
        parser.add_argument(arg.name, **kwargs);
    } elif arg.kind == ArgKind.FLAG or arg.typ == bool {
        # Boolean flag
        kwargs["action"] = "store_true";
        kwargs["default"] = arg.default if arg.default is not None else False;
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
        # Add --no-X variant
        no_kwargs = {
            "action": "store_false",
            "dest": arg.name,
            "help": f"Disable {arg.name}"
        };
        parser.add_argument(f"--no-{arg.name}", **no_kwargs);
    } else {
        # Regular option
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

# ===============================================================================
# Module-level Functions Implementation
# ===============================================================================
"""Get the global command registry."""
impl get_registry -> CommandRegistry {
    import from jaclang.cli.registry { CommandRegistry }
    global _registry;
    if _registry is None {
        _registry = CommandRegistry();
    }
    return _registry;
}
