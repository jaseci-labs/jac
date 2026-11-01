comptime SPEC_NATIVE: CommandSpec = CommandSpec(
         name="native",
         help="Inspect or build the native artifacts a checkout or release runs on",
         hidden=True,
         args=[
             Arg.create(
                 "action",
                 kind=ArgKind.POSITIONAL,
                 `default="status",
                 help="Action: status (default), build"
             ),
             Arg.create(
                 "names",
                 kind=ArgKind.MULTI_POSITIONAL,
                 `default=[],
                 help="Artifacts to inspect or build (none = all of them); a per-target artifact takes its target as name@os-arch"
             ),
             Arg.create(
                 "force",
                 typ=bool,
                 `default=False,
                 help="With build: rebuild the named artifacts even when they are current",
                 short="f"
             ),
             Arg.create(
                 "exact",
                 typ=bool,
                 `default=False,
                 help="With build: rebuild every unit with the compiler as edited",
                 short=""
             ),
             Arg.create(
                 "release",
                 typ=bool,
                 `default=False,
                 help="With build: build exactly the release set (an artifact this host cannot build is an error)",
                 short=""
             ),
             Arg.create(
                 "require",
                 `default="",
                 help="With status: exit non-zero unless these comma-separated artifacts are built and current; 'release' is the release set, 'kit' the same set, which every kit carries",
                 short=""
             ),
             Arg.create(
                 "target-spec",
                 dest="target_spec",
                 `default="",
                 help="With build kernel: a kernel build request; build the kernel this KernelTarget JSON describes with the running kernel (stage 0 runs this on the previous release)",
                 short=""
             ),
             Arg.create(
                 "output",
                 `default="",
                 help="With --target-spec: where to write the built kernel",
                 short=""
             ),
             Arg.create(
                 "triple",
                 `default="",
                 help="With --target-spec: the target triple (default: this host)",
                 short=""
             ),

         ],
         examples=[
             ("jac native status", "Every artifact, what this process runs, and why"),
             (
                 "jac native status kernel",
                 "Every input that moved since the kernel was built"
             ),
             (
                 "jac native build",
                 "Build every stale or missing artifact this host can build"
             ),
             (
                 "jac native build kernel --force",
                 "Relink the kernel although it is current"
             ),
             (
                 "jac native build kernel",
                 "Build this checkout's kernel from the pinned previous release (stage 0)"
             ),
             (
                 "jac native build musl@linux-aarch64",
                 "Build the static musl runtime for another target"
             ),
             ("jac native build --release", "Build exactly what a release carries"),
             (
                 "jac native status --require release",
                 "Fail unless the release set is in place"
             ),
             (
                 "jac native status --require kit",
                 "Fail unless this kit carries everything a release does"
             ),

         ],
         group="tools",
         handler_name=ct_name(native)
     );

def native(
    action: str = "status",
    names: (list[str] | None) = None,
    force: bool = False,
    exact: bool = False,
    release: bool = False,
    require: str = "",
    target_spec: str = "",
    output: str = "",
    triple: str = ""
) -> int;
