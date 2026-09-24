"""End-to-end tests for /metrics on a server that forks more than one worker.

Drives a real `jac run --serve` subprocess whose fixture asks for two workers,
so every scrape has to merge what each forked worker recorded, and a worker
that dies has to stop contributing its live gauges. The last test runs the
other serving entry point, an exported source project, because that one sets
the shared directory from its own code path.
"""

import contextlib;
import os;
import shutil;
import tempfile;
import signal;
import subprocess;
import threading;
import time;
import requests;
import from concurrent.futures { ThreadPoolExecutor }
import from pathlib { Path }
import from jaclang.scale.tests.support {
    cleanup_db_files,
    get_free_port,
    start_server,
    stop_server
}

glob FIXTURES_DIR: Path = Path(__file__).parent.parent
         / "fixtures"
         / "metrics_workers",
     SCRAPE_AUTH: tuple[str, str] = ("admin", "scrape-secret"),
     REQUESTS_TOTAL: str = "metrics_workers_http_requests_total",
     IN_PROGRESS: str = "metrics_workers_http_requests_in_progress",
     APP_PINGS: str = "app_pings_total",
     PING_SERIES: str = 'metrics_workers_http_requests_total{method="POST",path="/walker/Ping",status_code="200"}';

def _samples(body: str, name: str) -> dict[str, float] {
    found: dict[str, float] = {};
    for line in body.splitlines() {
        if line.startswith(name + "{") or line.startswith(name + " ") {
            (series, value) = line.rsplit(" ", 1);
            found[series] = float(value);
        }
    }
    return found;
}

def _scrape_until(base: str, done: Callable[[str], bool], budget: float) -> str {
    deadline = time.monotonic() + budget;
    body = "";
    while time.monotonic() < deadline {
        with contextlib.suppress(requests.RequestException) {
            res = requests.get(f"{base}/metrics", auth=SCRAPE_AUTH, timeout=5);
            if res.status_code == 200 {
                body = res.text;
                if done(body) {
                    return body;
                }
            }
        }
        time.sleep(0.25);
    }
    return body;
}

def _ping(base: str) -> int {
    res = requests.post(f"{base}/walker/Ping", json={}, timeout=10);
    assert res.status_code == 200 , res.text;
    return int(res.json()["data"]["reports"][0]);
}


"""Ping until more than one worker has answered, so a scrape that reports a
single worker cannot pass for a merged one."""
def _load_until_shared(base: str) -> tuple[int, set[int]] {
    sent = 0;
    pids: set[int] = set();
    deadline = time.monotonic() + 30.0;
    while time.monotonic() < deadline {
        def _one(_index: int) -> int {
            return _ping(base);
        }
        with ThreadPoolExecutor(max_workers=8) as pool {
            for pid in pool.map(_one, range(8)) {
                pids.add(pid);
            }
        }
        sent += 8;
        if len(pids) > 1 {
            break;
        }
    }
    return (sent, pids);
}


def _process_table -> dict[int, tuple[int, str]] {
    listing = subprocess.run(
        ["ps", "-A", "-o", "pid=,ppid=,command="],
        capture_output=True,
        text=True,
        check=True
    ).stdout;
    table: dict[int, tuple[int, str]] = {};
    for line in listing.splitlines() {
        parts = line.split(None, 2);
        if len(parts) == 3 {
            table[int(parts[0])] = (int(parts[1]), parts[2]);
        }
    }
    return table;
}

def _worker_pids(supervisor: int) -> list[int] {
    table = _process_table();
    (_parent, command) = table.get(supervisor, (0, ""));
    return [
        pid
        for (pid, (ppid, cmd)) in table.items()
        if ppid == supervisor and cmd == command
    ];
}

def _stop_fleet(server: subprocess.Popen) {
    table = _process_table();
    (_parent, command) = table.get(server.pid, (0, ""));
    workers = _worker_pids(server.pid);
    stop_server(server);
    table = _process_table();
    for pid in workers {
        if pid in table and table[pid][1] == command {
            with contextlib.suppress(ProcessLookupError) {
                os.kill(pid, signal.SIGKILL);
            }
        }
    }
}

