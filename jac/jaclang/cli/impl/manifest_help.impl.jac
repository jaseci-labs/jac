import os;
import sys;
import platform;

import from jaclang.cli.manifest {
    CommandMeta,
    GROUP_DISPLAY,
    GROUP_ORDER,
    TIER_ORDER,
    TIER_SECTIONS,
    iter_command_meta
}

glob _RESET: str = "\033[0m",
     _HEADER: str = "\033[1;34m",
     _CMD: str = "\033[32m",
     _PROG: str = "\033[1;35m",
     _TITLE: str = "\033[1m",
     _CYAN: str = "\033[36m",
     _BOLD_CYAN: str = "\033[1;36m";

impl _use_color -> bool {
    import from jaclang.cli.console { console }
    try {
        return bool(console.use_color);
    } except Exception {
        return False;
    }
}

def _color(text: str, code: str, use_color: bool | None = None) -> str {
    if use_color is None {
        use_color = _use_color();
    }
    if not use_color {
        return text;
    }
    return f"{code}{text}{_RESET}";
}

def _by_name(cmd: CommandMeta) -> str {
    return cmd.name;
}

def _render_command_block(
    cmds: list[CommandMeta], col: int, use_color: bool
) -> list[str] {
    cmds.sort(key=_by_name);
    lines: list[str] = [];
    for cmd in cmds {
        pad = ' ' * (col - len(cmd.name));
        lines.append(f"    {_color(cmd.name, _CMD, use_color)}{pad}{cmd.help}");
    }
    return lines;
}

impl format_verbose_help(prog: str = "jac") -> str {
    use_color = _use_color();
    commands = iter_command_meta();
    commands.sort(key=_by_name);
    lines: list[str] = [];
    lines.append(_color('The Jac programming language', _TITLE, use_color));
    lines.append('');
    lines.append(
        f"{_color('Usage:', _HEADER, use_color)} {_color(
            prog, _PROG, use_color
        )} [OPTIONS] COMMAND [ARGS]..."
    );
    lines.append('');
    lines.append(_color('Options:', _HEADER, use_color));
    lines.append(f"  {_color('-V, --version', _CMD, use_color)}");
    lines.append('          Print version info and exit');
    lines.append(f"  {_color('-h, --help', _CMD, use_color)}");
    lines.append('          Print help');
    lines.append('');

    grouped: dict[str, list[CommandMeta]] = {};
    for cmd in commands {
        grouped.setdefault(cmd.group or 'general', []).append(cmd);
    }

    col = 12;
    for cmd in commands {
        if len(cmd.name) >= col {
            col = len(cmd.name) + 2;
        }
    }

    for group in GROUP_ORDER {
        cmds = grouped.get(group);
        if not cmds {
            continue;
        }
        display = GROUP_DISPLAY.get(group, group.title());
        lines.append(_color(f"{display}:", _HEADER, use_color));
        lines.extend(_render_command_block(cmds, col, use_color));
        lines.append('');
    }

    for (group, cmds) in grouped.items() {
        if group in GROUP_ORDER {
            continue;
        }
        display = GROUP_DISPLAY.get(group, group.title());
        lines.append(_color(f"{display}:", _HEADER, use_color));
        lines.extend(_render_command_block(cmds, col, use_color));
        lines.append('');
    }

    lines.append(
        f"See '{prog} COMMAND --help' for more information on a specific command."
    );
    return '\n'.join(lines);
}

impl format_curated_help(prog: str = "jac") -> str {
    use_color = _use_color();
    commands = iter_command_meta();
    lines: list[str] = [];
    lines.append(_color('The Jac programming language', _TITLE, use_color));
    lines.append('');
    lines.append(
        f"{_color('Usage:', _HEADER, use_color)} {_color(
            prog, _PROG, use_color
        )} [OPTIONS] COMMAND [ARGS]..."
    );
    lines.append('');

    by_tier: dict[str, list[CommandMeta]] = {};
    for cmd in commands {
        if cmd.tier {
            by_tier.setdefault(cmd.tier, []).append(cmd);
        }
    }

    col = 12;
    for cmd in commands {
        if cmd.tier and len(cmd.name) >= col {
            col = len(cmd.name) + 2;
        }
    }

    for tier in TIER_ORDER {
        cmds = by_tier.get(tier, []);
        if not cmds {
            continue;
        }
        lines.append(_color(f"{TIER_SECTIONS.get(tier, tier)}:", _HEADER, use_color));
        lines.extend(_render_command_block(cmds, col, use_color));
        lines.append('');
    }

    lines.append(
        f"AI agents: run `{prog} guide` first to learn how to build with Jac."
    );
    lines.append('');
    lines.append(f"  {prog} --help          Show all commands");
    lines.append(f"  {prog} COMMAND --help  Show help for a command");
    return '\n'.join(lines);
}

impl format_logo(version: str) -> str {
    logo = [
        '   _',
        '  (_) __ _  ___',
        '  | |/ _` |/ __|',
        '  | | (_| | (__',
        ' _/ |\\__,_|\\___|',
        '|__/'
    ];
    if platform.system() == 'Linux' {
        plat = f"Linux {platform.machine()}";
    } elif platform.system() == 'Darwin' {
        plat = f"macOS {platform.machine()}";
    } elif platform.system() == 'Windows' {
        plat = f"Windows {platform.machine()}";
    } else {
        plat = platform.platform();
    }

    use_color = _use_color();

    lines = [
        _color(logo[0], _BOLD_CYAN, use_color),
        f"{_color(logo[1], _BOLD_CYAN, use_color)}     Jac Language",
        _color(logo[2], _BOLD_CYAN, use_color),
        f"{_color(logo[3], _CYAN, use_color)}     Version:  {version}",
        _color(logo[4], _CYAN, use_color),
        f"{_color(logo[5], _CYAN, use_color)}                Platform: {plat}"
    ];
    return '\n'.join(lines);
}
