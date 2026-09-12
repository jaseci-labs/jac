import os;
import sys;

import from jaclang.dist.payload.assemble { mk_payload }
import from jaclang.dist.payload.fetch {
    fetch_bun,
    fetch_llvm,
    fetch_typeshed,
    typeshed_sha
}
import from jaclang.dist.payload.fsutil { PayloadDie, die }
import from jaclang.dist.payload.pack { pack }
import from jaclang.dist.payload.pins { host_py_minor, py_ver }
import from jaclang.dist.payload.vendor { build_musl, build_wasm_libc }

impl main(argv: list[str]) -> int {
    import os;
    os.environ.setdefault("JAC_COMPILER_LIB", "off");
    try {
        dispatch(list(argv));
    } except PayloadDie as e {
        sys.stderr.write(f"payload: {e}\n");
        sys.stderr.flush();
        return 1;
    }
    return 0;
}

def _need(argv: list[str], count: int, usage: str) {
    if len(argv) < count {
        die(usage);
    }
}

impl dispatch(argv: list[str]) {
    if len(argv) < 1 {
        die("usage: payload <" + "|".join(SUBCOMMANDS) + "> ...");
    }
    cmd = argv[0];
    if cmd not in SUBCOMMANDS {
        die(f"unknown subcommand '{cmd}'");
    }
    if cmd == "fetch-llvm" {
        _need(argv, 2, "usage: payload fetch-llvm <dest-dir>");
        fetch_llvm(argv[1]);
    } elif cmd == "fetch-bun" {
        _need(argv, 3, "usage: payload fetch-bun <os-arch> <dest-dir>");
        fetch_bun(argv[1], argv[2]);
    } elif cmd == "build-musl" {
        _need(argv, 4, "usage: payload build-musl <os-arch> <dest-dir> <zig-exe>");
        build_musl(argv[1], argv[2], argv[3]);
    } elif cmd == "build-wasm-libc" {
        _need(
            argv,
            4,
            "usage: payload build-wasm-libc <wasm-rt-src-dir> <dest-dir> <zig-exe>"
        );
        build_wasm_libc(argv[1], argv[2], argv[3]);
    } elif cmd == "fetch-typeshed" {
        _need(argv, 2, "usage: payload fetch-typeshed <repo-root>");
        fetch_typeshed(argv[1]);
    } elif cmd == "mkpayload" {
        _need(argv, 4, MKPAYLOAD_USAGE);
        check_host_python();
        os.environ["JAC_HOST_EXEC_RESOLUTION"] = "1";
        mk_payload(argv[1], argv[2], argv[3], parse_mkpayload_flags(argv[4:]));
    } elif cmd == "typeshed-sha" {
        _need(argv, 2, "usage: payload typeshed-sha <commit>");
        typeshed_sha(argv[1]);
    } elif cmd == "stubcat" {
        _need(argv, 4, "usage: payload stubcat <python-dir> <site-dir> <out.bin>");
        import from jaclang.dist.payload.assemble { resolve_python, run_stubcat }
        if not run_stubcat(resolve_python(argv[1]), argv[1], argv[2], argv[3]) {
            die("stubcat: build failed (see log above)");
        }
    } elif cmd == "pack" {
        _need(
            argv, 4, "usage: payload pack <stub> <payload.tar.zst> <out> [stubcat.bin]"
        );
        pack(argv[1], argv[2], argv[3], argv[4] if len(argv) > 4 else None);
    }
}

impl parse_mkpayload_flags(flags: list[str]) -> MkPayloadOpts {
    opts = MkPayloadOpts();
    valued = {
        "--shim=": "shim_so",
        "--bun=": "bun_bin",
        "--link-source=": "link_source",
        "--musl=": "musl_dir",
        "--wasm-libc=": "wasm_libc_dir",
        "--precompiled-cache=": "precompiled_cache",
        "--layer-cache=": "layer_cache",
        "--stubcat-out=": "stubcat_out"
    };
    for arg in flags {
        if arg == "--skip-precompile" {
            opts.skip_precompile = True;
            continue;
        }
        if arg == "--seal" {
            opts.seal = True;
            continue;
        }
        if arg == "--debug-src" {
            opts.debug_src = True;
            continue;
        }
        if arg == "--skip-stubcat" {
            opts.skip_stubcat = True;
            continue;
        }
        for (prefix, field) in valued.items() {
            if arg.startswith(prefix) {
                setattr(opts, field, arg[len(prefix):]);
                break;
            }
        }
    }
    return opts;
}

impl check_host_python{
    want = py_ver();
    have = host_py_minor();
    if want != have {
        die(
            f"mkpayload: must run on the bundled CPython {want} (this interpreter is {have}); invoke it with the source-built python"
        );
    }
}
