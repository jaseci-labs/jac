import json;
import from pathlib { Path }

glob _COMMANDS: dict[str, CommandMeta] = {},
     _COMMANDS_LOADED: bool = False;

def _manifest_data_path -> Path {
    return Path(__file__).parent / '_manifest_data.json';
}

def _ensure_commands_loaded {
    global _COMMANDS,_COMMANDS_LOADED;
    if _COMMANDS_LOADED {
        return;
    }
    path = _manifest_data_path();
    payload = json.loads(path.read_text(encoding='utf-8'));
    raw_commands = payload.get('commands', []);
    for raw in raw_commands {
        meta = _parse_command(raw);
        _COMMANDS[meta.name] = meta;
    }
    _COMMANDS_LOADED = True;
}

def _parse_arg(raw: dict) -> ArgMeta {
    kind_raw = raw['kind'];
    if isinstance(kind_raw, str) and kind_raw.startswith('ArgKind.') {
        kind_raw = kind_raw.split('.', 1)[1];
    }
    choices = raw.get('choices');
    return ArgMeta(
        name=raw['name'],
        kind=ArgKind[kind_raw],
        typ=raw.get('typ', 'str'),
        `default=raw.get('default'),
        help=raw.get('help', ''),
        short=raw.get('short'),
        choices=list(choices) if choices else None,
        required=bool(raw.get('required', False)),
        dest=raw.get('dest'),
        metavar=raw.get('metavar')
    );
}

def _parse_command(raw: dict) -> CommandMeta {
    examples: list[tuple[str, str]] = [];
    for entry in raw.get('examples', []) {
        if len(entry) >= 2 {
            examples.append((entry[0], entry[1]));
        } elif len(entry) == 1 {
            examples.append((entry[0], ''));
        }
    }
    args = [_parse_arg(a) for a in raw.get('args', [])];
    return CommandMeta(
        name=raw['name'],
        help=raw['help'],
        description=raw.get('description', ''),
        group=raw.get('group', 'general'),
        tier=raw.get('tier', ''),
        hidden=bool(raw.get('hidden', False)),
        examples=examples,
        args=args,
        handler_module=raw['handler_module'],
        handler_name=raw['handler_name']
    );
}

impl validate_manifest -> list[str] {
    _ensure_commands_loaded();
    errors: list[str] = [];
    names = list(_COMMANDS.keys());
    if len(names) != len(set(names)) {
        errors.append('duplicate command names in manifest');
    }

    visible = [
        n
        for (n, m) in _COMMANDS.items()
        if not m.hidden
    ];
    if len(visible) > VERB_BUDGET {
        errors.append(
            f"{len(visible)} visible verbs exceed budget of {VERB_BUDGET}: {sorted(
                visible
            )}"
        );
    }

    revived = sorted(
        v
        for v in TOMBSTONED_VERBS
        if v in _COMMANDS
    );
    if revived {
        errors.append(f"tombstoned verb(s) present in manifest: {revived}");
    }

    for (name, meta) in _COMMANDS.items() {
        if not meta.handler_module or not meta.handler_name {
            errors.append(f"{name}: missing handler reference");
        }
        if meta.tier and meta.tier not in TIER_SECTIONS {
            errors.append(f"{name}: unknown tier {meta.tier!r}");
        }
    }
    return errors;
}

impl get_command_meta(name: str) -> CommandMeta | None {
    _ensure_commands_loaded();
    return _COMMANDS.get(name);
}

impl iter_command_meta(include_hidden: bool = False) -> list[CommandMeta] {
    _ensure_commands_loaded();
    out: list[CommandMeta] = [];
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
