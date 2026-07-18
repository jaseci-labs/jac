"""Phase 3.5 acceptance: flagship PyO3 wheels ship in an na binary, no host python.

3.3.4 proved the packaging half with orjson (a small single-`.so` wheel). This is
the flagship acceptance: the two wheels the py tier exists to inherit -- `polars`
(a data-frame engine doing a real group_by/agg) and `cryptography` (an openssl
vendoring wheel, the symbol-interposition risk called out in FFI-LANES 3.5) --
bundled the same way and booted from the embedded interpreter.

Each host is nacompiled to an ELF, a CUSTOM slim runtime payload is assembled
carrying the pip-installed wheel (_assemble_pyinterop_payload -> __extractrt +
pip install --target site-packages + slim + patchelf-RPATH + repack), grafted
onto the host (__graftrt <bin> <payload>), and run: the single file brings up
embedded CPython 3.14 and drives the wheel with no Python on the machine. The
markers print from the Python side so a clean marker proves install + patchelf +
repack + boot + a real library call all line up.

polars exercises a native compute kernel (group_by + agg); cryptography exercises
a wheel that vendors its own openssl -- if na's NEEDED libs interposed those
symbols the Fernet round-trip would corrupt, so a clean round-trip is the
interposition check. Runs only where the fused runtime boots (the __graftrt
trailer a `zig build` jac carries) AND pip can reach the wheels for the host
platform tag (cp314/abi3), same gating as the sibling pyinterop tests. Host libc
must match the target.
"""
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.client.targets.desktop.desktop_build {
    _jac_bin,
    _stage_pyembed_shim
}
import from jaclang.cli.commands.project { _assemble_pyinterop_payload }


def _flagship_host_src(pysrc: str) -> str {
    # An na host: boot the runtime, then run `pysrc` in the embedded interpreter.
    # The wheel is imported off the grafted binary's own module_search_paths
    # (embed.zig's site-packages entry), so a clean import proves the bundled
    # wheel -- not a host site-packages -- is what booted. Exit 1 = boot failed,
    # exit 2 = the Python body raised.
    escaped = pysrc.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n");
    return (
        "import sys;\n"
        "import from python { py_boot }\n"
        "import from jacpyembed { def jpy_PyRun_SimpleString(cmd: str) -> i32; }\n"
        "with entry {\n"
        "    rc: i32 = py_boot();\n"
        "    if rc != 0 { sys.exit(1); }\n"
        f"    st: i32 = jpy_PyRun_SimpleString(\"{escaped}\");\n"
        "    if st != 0 { sys.exit(2); }\n"
        "}\n"
    );
}


def _bundle_and_run(name: str, pysrc: str, wheels: list) -> str {
    # nacompile the host -> assemble a slim payload carrying `wheels` -> graft it
    # -> run. Returns the binary's stdout for the caller to assert markers on.
    jac = _jac_bin();
    tmp = tempfile.mkdtemp(prefix=f"{name}-");
    try {
        out_dir = Path(tmp);
        # The shim rides $ORIGIN-adjacent so `import from jacpyembed` resolves the
        # sibling libjacpyembed at load (it ships in the fused payload).
        _stage_pyembed_shim(out_dir);
        (out_dir / f"{name}.na.jac").write_text(_flagship_host_src(pysrc));
        binary = out_dir / name;
        comp = subprocess.run(
            [jac, "nacompile", f"{name}.na.jac", "-o", name],
            cwd=tmp,
            capture_output=True,
            text=True,
            timeout=300
        );
        assert comp.returncode == 0 and binary.exists() , f"nacompile failed:\n{comp.stderr}";

        stage = Path(tempfile.mkdtemp(prefix=f"{name}-stage-", dir=tmp));
        payload = _assemble_pyinterop_payload(wheels, stage);
        assert payload is not None and payload.exists() , f"{name} payload assembly failed";

        graft = subprocess.run(
            [jac, "__graftrt", str(binary), str(payload)],
            capture_output=True,
            text=True,
            timeout=120
        );
        assert graft.returncode == 0 , f"__graftrt failed:\n{graft.stderr}";

        run = subprocess.run(
            [str(binary)], cwd=tmp, capture_output=True, text=True, timeout=180
        );
        assert run.returncode == 0 , (
            f"{name} binary exited {run.returncode}\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        return run.stdout;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "na binary runs a polars group_by with no host python" {
    pysrc = (
        "import polars as pl\n"
        "print('POLARS_VERSION', pl.__version__, flush=True)\n"
        "df = pl.DataFrame({'g': ['a', 'b', 'a', 'b'], 'v': [1, 2, 3, 4]})\n"
        "out = df.group_by('g').agg(pl.col('v').sum()).sort('g')\n"
        "vals = dict(zip(out['g'].to_list(), out['v'].to_list()))\n"
        "ok = vals == {'a': 4, 'b': 6}\n"
        "print('POLARS_GROUPBY_OK' if ok else 'POLARS_GROUPBY_BAD', vals, flush=True)\n"
    );
    stdout = _bundle_and_run("pyinterop_polars", pysrc, ["polars"]);
    for marker in ["POLARS_VERSION", "POLARS_GROUPBY_OK"] {
        assert marker in stdout , f"marker {marker} missing\nstdout:\n{stdout}";
    }
}


test "na binary runs a cryptography Fernet round-trip with no host python" {
    pysrc = (
        "import cryptography\n"
        "from cryptography.fernet import Fernet\n"
        "print('CRYPTOGRAPHY_VERSION', cryptography.__version__, flush=True)\n"
        "f = Fernet(Fernet.generate_key())\n"
        "tok = f.encrypt(b'jac-py-tier')\n"
        "ok = f.decrypt(tok) == b'jac-py-tier'\n"
        "print('CRYPTO_ROUNDTRIP_OK' if ok else 'CRYPTO_ROUNDTRIP_BAD', flush=True)\n"
    );
    stdout = _bundle_and_run("pyinterop_crypto", pysrc, ["cryptography"]);
    for marker in ["CRYPTOGRAPHY_VERSION", "CRYPTO_ROUNDTRIP_OK"] {
        assert marker in stdout , f"marker {marker} missing\nstdout:\n{stdout}";
    }
}
