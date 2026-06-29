impl CommandGroups.get_display_name(group: str) -> str {
    return self.groups.get(group, group.title());
}

impl CommandGroups.get_ordered_groups -> list[str] {
    return self.group_order.copy();
}

impl HelpFormatter.format_main_help(
    commands: list[CommandSpec],
    prog: str = "jac",
    version: str | None = None,
    verbose: bool = False
) -> str {
    import from jaclang.cli.command { CommandSpec }

    if not verbose {
        return self.format_curated_help(commands, prog);
    }

    lines: list[str] = [];

    lines.append("Jac Programming Language CLI");
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
    lines.append(f"New to Jac? Run '{prog} guide' for curated docs.");
    return "\n".join(lines);
}

impl HelpFormatter.format_curated_help(
    commands: list[CommandSpec], prog: str = "jac"
) -> str {
    import from jaclang.cli.command { CommandSpec }
    lines: list[str] = [];

    lines.append(f"Usage: {prog} COMMAND [ARGS]...");
    lines.append("");

    by_tier: dict[str, list[CommandSpec]] = {};
    for cmd in commands {
        if cmd.tier {
            if cmd.tier not in by_tier {
                by_tier[cmd.tier] = [];
            }
            by_tier[cmd.tier].append(cmd);
        }
    }

    for tier in self.groups.tier_order {
        cmds = by_tier.get(tier, []);
        if not cmds {
            continue;
        }
        lines.append(f"{self.groups.tier_sections.get(tier, tier)}:");
        cmds.sort(key=lambda c: str : c.name);
        for cmd in cmds {
            padding = " " * (12 - len(cmd.name));
            lines.append(f"  {cmd.name}{padding}{cmd.help}");
        }
        lines.append("");
    }

    lines.append(
        f"AI agents: run `{prog} guide` first to learn how to build with Jac."
    );
    lines.append("");
    lines.append(f"  {prog} --help          Show all commands");
    lines.append(f"  {prog} COMMAND --help  Show help for a command");
    return "\n".join(lines);
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
