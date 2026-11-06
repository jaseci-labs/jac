"""`on_drain` on a real `jac run --serve` (jac#10631). SIGTERM goes to the server
process alone, as a pod stop sends it, and the fixture records each hook with the
pid that ran it."""

import os;
import signal;
import tempfile;
import from pathlib { Path }

glob FIXTURES_DIR: Path = Path(__file__).parent.parent / "fixtures";


"""Serve the fixture with `workers` workers, SIGTERM it, and return its exit code,
the recorded lines, and its output."""
def _serve_and_stop(workers: int) -> tuple[int, list[str], str] {
    mark = tempfile.mktemp(prefix="drain_hooks_", suffix=".txt");
    server = start_server(
        FIXTURES_DIR,
        FIXTURES_DIR / "drain_hooks_app.jac",
        get_free_port(),
        env={"HOOK_MARK": mark, "JAC_SERVE_WORKERS": str(workers)}
    );
    try {
        server.send_signal(signal.SIGTERM);
        (stdout, stderr) = server.communicate(timeout=60);
    } finally {
        stop_server(server);
    }
    lines: list[str] = Path(mark).read_text().split() if os.path.exists(mark) else [];
    return (server.returncode, lines, stdout + stderr);
}


"""The hooks ran once each, in order, in the process that ran `with entry`."""
def _assert_ran_where_registered(lines: list[str]) {
    pid = lines[1] if len(lines) > 1 else "";
    assert lines == ["entry", pid, "decorated", pid, "called", pid] , lines;
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
