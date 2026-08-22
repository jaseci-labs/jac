import from jaclang.payload.assemble { MkPayloadOpts }

glob SUBCOMMANDS: tuple[str, ...] = (
         "fetch-pbs",
         "fetch-typeshed",
         "fetch-llvm",
         "fetch-bun",
         "build-musl",
         "build-wasm-libc",
         "mkpayload",
         "typeshed-sha",
         "pack"
     ),
     MKPAYLOAD_USAGE: str = (
         "usage: payload mkpayload <pbs-python-dir> <repo-root> <out.tar.zst> [--shim=PATH]"
         " [--skip-precompile] [--link-source=PATH] [--precompiled-cache=DIR] [--layer-cache=DIR]"
         " [--bun=PATH] [--musl=DIR] [--wasm-libc=DIR] [--seal] [--debug-src]\n"
         "(--seal: freeze bootstrap + emit MANIFEST.json; the payload boots from JIR, sources ship for tracebacks)"
     );

def main(argv: list[str]) -> int;
def dispatch(argv: list[str]);
def parse_mkpayload_flags(flags: list[str]) -> MkPayloadOpts;
def check_host_python;
