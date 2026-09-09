import from jaclang.comptime { name as ct_name }
import from jaclang.cli.command { Arg, ArgKind, CommandSpec }


comptime SPEC_PRECOMPILE: CommandSpec = CommandSpec(
         name="precompile",
         help="Precompile a package tree into _precompiled .jir units (the seal engine behind 'jac build --as jab|sealed')",
         hidden=True,
         args=[
             Arg.create(
                 "source_dir",
                 kind=ArgKind.POSITIONAL,
                 help="Directory holding the package (or staged app) to precompile"
             ),
             Arg.create(
                 "seal",
                 kind=ArgKind.FLAG,
                 `default=False,
                 short="",
                 help=(
                     "Precompile, freeze the bootstrap seed tier, and emit "
                     "MANIFEST.json (JIR-authoritative image; .jac sources stay "
                     "on disk for tracebacks, never compiled at runtime)"
                 )
             ),
             Arg.create(
                 "seal-compile",
                 kind=ArgKind.FLAG,
                 `default=False,
                 short="",
                 help=(
                     "Compile only (exclude the seed tier), no finalize -- the "
                     "payload build's crash-tolerant first pass"
                 )
             ),
             Arg.create(
                 "seal-finalize",
                 kind=ArgKind.FLAG,
                 `default=False,
                 short="",
                 help=(
                     "Run ONLY the seal step over an already-precompiled tree "
                     "(verify completeness, build the manifest, freeze) -- "
                     "resilient to the best-effort compile crashing on a native "
                     "module"
                 )
             ),
             Arg.create(
                 "debug-src",
                 kind=ArgKind.FLAG,
                 `default=False,
                 short="",
                 help="Embed zlib source text in each .jir (dev tracebacks)"
             ),
             Arg.create(
                 "jobs",
                 kind=ArgKind.OPTION,
                 `default="",
                 short="",
                 help=(
                     "Worker processes: a count, 'auto' (one per core) or 0 for "
                     "serial; defaults to JAC_PRECOMPILE_JOBS / JAC_JOBS"
                 )
             ),
             Arg.create(
                 "app",
                 kind=ArgKind.OPTION,
                 `default="",
                 short="",
                 help="With --seal: the [apps.<name>] app whose entry the image carries (default: the default app)"
             ),

         ],
         examples=[
             ("jac precompile ./jac", "Precompile the jaclang tree into _precompiled/"),
             (
                 "jac precompile <stage-dir> --seal",
                 "Seal a staged app image (what jab builds and scale deploys run)"
             ),

         ],
         group="build",
         handler_name=ct_name(precompile)
     );

def precompile(
    source_dir: str,
    seal: bool = False,
    seal_compile: bool = False,
    seal_finalize: bool = False,
    debug_src: bool = False,
    jobs: str = "",
    app: str = ""
) -> int;
