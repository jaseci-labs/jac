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
                 help="Action: init (write arch.jac from the current imports, with the "
                 "layering rules the imports already follow), sync (add the wires and "
                 "rules sealed modules are missing), graph (render the wiring; default)"
             ),
             Arg.create(
                 "scope",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="With init: a dotted package; wire only its modules and the "
                 "modules they import from, transitively, and merge into an existing "
                 "arch.jac instead of replacing it"
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
                 "Write arch.jac from every project-module import, with one rule per "
                 "package stating where it flows today, and remove those imports "
                 "from the modules"
             ),
             (
                 "jac arch init core.docs",
                 "Wire one package and everything it depends on, adding to an "
                 "existing arch.jac"
             ),
             (
                 "jac arch sync",
                 "Add a wire for every import a sealed module writes that arch.jac "
                 "does not declare, and a rule for every provider that has none"
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
    scope: str = "",
    strip: bool = False,
    force: bool = False,
    format: str = "mermaid",
    output: str = ""
) -> int;
