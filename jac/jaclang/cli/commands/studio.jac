comptime SPEC_STUDIO: CommandSpec = CommandSpec(
         name="hack",
         help="Open hack mode: a compiler-backed terminal workspace for coding agents",
         args=[
             Arg.create(
                 "action",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="(none) open the workspace | model | graph | roles | interface | rules | slice | blast | clusters | tour | diff | ask | agents | sessions | mcp"
             ),
             Arg.create(
                 "args",
                 kind=ArgKind.REMAINDER,
                 `default=[],
                 help="Arguments for the action (a module or symbol, an instruction, ...)"
             ),
             Arg.create(
                 "agent",
                 `default="",
                 short="a",
                 help="Agent to drive (see `jac hack agents`)"
             ),
             Arg.create(
                 "session",
                 `default="",
                 short="s",
                 help="Session id to resume (see `jac hack sessions`)"
             ),
             Arg.create(
                 "json",
                 kind=ArgKind.FLAG,
                 typ=bool,
                 `default=False,
                 dest="as_json",
                 help="Print JSON instead of text"
             ),
             Arg.create(
                 "dir",
                 `default="",
                 short="d",
                 dest="directory",
                 help="Project directory (default: the project around the current directory)"
             ),

         ],
         examples=[
             ("jac hack", "Open the workspace on the current project"),
             (
                 "jac hack model --json",
                 "Dump the project model: modules, wires, rules and symbols"
             ),
             ("jac hack model core.jobs", "Show one module's wiring and symbols"),
             (
                 "jac hack graph core",
                 "Show the wiring between a package's parts: layers, matrix, backward wires and cycles"
             ),
             (
                 "jac hack roles",
                 "Sort modules into foundations, hubs, integrators and entry points"
             ),
             (
                 "jac hack interface core",
                 "List the names that cross a package's boundary, and who uses each"
             ),
             (
                 "jac hack rules",
                 "Compare the archwire rules with the wires: unused permissions and violations"
             ),
             (
                 "jac hack slice app.main",
                 "Show everything an entry point rests on, step by step"
             ),
             (
                 "jac hack blast core.jobs.Runner",
                 "Show what depends on a module or a name"
             ),
             (
                 "jac hack clusters core",
                 "Compare the declared packages with the clusters the wiring implies"
             ),
             (
                 "jac hack tour",
                 "Write an onboarding tour of the codebase from its wiring"
             ),
             (
                 "jac hack diff main",
                 "Show how the architecture changed since a git revision"
             ),
             (
                 "jac hack ask core.jobs.Runner.start \"add retry with backoff\"",
                 "Hand a symbol and an instruction to an agent without the UI"
             ),
             ("jac hack agents", "List the agents hack mode can drive"),
             ("jac hack sessions", "List saved sessions"),
             (
                 "jac hack sessions fork <id>",
                 "Copy a session to try a different direction"
             ),

         ],
         group="tools",
         handler_name=ct_name(studio)
     );

def studio(
    action: str = "",
    args: list[str] = [],
    agent: str = "",
    session: str = "",
    as_json: bool = False,
    directory: str = ""
) -> int;

impl studio(
    action: str = "",
    args: list[str] = [],
    agent: str = "",
    session: str = "",
    as_json: bool = False,
    directory: str = ""
) -> int {
    return run_studio(action, args, agent, session, as_json, directory);
}
