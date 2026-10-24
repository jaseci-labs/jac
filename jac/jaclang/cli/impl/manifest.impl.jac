glob _COMMANDS: dict[str, CommandSpec] = {},
     _COMMANDS_LOADED: bool = False;

def _ensure_commands_loaded;

impl get_command_meta(name: str) -> CommandSpec | None {
    _ensure_commands_loaded();
    return _COMMANDS.get(name);
}

impl iter_command_meta(include_hidden: bool = False) -> list[CommandSpec] {
    _ensure_commands_loaded();
    out: list[CommandSpec] = [];
    for meta in _COMMANDS.values() {
        if not include_hidden and meta.hidden {
            continue;
        }
        out.append(meta);
    }
    return out;
}

impl known_command_names(include_hidden: bool = False) -> set[str] {
    return {meta.name for meta in iter_command_meta(include_hidden=include_hidden)};
}

impl get_groups -> list[str] {
    groups = {meta.group for meta in iter_command_meta(include_hidden=True)};
    return sorted(groups);
}

impl _ensure_commands_loaded {
    if _COMMANDS_LOADED {
        return;
    }
    built: dict[str, CommandSpec] = {};
    for meta in ROUTES {
        built[meta.name] = meta;
    }
    _COMMANDS = built;
    _COMMANDS_LOADED = True;
}
