"""Shared test utilities for jac-client tests."""

import gc;
import os;
import shutil;
import socket;
import sys;
import time;
import from pathlib { Path }
import from http.client { RemoteDisconnected }
import from subprocess { PIPE, STDOUT, Popen }
import from urllib.error { HTTPError, URLError }
import from urllib.request { urlopen }

"""Get a free port by binding to port 0 and releasing it."""
def get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        port = s.getsockname()[1];
    }
    return port;
}

"""Get the jac command with proper path handling."""
def get_jac_command -> list[str] {
    jac_path = shutil.which("jac");
    if jac_path {
        return [jac_path];
    }
    return [sys.executable, "-m", "jaclang"];
}

"""Get environment dict with bun in PATH."""
def get_env_with_bun -> dict[str, str] {
    import from jaclang.client { get_bun }
    env = os.environ.copy();
    bun_path = get_bun();
    if not bun_path {
        bun_path = shutil.which("bun");
    }
    if bun_path {
        bun_dir = str(Path(bun_path).parent);
        current_path = env.get("PATH", "");
        if bun_dir not in current_path {
            env["PATH"] = f"{bun_dir}:{current_path}";
        }
    }
    return env;
}

# Backward compatibility alias
glob get_env_with_npm = get_env_with_bun;

"""Block until a TCP port is accepting connections or timeout."""
def wait_for_port(host: str, port: int, timeout: float = 60.0) -> None {
    deadline = time.time() + timeout;
    while time.time() < deadline {
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock {
            sock.settimeout(0.5);
            try {
                sock.connect((host, port));
                return;
            } except OSError {
                time.sleep(0.5);
            }
        }
    }
    raise TimeoutError(f"Timed out waiting for {host}:{port}");
}

"""Absolute path to a fixture directory under ``fixtures/``."""
def fixture_dir(name: str) -> str {
    tests_dir = os.path.dirname(os.path.abspath(__file__));
    return os.path.join(tests_dir, "fixtures", name);
}

"""Copy a fixture into ``dest`` minus build artifacts; return the project dir.

Building in a throwaway copy keeps the committed fixture pristine -- ``jac
start`` otherwise rewrites jac.toml and drops a ``.jac/`` dir.
"""
def copy_fixture(name: str, dest: any) -> str {
    src = fixture_dir(name);
    assert os.path.isdir(src) , f"fixture missing: {src}";
    project_dir = os.path.join(dest, name);
    shutil.copytree(
        src,
        project_dir,
        ignore=shutil.ignore_patterns("node_modules", ".jac", "dist", "build"),
    );
    return project_dir;
}

"""GET an endpoint with retry, returning the response body as bytes.

Retries on connection errors and 503s (server still warming up / building)
until the deadline. A 500 (e.g. a compile failure) is surfaced immediately.
"""
def request_endpoint(
    url: str,
    timeout: float = 120.0,
    poll_interval: float = 2.0,
    request_timeout: float = 30.0,
) -> bytes {
    deadline = time.time() + timeout;
    last_err: any = None;
    while time.time() < deadline {
        try {
            resp = urlopen(url, timeout=request_timeout);
            try {
                return bytes(resp.read());
            } finally {
                resp.close();
            }
        } except HTTPError as exc {
            if exc.code == 503 {
                exc.close();
                last_err = exc;
                time.sleep(poll_interval);
            } else {
                raise;
            }
        } except (URLError, RemoteDisconnected, ConnectionError, TimeoutError) as exc {
            last_err = exc;
            time.sleep(poll_interval);
        }
    }
    raise TimeoutError(
        f"Timed out waiting for {url} to become available. Last error: {last_err}"
    );
}

"""Start `jac run --serve <app>` on a project dir and wait for the port.

``app`` is the workspace app to serve (the positional `run` target; default
``"web"``). ``extra_args`` is inserted after ``--serve`` (e.g.
``["--profile", "prod"]``). Every flag precedes the app name: `run` carries a
REMAINDER for script args, so a flag written after the target would be handed
to the app instead. Returns ``(server_process, port)``. Caller must
``stop_server`` it.
"""
def start_app_server(
    project_path: any, extra_args: list | None = None, app: str = ""
) -> tuple {
    import tempfile;
    port = get_free_port();
    jac_cmd = get_jac_command();
    env = get_env_with_bun();
    args = [*jac_cmd, "run", "--serve"];
    if extra_args {
        args = [*args, *extra_args];
    }
    args = [*args, "-p", str(port)];
    if app {
        args = [*args, app];
    }
    # Capture the server's output so a boot failure surfaces as a diagnosis
    # instead of an opaque 120s port-wait timeout (a crashed server and a
    # hung one look identical from wait_for_port).
    log_f = tempfile.NamedTemporaryFile(
        mode="w+", suffix=".log", prefix="jac_server_", delete=False
    );
    server = Popen(args, cwd=project_path, env=env, stdout=log_f, stderr=log_f);
    try {
        # The jaclang_org app is a full site: cold-compiling it plus its
        # client bundle takes minutes on a small CI runner, not the seconds
        # the littleX-era 120s budget assumed.
        wait_for_port("127.0.0.1", port, timeout=600.0);
    } except TimeoutError as exc {
        stop_server(server);
        log_f.flush();
        tail = "";
        try {
            with open(log_f.name, "r", errors="replace") as fh {
                tail = "".join(fh.readlines()[-60:]);
            }
        } except Exception {
            tail = "(server log unreadable)";
        }
        raise TimeoutError(f"{exc}\n---- server output (tail) ----\n{tail}") from exc;
    }
    return (server, port);
}

"""Terminate a server process, escalating to kill if it lingers."""
def stop_server(server: any) -> None {
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
        server.`wait(timeout=15);
    } except Exception {
        server.kill();
        try {
            server.`wait(timeout=5);
        } except Exception {
            0;
        }
    }
    time.sleep(1);
    gc.collect();
}
