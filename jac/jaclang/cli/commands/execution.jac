import from pathlib { Path }
import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.comptime { name as ct_name }


comptime SPEC_RUN: CommandSpec = CommandSpec(
         name="run",
         help="Run an app or a Jac file (executes or serves, per app kind)",
         tier="core",
         args=[
             Arg.create(
                 "target",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help=(
                     "App name from [apps], or a path to a .jac, .py or .jab file "
                     "(omit: [project] default-app, or the sole app)"
                 )
             ),
             Arg.create(
                 "backend",
                 `default="",
                 choices=["python", "native"],
                 help="Execution backend (omit for automatic selection)"
             ),
             Arg.create(
                 "show",
                 typ=bool,
                 `default=False,
                 help="Print the resolved run plan (every app's plan in a workspace) without executing it",
                 short="s"
             ),
             Arg.create(
                 "main",
                 typ=bool,
                 `default=True,
                 help="Treat module as __main__",
                 short="m",
                 config_key="run.main"
             ),
             Arg.create(
                 "cache",
                 typ=bool,
                 `default=True,
                 help="Enable compilation cache",
                 short="c",
                 config_key="run.cache"
             ),
             Arg.create(
                 "profile",
                 `default="",
                 short="",
                 help="Configuration profile to load (e.g. prod, staging)"
             ),
             Arg.create(
                 "diagnostics",
                 `default="",
                 help="Diagnostic verbosity: error (default, fail on errors), all (errors+warnings), none (silent)",
                 short="e"
             ),
             Arg.create(
                 "entry",
                 dest="entry_name",
                 `default="",
                 short="",
                 help="Invoke a specific function/walker entrypoint"
             ),
             Arg.create(
                 "node",
                 dest="nd",
                 `default="",
                 help="Starting node ID for --entry (OSP node binding)",
                 short="n"
             ),
             Arg.create(
                 "root",
                 dest="root_id",
                 `default="",
                 help="Root executor ID for --entry",
                 short="r"
             ),
             Arg.create(
                 "debug",
                 dest="debug_mode",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Run under the Python debugger"
             ),
             Arg.create(
                 "serve",
                 dest="serve_mode",
                 typ=bool,
                 `default=None,
                 short="",
                 help="Serve instead of executing (default: the app kind decides)"
             ),
             Arg.create(
                 "port",
                 typ=int,
                 `default=None,
                 help=(
                     "Server port (serving only, default 8000). A port given here "
                     "must be free: it is a contract with whatever sits in front "
                     "of it, so the server fails rather than moving to another port."
                 ),
                 short="p",
                 config_key="serve.port"
             ),
             Arg.create(
                 "dev",
                 typ=bool,
                 `default=None,
                 help="Serve with hot reload / HMR (serving only)",
                 short="d"
             ),
             Arg.create(
                 "api-port",
                 dest="api_port",
                 typ=int,
                 `default=None,
                 short="",
                 help="Separate backend API port in --dev mode (serving only)"
             ),
             Arg.create(
                 "no-client",
                 typ=bool,
                 `default=None,
                 help="Skip client bundling/serving, API only (serving only)",
                 short=""
             ),
             Arg.create(
                 "faux",
                 typ=bool,
                 `default=None,
                 help="Print endpoint docs only, no server (serving only)",
                 short="f"
             ),
             Arg.create(
                 "host",
                 typ=str,
                 `default=None,
                 short="",
                 help=(
                     "Interface to bind (serving only; default [serve] host, 0.0.0.0). "
                     "Use 127.0.0.1 to keep a dev server off the network. For mobile "
                     "dev (--client mobile --dev) this is also the host the device "
                     "reaches this machine on."
                 )
             ),
             Arg.create(
                 "workers",
                 typ=str,
                 `default=None,
                 short="w",
                 help=(
                     "Worker processes to serve with (serving only; default [serve.workers] "
                     "count, 1). 'auto' sizes from the CPU quota. Each worker is a full "
                     "process with its own thread pool; the parent only supervises."
                 )
             ),
             Arg.create(
                 "platform",
                 typ=str,
                 `default=None,
                 help=(
                     "Mobile apps: android or ios runs on a device or simulator, web runs "
                     "the same app in a browser via react-native-web "
                     "(auto = the app's [apps.<name>] platform, else android)"
                 ),
                 choices=["auto", "android", "ios", "web"],
                 short=""
             ),
             Arg.create(
                 "takeover",
                 typ=bool,
                 `default=None,
                 help=(
                     "Run a named file as the surrounding project even when the "
                     "file lives outside it (--no-takeover runs it standalone), "
                     "and evict any other session holding this project's "
                     "database before serving"
                 ),
                 short=""
             ),
             Arg.create(
                 "fleet",
                 typ=bool,
                 `default=False,
                 help=(
                     "Run the workspace's service apps as separate local processes "
                     "instead of colocating them in this server (serving only)"
                 ),
                 short=""
             ),
             Arg.create(
                 "args", kind=ArgKind.REMAINDER, help="Arguments passed to the script"
             ),

         ],
         examples=[
             ("jac run hello.jac", "Run a simple program"),
             ("jac run", "Run the default app per its kind"),
             ("jac run web", "Run the app named 'web' from [apps]"),
             (
                 "jac run app.jab",
                 "Run a sealed app bundle (kind-aware; servable kinds serve on the app's configured port)"
             ),
             ("jac run --entry my_walker app.jac arg1", "Invoke a specific entrypoint"),
             ("jac run --debug app.jac", "Run under the Python debugger"),
             (
                 "jac run --show",
                 "Print what each app would run/serve/build, without doing it"
             ),
             ("jac run --no-cache app.jac", "Run without caching"),
             ("jac run --profile prod app.jac", "Run with production profile"),
             (
                 "jac run -e all app.jac",
                 "Run and show all diagnostics (errors+warnings)"
             ),
             ("jac run script.jac arg1 arg2", "Run with script arguments"),
             (
                 "jac run --serve app.jac",
                 "Serve a file that no jac.toml marks as servable"
             ),
             ("jac run --port 3000", "Serve the default app on port 3000"),
             ("jac run --dev", "Serve the default app with hot module replacement"),
             ("jac run --dev --no-client", "HMR mode without client bundling"),
             ("jac run --faux", "Print the app's endpoint docs without serving"),
             ("jac run --platform web mobile", "Run a mobile app in the browser"),
             (
                 "jac run web --fleet",
                 "Serve 'web' with the workspace's service apps as local processes"
             ),
             (
                 "jac run --takeover",
                 "Evict a stuck session holding this project's database"
             ),
             (
                 "jac run --no-takeover tool.jac",
                 "Run a project file standalone, leaving the project untouched"
             ),

         ],
         group="execution",
         handler_name=ct_name(run)
     );

