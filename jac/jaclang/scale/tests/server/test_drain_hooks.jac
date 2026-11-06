"""`on_drain` on a real `jac run --serve` (jac#10631). SIGTERM goes to the server
process alone, as a pod stop sends it, and the fixture records each hook with the
pid that ran it."""

import signal;
import tempfile;
import from pathlib { Path }

glob FIXTURES_DIR: Path = Path(__file__).parent.parent / "fixtures";


"""Serve the fixture with `workers` workers, SIGTERM it, and return its exit code,
the recorded lines, and its output."""
def _serve_and_stop(workers: int) -> tuple[int, list[str], str] {
    with tempfile.TemporaryDirectory(prefix="drain_hooks_") as tmp {
        mark = Path(tmp) / "mark.txt";
        server = start_server(
            FIXTURES_DIR,
            FIXTURES_DIR / "drain_hooks_app.jac",
            get_free_port(),
            env={"HOOK_MARK": str(mark), "JAC_SERVE_WORKERS": str(workers)}
        );
        try {
            server.send_signal(signal.SIGTERM);
            (stdout, stderr) = server.communicate(timeout=60);
        } finally {
            stop_server(server);
        }
        lines: list[str] = mark.read_text().split() if mark.exists() else [];
    }
    return (server.returncode, lines, stdout + stderr);
}


"""The hooks ran once each, in order, in the process that ran `with entry`."""
def _assert_ran_where_registered(lines: list[str]) {
    pid = lines[1] if len(lines) > 1 else "";
    assert lines
        == ["entry", pid, "decorated", pid, "async", pid, "called", pid] , lines;
}


test "one worker runs the drain hooks in the order they were registered" {
    (code, lines, output) = _serve_and_stop(1);
    assert code == 0 , output;
    _assert_ran_where_registered(lines);
}


test "with workers, the supervisor runs the hooks it registered and the workers do not" {
    (code, lines, output) = _serve_and_stop(2);
    assert code == 0 , output;
    assert "supervising 2 worker(s)" in output , output;
    _assert_ran_where_registered(lines);
}


test "a slow hook does not cost a request in flight its response" {
    import time;
    import requests;
    import from concurrent.futures { ThreadPoolExecutor }

    port = get_free_port();
    server = start_server(
        FIXTURES_DIR,
        FIXTURES_DIR / "drain_slow_hook_app.jac",
        port,
        env={"JAC_SERVE_WORKERS": "1", "JAC_SERVE_DRAIN_TIMEOUT": "2"}
    );
    try {
        with ThreadPoolExecutor(max_workers=1) as pool {
            call = pool.submit(
                requests.post,
                f"http://localhost:{port}/walker/slow",
                json={},
                timeout=30
            );
            time.sleep(0.5);
            server.send_signal(signal.SIGTERM);
            assert call.result().status_code == 200;
        }
    } finally {
        stop_server(server);
    }
}
