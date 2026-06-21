"""Build-and-serve tests for the client styling example fixtures.

Each fixture under ``fixtures/styling/`` is a minimal client app that
exercises one styling mechanism (JS style objects, plain CSS, Material UI,
styled-components). Every test copies the fixture into a throwaway temp dir,
``jac start``s it there (a real ``bun install`` + vite build happens), then
GETs the served routes and asserts the styling artifact made it into the
built bundle the page actually references.

The fixtures are copied (never built in place) so the committed source tree
stays pristine -- ``jac start`` otherwise rewrites ``jac.toml`` and drops a
``.jac/`` build dir next to the sources.

Recovers coverage dropped when PR #6840 merged jac-client/jac-desktop into
core and removed the standalone styling example apps.
"""

import gc;
import os;
import shutil;
import tempfile;
import time;
import from subprocess { PIPE, STDOUT, Popen }
import from urllib.error { HTTPError, URLError }
import from urllib.request { urlopen }

import from .test_helpers {
    get_env_with_bun,
    get_free_port,
    get_jac_command,
    wait_for_port
}

"""GET an endpoint with retry, returning the response body as bytes.

Builds are slow, so this retries on connection errors, 503s (server still
warming up) and 404s (an asset whose route is not registered yet) until the
deadline. A 500 (e.g. a compilation failure) is surfaced immediately.
"""
def _request_endpoint(
    url: str,
    timeout: float = 120.0,
    poll_interval: float = 2.0,
    request_timeout: float = 30.0,
) -> bytes {
    deadline = time.time() + timeout;
    last_err: Exception | None = None;

    while time.time() < deadline {
        try {
            resp = urlopen(url, timeout=request_timeout);
            try {
                return bytes(resp.read());
            } finally {
                resp.close();
            }
        } except HTTPError as exc {
            if exc.code == 503 or exc.code == 404 {
                exc.close();
                last_err = exc;
                time.sleep(poll_interval);
            } else {
                raise;
            }
        } except URLError as exc {
            last_err = exc;
            time.sleep(poll_interval);
        } except TimeoutError as exc {
            last_err = exc;
            time.sleep(poll_interval);
        }
    }

    raise TimeoutError(
        f"Timed out waiting for {url} to become available. Last error: {last_err}"
    );
}

"""Resolve a styling fixture source directory relative to this test file."""
def _fixture_src(name: str) -> str {
    tests_dir = os.path.dirname(os.path.abspath(__file__));
    return os.path.join(tests_dir, "fixtures", "styling", name);
}

"""Copy a styling fixture into ``dest`` minus any build artifacts.

Returns the project dir to run ``jac start`` in. Building in this throwaway
copy keeps the committed fixture pristine (``jac start`` rewrites jac.toml
and writes a ``.jac/`` dir).
"""
def _copy_fixture(name: str, dest: any) -> str {
    src = _fixture_src(name);
    assert os.path.isdir(src) , f"styling fixture missing: {src}";
    project_dir = os.path.join(dest, name);
    shutil.copytree(
        src,
        project_dir,
        ignore=shutil.ignore_patterns("node_modules", ".jac", "dist", "build"),
    );
    return project_dir;
}

"""Terminate a server process started for a fixture, closing its pipes."""
def _shutdown_server(server: Popen | None) {
    if server is None {
        return;
    }
    if server.stdout {
        try {
            server.stdout.close();
        } except Exception {
            0;
        }
    }
    server.terminate();
    try {
        server.wait(timeout=15);
    } except Exception {
        server.kill();
        try {
            server.wait(timeout=5);
        } except Exception {
            0;
        }
    }
    time.sleep(1);
    gc.collect();
}

"""Start `jac start main.jac` for a fixture and wait for the port.

Returns ``(server_process, port)``. Caller must ``_shutdown_server`` it.
"""
def _start_fixture_server(project_path: str) -> tuple {
    port = get_free_port();
    jac_cmd = get_jac_command();
    env = get_env_with_bun();
    server = Popen(
        [*jac_cmd, "start", "main.jac", "-p", str(port)],
        cwd=project_path,
        env=env,
        stdout=PIPE,
        stderr=STDOUT,
    );
    wait_for_port("127.0.0.1", port, timeout=120.0);
    return (server, port);
}