def run(
    target: str = "",
    show: bool = False,
    main: bool = True,
    cache: bool = True,
    diagnostics: str = "",
    entry_name: str = "",
    nd: str = "",
    root_id: str = "",
    debug_mode: bool = False,
    serve_mode: bool | None = None,
    port: int | None = None,
    dev: bool | None = None,
    api_port: int | None = None,
    no_client: bool | None = None,
    faux: bool | None = None,
    host: str | None = None,
    platform: str | None = None,
    takeover: bool | None = None,
    fleet: bool = False,
    workers: str | None = None,
    args: list[str] = [],
    backend: str = ""
) -> int;

def serve(
    filename: str,
    port: int = 0,
    main: bool = True,
    faux: bool = False,
    dev: bool = False,
    api_port: int = 0,
    no_client: bool = False,
    host: str = "",
    platform: str = "",
    takeover: bool = False,
    fleet: bool = False,
    app: str = "",
    workers: str = ""
) -> int;

def debug(filename: str, main: bool = True, cache: bool = False) -> int;

def run_jab_image(
    img_root: Path, port: (int | None), args: list[str], serve_only: bool, label: str
) -> int;

comptime SPEC_X: CommandSpec = CommandSpec(
         name="x",
         help="Run an installed CLI tool (console-script) under the Jac runtime",
         args=[
             Arg.create(
                 "name",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="Tool/command name to run (omit to list available tools)"
             ),
             Arg.create(
                 "global",
                 typ=bool,
                 `default=False,
                 help="Resolve from jac-owned global tools only (global python site + global npm), ignoring the project",
                 short="g",
                 dest="use_global"
             ),
             Arg.create(
                 "node",
                 typ=bool,
                 `default=False,
                 help="Resolve from the project's npm tools (node_modules/.bin) only",
                 short="n",
                 dest="use_node"
             ),
             Arg.create(
                 "list_tools",
                 typ=bool,
                 `default=False,
                 help="List the CLI tools available to run here",
                 short="l"
             ),
             Arg.create(
                 "args", kind=ArgKind.REMAINDER, help="Arguments passed to the tool"
             ),

         ],
         examples=[
             (
                 "jac x hf download gpt2",
                 "Run the 'hf' tool (project venv first, else global)"
             ),
             ("jac x black .", "Run an installed formatter on the current directory"),
             ("jac x eslint .", "Run a project npm tool (node_modules/.bin) via bun"),
             ("jac x --global hf whoami", "Force the global-site copy of a tool"),
             (
                 "jac x --global eslint .",
                 "Run a globally-installed npm tool (jac install --npm --global eslint)"
             ),
             ("jac x --node vite build", "Force the project's npm tool"),
             ("jac x --list", "List the CLI tools available here"),

         ],
         group="execution",
         handler_name=ct_name(x)
     );

def x(
    name: str = "",
    use_global: bool = False,
    use_node: bool = False,
    list_tools: bool = False,
    args: list[str] = []
) -> int;
