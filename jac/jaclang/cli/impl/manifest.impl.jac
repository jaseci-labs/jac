def _command_routes -> list[CommandMeta] {
    return [
        CommandMeta(
            name='ai',
            help='Launch an interactive Jac coding agent',
            group='general',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.ai',
            handler_name='ai',
            needs=[]
        ),
        CommandMeta(
            name='browse',
            help='Headless browser automation over CDP (open, click, snapshot, ...)',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.browse',
            handler_name='browse',
            needs=[]
        ),
        CommandMeta(
            name='build',
            help='Build a sealed .jab artifact (type-checks first)',
            group='build',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.build',
            handler_name='build',
            needs=['providers', 'client']
        ),
        CommandMeta(
            name='check',
            help='Type check Jac files',
            group='analysis',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.analysis',
            handler_name='check',
            needs=[]
        ),
        CommandMeta(
            name='clean',
            help='Clean project build artifacts',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.project',
            handler_name='clean',
            needs=['providers']
        ),
        CommandMeta(
            name='code',
            help="Query code structure via the compiler (grep's structural successor)",
            group='analysis',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.code',
            handler_name='code',
            needs=[]
        ),
        CommandMeta(
            name='completions',
            help='Generate shell completion script',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.tools',
            handler_name='completions',
            needs=[]
        ),
        CommandMeta(
            name='config',
            help='Manage Jac configuration',
            group='config',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.config',
            handler_name='config',
            needs=[]
        ),
        CommandMeta(
            name='create',
            help='Create a new Jac project',
            group='project',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.project',
            handler_name='create',
            needs=['providers', 'templates']
        ),
        CommandMeta(
            name='db',
            help='Inspect, rescue, and manage Jac persistence databases',
            group='db',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.db',
            handler_name='db',
            needs=[]
        ),
        CommandMeta(
            name='dev',
            help='Serve with hot reload and live compilation',
            group='execution',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.execution',
            handler_name='dev',
            needs=['providers']
        ),
        CommandMeta(
            name='dot',
            help='Generate graph visualization (DOT format)',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.tools',
            handler_name='dot',
            needs=[]
        ),
        CommandMeta(
            name='fmt',
            help='Format Jac source code',
            group='analysis',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.analysis',
            handler_name='format',
            needs=[]
        ),
        CommandMeta(
            name='gen-jir-registry',
            help='Regenerate jir_registry.jac from unitree node classes',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.tools',
            handler_name='gen_jir_registry',
            needs=[]
        ),
        CommandMeta(
            name='gen-uni-dispatch',
            help='Regenerate static enter_node/exit_node dispatch for UniPass subclasses',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.tools',
            handler_name='gen_uni_dispatch',
            needs=[]
        ),
        CommandMeta(
            name='gen_parser',
            help='Generate Jac parser (internal use)',
            group='analysis',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.analysis',
            handler_name='gen_parser',
            needs=[]
        ),
        CommandMeta(
            name='guide',
            help='Show curated Jac reference guides',
            group='general',
            tier='learn',
            hidden=False,
            handler_module='jaclang.cli.commands.guide',
            handler_name='guide',
            needs=[]
        ),
        CommandMeta(
            name='install',
            help='Install project dependencies',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.project',
            handler_name='install',
            needs=['providers']
        ),
        CommandMeta(
            name='lsp',
            help='Start Jac language server',
            group='tools',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.tools',
            handler_name='lsp',
            needs=[]
        ),
        CommandMeta(
            name='model',
            help='Manage byllm local-model weights (Gemma 4 and friends)',
            group='config',
            tier='',
            hidden=False,
            handler_module='jaclang.byllm.cli',
            handler_name='model',
            needs=[]
        ),
        CommandMeta(
            name='nacompile',
            help="Compile a Jac file to a standalone native binary (prefer 'jac build --as native' for projects)",
            group='transform',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.nacompile',
            handler_name='nacompile',
            needs=[]
        ),
        CommandMeta(
            name='ninja',
            help='Open the built-in jac editor (fused Neovim + LSP + tree-sitter)',
            group='tools',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.tools',
            handler_name='ninja',
            needs=[]
        ),
        CommandMeta(
            name='precommit',
            help='Run fmt (--lintfix) + check using jac.toml lint settings; installable as a git hook',
            group='analysis',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.analysis',
            handler_name='precommit',
            needs=[]
        ),
        CommandMeta(
            name='remove',
            help='Remove a dependency from the project',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.project',
            handler_name='remove',
            needs=['providers']
        ),
        CommandMeta(
            name='retheme',
            help='Re-theme a jac-shadcn project: regenerate global.css from [jac-shadcn]',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.shadcn.cli',
            handler_name='retheme',
            needs=[]
        ),
        CommandMeta(
            name='run',
            help='Run a Jac program',
            group='execution',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.execution',
            handler_name='run',
            needs=['providers']
        ),
        CommandMeta(
            name='scale',
            help='Manage scale deployments: local microservices (status/stop/restart/logs) and platform deployments (status/destroy on a .jac app)',
            group='microservices',
            tier='',
            hidden=False,
            handler_module='jaclang.scale.plugin',
            handler_name='scale_cmd',
            needs=['providers']
        ),
        CommandMeta(
            name='setup',
            help='Setup a build target (one-time initialization)',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.runtimelib.client.cli',
            handler_name='setup',
            needs=['providers', 'client']
        ),
        CommandMeta(
            name='start',
            help='Start server for a Jac program',
            group='execution',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.execution',
            handler_name='start',
            needs=['providers', 'client']
        ),
        CommandMeta(
            name='test',
            help='Run Jac test suite',
            group='analysis',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.analysis',
            handler_name='test',
            needs=[]
        ),
        CommandMeta(
            name='tool',
            help='Run AST tools',
            group='tools',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.tools',
            handler_name='tool',
            needs=[]
        ),
        CommandMeta(
            name='update',
            help='Update project dependencies to latest compatible versions',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.project',
            handler_name='update',
            needs=['providers']
        ),
        CommandMeta(
            name='x',
            help='Run an installed CLI tool (console-script) under the Jac runtime',
            group='execution',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.execution',
            handler_name='x',
            needs=['providers']
        )
    ];
}

glob _COMMANDS: dict[str, CommandMeta] = {},
     _COMMANDS_LOADED: bool = False;

def _ensure_commands_loaded {
    if _COMMANDS_LOADED {
        return;
    }
    built: dict[str, CommandMeta] = {};
    for meta in _command_routes() {
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
