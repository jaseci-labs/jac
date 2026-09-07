"""Tier-A end-to-end test: a minimal na host actually boots the fused runtime.

The codegen string tests prove what the host SOURCE contains; this proves the
whole chain RUNS in a real binary. Build a tiny na host over the fused runtime
library (jaclang/dist/fused, staged beside it exactly as the desktop
builder does), bundle THIS jac's runtime trailer onto it, run it, and confirm
engine_boot() materialized the trailer payload, dlopened the bundled CPython,
initialized it, and imported jaclang + oauth_broker straight from the fused
runtime -- with no webview, no display, and no system libpython (the
interpreter is the one bundled in the payload). Same chain a desktop host runs,
minus the window. Needs only the jac toolchain (`nacompile`).
"""
import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.client.targets.desktop.desktop_build {
    _jac_bin,
    _stage_fused_runtime,
    _bundle_runtime
}

test "na host boots the fused runtime (no display)" {
    # A windowless host: bring up the fused runtime, import jaclang + a desktop
    # bootstrap module from it, print a marker, finalize. If boot fails the
    # interpreter is not up, so bail (sys.exit) before any Py_* call.
    host_src = (
        "import from fused.bringup { engine_boot }\n"
        "with entry {\n"
        "    api = engine_boot().api;\n"
        "    api.PyRun_SimpleString(\"import jaclang, ssl, os; from jaclang.client.targets.desktop.native import oauth_broker; assert ssl.create_default_context().cert_store_stats()['x509_ca'] > 0; print('ENGINE_BOOT_OK', os.environ.get('SSL_CERT_FILE'), flush=True)\");\n"
        "    api.Py_Finalize();\n"
        "}\n"
    );
    jac = _jac_bin();
    tmp = tempfile.mkdtemp();
    try {
        out_dir = Path(tmp);
        # The fused runtime library is staged beside the host so its
        # `import from fused.bringup` resolves, exactly as the desktop builder does.
        _stage_fused_runtime(out_dir);
        host = out_dir / "host.jac";
        host.write_text(host_src);
        binary = out_dir / "engineboot";
        # Compile from the runner's cwd, not the temp dir: the [dev] reroute is
        # chosen by the nearest jac.toml from the cwd, and the host must be built
        # by the same compiler whose fused library was just staged beside it.
        comp = subprocess.run(
            [jac, "build", "--native", str(host), "-o", str(binary)],
            capture_output=True,
            text=True,
            timeout=300
        );
        assert comp.returncode == 0 and binary.exists() , (
            f"nacompile failed:\nstdout:\n{comp.stdout}\nstderr:\n{comp.stderr}"
        );
        # Append this jac's [payload][trailer] so the host carries the fused runtime
        # and engine_boot() can materialize it from /proc/self/exe at launch.
        _bundle_runtime(binary);
        env = dict(os.environ);
        env.pop("SSL_CERT_FILE", None);
        env.pop("SSL_CERT_DIR", None);
        run = subprocess.run(
            [str(binary)], cwd=tmp, env=env, capture_output=True, text=True, timeout=120
        );
        assert run.returncode == 0 , (
            f"engine-boot binary exited {run.returncode}\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        assert "ENGINE_BOOT_OK" in run.stdout , (
            f"fused-runtime boot marker missing\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        custom_ca = out_dir / "custom-ca.pem";
        shutil.copy2(Path(sys.prefix) / "floor" / "cacert.pem", custom_ca);
        env["SSL_CERT_FILE"] = str(custom_ca);
        custom = subprocess.run(
            [str(binary)], cwd=tmp, env=env, capture_output=True, text=True, timeout=120
        );
        assert custom.returncode == 0 , custom.stderr;
        assert str(custom_ca) in custom.stdout , "runtime replaced an explicit CA bundle";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
