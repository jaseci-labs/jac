"""`on_drain` on a real `jac run --serve` (jac#10631). SIGTERM goes to the server
process alone, as a pod stop sends it, while a request is in flight."""

import signal;
import tempfile;
import time;
import requests;
import from concurrent.futures { ThreadPoolExecutor }
import from pathlib { Path }

glob APP: Path = Path(__file__).parent.parent / "fixtures" / "drain_hooks_app.jac";


test "SIGTERM runs each drain hook once where it was registered, and the request in flight still answers" {
    for workers in [1, 2] {
        with tempfile.TemporaryDirectory(prefix="drain_hooks_") as tmp {
            mark = Path(tmp) / "mark.txt";
            port = get_free_port();
            server = start_server(
                APP.parent,
                APP,
                port,
                env={
                    "HOOK_MARK": str(mark),
                    "JAC_SERVE_WORKERS": str(workers),
                    "JAC_SERVE_DRAIN_TIMEOUT": "2"
                }
            );
            try {
                with ThreadPoolExecutor(max_workers=1) as pool {
                    call = pool.submit(
                        requests.post,
                        f"http://localhost:{port}/walker/slow",
                        json={},
                        timeout=30
                    );
                    deadline = time.monotonic() + 20;
                    while "walker" not in (mark.read_text() if mark.exists() else "")
                        and time.monotonic() < deadline {
                        time.sleep(0.05);
                    }
                    server.send_signal(signal.SIGTERM);
                    (stdout, stderr) = server.communicate(timeout=60);
                    assert call.result().status_code == 200 , (
                        workers,
                        stdout + stderr
                    );
                }
            } finally {
                stop_server(server);
            }
            assert server.returncode == 0 , (workers, stdout + stderr);
            marks = [line.split() for line in mark.read_text().splitlines()];
        }
        stages = [m[0] for m in marks];
        assert stages == ["entry", "walker", "decorated", "async", "called"] , (
            workers,
            marks
        );
        hook_pids = {
            m[1]
            for m in marks
            if m[0] != "walker"
        };
        assert hook_pids == {marks[0][1]} , (workers, marks);
        assert (marks[1][1] == marks[0][1]) == (workers == 1) , (workers, marks);
    }
}
