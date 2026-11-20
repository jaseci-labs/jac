"""Full-ecosystem integration checks, formerly `scripts/integration_tests.jac`.

These prove the assembled distribution behaves as one system: the .pth/meta
finder imports .jac modules from bare CPython, the CLI answers through the
real dispatch path, and the scale server boots a project and serves the admin
dashboard from the pre-built bundle when one is shipped. The server test
needs scale's serve deps, so it gates on `dotenv` and skips (or fails under
JAC_TEST_STRICT) instead of erroring where they are absent.
"""

import os;
import subprocess;
import sys;
import socket;
import tempfile;
import time;
import urllib.request;
import from pathlib { Path }
import from tests.support { JAC_ROOT }


def _spawn_jac(
    argv: list[str], cwd: str, timeout: (int | None) = 600
) -> tuple[int, str] {
    argv_repr = repr(["jac"] + argv);
    script = f"""
import sys, runpy
sys.path.insert(0, {JAC_ROOT!r})
sys.argv = {argv_repr}
try:
    runpy.run_module('jaclang', run_name='__main__', alter_sys=True)
except SystemExit as exc:
    raise SystemExit(int(exc.code) if isinstance(exc.code, int) else 1)
""";
    proc = subprocess.run(
        [sys.executable, "-c", script],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
    );
    return (proc.returncode, proc.stdout + proc.stderr);
}


def _free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        return s.getsockname()[1];
    }
}


test "pth finder imports a .jac module without explicit jaclang import" {
    with tempfile.TemporaryDirectory() as tmpdir {
        jac_file = os.path.join(tmpdir, "hello_pth.jac");
        with open(jac_file, "w") as f {
            f.write('with entry { print("pth_import_ok"); }\n');
        }
        proc = subprocess.run(
            [
                sys.executable,
                "-c",
                f"import sys; sys.path.insert(0, {tmpdir!r}); import hello_pth",

            ],
            capture_output=True,
            text=True,
            timeout=600,
        );
        assert proc.returncode == 0 , proc.stdout + proc.stderr;
        assert "pth_import_ok" in proc.stdout , proc.stdout + proc.stderr;
    }
}


test "cli answers --version and checks a fixture through real dispatch" {
    (rc, out) = _spawn_jac(["--version"], JAC_ROOT);
    assert rc == 0 , out;
    assert "jac" in out.lower() , out;
    fixture = os.path.join(
        JAC_ROOT,
        "tests",
        "compiler",
        "passes",
        "fixtures",
        "checker",
        "checker_type_ref.jac",
    );
    (rc, out) = _spawn_jac(["check", fixture], JAC_ROOT);
    assert rc == 0 , out;
}


test "scale server boots a project and serves the admin dashboard" {
    import from jaclang.testing.requires { require_module }
    require_module("dotenv");
    import jaclang.scale;
    dist_dir = Path(jaclang.scale.__file__).parent / "admin" / "_dist";
    with tempfile.TemporaryDirectory(prefix="admin-e2e-") as tmpdir {
        with open(os.path.join(tmpdir, "main.jac"), "w") as f {
            f.write(
                'walker:pub Health {\n'
                '    can check with Root entry {\n'
                '        report {"status": "healthy"};\n'
                '    }\n'
                '}\n'
            );
        }
        with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
            f.write('[project]\nname = "admin-e2e-test"\nversion = "0.0.1"\n');
        }
        port = _free_port();
        argv_repr = repr(["jac", "run", "--serve", "--port", str(port), "main.jac"]);
        boot = f"""
import sys, runpy
sys.path.insert(0, {JAC_ROOT!r})
sys.argv = {argv_repr}
runpy.run_module('jaclang', run_name='__main__', alter_sys=True)
""";
        log_path = os.path.join(tmpdir, "server.log");
        log_fh = open(log_path, "w");
        server = subprocess.Popen(
            [sys.executable, "-c", boot],
            cwd=tmpdir,
            stdout=log_fh,
            stderr=subprocess.STDOUT,
        );
        try {
            # A cold cache compiles the scale stack inside the child's boot;
            # the window must cover that, and a ready server exits it early.
            ready = False;
            for _ in range(240) {
                if server.poll() is not None {
                    break;
                }
                try {
                    urllib.request.urlopen(
                        f"http://localhost:{port}/healthz", timeout=3
                    );
                    ready = True;
                    break;
                } except Exception {
                    time.sleep(2);
                }
            }
            log_fh.flush();
            log_text = Path(log_path).read_text(errors="replace");
            assert server.poll() is None , (
                f"server exited {server.returncode} during startup:\n{log_text[-2000:]}"
            );
            assert ready , f"server never became ready:\n{log_text[-2000:]}";
            if dist_dir.exists() {
                resp = urllib.request.urlopen(
                    f"http://localhost:{port}/admin/", timeout=15
                );
                body = resp.read().decode(errors="replace");
                assert resp.status == 200 , f"/admin/ answered HTTP {resp.status}";
                assert "<html" in body.lower() , "/admin/ did not serve HTML";
                idx = dist_dir / "index.html";
                assert idx.is_file() , f"pre-built bundle missing {idx}";
                html = idx.read_text(errors="replace").lower();
                assert "<html" in html and "script" in html , (
                    "index.html is not a real build output"
                );
                log_fh.flush();
                log_text = Path(log_path).read_text(errors="replace");
                assert "Building admin client from source" not in log_text , (
                    "server rebuilt the dashboard instead of using the bundle"
                );
            }
        } finally {
            if server.poll() is None {
                server.terminate();
                try {
                    server.`wait(timeout=10);
                } except subprocess.TimeoutExpired {
                    server.kill();
                    server.`wait();
                }
            }
            log_fh.close();
        }
    }
}
