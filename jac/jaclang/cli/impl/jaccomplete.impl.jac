"""Generate a static shell completion script from pre-processed command data."""
impl static_shellcode(
    commands: list, executable: str = "jac", shell: str = "bash"
) -> str {
    if shell == "fish" {
        return _static_fish(commands, executable);
    }
    if shell == "zsh" {
        return _static_zsh(commands, executable);
    }
    return _static_bash(commands, executable);
}

impl _static_bash(commands: list, exe: str) -> str {
    cmd_names = " ".join(c["name"] for c in commands);
    # Build per-command value-option cases
    value_cases: list = [];
    for c in commands {
        if not c["value_opts"] {
            continue;
        }
        prev_cases: list = [];
        for (long, short, choices) in c["value_opts"] {
            pattern = long;
            if short {
                pattern += "|" + short;
            }
            line = '                %s) COMPREPLY=($(compgen -W "%s" -- "$cur")); return ;;' % (
                pattern,
                " ".join(choices)
            );
            prev_cases.append(line);
        }
        value_cases.append(_BASH_VALUE_CASE % (c["name"], "\n".join(prev_cases)));
    }
    value_block = "";
    if value_cases {
        value_block = _BASH_VALUE_BLOCK % "\n".join(value_cases);
    }
    # Build per-command flag/positional cases
    cmd_cases: list = [];
    for c in commands {
        flags = " ".join(
            flag for (long, short, _) in c["flags"]
            for flag in ([long] + ([short] if short else []))
        );
        for (long, short, _) in c["value_opts"] {
            flags += " " + long;
            if short {
                flags += " " + short;
            }
        }

        if c["has_file_positional"] {
            cmd_cases.append(_BASH_CMD_WITH_FILES % (c["name"], flags));
        } else {
            cmd_cases.append(_BASH_CMD_NO_FILES % (c["name"], flags));
        }
    }
    return _BASH_TEMPLATE % (
        exe,
        cmd_names,
        value_block,
        "\n".join(cmd_cases),
        exe,
        exe
    );
}

impl _static_zsh(commands: list, exe: str) -> str {
    cmd_descs: list = [];
    for c in commands {
        h = c["help"].replace("'", "'\\''");
        cmd_descs.append("        '%s:%s'" % (c["name"], h));
    }
    subcases: list = [];
    for c in commands {
        args_lines: list = [];
        for (long, short, helptext) in c["flags"] {
            h = helptext.replace("'", "'\\''").replace("[", "\\[").replace("]", "\\]");
            if short {
                args_lines.append(
                    "                '(%s %s)'{%s,%s}'[%s]' \\" % (
                        short,
                        long,
                        short,
                        long,
                        h
                    )
                );
            } else {
                args_lines.append("                '%s[%s]' \\" % (long, h));
            }
        }
        for (long, short, choices) in c["value_opts"] {
            vals = " ".join(choices);
            if short {
                args_lines.append(
                    "                '(%s %s)'{%s,%s}'[]:value:(%s)' \\" % (
                        short,
                        long,
                        short,
                        long,
                        vals
                    )
                );
            } else {
                args_lines.append(
                    "                '%s[]:value:(%s)' \\" % (long, vals)
                );
            }
        }
        if c["has_file_positional"] {
            args_lines.append("                '*:file:_files' \\");
        }

        if args_lines {
            body = "            _arguments -s \\\n" + "\n".join(args_lines) + "\n                ;;";
        } else {
            body = "            ;;";
        }
        subcases.append("            %s)\n%s" % (c["name"], body));
    }
    return _ZSH_TEMPLATE % (exe, exe, "\n".join(cmd_descs), "\n".join(subcases), exe);
}

impl _static_fish(commands: list, exe: str) -> str {
    lines: list = ["# Fish completions for " + exe];
    lines.append("complete -c %s -f" % exe);
    # Subcommand completions
    for c in commands {
        h = c["help"].replace("'", "\\'");
        lines.append(
            "complete -c %s -n '__fish_use_subcommand' -a '%s' -d '%s'" % (
                exe,
                c["name"],
                h
            )
        );
    }
    # Per-command flags
    for c in commands {
        cond = "__fish_seen_subcommand_from " + c["name"];
        for (long, short, helptext) in c["flags"] {
            h = helptext.replace("'", "\\'");
            l = long.lstrip("-");
            parts = ["complete -c %s -n '%s' -l '%s'" % (exe, cond, l)];
            if short {
                parts.append("-s '%s'" % short.lstrip("-"));
            }
            parts.append("-d '%s'" % h);
            lines.append(" ".join(parts));
        }
        for (long, short, choices) in c["value_opts"] {
            l = long.lstrip("-");
            parts = ["complete -c %s -n '%s' -l '%s' -r" % (exe, cond, l)];
            if short {
                parts.append("-s '%s'" % short.lstrip("-"));
            }
            parts.append("-a '%s'" % " ".join(choices));
            lines.append(" ".join(parts));
        }
        if c["has_file_positional"] {
            lines.append("complete -c %s -n '%s' -F" % (exe, cond));
        }
    }
    return "\n".join(lines) + "\n";
}
