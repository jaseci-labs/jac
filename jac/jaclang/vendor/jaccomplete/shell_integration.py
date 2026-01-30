"""Shell completion script generation for bash, zsh, and fish."""


def static_shellcode(commands, executable="jac", shell="bash"):
    """Generate a static shell completion script from pre-processed command data.

    commands: list of dicts, each with:
        name: str
        help: str
        flags: list of (long_flag, short_flag_or_None, help_text)
        value_opts: list of (long_flag, short_flag_or_None, choices_list)
        has_file_positional: bool
    """
    if shell == "fish":
        return _static_fish(commands, executable)
    if shell == "zsh":
        return _static_zsh(commands, executable)
    return _static_bash(commands, executable)


def _static_bash(commands, exe):
    cmd_names = " ".join(c["name"] for c in commands)

    # Build per-command value-option cases (e.g. --shell bash zsh fish)
    value_cases = []
    for c in commands:
        if not c["value_opts"]:
            continue
        prev_cases = []
        for long, short, choices in c["value_opts"]:
            pattern = f"{long}"
            if short:
                pattern += f"|{short}"
            prev_cases.append(
                f'                {pattern}) COMPREPLY=($(compgen -W "{" ".join(choices)}" -- "$cur")); return ;;'
            )
        value_cases.append(
            f"        {c['name']})\n"
            f"            case \"$prev\" in\n"
            + "\n".join(prev_cases) + "\n"
            f"            esac\n"
            f"            ;;"
        )

    value_block = ""
    if value_cases:
        value_block = (
            "    # Complete option values\n"
            "    case \"$cmd\" in\n"
            + "\n".join(value_cases) + "\n"
            "    esac\n\n"
        )

    # Build per-command flag/positional cases
    cmd_cases = []
    for c in commands:
        flags = " ".join(
            f for long, short, _ in c["flags"]
            for f in ([long] + ([short] if short else []))
        )
        # Also include value option flags in the flag list
        for long, short, _ in c["value_opts"]:
            flags += f" {long}"
            if short:
                flags += f" {short}"

        if c["has_file_positional"]:
            body = (
                f"            case \"$cur\" in\n"
                f"                -*) COMPREPLY=($(compgen -W \"{flags}\" -- \"$cur\")) ;;\n"
                f"            esac"
            )
        else:
            body = f"            COMPREPLY=($(compgen -W \"{flags}\" -- \"$cur\"))"

        cmd_cases.append(f"        {c['name']})\n{body}\n            ;;")

    return (
        f"_{exe}_complete() {{\n"
        f"    local cur prev cmd\n"
        f"    COMPREPLY=()\n"
        f"    cur=\"${{COMP_WORDS[COMP_CWORD]}}\"\n"
        f"    prev=\"${{COMP_WORDS[COMP_CWORD-1]}}\"\n"
        f"    cmd=\"${{COMP_WORDS[1]}}\"\n"
        f"\n"
        f"    if [[ $COMP_CWORD -eq 1 ]]; then\n"
        f"        COMPREPLY=($(compgen -W \"{cmd_names}\" -- \"$cur\"))\n"
        f"        return\n"
        f"    fi\n"
        f"\n"
        f"{value_block}"
        f"    case \"$cmd\" in\n"
        + "\n".join(cmd_cases) + "\n"
        f"    esac\n"
        f"}}\n"
        f"complete -o default -o bashdefault -F _{exe}_complete {exe}\n"
    )


def _static_zsh(commands, exe):
    # Generate native zsh completion with descriptions
    cmd_descs = []
    for c in commands:
        h = c["help"].replace("'", "'\\''")
        cmd_descs.append(f"        '{c['name']}:{h}'")

    subcases = []
    for c in commands:
        args_lines = []
        for long, short, helptext in c["flags"]:
            h = helptext.replace("'", "'\\''").replace("[", "\\[").replace("]", "\\]")
            if short:
                args_lines.append(f"                '({short} {long})'{{{short},{long}}}'[{h}]' \\")
            else:
                args_lines.append(f"                '{long}[{h}]' \\")
        for long, short, choices in c["value_opts"]:
            vals = " ".join(choices)
            if short:
                args_lines.append(
                    f"                '({short} {long})'{{{short},{long}}}'[]:value:({vals})' \\"
                )
            else:
                args_lines.append(f"                '{long}[]:value:({vals})' \\")
        if c["has_file_positional"]:
            args_lines.append("                '*:file:_files' \\")

        if args_lines:
            body = "            _arguments -s \\\n" + "\n".join(args_lines) + "\n                ;;"
        else:
            body = "            ;;"
        subcases.append(f"            {c['name']})\n{body}")

    return (
        f"#compdef {exe}\n"
        f"_{exe}() {{\n"
        f"    local -a commands\n"
        f"    commands=(\n"
        + "\n".join(cmd_descs) + "\n"
        f"    )\n"
        f"\n"
        f"    _arguments -C \\\n"
        f"        '1:command:->command' \\\n"
        f"        '*::arg:->args'\n"
        f"\n"
        f"    case $state in\n"
        f"        command)\n"
        f"            _describe 'command' commands\n"
        f"            ;;\n"
        f"        args)\n"
        f"            case $words[1] in\n"
        + "\n".join(subcases) + "\n"
        f"            esac\n"
        f"            ;;\n"
        f"    esac\n"
        f"}}\n"
        f"_{exe} \"$@\"\n"
    )


def _static_fish(commands, exe):
    lines = [f"# Fish completions for {exe}"]
    # Disable file completion by default, enable per-command
    lines.append(f"complete -c {exe} -f")
    # Subcommand completions (only at top level)
    for c in commands:
        h = c["help"].replace("'", "\\'")
        lines.append(
            f"complete -c {exe} -n '__fish_use_subcommand' -a '{c['name']}' -d '{h}'"
        )
    # Per-command flags
    for c in commands:
        cond = f"__fish_seen_subcommand_from {c['name']}"
        for long, short, helptext in c["flags"]:
            h = helptext.replace("'", "\\'")
            l = long.lstrip("-")
            parts = [f"complete -c {exe} -n '{cond}' -l '{l}'"]
            if short:
                parts.append(f"-s '{short.lstrip('-')}'")
            parts.append(f"-d '{h}'")
            lines.append(" ".join(parts))
        for long, short, choices in c["value_opts"]:
            l = long.lstrip("-")
            parts = [f"complete -c {exe} -n '{cond}' -l '{l}' -r"]
            if short:
                parts.append(f"-s '{short.lstrip('-')}'")
            parts.append(f"-a '{' '.join(choices)}'")
            lines.append(" ".join(parts))
        if c["has_file_positional"]:
            lines.append(f"complete -c {exe} -n '{cond}' -F")
    return "\n".join(lines) + "\n"
