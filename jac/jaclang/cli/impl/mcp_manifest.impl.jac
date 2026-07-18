impl list_commands -> dict[str, any] {
    import from jaclang.cli.manifest { get_groups, iter_command_meta }

    commands: list[dict[str, any]] = [];
    for meta in iter_command_meta() {
        commands.append({'name': meta.name, 'help': meta.help, 'group': meta.group});
    }
    commands.sort(key=lambda (c: dict) { (c['group'], c['name']); });
    return {'commands': commands, 'groups': get_groups(), 'total': len(commands)};
}

impl get_command(name: str) -> dict[str, any] {
    import from jaclang.cli.manifest { get_command_meta }
    import from jaclang.cli.loader { load_handler }
    import from jaclang.cli.registry { get_registry }

    meta = get_command_meta(name);
    if meta is None {
        return {'error': f"Command not found: {name}"};
    }

    load_handler(name);
    spec = get_registry().get(name);
    if spec is None {
        return {'error': f"Command not found: {name}"};
    }

    args: list[dict[str, any]] = [];
    seen: set = set();
    for arg in spec.args {
        if arg.name in seen {
            continue;
        }
        seen.add(arg.name);
        info: dict[str, any] = {
            'name': arg.name,
            'kind': arg.kind.name,
            'type': getattr(arg.typ, '__name__', str(arg.typ)),
            'required': arg.required,
            'default': arg.default,
            'help': arg.help
        };
        if arg.short is not None {
            info['short'] = arg.short;
        }
        if arg.choices is not None {
            info['choices'] = list(arg.choices);
        }
        args.append(info);
    }

    return {
        'name': spec.name,
        'help': spec.help,
        'description': spec.description,
        'group': spec.group,
        'tier': spec.tier,
        'args': args,
        'examples': [{'command': c, 'description': d} for (c, d) in spec.examples]
    };
}
