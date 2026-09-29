import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.comptime { name as ct_name }


comptime SPEC_FIX: CommandSpec = CommandSpec(
         name="fix",
         help="Mechanical source migrations. 'jac fix placement' strips removed sv/cl/na placement markers, renames retired .sv.jac/.cl.jac/.na.jac files, declares each imported service module as an [apps.<name>] service app (kind, entry-point, and its old route), and pins any element whose inferred placement differs from its old marker via [placement.pins]. 'jac fix access' migrates to declared exposure: every top-level plain `def` in a serving app's entry module (and the plain defs that entry imports from project modules) and every plain `walker` reachable from a serving app become `:protect`, which is what the old plain-means-authenticated-endpoint runtime did; `_`-prefixed names and client (JSX) components are left alone",
         args=[
             Arg.create(
                 "target",
                 kind=ArgKind.POSITIONAL,
                 help="Migration to run: placement | access"
             ),
             Arg.create(
                 "paths",
                 kind=ArgKind.MULTI_POSITIONAL,
                 `default=["."],
                 help="Files or directories to migrate (default: current directory)"
             ),
             Arg.create(
                 "dry-run",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Report what would change without writing anything"
             ),
             Arg.create(
                 "strip-only",
                 typ=bool,
                 `default=False,
                 short="",
                 help="Only strip markers and rename files; skip placement verification and jac.toml pin/route recording (for fixture trees)"
             ),

         ],
         examples=[
             ("jac fix placement", "Migrate the current project off sv/cl/na markers"),
             ("jac fix placement src/", "Migrate one directory"),
             ("jac fix placement --dry-run", "Preview the migration"),
             (
                 "jac fix access",
                 "Mark the endpoints that were plain defs/walkers as :protect"
             ),
             (
                 "jac fix access --dry-run",
                 "List every declaration the access migration would change"
             ),

         ],
         group="analysis",
         handler_name=ct_name(fix)
     );

def fix(
    target: str, paths: list[str], dry_run: bool = False, strip_only: bool = False
) -> int;
