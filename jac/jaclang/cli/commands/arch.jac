import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.comptime { name as ct_name }


comptime SPEC_ARCH: CommandSpec = CommandSpec(
         name="arch",
         help="Declare the project's module wiring in arch.jac and keep it in sync",
         args=[
             Arg.create(
                 "action",
                 kind=ArgKind.POSITIONAL,
                 `default="graph",
                 help="Action: init (write arch.jac from the current imports), sync (add "
                 "missing wires for covered modules), graph (render the wiring; default)"
             ),
             Arg.create(
                 "strip",
                 typ=bool,
                 `default=False,
                 help="With init or sync: remove the imports that arch.jac now provides "
                 "from every covered module (the same fix `jac fmt --lintfix` applies)",
                 short="s"
             ),
             Arg.create(
                 "force",
                 typ=bool,
                 `default=False,
                 help="With init: overwrite an existing arch.jac",
                 short="f"
             ),
             Arg.create(
                 "format",
                 `default="mermaid",
                 choices=["mermaid", "json"],
                 help="With graph: output format",
                 short=""
             ),
             Arg.create(
                 "output",
                 `default="",
                 help="With graph: write to this file instead of stdout",
                 short="o"
             ),

         ],
         examples=[
             (
                 "jac arch init --strip",
                 "Write arch.jac from every project-module import and remove those "
                 "imports from the modules"
             ),
             (
                 "jac arch sync",
                 "Add a wire for every import a covered module writes that arch.jac "
                 "does not declare"
             ),
             ("jac arch graph", "Print the wiring as a mermaid diagram"),
             (
                 "jac arch graph --format json -o wiring.json",
                 "Dump wires and rules as JSON"
             ),

         ],
         group="project",
         handler_name=ct_name(arch)
     );

def arch(
    action: str = "graph",
    strip: bool = False,
    force: bool = False,
    format: str = "mermaid",
    output: str = ""
) -> int;
