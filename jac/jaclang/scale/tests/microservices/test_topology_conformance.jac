"""One app served colocated and as a fleet must answer the same (#8173).

Rows that diverge today are pinned in `_KNOWN_DIVERGENT`, so a fix that makes
the two agree fails the row until it moves to the conformant set.
"""

import shutil;
import time;
import requests;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob _FIXTURE: Path = Path(__file__).parent.parent / "fixtures" / "typed_boundary";

"""Serve the copied project in `topology`. Both share one project, so one
database (#10680), and a fleet must be healthy before its rows are asked."""
def _serve(project: Path, topology: str) -> tuple[any, str] {
    import jaclang;
    manifest = (_FIXTURE / "jac.toml").read_text(encoding="utf-8");
    manifest += f"\n[dev]\njaclang_source = {repr(
        str(Path(jaclang.__file__).parent.parent)
    )}\n";
    manifest += "\n[serve.workers]\ncount = 1\n";
    if topology == "fleet" {
        manifest += "\n[scale.gateway]\ncolocate = false\n";
    }
    (project / "jac.toml").write_text(manifest, encoding="utf-8");
    port = get_free_port();
    server = start_server(project, project / "consumer.jac", port);
    base = f"http://127.0.0.1:{port}";
    deadline = time.monotonic() + 300.0;
    try {
        while topology == "fleet" {
            health = requests.get(f"{base}/healthz", timeout=5).json();
            if health.get("status") == "healthy" {
                break;
            }
            if time.monotonic() > deadline {
                raise RuntimeError(f"fleet never became healthy: {health}");
            }
            time.sleep(1);
        }
    } except BaseException {
        stop_server(server);
        raise;
    }
    return (server, base);
}

"""Call a function: a `probe_*` returns plain facts, compared in full; any
other function is compared by status only."""
def _call(base: str, fn: str) -> dict[str, any] {
    response = requests.post(f"{base}/function/{fn}", json={}, timeout=60);
    if response.status_code != 200 or not fn.startswith("probe_") {
        return {"status": response.status_code};
    }
    return {"status": 200, "result": extract(response.json())["result"]};
}

"""Stream a function that writes and then yields; report whether the write
is visible afterwards."""
def _stream_write(base: str) -> dict[str, any] {
    before = _call(base, "probe_marks")["result"];
    response = requests.post(f"{base}/function/stream_write", json={}, timeout=60);
    events = [
        line
        for line in response.text.splitlines()
        if line.startswith(("data:", "event:"))
    ];
    after = _call(base, "probe_marks")["result"];
    return {
        "status": response.status_code,
        "events": events,
        "committed": after - before
    };
}

glob _ROWS: list[tuple[str, str]] = [
         ("typed return across the boundary", "probe_typed"),
         ("bridged generator function", "probe_stream"),
         ("bridged walker reporting a generator", "probe_walker_stream"),
         ("bridged function that raises", "probe_raise"),
         ("write inside an SSE stream", "stream_write"),
         ("provider function at the canonical path", "fetch_score"),
         ("unknown function name", "no_such_fn")
     ];

"""What a conformant row must also answer, so a shared regression cannot pass
as agreement. The stream's write count is held to equality only (#10313)."""
glob _EXPECTED: dict[str, dict[str, any]] = {
         "bridged generator function": {"status": 200, "result": {"items": [0, 1, 2]}},
         "write inside an SSE stream": {
             "status": 200,
             "events": ['data: "wrote"', "event: end", "data: {}"]
         }
     };

"""Rows that diverge today, pinned per topology, each with its #8173 clause."""
glob _KNOWN_DIVERGENT: dict[str, dict[str, dict[str, any]]] = {
         # clause 5 (types): colocated hands back the provider's own class.
         "typed return across the boundary": {
             "colocated": {
                 "status": 200,
                 "result": {"is_payload": False, "owner": "jaseci-labs"}
             },
             "fleet": {
                 "status": 200,
                 "result": {"is_payload": True, "owner": "jaseci-labs"}
             }
         },
         # clause 3 (streaming): colocated reports the generator object, the
         # fleet fails to decode the streamed reply.
         "bridged walker reporting a generator": {
             "colocated": {"status": 200, "result": {"reports": ["generator"]}},
             "fleet": {"status": 500}
         },
         # clause 6 (failure): the fleet wraps the provider's message.
         "bridged function that raises": {
             "colocated": {
                 "status": 200,
                 "result": {"type": "BridgeError", "status": 0, "own_message": True}
             },
             "fleet": {
                 "status": 200,
                 "result": {"type": "BridgeError", "status": 0, "own_message": False}
             }
         },
         # clause 2 (addressing): only the fleet serves the canonical path.
         "provider function at the canonical path": {
             "colocated": {"status": 405},
             "fleet": {"status": 200}
         },
         # clauses 2 and 6: an unknown name is 405 colocated, 404 behind the gateway.
         "unknown function name": {
             "colocated": {"status": 405},
             "fleet": {"status": 404}
         }
     };

test "every conformance row means the same thing colocated and as a fleet" {
    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        shutil.copytree(
            _FIXTURE, project, dirs_exist_ok=True, ignore=shutil.ignore_patterns(".jac")
        );
        seen: dict[str, dict[str, any]] = {name: {} for (name, _) in _ROWS};
        for topology in ["colocated", "fleet"] {
            (server, base) = _serve(project, topology);
            try {
                for (name, fn) in _ROWS {
                    seen[name][topology] = _stream_write(base)
                        if fn == "stream_write"
                        else _call(base, fn);
                }
            } finally {
                stop_server(server);
            }
        }
        failures: list[str] = [];
        for (name, both) in seen.items() {
            if name in _KNOWN_DIVERGENT {
                if both != _KNOWN_DIVERGENT[name] {
                    failures.append(f"{name}: divergence changed, now {both}");
                }
            } elif both["colocated"] != both["fleet"] {
                failures.append(
                    f"{name}: colocated {both['colocated']} != fleet {both['fleet']}"
                );
            }
            for (key, want) in _EXPECTED.get(name, {}).items() {
                for (topology, got) in both.items() {
                    if got.get(key) != want {
                        failures.append(
                            f"{name}: {topology} {key}={got.get(key)!r}, expected {want!r}"
                        );
                    }
                }
            }
        }
        assert not failures , "\n".join(failures);
    }
}
