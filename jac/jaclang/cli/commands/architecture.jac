comptime SPEC_ARCH: CommandSpec = CommandSpec(
         name="arch",
         help="Declare the project's module wiring in arch.jac and keep it in sync",
         args=[
             Arg.create(
                 "action",
                 kind=ArgKind.POSITIONAL,
                 `default="graph",
                 help="Action: init (write arch.jac from the current imports, sealing "
                 "the directory), sync (add the wires its modules are missing), graph "
                 "(render the wiring; default)"
             ),
             Arg.create(
                 "scope",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="The directory an arch.jac governs (default: the project root). "
                 "Without it, sync visits every arch.jac in the project"
             ),
             Arg.create(
                 "strip",
                 typ=bool,
                 `default=False,
                 help="With init or sync: remove the imports that arch.jac now provides "
                 "from its modules (the same fix `jac fmt --lintfix` applies)",
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
                 "Seal the project: write arch.jac from every import between its "
                 "modules and remove those imports from the modules"
             ),
             ("jac arch init core --strip", "Seal one directory with its own arch.jac"),
             (
                 "jac arch sync",
                 "Add a wire for every import a module writes that its arch.jac does "
                 "not declare"
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
