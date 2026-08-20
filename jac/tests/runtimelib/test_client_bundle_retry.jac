"""A failed client-bundle build must not disable client pages until restart.

The serving core builds the bundle at boot for any app with client exports
(`jaclang/scale/server/impl/serve.core.impl.jac`), and when that build fails it
warns and keeps serving. `ensure_bundle` had already cached the reason in
`_bundle_error` and re-raised it on every later call without ever clearing it,
so a single boot-time build failure disabled every client page for the life of
the process: requests came back 503 in under 150ms because no rebuild was ever
attempted again. Recovery needed a restart.

End to end against a real `jac start` subprocess. The build really fails (the
client module imports an npm package that does not exist), and the assertion is
on whether the server keeps trying, read from its own log.
"""

import os;
import shutil;
import subprocess;
import time;
import from pathlib { Path }
import from tempfile { mkdtemp }
import socket;

glob _BUILD_LINE: str = "Building client bundle",
     _PAGE: str = "/cl/app";

glob _BROKEN_APP: str = 'import from "@jac/runtime" { renderJsxTree, }\n'
     'import from "totally-not-a-real-package-7998" { boom }\n'
     '\n'
     'def:pub app -> JsxElement {\n'
     '    <div id="x">{boom()}</div>\n'
     '}\n';


"""The bundle build runs the real Vite/Bun pipeline, so this is an integration
test, gated the way the other client tests in this repo are."""
def _require_client_integration {
    if not os.environ.get("JAC_CLIENT_INTEGRATION") {
        testskip(
            "client bundle build requires the Vite/Bun toolchain; "
            "set JAC_CLIENT_INTEGRATION=1 to run"
        );
    }
}


def _broken_project -> Path {
    proj = Path(mkdtemp(prefix="jac-bundle-retry-"));
    (proj / "brokenapp.jac").write_text(_BROKEN_APP);
    (proj / "jac.toml").write_text(
        '[project]\n' 'name = "bundleretry"\n' 'entry-point = "brokenapp.jac"\n'
    );
    return proj;
}


def _build_attempts(log: Path) -> int {
    try {
        return log.read_text(errors="replace").count(_BUILD_LINE);
    } except OSError {
        return 0;
    }
}


"""Bind an ephemeral port and hand back its number.

Inlined rather than taken from `jaclang.scale.tests.server_support`: that
module imports `requests` at module scope, which is not installed for the
runtime CI job, so importing one socket helper from it took this whole file
down with a ModuleNotFoundError."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock {
        sock.bind(("", 0));
        sock.listen(1);
        port = sock.getsockname()[1];
    }
    return port;
}


"""GET *url* and return the HTTP status. urllib raises on 4xx/5xx, so an error
response is reported as its status rather than as an exception. Uses the
stdlib rather than `requests`: this test is swept by the runtime CI job, which
installs no third-party HTTP client."""
def _get_status(url: str, timeout: float) -> int {
    import from urllib.request { urlopen }
    import from urllib.error { HTTPError }
    try {
        resp = urlopen(url, timeout=timeout);
        try {
            return resp.status;
        } finally {
            resp.close();
        }
    } except HTTPError as exc {
        return exc.code;
    }
}

test "a failed bundle build is retried on a later request, not cached until restart" {
    _require_client_integration();
    proj = _broken_project();
    log_path = proj / "server.log";
    handle = open(log_path, "wb");
    try {
        import from jaclang.scale.runtime.context.util { jac_executable }
        port = get_free_port();
        proc = subprocess.Popen(
            [jac_executable(), "start", "brokenapp.jac", "--port", str(port)],
            stdout=handle,
            stderr=subprocess.STDOUT,
            cwd=str(proj)
        );
    } finally {
        handle.close();
    }
    base = f"http://127.0.0.1:{port}";
    try {
        # The boot build fails; the server is expected to come up anyway.
        deadline = time.time() + 300;
        ready = False;
        while time.time() < deadline {
            if proc.poll() is not None {
                raise RuntimeError(
                    f"server exited ({proc.returncode})\n"
                        + log_path.read_text(errors="replace")[-2000:]
                );
            }
            try {
                if _get_status(f"{base}/healthz", 2) == 200 {
                    ready = True;
                    break;
                }
            } except Exception {
                time.sleep(1);
            }
        }
        assert ready , "server never became healthy despite a failed bundle build";

        after_boot = _build_attempts(log_path);
        assert after_boot > 0 , (
            "the boot build never ran, so this test is not exercising a failed build"
        );

        first_status = _get_status(f"{base}{_PAGE}", 300);
        after_first = _build_attempts(log_path);
        assert after_first > after_boot , (
            f"the failed build was replayed from cache instead of retried "
            f"(build attempts stayed at {after_boot} across a request that "
            f"returned {first_status}); a boot-time failure must not "
            "disable client pages until restart"
        );

        _get_status(f"{base}{_PAGE}", 300);
        assert _build_attempts(log_path) > after_first , (
            "the second request did not retry either; the failure is still sticky"
        );
    } finally {
        proc.terminate();
        try {
            proc.`wait(timeout=30);
        } except Exception {
            proc.kill();
        }
        shutil.rmtree(proj, ignore_errors=True);
    }
}
