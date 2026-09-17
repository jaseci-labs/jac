import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.comptime { name as ct_name }


comptime SPEC_CACHE: CommandSpec = CommandSpec(
         name="cache",
         help="Inspect and reclaim the machine-wide jac cache",
         args=[
             Arg.create(
                 "action",
                 kind=ArgKind.POSITIONAL,
                 `default="status",
                 help="Action: status (default), gc, purge"
             ),
             Arg.create(
                 "bucket",
                 `default="",
                 help="With purge: only this bucket (`jac cache status` lists the names)",
                 short="b"
             ),
             Arg.create(
                 "dry-run",
                 typ=bool,
                 `default=False,
                 help="With gc or purge: report what would be removed without removing it",
                 short="n"
             ),

         ],
         examples=[
             (
                 "jac cache status",
                 "Every bucket with its path, entry count, size and retention policy"
             ),
             (
                 "jac cache gc",
                 "Run every retention policy now and report the bytes reclaimed"
             ),
             ("jac cache gc --dry-run", "Show what gc would remove"),
             (
                 "jac cache purge",
                 "Remove every managed bucket (keeps the running runtime; never touches pg/)"
             ),
             ("jac cache purge --bucket jir-modules", "Remove one bucket"),

         ],
         group="tools",
         handler_name=ct_name(cache)
     );

def cache(action: str = "status", bucket: str = "", dry_run: bool = False) -> int;