"""js style-objects: the style-object keys are bundled into the client JS."""
test "js style objects build and serve" {
    with tempfile.TemporaryDirectory() as temp_dir {
        project_path = _copy_fixture("js", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = _start_fixture_server(project_path);
            base = f"http://127.0.0.1:{port}";

            app_body = _request_endpoint(f"{base}/cl/app").decode(
                "utf-8", errors="ignore"
            );
            assert "/static/client.js" in app_body , (
                f"/cl/app should reference the client bundle; got:\n{app_body[:500]}"
            );

            js_body = _request_endpoint(f"{base}/static/client.js").decode(
                "utf-8", errors="ignore"
            );
            assert "countDisplay" in js_body , (
                "client bundle should carry the JS style-object key 'countDisplay'"
            );
        } finally {
            _shutdown_server(server);
        }
    }
}

"""pure css: the imported stylesheet is emitted as the served CSS bundle."""
test "pure css build and serve" {
    with tempfile.TemporaryDirectory() as temp_dir {
        project_path = _copy_fixture("pure-css", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = _start_fixture_server(project_path);
            base = f"http://127.0.0.1:{port}";

            app_body = _request_endpoint(f"{base}/cl/app").decode(
                "utf-8", errors="ignore"
            );
            assert "/static/styles.css" in app_body , (
                f"/cl/app should link the compiled stylesheet; got:\n{app_body[:500]}"
            );
            assert "/static/client.js" in app_body , (
                "/cl/app should reference the client bundle"
            );

            css_body = _request_endpoint(f"{base}/static/styles.css").decode(
                "utf-8", errors="ignore"
            );
            assert ".container" in css_body , (
                f"compiled styles.css should contain the .container rule; got:\n{css_body[:500]}"
            );
        } finally {
            _shutdown_server(server);
        }
    }
}

"""material ui: the @mui/@emotion deps bundle and the app builds + serves."""
test "material ui build and serve" {
    with tempfile.TemporaryDirectory() as temp_dir {
        project_path = _copy_fixture("mui", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = _start_fixture_server(project_path);
            base = f"http://127.0.0.1:{port}";

            app_body = _request_endpoint(f"{base}/cl/app").decode(
                "utf-8", errors="ignore"
            );
            assert "/static/client.js" in app_body , (
                f"/cl/app should reference the client bundle; got:\n{app_body[:500]}"
            );

            js_body = _request_endpoint(f"{base}/static/client.js").decode(
                "utf-8", errors="ignore"
            );
            assert "Static file not found" not in js_body , (
                "client.js should serve the bundle, not the not-found sentinel"
            );
            assert "Mui" in js_body , (
                "client bundle should carry Material UI component code"
            );
        } finally {
            _shutdown_server(server);
        }
    }
}

"""styled-components: the styled() runtime is bundled into the client JS."""
test "styled components build and serve" {
    with tempfile.TemporaryDirectory() as temp_dir {
        project_path = _copy_fixture("styled", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = _start_fixture_server(project_path);
            base = f"http://127.0.0.1:{port}";

            app_body = _request_endpoint(f"{base}/cl/app").decode(
                "utf-8", errors="ignore"
            );
            assert "/static/client.js" in app_body , (
                f"/cl/app should reference the client bundle; got:\n{app_body[:500]}"
            );

            js_body = _request_endpoint(f"{base}/static/client.js").decode(
                "utf-8", errors="ignore"
            );
            assert "styled-components" in js_body , (
                "client bundle should carry the styled-components runtime"
            );
        } finally {
            _shutdown_server(server);
        }
    }
}

"""sass: the .scss is compiled (variables resolved) into the served CSS."""
test "sass build and serve" {
    with tempfile.TemporaryDirectory() as temp_dir {
        project_path = _copy_fixture("sass", temp_dir);
        server: Popen | None = None;
        try {
            (server, port) = _start_fixture_server(project_path);
            base = f"http://127.0.0.1:{port}";

            app_body = _request_endpoint(f"{base}/cl/app").decode(
                "utf-8", errors="ignore"
            );
            assert "/static/styles.css" in app_body , (
                f"/cl/app should link the compiled stylesheet; got:\n{app_body[:500]}"
            );

            css_body = _request_endpoint(f"{base}/static/styles.css").decode(
                "utf-8", errors="ignore"
            );
            assert ".container" in css_body , (
                "compiled stylesheet should contain the .container rule"
            );
            # $accent (#16a34a) only appears if the .scss was actually run
            # through Sass rather than copied verbatim.
            assert "#16a34a" in css_body , (
                f"Sass variable should be compiled into the output; got:\n{css_body[:500]}"
            );
        } finally {
            _shutdown_server(server);
        }
    }
}
