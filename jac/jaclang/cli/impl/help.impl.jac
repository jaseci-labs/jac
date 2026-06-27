impl CommandGroups.get_display_name(group: str) -> str {
    return self.groups.get(group, group.title());
}

impl CommandGroups.get_order(group: str) -> int {
    if group in self.group_order {
        return self.group_order.index(group);
    }
    return len(self.group_order);
}

impl CommandGroups.register_group(
    name: str, display_name: str, order: int | None = None
) -> None {
    self.groups[name] = display_name;
    if name not in self.group_order {
        if order is not None and order < len(self.group_order) {
            self.group_order.insert(int(order), name);
        } else {
            if "general" in self.group_order {
                idx = self.group_order.index("general");
                self.group_order.insert(idx, name);
            } else {
                self.group_order.append(name);
            }
        }
    }
}

impl CommandGroups.get_ordered_groups -> list[str] {
    return self.group_order.copy();
}

impl HelpFormatter.format_main_help(
    commands: list[CommandSpec], prog: str = "jac", version: str | None = None
) -> str {
    import from jaclang.cli.command { CommandSpec }
    lines: list[str] = [];
    lines.append(f"Jac Programming Language CLI");
    if version {
        lines.append(f"Version: {version}");
    }
    lines.append("");
    lines.append(f"Usage: {prog} [OPTIONS] COMMAND [ARGS]...");
    lines.append("");
    lines.append("Options:");
    lines.append("  -V, --version  Show version and exit");
    lines.append("  -h, --help     Show this message and exit");
    lines.append("");
    grouped: dict[str, list[CommandSpec]] = {};
    for cmd in commands {
        group = cmd.group or "general";
        if group not in grouped {
            grouped[group] = [];
        }
        grouped[group].append(cmd);
    }
    ordered_groups = self.groups.get_ordered_groups();
    for group in ordered_groups {
        if group not in grouped {
            continue;
        }

        cmds = grouped[group];
        if not cmds {
            continue;
        }

        display_name = self.groups.get_display_name(group);

        sources = set(cmd.source for cmd in cmds);
        if len(sources) == 1 and "jaclang" not in sources {
            display_name += f"  [{list(sources)[0]}]";
        }

        lines.append(f"{display_name}:");

        cmds.sort(key=lambda c: str : c.name);
        for cmd in cmds {
            padding = " " * (12 - len(cmd.name));
            lines.append(f"  {cmd.name}{padding}{cmd.help}");
        }

        lines.append("");
    }
    for group in grouped.keys() {
        if group not in ordered_groups {
            cmds = grouped[group];
            display_name = self.groups.get_display_name(group);
            lines.append(f"{display_name}:");
            for cmd in cmds {
                padding = " " * (12 - len(cmd.name));
                lines.append(f"  {cmd.name}{padding}{cmd.help}");
            }
            lines.append("");
        }
    }
    lines.append(f"Run '{prog} COMMAND --help' for command details.");
    return "\n".join(lines);
}

impl HelpFormatter.format_command_help(spec: CommandSpec) -> str {
    import from jaclang.cli.command { CommandSpec }
    lines: list[str] = [];
    lines.append(spec.help);
    lines.append("");
    if spec.description {
        lines.append(spec.description);
        lines.append("");
    }
    lines.append(self.format_usage(spec));
    lines.append("");
    all_args = spec.get_all_args();
    if all_args {
        lines.append(self.format_arguments(spec.args, spec.extra_args));
    }
    if spec.examples {
        lines.append(self.format_examples(spec.examples));
    }
    return "\n".join(lines);
}

