import from jaclang.comptime { name as ct_name }
import from jaclang.cli.command { Arg, ArgKind, CommandSpec }


comptime SPEC_BUILD: CommandSpec = CommandSpec(
         name="build",
         help="Build an app's artifact (.jab by default; type-checks first)",
         args=[
             Arg.create(
                 "target",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help=(
                     "App name from [apps], or an entry .jac file "
                     "(omit: [project] default-app, or the sole app)"
                 )
             ),
             Arg.create(
                 "all",
                 dest="all_apps",
                 typ=bool,
                 `default=False,
                 help="Build every app in the workspace into <output>/<app>/",
                 short=""
             ),
             Arg.create(
                 "as",
                 dest="projection",
                 `default="jab",
                 choices=[
                     "jab",
                     "sealed",
                     "binary",
                     "wheel",
                     "npm",
                     "source",
                     "client"
                 ],
                 help=(
                     "What to emit: 'jab' (single-file sealed app bundle, default), "
                     "'sealed' (unpacked image dir), 'binary' (self-contained "
                     "executable), 'wheel' (PyPI), 'npm' (tarball), 'source' "
                     "(ejected FastAPI+JS tree), 'client' (the app's client bundle only)"
                 )
             ),
             Arg.create(
                 "native",
                 typ=bool,
                 `default=False,
                 short="",
                 help=(
                     "Compile one self-contained native artifact through LLVM: a binary "
                     "when the module has a `with entry` block, a C-ABI library otherwise"
                 )
             ),
             Arg.create(
                 "lib",
                 typ=bool,
                 `default=False,
                 short="",
                 help="With --native: force the C-ABI shared library form (.so/.dylib/.dll)"
             ),
             Arg.create(
                 "memory",
                 `default="",
                 choices=["managed", "rc", "nogc"],
                 short="",
                 help=(
                     "With --native: memory profile for this build, overriding [memory] "
                     "profile in jac.toml (managed = refcounting + cycle collector, rc = "
                     "refcounting only, nogc = no runtime, every module borrow-checked)"
                 )
             ),
             Arg.create(
                 "target-triple",
                 dest="native_target",
                 `default="",
                 short="",
                 help="With --native: 'host' (default), 'wasm32', or an LLVM triple"
             ),
             Arg.create(
                 "link-mode",
                 dest="native_link_mode",
                 `default="",
                 choices=["objects", "bitcode"],
                 short="",
                 help="With --native: reuse optimized objects (default) or optimize whole-program bitcode"
             ),
             Arg.create(
                 "debug",
                 typ=bool,
                 `default=False,
                 short="",
                 help="With --native: DWARF debug info, symbols, and the RC trace machinery"
             ),
             Arg.create(
                 "output",
                 `default="dist",
                 help="Output directory for the built artifact",
                 short="o"
             ),
             Arg.create(
                 "fat",
                 typ=bool,
                 `default=False,
                 help=(
                     "Vendor the Python dependency closure as wheels into the bundle "
                     "(jab/binary only) so it materializes offline, with no PyPI"
                 )
             ),
             Arg.create(
                 "check_only",
                 typ=bool,
                 `default=False,
                 help="Run the gate and emit nothing"
             ),
             Arg.create(
                 "platform",
                 typ=str,
                 `default=None,
                 help=(
                     "Platform for desktop (windows, macos, linux, all) and mobile "
                     "(android, ios; web builds the mobile app for a browser)"
                 ),
                 choices=["windows", "macos", "linux", "all", "android", "ios", "web"],
                 short="p"
             ),

         ],
         examples=[
             ("jac build", "Build the default app's .jab into dist/"),
             ("jac build web", "Build the app named 'web'"),
             ("jac build --all", "Build every app into dist/<app>/"),
             ("jac build --as binary", "Build a self-contained executable"),
             ("jac build main.jac --native", "Compile one module to a native binary"),
             (
                 "jac build main.jac --native --memory nogc",
                 "Borrow-checked, no runtime"
             ),
             ("jac build lib.jac --native --lib", "Compile a C-ABI shared library"),
             (
                 "jac build main.jac --native --target-triple wasm32",
                 "Compile to WebAssembly"
             ),
             ("jac build --fat", "Build a fat jab (Python deps vendored)"),
             ("jac build --as wheel", "Build a PyPI wheel"),
             ("jac build --as client web", "Build only the web app's browser bundle"),
             (
                 "jac build --check_only",
                 "Type-check the whole project without building"
             ),
             (
                 "jac build --platform ios mobile",
                 "Build the app named 'mobile' for iOS"
             ),
             (
                 "jac build --platform web mobile",
                 "Build the mobile app as a browser bundle into dist/mobile/"
             ),

         ],
         group="build",
         handler_name=ct_name(build)
     );

def build(
    target: str = "",
    all_apps: bool = False,
    projection: str = "jab",
    output: str = "dist",
    check_only: bool = False,
    platform: str | None = None,
    fat: bool = False,
    native: bool = False,
    lib: bool = False,
    memory: str = "",
    native_target: str = "",
    debug: bool = False,
    native_link_mode: str = ""
) -> int;
