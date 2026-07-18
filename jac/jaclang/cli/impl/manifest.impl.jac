glob _COMMAND_ROUTES: list[tuple[str, str, str, str, bool, str, str, list[str]]] = [
         (
             'ai',
             'Launch an interactive Jac coding agent',
             'general',
             '',
             False,
             'jaclang.cli.commands.ai',
             'ai',
             []
         ),
         (
             'browse',
             'Headless browser automation over CDP (open, click, snapshot, ...)',
             'tools',
             '',
             True,
             'jaclang.cli.commands.browse',
             'browse',
             []
         ),
         (
             'build',
             'Build a sealed .jab artifact (type-checks first)',
             'build',
             '',
             False,
             'jaclang.cli.commands.build',
             'build',
             ['providers', 'client']
         ),
         (
             'check',
             'Type check Jac files',
             'analysis',
             'core',
             False,
             'jaclang.cli.commands.analysis',
             'check',
             []
         ),
         (
             'clean',
             'Clean project build artifacts',
             'project',
             '',
             False,
             'jaclang.cli.commands.project',
             'clean',
             ['providers']
         ),
         (
             'code',
             "Query code structure via the compiler (grep's structural successor)",
             'analysis',
             '',
             False,
             'jaclang.cli.commands.code',
             'code',
             []
         ),
         (
             'completions',
             'Generate shell completion script',
             'tools',
             '',
             True,
             'jaclang.cli.commands.tools',
             'completions',
             []
         ),
         (
             'config',
             'Manage Jac configuration',
             'config',
             '',
             False,
             'jaclang.cli.commands.config',
             'config',
             []
         ),
         (
             'create',
             'Create a new Jac project',
             'project',
             'core',
             False,
             'jaclang.cli.commands.project',
             'create',
             ['providers', 'templates']
         ),
         (
             'db',
             'Inspect, rescue, and manage Jac persistence databases',
             'db',
             '',
             False,
             'jaclang.cli.commands.db',
             'db',
             []
         ),
         (
             'dev',
             'Serve with hot reload and live compilation',
             'execution',
             'core',
             False,
             'jaclang.cli.commands.execution',
             'dev',
             ['providers']
         ),
         (
             'dot',
             'Generate graph visualization (DOT format)',
             'tools',
             '',
             True,
             'jaclang.cli.commands.tools',
             'dot',
             []
         ),
         (
             'fmt',
             'Format Jac source code',
             'analysis',
             'core',
             False,
             'jaclang.cli.commands.analysis',
             'format',
             []
         ),
         (
             'gen-jir-registry',
             'Regenerate jir_registry.jac from unitree node classes',
             'tools',
             '',
             True,
             'jaclang.cli.commands.tools',
             'gen_jir_registry',
             []
         ),
         (
             'gen-uni-dispatch',
             'Regenerate static enter_node/exit_node dispatch for UniPass subclasses',
             'tools',
             '',
             True,
             'jaclang.cli.commands.tools',
             'gen_uni_dispatch',
             []
         ),
         (
             'gen_parser',
             'Generate Jac parser (internal use)',
             'analysis',
             '',
             True,
             'jaclang.cli.commands.analysis',
             'gen_parser',
             []
         ),
         (
             'guide',
             'Show curated Jac reference guides',
             'general',
             'learn',
             False,
             'jaclang.cli.commands.guide',
             'guide',
             []
         ),
         (
             'install',
             'Install project dependencies',
             'project',
             '',
             False,
             'jaclang.cli.commands.project',
             'install',
             ['providers']
         ),
         (
             'lsp',
             'Start Jac language server',
             'tools',
             '',
             False,
             'jaclang.cli.commands.tools',
             'lsp',
             []
         ),
         (
             'model',
             'Manage byllm local-model weights (Gemma 4 and friends)',
             'config',
             '',
             False,
             'jaclang.byllm.cli',
             'model',
             []
         ),
         (
             'nacompile',
             "Compile a Jac file to a standalone native binary (prefer 'jac build --as native' for projects)",
             'transform',
             '',
             True,
             'jaclang.cli.commands.nacompile',
             'nacompile',
             []
         ),
         (
             'ninja',
             'Open the built-in jac editor (fused Neovim + LSP + tree-sitter)',
             'tools',
             '',
             False,
             'jaclang.cli.commands.tools',
             'ninja',
             []
         ),
         (
             'precommit',
             'Run fmt (--lintfix) + check using jac.toml lint settings; installable as a git hook',
             'analysis',
             '',
             True,
             'jaclang.cli.commands.analysis',
             'precommit',
             []
         ),
         (
             'remove',
             'Remove a dependency from the project',
             'project',
             '',
             False,
             'jaclang.cli.commands.project',
             'remove',
             ['providers']
         ),
         (
             'retheme',
             'Re-theme a jac-shadcn project: regenerate global.css from [jac-shadcn]',
             'project',
             '',
             False,
             'jaclang.cli.shadcn.cli',
             'retheme',
             []
         ),
         (
             'run',
             'Run a Jac program',
             'execution',
             'core',
             False,
             'jaclang.cli.commands.execution',
             'run',
             ['providers']
         ),
         (
             'scale',
             'Manage scale deployments: local microservices (status/stop/restart/logs) and platform deployments (status/destroy on a .jac app)',
             'microservices',
             '',
             False,
             'jaclang.scale.plugin',
             'scale_cmd',
             ['providers']
         ),
         (
             'setup',
             'Setup a build target (one-time initialization)',
             'project',
             '',
             False,
             'jaclang.runtimelib.client.cli',
             'setup',
             ['providers', 'client']
         ),
         (
             'start',
             'Start server for a Jac program',
             'execution',
             'core',
             False,
             'jaclang.cli.commands.execution',
             'start',
             ['providers', 'client']
         ),
         (
             'test',
             'Run Jac test suite',
             'analysis',
             'core',
             False,
             'jaclang.cli.commands.analysis',
             'test',
             []
         ),
         (
             'tool',
             'Run AST tools',
             'tools',
             '',
             False,
             'jaclang.cli.commands.tools',
             'tool',
             []
         ),
         (
             'update',
             'Update project dependencies to latest compatible versions',
             'project',
             '',
             False,
             'jaclang.cli.commands.project',
             'update',
             ['providers']
         ),
         (
             'x',
             'Run an installed CLI tool (console-script) under the Jac runtime',
             'execution',
             '',
             False,
             'jaclang.cli.commands.execution',
             'x',
             ['providers']
         )
     ];

glob _COMMANDS: dict[str, CommandMeta] = {},
     _COMMANDS_LOADED: bool = False;

def _ensure_commands_loaded {
    if _COMMANDS_LOADED {
        return;
    }
    built: dict[str, CommandMeta] = {};
    for row in _COMMAND_ROUTES {
        meta = CommandMeta(
            name=row[0],
            help=row[1],
            group=row[2],
            tier=row[3],
            hidden=row[4],
            handler_module=row[5],
            handler_name=row[6],
            needs=row[7]
        );
        built[meta.name] = meta;
    }
    _COMMANDS = built;
    _COMMANDS_LOADED = True;
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

    for (nm, meta) in _COMMANDS.items() {
        if not meta.handler_module or not meta.handler_name {
            errors.append(f"{nm}: missing handler reference");
        }
        if meta.tier and meta.tier not in TIER_SECTIONS {
            errors.append(f"{nm}: unknown tier {meta.tier!r}");
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
