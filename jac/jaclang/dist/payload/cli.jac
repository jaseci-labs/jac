import from jaclang.dist.payload.assemble { MkPayloadOpts }

glob SUBCOMMANDS: tuple[str, ...] = (
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
         "usage: payload mkpayload <python-dir> <repo-root> <out.tar.zst>"
         " --compiler-image=DIR --stub-catalog=PATH"
         " [--layer-cache=DIR] [--bun=PATH] [--musl=DIR] [--wasm-libc=DIR]"
     );

def main(argv: list[str]) -> int;
def dispatch(argv: list[str]);
def parse_mkpayload_flags(flags: list[str]) -> MkPayloadOpts;
def check_host_python;
