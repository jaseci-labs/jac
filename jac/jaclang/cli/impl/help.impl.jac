glob _HELP_RESET: str = "\033[0m",
     _HELP_HEADER: str = "\033[1;34m",
     _HELP_CMD: str = "\033[32m",
     _HELP_PROG: str = "\033[1;35m",
     _HELP_TITLE: str = "\033[1m";

def _help_color(text: str, code: str) -> str {
    import from jaclang.cli.console { console }
    try {
        if not console.use_color {
            return text;
        }
    } except Exception {
        return text;
    }
    return f"{code}{text}{_HELP_RESET}";
}

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

    lines.append(_help_color("The Jac programming language", _HELP_TITLE));
    lines.append("");
    lines.append(
        f"{_help_color('Usage:', _HELP_HEADER)} "
        f"{_help_color(prog, _HELP_PROG)} [OPTIONS] COMMAND [ARGS]..."
    );
    lines.append("");
    lines.append(_help_color("Options:", _HELP_HEADER));
    lines.append(f"  {_help_color('-V, --version', _HELP_CMD)}");
    lines.append(f"          Print version info and exit");
    lines.append(f"  {_help_color('-h, --help', _HELP_CMD)}");
    lines.append(f"          Print help");
    lines.append("");

    grouped: dict[str, list[CommandSpec]] = {};
    for cmd in commands {
        group = cmd.group or "general";
        if group not in grouped {
            grouped[group] = [];
        }
        grouped[group].append(cmd);
    }

    col = 12;
    for cmd in commands {
        if len(cmd.name) >= col {
            col = len(cmd.name) + 2;
        }
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
        lines.append(_help_color(f"{display_name}:", _HELP_HEADER));
        cmds.sort(key=lambda (c: str) { c.name; });
        for cmd in cmds {
            padding = " " * (col - len(cmd.name));
            lines.append(f"    {_help_color(cmd.name, _HELP_CMD)}{padding}{cmd.help}");
        }
        lines.append("");
    }

    for group in grouped.keys() {
        if group not in ordered_groups {
            cmds = grouped[group];
            display_name = self.groups.get_display_name(group);
            lines.append(_help_color(f"{display_name}:", _HELP_HEADER));
            for cmd in cmds {
                padding = " " * (col - len(cmd.name));
                lines.append(
                    f"    {_help_color(cmd.name, _HELP_CMD)}{padding}{cmd.help}"
                );
            }
            lines.append("");
        }
    }

    lines.append(
        f"See '{prog} COMMAND --help' for more information on a specific command."
    );
    return "\n".join(lines);
}

impl HelpFormatter.format_curated_help(
    commands: list[CommandSpec], prog: str = "jac"
) -> str {
    import from jaclang.cli.command { CommandSpec }
    lines: list[str] = [];

    lines.append(_help_color("The Jac programming language", _HELP_TITLE));
    lines.append("");
    lines.append(
        f"{_help_color('Usage:', _HELP_HEADER)} "
        f"{_help_color(prog, _HELP_PROG)} [OPTIONS] COMMAND [ARGS]..."
    );
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

    col = 12;
    for cmd in commands {
        if cmd.tier and len(cmd.name) >= col {
            col = len(cmd.name) + 2;
        }
    }

    for tier in self.groups.tier_order {
        cmds = by_tier.get(tier, []);
        if not cmds {
            continue;
        }
        lines.append(
            _help_color(f"{self.groups.tier_sections.get(tier, tier)}:", _HELP_HEADER)
        );
        cmds.sort(key=lambda (c: str) { c.name; });
        for cmd in cmds {
            padding = " " * (col - len(cmd.name));
            lines.append(f"    {_help_color(cmd.name, _HELP_CMD)}{padding}{cmd.help}");
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

impl get_help_formatter -> HelpFormatter {
    import from jaclang.cli.help { HelpFormatter }
    global _formatter;
    if _formatter is None {
        _formatter = HelpFormatter();
    }
    return _formatter;
}
