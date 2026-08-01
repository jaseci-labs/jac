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
            examples=[
                (
                    'jac ai',
                    "Start a session (uses jac.toml's model, else local default)"
                ),
                ('jac ai "add a walker to main.jac"', 'Run a single request and exit'),
                (
                    'jac ai -m openai/gpt-4o',
                    'Use a cloud model (key from jac.toml or env)'
                ),
                ('jac ai -m local:gemma-4-e2b', 'Use a smaller/faster local model'),
                (
                    'jac ai --n_ctx 32768',
                    'Give the local model a larger context window'
                ),
                ('jac ai --safe', 'Approve each file write and command before it runs'),
                (
                    'jac ai -q "fix the build"',
                    'Compact output -- just tool calls and the answer'
                ),
                (
                    'jac ai --ui',
                    'Open a web UI with a live agent phase-graph visualizer'
                )
            ],
            args=[
                ArgMeta(
                    name='prompt',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Optional one-shot request; omit for an interactive session'
                ),
                ArgMeta(
                    name='model',
                    default='',
                    help='Model to use, e.g. local:gemma-4-e4b or openai/gpt-4o',
                    short='m'
                ),
                ArgMeta(
                    name='n_ctx',
                    typ='int',
                    default=0,
                    help='Context-window size for local models (tokens)',
                    short='n'
                ),
                ArgMeta(
                    name='safe',
                    kind=ArgKind.FLAG,
                    typ='bool',
                    default=False,
                    help='Confirm every file write and code execution (off by default)',
                    short='s'
                ),
                ArgMeta(
                    name='quiet',
                    kind=ArgKind.FLAG,
                    typ='bool',
                    default=False,
                    help='Compact output: hide live reasoning, timings, and step detail',
                    short='q'
                ),
                ArgMeta(
                    name='ui',
                    kind=ArgKind.FLAG,
                    typ='bool',
                    default=False,
                    help='Open the agent in a web UI with a live phase-graph visualizer',
                    short='u'
                ),

            ]
        ),
        CommandMeta(
            name='browse',
            help='Headless browser automation over CDP (open, click, snapshot, ...)',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.browse',
            handler_name='browse',
            examples=[
                ('jac browse open example.com', 'Launch a browser and navigate'),
                ('jac browse snapshot', 'Accessibility tree with @e1/@e2 refs'),
                (
                    'jac browse click @e5',
                    'Click an element by snapshot ref (real input)'
                ),
                ("jac browse fill '#email' you@example.com", 'Clear and fill a field'),
                ('jac browse get title', 'Read the page title'),
                ("jac browse wait '#app'", 'Wait until a selector is actionable'),
                ('jac browse console', 'Read buffered console/log output'),
                ('jac browse scroll down', 'Scroll the page by ~one viewport'),
                (
                    'jac browse -s work open example.com',
                    "Use an isolated 'work' session"
                ),
                ('jac browse state save auth.json', 'Save cookies + localStorage'),
                ('jac browse close', 'Close the browser')
            ],
            args=[
                ArgMeta(
                    name='action',
                    kind=ArgKind.POSITIONAL,
                    help='open|navigate|click|type|fill|press|get|eval|wait|scroll|console|snapshot|screenshot|state|sessions|close',
                    required=True
                ),
                ArgMeta(
                    name='args',
                    kind=ArgKind.REMAINDER,
                    default=[],
                    help='Arguments for the action (selector, url, text, path, ...)',
                    short='a'
                ),
                ArgMeta(
                    name='session',
                    default='default',
                    help='Session name; each session is an isolated browser instance',
                    short='s'
                ),
                ArgMeta(
                    name='viewport',
                    default='1280x720',
                    help='Browser window size as WIDTHxHEIGHT (applied at open)',
                    short='v'
                ),

            ]
        ),
        CommandMeta(
            name='build',
            help='Build a sealed .jab artifact (type-checks first)',
            group='build',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.build',
            handler_name='build',
            examples=[
                ('jac build', 'Gate + build a single .jab into dist/'),
                ('jac build --as binary', 'Gate + build a self-contained executable'),
                ('jac build --fat', 'Gate + build a fat jab (Python deps vendored)'),
                ('jac build --as wheel', 'Gate + build a PyPI wheel'),
                ('jac build --check_only', 'Run the whole-program gate only'),
                ('jac build --no_typecheck', 'Build without the gate (escape hatch)'),
                ('jac build --client mobile', 'Build the mobile client shell')
            ],
            args=[
                ArgMeta(
                    name='filename',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Entry .jac file (default: [project] entry-point from jac.toml)'
                ),
                ArgMeta(
                    name='as',
                    default='jab',
                    help="What to emit: 'jab' (single-file sealed app bundle, default), 'sealed' (unpacked image dir), 'binary' (self-contained executable), 'wheel' (PyPI), 'npm' (tarball), 'source' (ejected FastAPI+JS tree), 'native' (AOT native binary)",
                    short='a',
                    choices=[
                        'jab',
                        'sealed',
                        'binary',
                        'wheel',
                        'npm',
                        'source',
                        'native'
                    ],
                    dest='projection'
                ),
                ArgMeta(
                    name='output',
                    default='dist',
                    help='Output directory for the built artifact',
                    short='o'
                ),
                ArgMeta(
                    name='no_typecheck',
                    typ='bool',
                    default=False,
                    help='Skip the whole-program type-check gate (escape hatch)',
                    short='n'
                ),
                ArgMeta(
                    name='fat',
                    typ='bool',
                    default=False,
                    help='Vendor the Python dependency closure as wheels into the bundle (jab/binary only) so it materializes offline, with no PyPI',
                    short='f'
                ),
                ArgMeta(
                    name='check_only',
                    typ='bool',
                    default=False,
                    help='Run the gate and emit nothing',
                    short='c'
                ),
                ArgMeta(
                    name='client',
                    default='',
                    help='Build a client shell instead of the artifact: web, pwa, mobile, desktop (desktop builds a native webview app).',
                    short='',
                    choices=[
                        'web',
                        'pwa',
                        'static',
                        'mobile',
                        'desktop',
                        'cef',
                        'react-native'
                    ]
                ),
                ArgMeta(
                    name='platform',
                    help='Platform for desktop/mobile shells (windows, macos, linux, all, android, ios)',
                    short='p',
                    choices=['windows', 'macos', 'linux', 'all', 'android', 'ios']
                ),

            ]
        ),
        CommandMeta(
            name='check',
            help='Type check Jac files',
            group='analysis',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.analysis',
            handler_name='check',
            examples=[
                ('jac check myprogram.jac', 'Check a single file'),
                (
                    'jac check . --native-census',
                    'Rank modules by native compile outcome'
                ),
                ('jac check . --placements', 'Show element placements with evidence'),
                ('jac check . --lint', 'Report lint violations only'),
                ('jac check . --lint --fix', 'Auto-fix lint violations'),
                ('jac check file1.jac file2.jac', 'Check multiple files'),
                ('jac check myproject/', 'Check all files in directory'),
                ('jac check . --ignore jac scale test', 'Check excluding directories'),
                (
                    'jac check myprogram.jac --disable-error-code E1030 W2001',
                    'Check while suppressing selected diagnostics'
                ),
                (
                    'jac check myprogram.jac --parse-only',
                    'Only check syntax, skip type checking'
                ),
                ('jac check myprogram.jac --nowarn', 'Check without warnings')
            ],
            args=[
                ArgMeta(
                    name='paths',
                    kind=ArgKind.MULTI_POSITIONAL,
                    help='Paths to .jac files or directories',
                    short='p'
                ),
                ArgMeta(
                    name='print_errs',
                    typ='bool',
                    default=True,
                    help='Print detailed error messages',
                    short='e'
                ),
                ArgMeta(
                    name='ignore',
                    kind=ArgKind.MULTI_OPTION,
                    default=[],
                    help='Directories or files to ignore (space separated)',
                    short='i'
                ),
                ArgMeta(
                    name='disable-error-code',
                    kind=ArgKind.MULTI_OPTION,
                    default=[],
                    help='Diagnostic codes or lint kebab aliases to suppress (same as [check].suppress in jac.toml; e.g. E1030 no-print)',
                    short='d'
                ),
                ArgMeta(
                    name='parse_only',
                    typ='bool',
                    default=False,
                    help='Only check syntax (skip type checking)',
                    short='p'
                ),
                ArgMeta(
                    name='nowarn',
                    typ='bool',
                    default=False,
                    help='Suppress warning output (warnings are still counted)',
                    short='n'
                ),
                ArgMeta(
                    name='lint',
                    typ='bool',
                    default=False,
                    help="Report lint violations only (absorbs 'jac lint')",
                    short='',
                    dest='lint_only'
                ),
                ArgMeta(
                    name='fix',
                    typ='bool',
                    default=False,
                    help='With --lint: auto-fix violations',
                    short=''
                ),
                ArgMeta(
                    name='native-census',
                    typ='bool',
                    default=False,
                    help='Compile with codegen and report per-module native outcome (native / demoted / server) ranked by reason (needs the native toolchain)',
                    short=''
                ),
                ArgMeta(
                    name='placements',
                    typ='bool',
                    default=False,
                    help='Report where every top-level element was placed (server / client / native / dual) with the evidence behind each decision',
                    short=''
                ),

            ]
        ),
        CommandMeta(
            name='clean',
            help='Clean project build artifacts',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.project',
            handler_name='clean',
            examples=[
                ('jac clean', 'Clean data directory (default)'),
                ('jac clean --all', 'Clean all .jac artifacts'),
                ('jac clean --cache', 'Clean only cache directory'),
                ('jac clean --data --cache', 'Clean data and cache directories')
            ],
            args=[
                ArgMeta(
                    name='all',
                    typ='bool',
                    default=False,
                    help='Clean all .jac artifacts (data, cache, packages, client)',
                    short='a'
                ),
                ArgMeta(
                    name='data',
                    typ='bool',
                    default=False,
                    help='Clean data directory (.jac/data)',
                    short='d'
                ),
                ArgMeta(
                    name='cache',
                    typ='bool',
                    default=False,
                    help='Clean cache directory (.jac/cache)',
                    short='c'
                ),
                ArgMeta(
                    name='packages',
                    typ='bool',
                    default=False,
                    help='Clean virtual environment (.jac/venv)',
                    short='p'
                ),
                ArgMeta(
                    name='force',
                    typ='bool',
                    default=False,
                    help='Force clean without confirmation',
                    short='f'
                ),

            ]
        ),
        CommandMeta(
            name='code',
            help="Query code structure via the compiler (grep's structural successor)",
            group='analysis',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.code',
            handler_name='code',
            examples=[
                (
                    'jac code symbol User',
                    'Definition(s) of a symbol plus where it is used'
                ),
                (
                    'jac code uses make_user',
                    'Every read/write of a symbol, def/use-precise'
                ),
                ('jac code map', 'Structural overview: nodes, walkers, edges, objs'),
                ('jac code map walker', 'Only walker archetypes'),
                (
                    'jac code walkers User',
                    'Walkers whose entry points traverse a node type'
                ),
                (
                    'jac code slice Profile --depth 2',
                    'Typed neighbourhood for prompt assembly'
                ),
                ('jac code diag', 'Structured compiler errors and warnings'),
                ('jac code symbol User --text', 'Same query, human-readable output')
            ],
            args=[
                ArgMeta(
                    name='action',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='symbol | uses | map | walkers | slice | diag'
                ),
                ArgMeta(
                    name='target',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Symbol name, node type, archetype-kind filter, or file path'
                ),
                ArgMeta(
                    name='text',
                    kind=ArgKind.FLAG,
                    typ='bool',
                    default=False,
                    help='Human-readable text instead of the default JSON',
                    short='t'
                ),
                ArgMeta(
                    name='depth',
                    typ='int',
                    default=1,
                    help='Type-dependency depth for `slice` (default 1)',
                    short='d'
                ),

            ]
        ),
        CommandMeta(
            name='completions',
            help='Generate shell completion script',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.tools',
            handler_name='completions',
            examples=[
                ('jac completions --install', 'Install bash completions to ~/.bashrc'),
                (
                    'jac completions --shell zsh --install',
                    'Install zsh completions to ~/.zshrc'
                ),
                ('jac completions --shell bash', 'Print bash completions to stdout')
            ],
            args=[
                ArgMeta(
                    name='shell',
                    default='bash',
                    help='Shell to generate completions for (bash, zsh, fish)',
                    short='s'
                ),
                ArgMeta(
                    name='install',
                    typ='bool',
                    default=False,
                    help='Install completions to shell config file (~/.bashrc, ~/.zshrc, etc.)',
                    short='i'
                ),

            ]
        ),
        CommandMeta(
            name='config',
            help='Manage Jac configuration',
            group='config',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.config',
            handler_name='config',
            examples=[
                ('jac config show', 'Show all configuration'),
                ('jac config get run.cache', 'Get specific setting'),
                ('jac config set run.cache false', 'Set a value'),
                ('jac config reset run.cache', 'Reset to default'),
                ('jac config list', 'List available settings'),
                ('jac config show --group run', 'Show settings in a group')
            ],
            args=[
                ArgMeta(
                    name='action',
                    kind=ArgKind.POSITIONAL,
                    default='show',
                    help='Action: show, get, set, reset, list'
                ),
                ArgMeta(
                    name='key',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Configuration key'
                ),
                ArgMeta(
                    name='value',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Value to set'
                ),
                ArgMeta(
                    name='group', default='', help='Config group filter', short='g'
                ),
                ArgMeta(
                    name='output',
                    default='table',
                    help='Output format: table, json, toml',
                    short='o'
                ),

            ]
        ),
        CommandMeta(
            name='create',
            help='Create a new Jac project',
            group='project',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.project',
            handler_name='create',
            examples=[
                (
                    'jac create',
                    'Initialize a cli project in the current directory (name from cwd)'
                ),
                (
                    'jac create --pack ./my-template --pack_output my.jacpack',
                    'Bundle a template directory into a .jacpack'
                ),
                ('jac create myapp', 'Create new myapp/ directory (cli kind)'),
                ('jac create myapp --kind service', 'Scaffold a headless API service'),
                (
                    'jac create myapp --kind native-binary',
                    'Scaffold a natively-compiled binary'
                ),
                ('jac create myapp --kind web-app', 'Scaffold a full-stack web app'),
                ('jac create --force', 'Reinitialize existing project'),
                ('jac create --use ./my.jacpack', 'Create from local .jacpack file'),
                ('jac create --use https://example.com/t.jacpack', 'Create from URL'),
                ('jac create --list', 'List available project kinds and named variants')
            ],
            args=[
                ArgMeta(
                    name='name',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Project name (omit to initialize the current directory)'
                ),
                ArgMeta(
                    name='force',
                    typ='bool',
                    default=False,
                    help='Overwrite existing jac.toml',
                    short='f'
                ),
                ArgMeta(
                    name='kind',
                    default='',
                    help='Project kind to scaffold (cli, cli-native, service, web-app, ...)',
                    short='k'
                ),
                ArgMeta(
                    name='use',
                    default='default',
                    help='Custom template: file path or URL to a .jacpack (or a variant name)',
                    short='u'
                ),
                ArgMeta(
                    name='list',
                    typ='bool',
                    default=False,
                    help='List available project kinds and named variants',
                    short='l'
                ),
                ArgMeta(
                    name='pack',
                    default='',
                    help="Bundle a template directory into a .jacpack instead of creating (absorbs 'jac jacpack pack')",
                    short=''
                ),
                ArgMeta(
                    name='pack_output',
                    default='',
                    help='With --pack: output .jacpack file path',
                    short=''
                ),
                ArgMeta(
                    name='skip',
                    typ='bool',
                    default=False,
                    help="Skip dependency installation (Python + npm); run 'jac install' later",
                    short='s'
                ),
                ArgMeta(
                    name='style',
                    help='shadcn style preset (nova|vega|maia|lyra|mira)',
                    short=''
                ),
                ArgMeta(
                    name='baseColor',
                    help='shadcn base palette (neutral|stone|zinc|gray)',
                    short=''
                ),
                ArgMeta(
                    name='theme',
                    help='shadcn accent theme (e.g. rose, emerald)',
                    short=''
                ),
                ArgMeta(
                    name='font',
                    help='shadcn font family (e.g. inter, outfit)',
                    short=''
                ),
                ArgMeta(
                    name='radius',
                    help='shadcn border radius (none|small|medium|large)',
                    short=''
                ),
                ArgMeta(
                    name='menuAccent', help='shadcn menu accent (subtle|bold)', short=''
                ),
                ArgMeta(name='menuColor', help='shadcn menu color scheme', short=''),

            ]
        ),
        CommandMeta(
            name='db',
            help='Inspect, rescue, and manage Jac persistence databases',
            group='db',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.db',
            handler_name='db',
            examples=[
                ('jac db inspect', 'Summarize the DB for the .jac in cwd'),
                (
                    'jac db inspect --app path/to/app.jac',
                    "Summarize a specific app's DB"
                ),
                ('jac db fsck', 'Scan for dangling refs / orphans (read-only)'),
                ('jac db fsck repair', 'Heal dangling refs and collect orphans'),
                ('jac db quarantine list', 'List quarantined anchors'),
                ('jac db quarantine show <row-id>', 'Show one quarantined row in full'),
                ('jac db alias list', 'List DB-resident aliases'),
                (
                    'jac db alias add old.mod.OldName new.mod.NewName',
                    'Register a rescue alias'
                ),
                ('jac db alias remove old.mod.OldName', 'Remove a rescue alias'),
                ('jac db recover <row-id>', 'Try to un-quarantine one row'),
                ('jac db recover-all', 'Try to un-quarantine every row; report counts'),
                ('jac db schema rules', 'List registered __jac_schema__ drift rules')
            ],
            args=[
                ArgMeta(
                    name='action',
                    kind=ArgKind.POSITIONAL,
                    default='inspect',
                    help='Action: inspect, fsck, quarantine, alias, recover, recover-all, schema'
                ),
                ArgMeta(
                    name='sub',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Sub-action (for alias/quarantine) or row id (for recover)'
                ),
                ArgMeta(
                    name='arg1',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='First argument (alias old_name, row id, etc.)'
                ),
                ArgMeta(
                    name='arg2',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Second argument (alias new_name, etc.)'
                ),
                ArgMeta(
                    name='limit',
                    typ='int',
                    default=50,
                    help='Row limit for list commands',
                    short='n'
                ),
                ArgMeta(
                    name='app',
                    default='',
                    help='Path to the .jac app file to import before dispatching. If omitted, the single .jac file in the current directory is used. The app must be importable so user-defined archetypes (and any @archetype_alias decorators) register before the command touches the backend.',
                    short='a'
                ),

            ]
        ),
        CommandMeta(
            name='dev',
            help='Serve with hot reload and live compilation',
            group='execution',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.execution',
            handler_name='dev',
            examples=[
                ('jac dev', 'Dev-serve the current project with hot reload'),
                (
                    'jac dev main.jac --port 3000',
                    'Dev-serve a specific entry on port 3000'
                )
            ],
            args=[
                ArgMeta(
                    name='filename',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Entry .jac file (default: [project] entry-point from jac.toml)'
                ),
                ArgMeta(
                    name='port',
                    typ='int',
                    default=8000,
                    help='Port to serve on',
                    short='p',
                    config_key='serve.port'
                ),
                ArgMeta(
                    name='api_port',
                    typ='int',
                    default=0,
                    help='Backend API port for client dev servers (0 = auto)',
                    short=''
                ),

            ]
        ),
        CommandMeta(
            name='dot',
            help='Generate graph visualization (DOT format)',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.tools',
            handler_name='dot',
            examples=[
                ('jac dot myprogram.jac', 'Generate DOT graph'),
                ('jac dot myprogram.jac --saveto graph.dot', 'Save to file'),
                ('jac dot myprogram.jac --depth 3', 'Limit traversal depth')
            ],
            args=[
                ArgMeta(
                    name='filename',
                    kind=ArgKind.POSITIONAL,
                    help='Path to .jac file',
                    required=True
                ),
                ArgMeta(
                    name='session', default='', help='Session identifier', short='s'
                ),
                ArgMeta(name='initial', default='', help='Initial node ID', short='i'),
                ArgMeta(
                    name='depth',
                    typ='int',
                    default=-1,
                    help='Max traversal depth',
                    short='d'
                ),
                ArgMeta(
                    name='traverse',
                    typ='bool',
                    default=False,
                    help='Enable traversal mode',
                    short='t'
                ),
                ArgMeta(
                    name='connection',
                    kind=ArgKind.MULTI_OPTION,
                    default=[],
                    help='Connection filters',
                    short='c'
                ),
                ArgMeta(
                    name='bfs',
                    typ='bool',
                    default=False,
                    help='Use breadth-first search',
                    short='b'
                ),
                ArgMeta(
                    name='edge_limit',
                    typ='int',
                    default=512,
                    help='Max edges',
                    short='e'
                ),
                ArgMeta(
                    name='node_limit',
                    typ='int',
                    default=512,
                    help='Max nodes',
                    short='n'
                ),
                ArgMeta(name='saveto', default='', help='Output file path', short='o'),
                ArgMeta(
                    name='to_screen',
                    typ='bool',
                    default=False,
                    help='Print to stdout',
                    short='p'
                ),
                ArgMeta(name='format', default='dot', help='Output format', short='f'),

            ]
        ),
        CommandMeta(
            name='fix',
            help="Mechanical source migrations. 'jac fix placement' strips removed sv/cl/na placement markers, renames retired .sv.jac/.cl.jac/.na.jac files, preserves service topology as [scale.microservices.routes] entries, and pins any element whose inferred placement differs from its old marker via [placement.pins]",
            group='analysis',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.fix',
            handler_name='fix',
            examples=[
                (
                    'jac fix placement',
                    'Migrate the current project off sv/cl/na markers'
                ),
                ('jac fix placement src/', 'Migrate one directory'),
                ('jac fix placement --dry-run', 'Preview the migration')
            ],
            args=[
                ArgMeta(
                    name='target',
                    kind=ArgKind.POSITIONAL,
                    help='Migration to run (currently: placement)',
                    required=True
                ),
                ArgMeta(
                    name='paths',
                    kind=ArgKind.MULTI_POSITIONAL,
                    default=['.'],
                    help='Files or directories to migrate (default: current directory)',
                    short='p'
                ),
                ArgMeta(
                    name='dry-run',
                    typ='bool',
                    default=False,
                    help='Report what would change without writing anything',
                    short=''
                ),
                ArgMeta(
                    name='strip-only',
                    typ='bool',
                    default=False,
                    help='Only strip markers and rename files; skip placement verification and jac.toml pin/route recording (for fixture trees)',
                    short=''
                ),

            ]
        ),
        CommandMeta(
            name='fmt',
            help='Format Jac source code',
            group='analysis',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.analysis',
            handler_name='format',
            examples=[
                ('jac fmt myfile.jac', 'Format a single file'),
                ('jac fmt myproject/', 'Format all files in directory'),
                ('jac fmt myfile.jac --to_screen', 'Preview formatted output'),
                ('jac fmt . --lintfix', 'Format and auto-fix lint violations'),
                ('jac fmt . --check', 'Check formatting without modifying files')
            ],
            args=[
                ArgMeta(
                    name='paths',
                    kind=ArgKind.MULTI_POSITIONAL,
                    help='Paths to .jac files or directories',
                    short='p'
                ),
                ArgMeta(
                    name='to_screen',
                    typ='bool',
                    default=False,
                    help='Print to stdout instead of writing',
                    short='s'
                ),
                ArgMeta(
                    name='lintfix',
                    typ='bool',
                    default=False,
                    help='Also apply auto-lint fixes in the same pass',
                    short='l'
                ),
                ArgMeta(
                    name='check',
                    typ='bool',
                    default=False,
                    help='Check if files are formatted without modifying them (exit 1 if unformatted)',
                    short='c'
                ),
                ArgMeta(
                    name='cache',
                    typ='bool',
                    default=False,
                    help='Skip files already known to be formatted (content + config + version keyed)',
                    short='C'
                ),

            ]
        ),
        CommandMeta(
            name='gen-cli-manifest',
            help='Regenerate the CLI manifest route table from the command registry',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.tools',
            handler_name='gen_cli_manifest',
            examples=[
                ('jac gen-cli-manifest', 'Regenerate the manifest route table'),
                (
                    'jac gen-cli-manifest --verify',
                    'Check the manifest is up to date (for CI)'
                )
            ],
            args=[
                ArgMeta(
                    name='verify',
                    typ='bool',
                    default=False,
                    help='Check that manifest.impl.jac route table is up to date; exit 1 if not',
                    short='v'
                ),

            ]
        ),
        CommandMeta(
            name='gen-jir-registry',
            help='Regenerate jir_registry.jac from unitree node classes',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.tools',
            handler_name='gen_jir_registry',
            examples=[
                ('jac gen-jir-registry', 'Regenerate jir_registry.jac'),
                (
                    'jac gen-jir-registry --verify',
                    'Check registry is up to date (for CI)'
                )
            ],
            args=[
                ArgMeta(
                    name='verify',
                    typ='bool',
                    default=False,
                    help='Check that jir_registry.jac is up to date; exit 1 if not',
                    short='v'
                ),

            ]
        ),
        CommandMeta(
            name='gen-uni-dispatch',
            help='Regenerate static enter_node/exit_node dispatch for UniPass subclasses',
            group='tools',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.tools',
            handler_name='gen_uni_dispatch',
            examples=[
                ('jac gen-uni-dispatch', 'Regenerate all dispatch annexes'),
                (
                    'jac gen-uni-dispatch --verify',
                    'Check annexes are up to date (for CI)'
                )
            ],
            args=[
                ArgMeta(
                    name='verify',
                    typ='bool',
                    default=False,
                    help='Check that dispatch annexes are up to date; exit 1 if not',
                    short='v'
                ),

            ]
        ),
        CommandMeta(
            name='gen_parser',
            help='Generate Jac parser (internal use)',
            group='analysis',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.analysis',
            handler_name='gen_parser',
            examples=[('jac gen_parser', 'Regenerate the Jac parser')],
            args=[]
        ),
        CommandMeta(
            name='guide',
            help='Show bundled Jac guides and documentation',
            group='general',
            tier='learn',
            hidden=False,
            handler_module='jaclang.cli.commands.guide',
            handler_name='guide',
            examples=[
                ('jac guide', 'List every bundled guide and doc set'),
                ('jac guide jac-types', 'Print the jac-types guide'),
                (
                    'jac guide reference/diagnostics',
                    'Print the bundled diagnostics reference'
                ),
                ('jac guide reference', 'List every doc in the reference set'),
                ("jac guide --search 'breaking changes'", 'Grep all bundled content'),
                ('jac guide --json', 'Full guide/doc index as JSON for tooling'),
                ('jac guide --export ~/.claude/skills', 'Export guides as Agent Skills')
            ],
            args=[
                ArgMeta(
                    name='topic',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Guide or doc to print, or a doc set (reference, quick-guide, build, tutorials, internals, community) to list; omit to show the full index'
                ),
                ArgMeta(
                    name='search',
                    default='',
                    help='Grep every bundled guide and doc (name:line: hits)',
                    short='s'
                ),
                ArgMeta(
                    name='export',
                    default='',
                    help='Export all guides as a Claude Code skills directory at this path',
                    short='e'
                ),
                ArgMeta(
                    name='json',
                    typ='bool',
                    default=False,
                    help='Emit machine-readable JSON (for tools and agents)',
                    short='j',
                    dest='as_json'
                ),

            ]
        ),
        CommandMeta(
            name='install',
            help='Install project dependencies',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.project',
            handler_name='install',
            examples=[
                ('jac install', 'Install all dependencies from jac.toml'),
                ('jac install --plan', 'Show the fully resolved dependency plan'),
                (
                    'jac install --scale',
                    'Also install deploy-time capabilities (kubernetes/docker) for the operator machine'
                ),
                ('jac install requests', 'Add requests to jac.toml and install it'),
                (
                    'jac install "numpy>=1.24" pandas',
                    'Add multiple packages with version constraints'
                ),
                ('jac install pytest --dev', 'Add a dev dependency'),
                (
                    'jac install numpy --no-save',
                    'Install without recording in jac.toml'
                ),
                (
                    'jac install --git https://github.com/user/plugin.git',
                    'Install and record a git dependency'
                ),
                ('jac install --npm left-pad', 'Add a client-side npm dependency'),
                ('jac install --shadcn button card', 'Add shadcn UI components'),
                ('jac install -e .', 'Install current package in editable mode'),
                (
                    'jac install -e /path/to/lib',
                    'Install a cloned library in editable mode'
                ),
                (
                    'jac install -e ./my-plugin -e ./my-lib',
                    'Install multiple packages in editable mode (space-separated or repeated -e)'
                ),
                ('jac install --dev', 'Include dev dependencies'),
                (
                    'jac install --extras data monitoring',
                    'Include optional dependency groups'
                ),
                (
                    'jac install -e . --extras all',
                    'Editable install with all optional deps'
                ),
                (
                    'jac install --force-reinstall',
                    'Reinstall all packages from scratch'
                ),
                ('jac install --pre', 'Include pre-release versions'),
                (
                    'jac install --no-cache-dir',
                    "Install without using pip's download cache"
                ),
                (
                    'jac install --dry-run',
                    'Preview what would be installed without doing it'
                ),
                (
                    'jac install --no-deps',
                    'Install packages without their dependencies'
                ),
                (
                    'jac install --prefer-binary',
                    'Prefer pre-built wheels over source builds'
                ),
                (
                    'jac install -e ./my-plugin --global',
                    "Install a plugin into the global site so it's importable from any project"
                )
            ],
            args=[
                ArgMeta(
                    name='packages',
                    kind=ArgKind.MULTI_POSITIONAL,
                    default=[],
                    help="Package(s) to add to jac.toml and install into the project's venv (.jac/venv)",
                    short='p'
                ),
                ArgMeta(
                    name='editable',
                    kind=ArgKind.APPEND,
                    default=[],
                    help='Install the package at this path in editable mode; repeat for multiple packages',
                    short='e',
                    metavar='PATH'
                ),
                ArgMeta(
                    name='dev',
                    typ='bool',
                    default=False,
                    help='Include dev dependencies, or record named package(s) as dev dependencies',
                    short='d'
                ),
                ArgMeta(
                    name='extras',
                    kind=ArgKind.MULTI_OPTION,
                    default=[],
                    help='Optional dependency groups to install (e.g. data monitoring)',
                    short='x'
                ),
                ArgMeta(
                    name='no-save',
                    typ='bool',
                    default=False,
                    help='Install named package(s) without recording them in jac.toml',
                    short=''
                ),
                ArgMeta(
                    name='git',
                    default='',
                    help='Git repository URL to install and record as a git dependency',
                    short='g'
                ),
                ArgMeta(
                    name='npm',
                    typ='bool',
                    default=False,
                    help="Install npm package(s); with no names, install all npm deps from jac.toml. With --global, install standalone npm CLI tools runnable via 'jac x --global'",
                    short='n'
                ),
                ArgMeta(
                    name='shadcn',
                    typ='bool',
                    default=False,
                    help='Install shadcn UI component(s) from the bundled registry',
                    short='s'
                ),
                ArgMeta(
                    name='verbose',
                    typ='bool',
                    default=False,
                    help='Verbose output',
                    short='v'
                ),
                ArgMeta(
                    name='force-reinstall',
                    typ='bool',
                    default=False,
                    help='Reinstall all packages even if they are already up-to-date',
                    short=''
                ),
                ArgMeta(
                    name='no-cache-dir',
                    typ='bool',
                    default=False,
                    help='Disable the pip download cache',
                    short=''
                ),
                ArgMeta(
                    name='pre',
                    typ='bool',
                    default=False,
                    help='Include pre-release and development versions',
                    short=''
                ),
                ArgMeta(
                    name='dry-run',
                    typ='bool',
                    default=False,
                    help='Show what would be installed without actually installing anything',
                    short=''
                ),
                ArgMeta(
                    name='no-deps',
                    typ='bool',
                    default=False,
                    help="Don't install package dependencies",
                    short=''
                ),
                ArgMeta(
                    name='quiet',
                    typ='bool',
                    default=False,
                    help='Suppress pip output',
                    short=''
                ),
                ArgMeta(
                    name='prefer-binary',
                    typ='bool',
                    default=False,
                    help='Prefer wheel files over source distributions',
                    short=''
                ),
                ArgMeta(
                    name='global',
                    typ='bool',
                    default=False,
                    help='Install into the jac-owned global store shared by every project, not the project venv (Python: the global site; with --npm: global npm CLI tools)',
                    short='',
                    dest='install_global'
                ),
                ArgMeta(
                    name='scale',
                    typ='bool',
                    default=False,
                    help='Materialize the deploy-time capability closure (adds deploy-only clients like kubernetes/docker) instead of just the runtime closure',
                    short=''
                ),
                ArgMeta(
                    name='plan',
                    typ='bool',
                    default=False,
                    help="Show the fully resolved dependency plan instead of installing (absorbs 'jac deps')",
                    short=''
                ),
                ArgMeta(
                    name='json',
                    typ='bool',
                    default=False,
                    help='With --plan: emit the plan as JSON',
                    short='',
                    dest='as_json'
                ),

            ]
        ),
        CommandMeta(
            name='lsp',
            help='Start Jac language server',
            group='tools',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.tools',
            handler_name='lsp',
            examples=[('jac lsp', 'Start language server for IDE integration')],
            args=[]
        ),
        CommandMeta(
            name='mcp',
            help='Start the MCP (Model Context Protocol) server for AI-assisted Jac development',
            group='tools',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.mcp',
            handler_name='mcp_cmd',
            examples=[
                ('jac mcp', 'Start MCP server with stdio transport (default)'),
                (
                    'jac mcp --transport streamable-http --port 3001',
                    'Start with HTTP transport'
                ),
                ('jac mcp --mode lite', 'Start with lite mode for smaller models'),
                ('jac mcp --inspect', 'List available resources, tools, and prompts')
            ],
            args=[
                ArgMeta(
                    name='transport',
                    default='stdio',
                    help='Transport protocol: stdio, sse, or streamable-http',
                    short='t',
                    choices=['stdio', 'sse', 'streamable-http']
                ),
                ArgMeta(
                    name='port',
                    typ='int',
                    default=3001,
                    help='Port for SSE/HTTP transports (default: 3001)',
                    short='p'
                ),
                ArgMeta(
                    name='host',
                    default='127.0.0.1',
                    help='Bind address for SSE/HTTP transports (default: 127.0.0.1)',
                    short=''
                ),
                ArgMeta(
                    name='mode',
                    default='',
                    help='Tool/prompt exposure mode: lite, standard, or full (default: full)',
                    short='',
                    choices=['lite', 'standard', 'full', '']
                ),
                ArgMeta(
                    name='inspect',
                    typ='bool',
                    default=False,
                    help='Print inventory of resources, tools, and prompts then exit',
                    short=''
                ),

            ]
        ),
        CommandMeta(
            name='model',
            help='Manage byllm local-model weights (Gemma 4 and friends)',
            group='config',
            tier='',
            hidden=False,
            handler_module='jaclang.byllm.cli',
            handler_name='model',
            examples=[
                ('jac model list', 'Show bundled aliases and download status'),
                ('jac model pull gemma-4-e4b', 'Download Gemma 4 E4B GGUF weights'),
                ('jac model rm gemma-4-e4b', 'Delete cached weights for an alias')
            ],
            args=[
                ArgMeta(
                    name='action',
                    kind=ArgKind.POSITIONAL,
                    default='list',
                    help='Action: list, pull, rm'
                ),
                ArgMeta(
                    name='alias',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Local-model alias (e.g. gemma-4-e4b). Omit for `list`.'
                ),

            ]
        ),
        CommandMeta(
            name='nacompile',
            help="Compile a Jac file to a standalone native binary (prefer 'jac build --as native' for projects)",
            group='transform',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.nacompile',
            handler_name='nacompile',
            examples=[
                ('jac nacompile program.jac', 'Compile to ./program'),
                ('jac nacompile program.jac', 'Auto-promote and compile to ./program'),
                ('jac nacompile program.jac -o mybin', 'Compile to ./mybin'),
                ('jac nacompile program.jac --scrub', 'Clean rebuild (wipe IR cache)'),
                (
                    'jac nacompile program.jac -g',
                    'Compile with DWARF debug info (gdb ./program works)'
                ),
                (
                    'jac nacompile game.jac --target wasm32 -o game.wasm',
                    'Compile to a wasm module'
                ),
                (
                    'jac nacompile mathlib.jac --shared',
                    'Build ./libmathlib.so exporting its `:pub` functions over the C ABI'
                ),
                (
                    'jac nacompile service.jac --gc none --assert-no-rc',
                    'Compile and prove the artifact contains no RC/collector machinery'
                )
            ],
            args=[
                ArgMeta(
                    name='filename',
                    kind=ArgKind.POSITIONAL,
                    help='Path to the .jac file to compile natively',
                    required=True
                ),
                ArgMeta(
                    name='output',
                    default='',
                    help='Output binary path (defaults to filename without extension)',
                    short='o'
                ),
                ArgMeta(
                    name='scrub',
                    kind=ArgKind.FLAG,
                    help='Scrub build: wipe cached IR and recompile everything from scratch',
                    short='s'
                ),
                ArgMeta(
                    name='target',
                    default='',
                    help="Code target: native host (default) or 'wasm32' for a browser .wasm module",
                    short='t'
                ),
                ArgMeta(
                    name='shared',
                    kind=ArgKind.FLAG,
                    help='Build a C-ABI shared library (.so/.dylib/.dll) exporting `:pub` symbols instead of an executable',
                    short=''
                ),
                ArgMeta(
                    name='debug',
                    kind=ArgKind.FLAG,
                    help='Emit DWARF debug info + symbol table so the binary is debuggable with gdb/lldb',
                    short='g'
                ),
                ArgMeta(
                    name='gc',
                    default='',
                    help="Memory-management runtime to emit: 'cycles' (refcounting + cycle collector), 'rc' (refcounting only, no collector code), or 'none' (no refcounting call sites; memory is never reclaimed). Defaults to jac.toml [gc] default, else 'cycles'",
                    short=''
                ),
                ArgMeta(
                    name='assert-no-rc',
                    kind=ArgKind.FLAG,
                    help='Fail the build if the emitted IR contains any RC/collector machinery: __rc_* helpers, trace functions, roots-buffer globals, or entry-point GC env probes',
                    short=''
                ),
                ArgMeta(
                    name='enforce-nogc',
                    kind=ArgKind.FLAG,
                    help='Enforce zero-RC ownership coverage (E140x hard errors) on the compiled module, regardless of jac.toml [gc.enforce] patterns',
                    short=''
                ),

            ]
        ),
        CommandMeta(
            name='ninja',
            help='Open the built-in jac editor (fused Neovim + LSP + tree-sitter)',
            group='tools',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.tools',
            handler_name='ninja',
            examples=[('jac ninja file.jac', 'Edit a jac file in the built-in editor')],
            args=[]
        ),
        CommandMeta(
            name='precommit',
            help='Run fmt (--lintfix) + check using jac.toml lint settings; installable as a git hook',
            group='analysis',
            tier='',
            hidden=True,
            handler_module='jaclang.cli.commands.analysis',
            handler_name='precommit',
            examples=[
                ('jac precommit', 'Format (lintfix) and check the whole project'),
                ('jac precommit --staged', "Run on staged '.jac' files only"),
                (
                    'jac precommit --install',
                    'Install the pre-commit + commit-msg hooks'
                ),
                (
                    'jac precommit --install --force',
                    'Replace existing hooks (kept as .bak backups)'
                )
            ],
            args=[
                ArgMeta(
                    name='paths',
                    kind=ArgKind.MULTI_POSITIONAL,
                    default=[],
                    help='Paths to .jac files or directories (default: project root)',
                    short='p'
                ),
                ArgMeta(
                    name='staged',
                    typ='bool',
                    default=False,
                    help='Only process git-staged .jac files',
                    short='s'
                ),
                ArgMeta(
                    name='verify',
                    typ='bool',
                    default=False,
                    help='Verify only: do not rewrite files (exit 1 if unformatted)',
                    short='v'
                ),
                ArgMeta(
                    name='install',
                    typ='bool',
                    default=False,
                    help='Install git pre-commit + commit-msg hooks',
                    short='i'
                ),
                ArgMeta(
                    name='force',
                    typ='bool',
                    default=False,
                    help='With --install: replace an existing foreign hook (a backup is kept)',
                    short='f'
                ),

            ]
        ),
        CommandMeta(
            name='remove',
            help='Remove a dependency from the project',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.project',
            handler_name='remove',
            examples=[
                ('jac remove requests', 'Remove a package'),
                ('jac remove pytest --dev', 'Remove dev dependency'),
                ('jac remove --npm left-pad', 'Remove a client-side npm dependency'),
                ('jac remove --shadcn button', 'Remove shadcn UI components')
            ],
            args=[
                ArgMeta(
                    name='packages',
                    kind=ArgKind.MULTI_POSITIONAL,
                    default=[],
                    help='Packages to remove',
                    short='p'
                ),
                ArgMeta(
                    name='dev',
                    typ='bool',
                    default=False,
                    help='Remove from dev dependencies',
                    short='d'
                ),
                ArgMeta(
                    name='npm',
                    typ='bool',
                    default=False,
                    help='Remove npm (client-side) dependency',
                    short='n'
                ),
                ArgMeta(
                    name='shadcn',
                    typ='bool',
                    default=False,
                    help='Remove shadcn UI component(s)',
                    short='s'
                ),

            ]
        ),
        CommandMeta(
            name='retheme',
            help='Re-theme a jac-shadcn project: regenerate global.css from [jac-shadcn]',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.shadcn.cli',
            handler_name='retheme',
            examples=[
                (
                    'jac retheme',
                    'Regenerate global.css from the current [jac-shadcn] config'
                ),
                (
                    'jac retheme --theme rose --font inter',
                    'Switch accent + font in place'
                ),
                (
                    'jac retheme --style mira',
                    'Switch style and re-resolve installed components'
                )
            ],
            args=[
                ArgMeta(name='style', help='Component style preset', short=''),
                ArgMeta(name='baseColor', help='Base neutral palette', short=''),
                ArgMeta(name='theme', help='Accent color theme', short=''),
                ArgMeta(name='font', help='Font family', short=''),
                ArgMeta(name='radius', help='Border radius preset', short=''),
                ArgMeta(name='menuAccent', help='Menu accent (subtle|bold)', short=''),
                ArgMeta(name='menuColor', help='Menu color scheme', short=''),

            ]
        ),
        CommandMeta(
            name='run',
            help='Run a Jac program',
            group='execution',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.execution',
            handler_name='run',
            examples=[
                ('jac run hello.jac', 'Run a simple program'),
                ('jac run', 'Run the current project per its jac.toml kind'),
                (
                    'jac run app.jab',
                    "Run a sealed app bundle (kind-aware; servable kinds use the app's configured port -- override with jac start app.jab --port N)"
                ),
                (
                    'jac run --entry my_walker app.jac arg1',
                    'Invoke a specific entrypoint'
                ),
                ('jac run --debug app.jac', 'Run under the Python debugger'),
                (
                    'jac run --show',
                    'Print what the project would run/build, without doing it'
                ),
                ('jac run --no-cache app.jac', 'Run without caching'),
                ('jac run --profile prod app.jac', 'Run with production profile'),
                (
                    'jac run -e all app.jac',
                    'Run and show all diagnostics (errors+warnings)'
                ),
                ('jac run -e none app.jac', 'Run silently, suppress all diagnostics'),
                ('jac run script.jac arg1 arg2', 'Run with script arguments')
            ],
            args=[
                ArgMeta(
                    name='filename',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help="Path to .jac or .py file (omit to use the project's jac.toml)"
                ),
                ArgMeta(
                    name='show',
                    typ='bool',
                    default=False,
                    help='Print the resolved project-kind run plan without executing it',
                    short='s'
                ),
                ArgMeta(
                    name='main',
                    typ='bool',
                    default=True,
                    help='Treat module as __main__',
                    short='m',
                    config_key='run.main'
                ),
                ArgMeta(
                    name='cache',
                    typ='bool',
                    default=True,
                    help='Enable compilation cache',
                    short='c',
                    config_key='run.cache'
                ),
                ArgMeta(
                    name='profile',
                    default='',
                    help='Configuration profile to load (e.g. prod, staging)',
                    short=''
                ),
                ArgMeta(
                    name='diagnostics',
                    default='',
                    help='Diagnostic verbosity: error (default, fail on errors), all (errors+warnings), none (silent)',
                    short='e'
                ),
                ArgMeta(
                    name='entry',
                    default='',
                    help="Invoke a specific function/walker entrypoint (absorbs 'jac enter')",
                    short='',
                    dest='entry_name'
                ),
                ArgMeta(
                    name='node',
                    default='',
                    help='Starting node ID for --entry (OSP node binding)',
                    short='n',
                    dest='nd'
                ),
                ArgMeta(
                    name='root',
                    default='',
                    help='Root executor ID for --entry',
                    short='r',
                    dest='root_id'
                ),
                ArgMeta(
                    name='debug',
                    typ='bool',
                    default=False,
                    help="Run under the Python debugger (absorbs 'jac debug')",
                    short='',
                    dest='debug_mode'
                ),
                ArgMeta(
                    name='args',
                    kind=ArgKind.REMAINDER,
                    help='Arguments passed to the script',
                    short='a'
                ),

            ]
        ),
        CommandMeta(
            name='scale',
            help='Manage scale deployments: local microservices (status/stop/restart/logs) and platform deployments (status/destroy on a .jac app)',
            group='microservices',
            tier='',
            hidden=False,
            handler_module='jaclang.scale.plugin',
            handler_name='scale_cmd',
            examples=[
                ('jac scale status', 'Show status of all microservices'),
                (
                    'jac scale split orders',
                    'Declare the orders module as a service in [scale.microservices.routes]'
                ),
                ('jac scale stop orders', 'Stop the orders service'),
                ('jac scale restart cart', 'Restart the cart service'),
                ('jac scale logs products', 'Show logs for products service'),
                ('jac scale destroy', 'Stop all services'),
                ('jac scale status app.jac', 'Show platform deployment status of app'),
                ('jac scale destroy app.jac', "Remove app's platform deployment"),
                (
                    'jac scale destroy app.jac --component database',
                    'Remove only MongoDB from the deployment'
                )
            ],
            args=[
                ArgMeta(
                    name='action',
                    kind=ArgKind.POSITIONAL,
                    help='Action: status, stop, restart, logs, destroy, split',
                    required=True
                ),
                ArgMeta(
                    name='service_name',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Service name (stop/restart/logs), module to declare as a service (split), or a .jac app file for platform status/destroy'
                ),
                ArgMeta(
                    name='lines',
                    typ='int',
                    default=50,
                    help="Number of log lines to show (for 'logs' action)",
                    short='l'
                ),
                ArgMeta(
                    name='target',
                    default='kubernetes',
                    help='Platform target for .jac app status/destroy (kubernetes, aws, gcp, etc.)',
                    short='t'
                ),
                ArgMeta(
                    name='component',
                    default='',
                    help='Platform destroy: component to remove (application, database, cache, monitoring, dashboard; default: entire deployment)',
                    short='c'
                ),

            ]
        ),
        CommandMeta(
            name='setup',
            help='Setup a build target (one-time initialization)',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.runtimelib.client.cli',
            handler_name='setup',
            examples=[
                ('jac setup mobile', 'Setup mobile target (default platform)'),
                ('jac setup mobile --platform ios', 'Setup iOS scaffold only'),
                (
                    'jac setup mobile --platform all',
                    'Setup both Android and iOS (macOS)'
                )
            ],
            args=[
                ArgMeta(
                    name='target',
                    kind=ArgKind.POSITIONAL,
                    help='Target to setup (e.g., desktop)',
                    required=True
                ),
                ArgMeta(
                    name='platform',
                    help='Platform for mobile setup (android, ios, all)',
                    short='p',
                    choices=['android', 'ios', 'all']
                ),

            ]
        ),
        CommandMeta(
            name='start',
            help='Start server for a Jac program',
            group='execution',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.execution',
            handler_name='start',
            examples=[
                ('jac start', 'Start server with default main.jac'),
                ('jac start app.jac', 'Start server with specific file'),
                ('jac start --port 3000', 'Start main.jac on port 3000'),
                ('jac start app.jac --faux', 'Generate API docs without starting'),
                ('jac start --dev', 'Start with hot module replacement'),
                (
                    'jac start app.jac --dev --no-client',
                    'HMR mode without client bundling'
                ),
                ('jac start --profile prod', 'Start with production profile'),
                ('jac start --client mobile', 'Run the mobile client dev server'),
                (
                    'jac start --scale',
                    'Deploy to a platform target instead of serving locally'
                )
            ],
            args=[
                ArgMeta(
                    name='filename',
                    kind=ArgKind.POSITIONAL,
                    default='main.jac',
                    help='Path to .jac file (default: main.jac)'
                ),
                ArgMeta(
                    name='port',
                    typ='int',
                    default=8000,
                    help='Server port',
                    short='p',
                    config_key='serve.port'
                ),
                ArgMeta(
                    name='main',
                    typ='bool',
                    default=True,
                    help='Treat as __main__',
                    short='m',
                    config_key='run.main'
                ),
                ArgMeta(
                    name='faux',
                    typ='bool',
                    default=False,
                    help='Print docs only (no server)',
                    short='f'
                ),
                ArgMeta(
                    name='dev',
                    typ='bool',
                    default=False,
                    help='Enable HMR (Hot Module Replacement) mode',
                    short='d'
                ),
                ArgMeta(
                    name='api_port',
                    typ='int',
                    default=0,
                    help='Separate API port for HMR mode (0=same as port)',
                    short='a'
                ),
                ArgMeta(
                    name='no-client',
                    typ='bool',
                    default=False,
                    help='Skip client bundling/serving (API only)',
                    short='n'
                ),
                ArgMeta(
                    name='profile',
                    default='',
                    help='Configuration profile to load (e.g. prod, staging)',
                    short=''
                ),
                ArgMeta(
                    name='client',
                    default='web',
                    help='Client build target for dev server (web, pwa, mobile, desktop). Choices reflect installed targets (desktop builds a native webview app).',
                    short='',
                    choices=[
                        'web',
                        'pwa',
                        'static',
                        'mobile',
                        'desktop',
                        'cef',
                        'react-native'
                    ]
                ),
                ArgMeta(
                    name='host',
                    default='',
                    help='Mobile dev (--client mobile --dev): optional host/IP override for Capacitor live-reload. When omitted, jac auto-selects a host.',
                    short=''
                ),
                ArgMeta(
                    name='platform',
                    default='auto',
                    help='Mobile start/dev: android or ios (auto = use [client.mobile] default_platform or android)',
                    short='',
                    choices=['auto', 'android', 'ios']
                ),
                ArgMeta(
                    name='scale',
                    typ='bool',
                    default=False,
                    help='Deploy to a target platform instead of running locally',
                    short=''
                ),
                ArgMeta(
                    name='target',
                    default='kubernetes',
                    help='Deployment target (kubernetes, aws, gcp, etc.)',
                    short='t'
                ),
                ArgMeta(
                    name='enable-tls',
                    typ='bool',
                    default=False,
                    help="Enable HTTPS via Let's Encrypt (run after pointing your domain CNAME to the NLB)",
                    short=''
                ),
                ArgMeta(
                    name='dry-run',
                    typ='bool',
                    default=False,
                    help='Print the manifests that would be applied; touch nothing (no cluster contact, no downloads, no client build, no DB provisioning, no TLS issuance, no deploy tooling installed)',
                    short=''
                ),
                ArgMeta(
                    name='show-yaml',
                    typ='bool',
                    default=False,
                    help='With --dry-run: dump the raw YAML stream',
                    short=''
                ),

            ]
        ),
        CommandMeta(
            name='test',
            help='Run Jac test suite',
            group='analysis',
            tier='core',
            hidden=False,
            handler_module='jaclang.cli.commands.analysis',
            handler_name='test',
            examples=[
                ('jac test', 'Run all tests in current directory'),
                ('jac test mytest.jac', 'Run tests in specific file'),
                ('jac test a.jac b.jac', 'Run tests in several files'),
                ('jac test --test_name my_test', 'Run only test_my_test'),
                (
                    'jac test --xit --verbose',
                    'Stop on first failure with verbose output'
                )
            ],
            args=[
                ArgMeta(
                    name='paths',
                    kind=ArgKind.MULTI_POSITIONAL,
                    default=[],
                    help='Paths to test files or directories',
                    short='p'
                ),
                ArgMeta(
                    name='test_name',
                    default='',
                    help='Run specific test (without test_ prefix)',
                    short='t'
                ),
                ArgMeta(
                    name='filter',
                    default='',
                    help='Filter test files (Unix patterns)',
                    short='f'
                ),
                ArgMeta(
                    name='xit',
                    typ='bool',
                    default=False,
                    help='Stop on first failure',
                    short='x'
                ),
                ArgMeta(
                    name='maxfail', typ='int', help='Stop after N failures', short='m'
                ),
                ArgMeta(name='directory', default='', help='Test directory', short='d'),
                ArgMeta(
                    name='verbose',
                    typ='bool',
                    default=False,
                    help='Verbose output',
                    short='v',
                    config_key='test.verbose'
                ),
                ArgMeta(
                    name='ignore',
                    default='',
                    help='Path to skip during collection (pytest --ignore)',
                    short='i'
                ),
                ArgMeta(
                    name='profile',
                    default='',
                    help='Configuration profile to load (e.g. prod, staging)',
                    short=''
                ),

            ]
        ),
        CommandMeta(
            name='tool',
            help='Run AST tools',
            group='tools',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.tools',
            handler_name='tool',
            examples=[
                ('jac tool list_tools', 'List all available AST tools'),
                ('jac tool <tool_name> [args...]', 'Run a specific tool')
            ],
            args=[
                ArgMeta(
                    name='tool',
                    kind=ArgKind.POSITIONAL,
                    help='Name of the AST tool to run',
                    required=True
                ),
                ArgMeta(
                    name='args',
                    kind=ArgKind.REMAINDER,
                    default=[],
                    help='Arguments for the tool',
                    short='a'
                ),

            ]
        ),
        CommandMeta(
            name='update',
            help='Update project dependencies to latest compatible versions',
            group='project',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.project',
            handler_name='update',
            examples=[
                ('jac update', 'Update all dependencies to latest compatible versions'),
                ('jac update requests', 'Update a specific package'),
                ('jac update --dev', 'Also update dev dependencies')
            ],
            args=[
                ArgMeta(
                    name='packages',
                    kind=ArgKind.MULTI_POSITIONAL,
                    default=[],
                    help='Packages to update (all if empty)',
                    short='p'
                ),
                ArgMeta(
                    name='dev',
                    typ='bool',
                    default=False,
                    help='Include dev dependencies',
                    short='d'
                ),
                ArgMeta(
                    name='verbose',
                    typ='bool',
                    default=False,
                    help='Verbose output',
                    short='v'
                ),

            ]
        ),
        CommandMeta(
            name='x',
            help='Run an installed CLI tool (console-script) under the Jac runtime',
            group='execution',
            tier='',
            hidden=False,
            handler_module='jaclang.cli.commands.execution',
            handler_name='x',
            examples=[
                (
                    'jac x hf download gpt2',
                    "Run the 'hf' tool (project venv first, else global)"
                ),
                (
                    'jac x black .',
                    'Run an installed formatter on the current directory'
                ),
                (
                    'jac x eslint .',
                    'Run a project npm tool (node_modules/.bin) via bun'
                ),
                ('jac x --global hf whoami', 'Force the global-site copy of a tool'),
                (
                    'jac x --global eslint .',
                    'Run a globally-installed npm tool (jac install --npm --global eslint)'
                ),
                ('jac x --node vite build', "Force the project's npm tool"),
                ('jac x --list', 'List the CLI tools available here')
            ],
            args=[
                ArgMeta(
                    name='name',
                    kind=ArgKind.POSITIONAL,
                    default='',
                    help='Tool/command name to run (omit to list available tools)'
                ),
                ArgMeta(
                    name='global',
                    typ='bool',
                    default=False,
                    help='Resolve from jac-owned global tools only (global python site + global npm), ignoring the project',
                    short='g',
                    dest='use_global'
                ),
                ArgMeta(
                    name='node',
                    typ='bool',
                    default=False,
                    help="Resolve from the project's npm tools (node_modules/.bin) only",
                    short='n',
                    dest='use_node'
                ),
                ArgMeta(
                    name='list_tools',
                    typ='bool',
                    default=False,
                    help='List the CLI tools available to run here',
                    short='l'
                ),
                ArgMeta(
                    name='args',
                    kind=ArgKind.REMAINDER,
                    help='Arguments passed to the tool',
                    short='a'
                ),

            ]
        ),

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