test "a two-worker scrape merges every worker into one series per metric" {
    cleanup_db_files(FIXTURES_DIR);
    port = get_free_port();
    base = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, FIXTURES_DIR / "app.jac", port);
    try {
        assert len(_worker_pids(server.pid)) == 2;
        (sent, pids) = _load_until_shared(base);
        assert len(pids) > 1 , f"one worker answered all {sent} pings: {pids}";
        def _all_counted(text: str) -> bool {
            return _samples(text, REQUESTS_TOTAL).get(PING_SERIES) == float(sent);
        }
        body = _scrape_until(base, _all_counted, 15.0);
        assert _samples(body, REQUESTS_TOTAL).get(PING_SERIES) == float(sent) , body;
        assert _samples(body, APP_PINGS).get(APP_PINGS) == float(sent) , body;
        assert list(_samples(body, IN_PROGRESS).keys()) == [IN_PROGRESS] , body;
        assert len(_samples(body, "jac_info")) == 1 , body;
    } finally {
        _stop_fleet(server);
        cleanup_db_files(FIXTURES_DIR);
    }
}

test "a worker killed mid-request stops counting as in progress" {
    cleanup_db_files(FIXTURES_DIR);
    port = get_free_port();
    base = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, FIXTURES_DIR / "app.jac", port);
    try {
        def _hold {
            with contextlib.suppress(requests.RequestException) {
                requests.post(f"{base}/walker/Hold", json={}, timeout=90);
            }
        }
        threading.Thread(target=_hold, daemon=True).start();
        def _held(text: str) -> bool {
            return _samples(text, IN_PROGRESS) == {IN_PROGRESS: 1.0};
        }
        body = _scrape_until(base, _held, 15.0);
        assert _samples(body, IN_PROGRESS) == {IN_PROGRESS: 1.0} , body;

        workers = _worker_pids(server.pid);
        assert len(workers) == 2;
        for pid in workers {
            os.kill(pid, signal.SIGKILL);
        }
        def _released(text: str) -> bool {
            respawned = _worker_pids(server.pid);
            return len(respawned) == 2
                and not set(workers) & set(respawned)
                and _samples(text, IN_PROGRESS) == {IN_PROGRESS: 0.0};
        }
        body = _scrape_until(base, _released, 30.0);
        assert _samples(body, IN_PROGRESS) == {IN_PROGRESS: 0.0} , body;
    } finally {
        _stop_fleet(server);
        cleanup_db_files(FIXTURES_DIR);
    }
}


def _serve_exported(project: Path, port: int) -> subprocess.Popen {
    import from jaclang.scale.runtime.context.util { jac_executable }
    server = subprocess.Popen(
        [jac_executable(), "run", "main.py", "--port", str(port)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(project)
    );
    deadline = time.monotonic() + 300.0;
    while time.monotonic() < deadline {
        if server.poll() is not None {
            (out, err) = server.communicate();
            raise RuntimeError(f"exported app exited\nSTDOUT:\n{out}\nSTDERR:\n{err}");
        }
        with contextlib.suppress(requests.RequestException) {
            if requests.get(f"http://localhost:{port}/healthz", timeout=1).status_code
                == 200 {
                return server;
            }
        }
        time.sleep(1);
    }
    server.kill();
    raise RuntimeError(f"exported app never answered /healthz on port {port}");
}


"""`jac build --as source` emits a project that serves itself through
`runtime/source_app.jac` with no jac binary in the loop, and that entry point
opens the shared metrics directory from its own code, so it gets the same
two-worker scrape this suite asks of `jac run --serve`."""
test "an exported source project merges its workers into one scrape" {
    import from jaclang.scale.runtime.context.util { jac_executable }
    workspace = Path(tempfile.mkdtemp(prefix="jac_metrics_export_"));
    server = None;
    try {
        for name in ["app.jac", "jac.toml"] {
            shutil.copy2(FIXTURES_DIR / name, workspace / name);
        }
        built = subprocess.run(
            [jac_executable(), "build", "app.jac", "--as", "source"],
            capture_output=True,
            text=True,
            cwd=str(workspace)
        );
        assert built.returncode == 0 , f"export failed:\n{built.stdout}\n{built.stderr}";
        port = get_free_port();
        base = f"http://localhost:{port}";
        server = _serve_exported(workspace / "dist" / "source", port);
        (sent, pids) = _load_until_shared(base);
        assert len(pids) > 1 , f"one worker answered all {sent} pings: {pids}";
        def _all_counted(text: str) -> bool {
            return _samples(text, REQUESTS_TOTAL).get(PING_SERIES) == float(sent);
        }
        body = _scrape_until(base, _all_counted, 15.0);
        assert _samples(body, REQUESTS_TOTAL).get(PING_SERIES) == float(sent) , body;
        assert _samples(body, APP_PINGS).get(APP_PINGS) == float(sent) , body;
        assert list(_samples(body, IN_PROGRESS).keys()) == [IN_PROGRESS] , body;
    } finally {
        if server is not None {
            _stop_fleet(server);
        }
        shutil.rmtree(str(workspace), ignore_errors=True);
    }
}
