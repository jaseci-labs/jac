import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.comptime { name as ct_name }


comptime SPEC_GUIDE: CommandSpec = CommandSpec(
         name="guide",
         help="Show bundled Jac guides and documentation",
         tier="learn",
         args=[
             Arg.create(
                 "topic",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help=(
                     "Guide or doc to print, or a doc set (reference, quick-guide, "
                     "build, tutorials, internals, community) to list; omit to "
                     "show the full index"
                 )
             ),
             Arg.create(
                 "search",
                 `default="",
                 help="Grep every bundled guide and doc (name:line: hits)",
                 short="s"
             ),
             Arg.create(
                 "section",
                 short="",
                 `default="",
                 help="Print one section by slug or exact heading; requires a topic"
             ),
             Arg(
                 name="sections",
                 kind=ArgKind.OPTION,
                 typ=bool,
                 `default=False,
                 help="List section headings and slugs without loading their text"
             ),
             Arg.create(
                 "export",
                 `default="",
                 help="Export all guides as a Claude Code skills directory at this path",
                 short="e"
             ),
             Arg(
                 name="nav",
                 kind=ArgKind.OPTION,
                 typ=bool,
                 `default=False,
                 help="Print the docs navigation: sections, titles, and reading order",
                 short="n"
             ),
             Arg(
                 name="json",
                 kind=ArgKind.OPTION,
                 typ=bool,
                 `default=False,
                 help="Emit machine-readable JSON (for tools and agents)",
                 short="j",
                 dest="as_json"
             ),

         ],
         examples=[
             ("jac guide", "List every bundled guide and doc set"),
             ("jac guide jac-types", "Print the jac-types guide"),
             ("jac guide jac-types --sections", "List sections before reading"),
             ("jac guide jac-types --section pitfalls", "Read one section"),
             (
                 "jac guide reference/diagnostics",
                 "Print the bundled diagnostics reference"
             ),
             ("jac guide reference", "List every doc in the reference set"),
             ("jac guide --search 'breaking changes'", "Grep all bundled content"),
             ("jac guide --nav", "Docs navigation: sections and reading order"),
             ("jac guide --json", "Full guide/doc index as JSON for tooling"),
             ("jac guide --nav --json", "Navigation manifest as JSON for tooling"),
             ("jac guide --export ~/.claude/skills", "Export guides as Agent Skills"),

         ],
         group="general",
         handler_name=ct_name(guide)
     );

def guide(
    topic: str = "",
    search: str = "",
    export: str = "",
    nav: bool = False,
    as_json: bool = False,
    section: str = "",
    sections: bool = False
) -> int;