impl HelpFormatter.format_arguments(
    args: list[Arg], extra_args: list[Arg] | None = None
) -> str {
    import from jaclang.cli.command { Arg, ArgKind }
    lines: list[str] = [];
    positional = [
        a
        for a in args
        if a.kind == ArgKind.POSITIONAL
        or a.kind == ArgKind.MULTI
        or a.kind == ArgKind.REMAINDER
    ];
    optional = [
        a
        for a in args
        if a.kind == ArgKind.OPTION or a.kind == ArgKind.FLAG
    ];
    if positional {
        lines.append("Arguments:");
        for arg in positional {
            desc = arg.help;
            if arg.default is not None {
                desc += f" (default: {arg.default})";
            }
            padding = " " * (16 - len(arg.name));
            lines.append(f"  {arg.name}{padding}{desc}");
        }
        lines.append("");
    }
    if optional {
        lines.append("Options:");
        for arg in optional {
            if arg.short {
                flag_str = f"-{arg.short}, --{arg.name}";
            } else {
                flag_str = f"--{arg.name}";
            }
            if arg.typ != bool and arg.kind != ArgKind.FLAG {
                type_name = arg.typ?.__name__ or str(arg.typ);
                flag_str += f" {type_name.upper()}";
            }

            desc = arg.help;
            if arg.default is not None and arg.typ != bool {
                desc += f" (default: {arg.default})";
            }
            if arg.choices {
                desc += f" [{', '.join(str(c) for c in arg.choices)}]";
            }

            padding = " " * max(1, 24 - len(flag_str));
            lines.append(f"  {flag_str}{padding}{desc}");
        }
        lines.append("");
    }
    if extra_args {
        by_source: dict[str, list[Arg]] = {};
        for arg in extra_args {
            src = arg.source or "plugin";
            if src not in by_source {
                by_source[src] = [];
            }
            by_source[src].append(arg);
        }
        for (source, source_args) in by_source.items() {
            lines.append(f"Options from [{source}]:");
            for arg in source_args {
                if arg.short {
                    flag_str = f"-{arg.short}, --{arg.name}";
                } else {
                    flag_str = f"--{arg.name}";
                }
                if arg.typ != bool and arg.kind != ArgKind.FLAG {
                    type_name = arg.typ?.__name__ or str(arg.typ);
                    flag_str += f" {type_name.upper()}";
                }

                desc = arg.help;
                if arg.default is not None and arg.typ != bool {
                    desc += f" (default: {arg.default})";
                }

                padding = " " * max(1, 24 - len(flag_str));
                lines.append(f"  {flag_str}{padding}{desc}");
            }
            lines.append("");
        }
    }
    return "\n".join(lines);
}

impl HelpFormatter.format_examples(examples: list[tuple[str, str]]) -> str {
    lines: list[str] = ["Examples:"];
    for (cmd, desc) in examples {
        lines.append(f"  {cmd}");
        if desc {
            lines.append(f"      {desc}");
        }
    }
    return "\n".join(lines);
}

impl HelpFormatter.format_usage(spec: CommandSpec, prog: str = "jac") -> str {
    import from jaclang.cli.command { CommandSpec, ArgKind }
    parts = [f"Usage: {prog} {spec.name}"];
    for arg in spec.args {
        if arg.kind == ArgKind.POSITIONAL {
            if arg.required or arg.default is None {
                parts.append(f"<{arg.name}>");
            } else {
                parts.append(f"[{arg.name}]");
            }
        } elif arg.kind == ArgKind.MULTI {
            parts.append(f"<{arg.name}>...");
        } elif arg.kind == ArgKind.REMAINDER {
            parts.append(f"[{arg.name}...]");
        }
    }
    optional_count = sum(
        1
        for a in spec.get_all_args()
        if a.kind == ArgKind.OPTION or a.kind == ArgKind.FLAG
    );
    if optional_count > 0 {
        parts.append("[OPTIONS]");
    }
    return " ".join(parts);
}

impl get_command_groups -> CommandGroups {
    import from jaclang.cli.help { CommandGroups }
    global _groups;
    if _groups is None {
        _groups = CommandGroups();
    }
    return _groups;
}

impl get_help_formatter -> HelpFormatter {
    import from jaclang.cli.help { HelpFormatter }
    global _formatter;
    if _formatter is None {
        _formatter = HelpFormatter();
    }
    return _formatter;
}
