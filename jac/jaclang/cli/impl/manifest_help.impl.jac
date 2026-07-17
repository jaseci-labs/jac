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
     _TITLE: str = "\033[1m";

def _use_color -> bool {
    if os.environ.get('NO_COLOR') {
        return False;
    }
    return sys.stdout?.isatty and sys.stdout.isatty();
}

def _color(text: str, code: str) -> str {
    if not _use_color() {
        return text;
    }
    return f"{code}{text}\033[0m";
}

def _by_name(cmd: CommandMeta) -> str {
    return cmd.name;
}

impl format_verbose_help(prog: str = "jac") -> str {
    commands = iter_command_meta();
    commands.sort(key=_by_name);
    lines: list[str] = [];
    lines.append(_color('The Jac programming language', _TITLE));
    lines.append('');
    lines.append(
        f"{_color('Usage:', _HEADER)} {_color(prog, _PROG)} [OPTIONS] COMMAND [ARGS]..."
    );
    lines.append('');
    lines.append(_color('Options:', _HEADER));
    lines.append(f"  {_color('-V, --version', _CMD)}");
    lines.append('          Print version info and exit');
    lines.append(f"  {_color('-h, --help', _CMD)}");
    lines.append('          Print help');
    lines.append('');

    grouped: dict[str, list] = {};
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
        lines.append(_color(f"{display}:", _HEADER));
        cmds.sort(key=_by_name);
        for cmd in cmds {
            pad = ' ' * (col - len(cmd.name));
            lines.append(f"    {_color(cmd.name, _CMD)}{pad}{cmd.help}");
        }
        lines.append('');
    }

    for (group, cmds) in grouped.items() {
        if group in GROUP_ORDER {
            continue;
        }
        display = GROUP_DISPLAY.get(group, group.title());
        lines.append(_color(f"{display}:", _HEADER));
        cmds.sort(key=_by_name);
        for cmd in cmds {
            pad = ' ' * (col - len(cmd.name));
            lines.append(f"    {_color(cmd.name, _CMD)}{pad}{cmd.help}");
        }
        lines.append('');
    }

    lines.append(
        f"See '{prog} COMMAND --help' for more information on a specific command."
    );
    return '\n'.join(lines);
}

impl format_curated_help(prog: str = "jac") -> str {
    commands = iter_command_meta();
    lines: list[str] = [];
    lines.append(_color('The Jac programming language', _TITLE));
    lines.append('');
    lines.append(
        f"{_color('Usage:', _HEADER)} {_color(prog, _PROG)} [OPTIONS] COMMAND [ARGS]..."
    );
    lines.append('');

    by_tier: dict[str, list] = {};
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
        lines.append(_color(f"{TIER_SECTIONS.get(tier, tier)}:", _HEADER));
        cmds.sort(key=_by_name);
        for cmd in cmds {
            pad = ' ' * (col - len(cmd.name));
            lines.append(f"    {_color(cmd.name, _CMD)}{pad}{cmd.help}");
        }
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
    cyan = '\033[36m' if use_color else '';
    bold_cyan = '\033[1;36m' if use_color else '';
    reset = _RESET if use_color else '';

    lines = [
        f"{bold_cyan}{logo[0]}{reset}",
        f"{bold_cyan}{logo[1]}     Jac Language{reset}",
        f"{bold_cyan}{logo[2]}{reset}",
        f"{cyan}{logo[3]}     Version:  {version}{reset}",
        f"{cyan}{logo[4]}{reset}",
        f"{cyan}{logo[5]}                Platform: {plat}{reset}"
    ];
    return '\n'.join(lines);
}
