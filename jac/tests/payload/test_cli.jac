"""`jaclang.dist.payload.cli.main`: the subcommand grammar build.zig drives. Every
usage error exits non-zero with its usage line on stderr (prefixed `payload: `
like the Zig tool's `die`), and the mkpayload trailing flags parse into
MkPayloadOpts."""

import contextlib;
import io;
import os;
import shutil;
import tempfile;

import from jaclang.dist.payload.cli { MKPAYLOAD_USAGE, main, parse_mkpayload_flags }

def run(argv: list[str]) -> tuple[int, str] {
    err = io.StringIO();
    with contextlib.redirect_stderr(err) {
        rc = main(argv);
    }
    return (rc, err.getvalue());
}

test "no subcommand and unknown subcommand are usage errors" {
    (rc, err) = run([]);
    assert rc == 1;
    assert err.startswith("payload: usage: payload <fetch-typeshed|");
    assert "|mkpayload|typeshed-sha|pack> ..." in err;

    (rc, err) = run(["bogus"]);
    assert rc == 1;
    assert err == "payload: unknown subcommand 'bogus'\n";
}

test "every subcommand reports its usage when positional args are missing" {
    cases = [
        (["fetch-llvm"], "usage: payload fetch-llvm <dest-dir>"),
        (
            ["fetch-bun", "linux-x86_64"],
            "usage: payload fetch-bun <os-arch> <dest-dir>"
        ),
        (
            ["build-musl", "linux-x86_64", "/tmp/x"],
            "usage: payload build-musl <os-arch> <dest-dir> <zig-exe>"
        ),
        (
            ["build-wasm-libc", "/src", "/dest"],
            "usage: payload build-wasm-libc <wasm-rt-src-dir> <dest-dir> <zig-exe>"
        ),
        (["fetch-typeshed"], "usage: payload fetch-typeshed <repo-root>"),
        (["mkpayload", "/pbs", "/root"], MKPAYLOAD_USAGE),
        (["typeshed-sha"], "usage: payload typeshed-sha <commit>"),
        (
            ["pack", "/stub", "/payload"],
            "usage: payload pack <stub> <payload.tar.zst> <out> [stubcat.bin]"
        )
    ];
    for (argv, usage) in cases {
        (rc, err) = run(argv);
        assert rc == 1 , argv;
        assert err == f"payload: {usage}\n" , (argv, err);
    }
    assert "--compiler-image=DIR" in MKPAYLOAD_USAGE
        and "--stub-catalog=PATH" in MKPAYLOAD_USAGE;
    assert "--nvim" not in MKPAYLOAD_USAGE and "--pyembed" not in MKPAYLOAD_USAGE;
}

test "offline argument validation dies before any network or subprocess" {
    tmp = tempfile.mkdtemp(prefix="jac-payload-cli-");
    try {
        (rc, err) = run(["fetch-bun", "plan9-z80", os.path.join(tmp, "bun")]);
        assert rc == 1
            and err == "payload: fetch-bun: unsupported platform 'plan9-z80'\n";

        (rc, err) = run(
            ["build-musl", "macos-aarch64", os.path.join(tmp, "musl"), "zig"]
        );
        assert rc == 1;
        assert err
            == "payload: build-musl: unsupported osarch 'macos-aarch64' (need linux-x86_64|linux-aarch64)\n";

        (rc, err) = run(
            [
                "build-wasm-libc",
                os.path.join(tmp, "nope"),
                os.path.join(tmp, "out"),
                "zig"
            ]
        );
        assert rc == 1;
        assert err
            == f"payload: build-wasm-libc: wasm_rt source dir missing at {tmp}/nope\n";

        (rc, err) = run(["fetch-typeshed", tmp]);
        assert rc == 1;
        assert err
            == f"payload: fetch-typeshed: no PIN at {tmp}/jaclang/vendor/typeshed/PIN\n";

        (rc, err) = run(
            [
                "mkpayload",
                os.path.join(tmp, "pbs"),
                tmp,
                os.path.join(tmp, "out.tar.zst")
            ]
        );
        assert rc == 1;
        assert err == f"payload: mkpayload: no python at {tmp}/pbs/install/bin\n";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "payload flags describe artifact inputs and reject obsolete build modes" {
    import from jaclang.dist.payload.fsutil { PayloadDie }
    opts = parse_mkpayload_flags(
        [
            "--compiler-image=/build/site",
            "--stub-catalog=/build/stubcat.bin",
            "--bun=/build/bun",
            "--musl=/build/musl",
            "--wasm-libc=/build/wasm",
            "--layer-cache=/cache/layers"
        ]
    );
    assert opts.compiler_image == "/build/site";
    assert opts.stub_catalog == "/build/stubcat.bin";
    assert opts.bun_bin == "/build/bun";
    assert opts.musl_dir == "/build/musl";
    assert opts.wasm_libc_dir == "/build/wasm";
    assert opts.layer_cache == "/cache/layers";
    for arg in (
        "--skip-precompile",
        "--link-source=/checkout",
        "--seal",
        "--compiler-image=",
        "--unknown"
    ) {
        with testraises(PayloadDie) {
            parse_mkpayload_flags([arg]);
        }
    }
}
