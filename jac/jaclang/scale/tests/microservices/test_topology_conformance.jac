"""One app, two topologies, one meaning (#8173).

The `typed_boundary` workspace is served twice, colocated (the default) and as
a fleet (`[scale.gateway] colocate = false`), and every row below is asked of
both. A row's normalized outcome must be the same in both topologies. Rows
whose divergence is known are pinned at their current values instead, each
naming the #8173 contract clause it breaks, so the row fails (and must be
moved to the conformant set) the day the two topologies agree.
"""

import shutil;
import requests;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob _FIXTURE: Path = Path(__file__).parent.parent / "fixtures" / "typed_boundary";


"""Serve `project` in `topology`. Both topologies run from the same project,
so they share its database and the colocated boot provisions the identity
schema before the fleet's services start side by side. Returns the server and
its base URL."""
def _serve(project: Path, topology: str) -> tuple[any, str] {
    import jaclang;
    manifest = (_FIXTURE / "jac.toml").read_text(encoding="utf-8");
    # Keep subprocesses on the same compiler source as the test runner.
    manifest += (
        "\n[dev]\njaclang_source = "
        + repr(str(Path(jaclang.__file__).parent.parent))
        + "\n\n[serve.workers]\ncount = 1\n"
    );
    if topology == "fleet" {
        manifest += "\n[scale.gateway]\ncolocate = false\n";
    }
    (project / "jac.toml").write_text(manifest, encoding="utf-8");
    port = get_free_port();
    server = start_server(project, project / "consumer.jac", port);
    return (server, f"http://127.0.0.1:{port}");
}


def _post(base: str, path: str) -> requests.Response {
    return requests.post(f"{base}{path}", json={}, timeout=60);
}


"""What a JSON function call answered: its status and, on success, its
result."""
def _result(base: str, path: str) -> dict[str, any] {
    response = _post(base, path);
    if response.status_code != 200 {
        return {"status": response.status_code};
    }
    return {"status": 200, "result": response.json()["data"]["result"]};
}


def _count_marks(base: str) -> int {
    return int(_result(base, "/function/count_marks")["result"]);
}


"""Stream a function that writes and then yields, and report whether the
write is visible afterwards."""
def _stream_write(base: str) -> dict[str, any] {
    before = _count_marks(base);
    response = _post(base, "/function/stream_write");
    return {
        "status": response.status_code,
        "events": [
            line
            for line in response.text.splitlines()
            if line.startswith(("data:", "event:"))
        ],
        "committed": _count_marks(base) - before
    };
}


def _typed_return(base: str) -> dict[str, any] {
    return _result(base, "/function/probe_typed");
}


def _bridged_generator(base: str) -> dict[str, any] {
    return _result(base, "/function/probe_stream");
}


def _bridged_walker_generator(base: str) -> dict[str, any] {
    return _result(base, "/function/probe_walker_stream");
}


"""A bridged call that raises: the exception the caller sees, and whether its
detail is the provider's own message rather than a transport wrapping of it."""
def _bridged_raise(base: str) -> dict[str, any] {
    outcome = _result(base, "/function/probe_raise");
    if "result" not in outcome {
        return outcome;
    }
    caught = outcome["result"];
    detail = str(caught["message"]).split(" failed: ", 1)[-1];
    return {
        "status": outcome["status"],
        "type": caught["type"],
        "error_status": caught["status"],
        "detail_is_provider_message": detail == "score failed"
    };
}


def _canonical_provider_path(base: str) -> dict[str, any] {
    return {"status": _post(base, "/function/fetch_score").status_code};
}


def _unknown_name(base: str) -> dict[str, any] {
    return {"status": _post(base, "/function/no_such_fn").status_code};
}


glob _ROWS: list[tuple[str, Callable[[str], dict[str, any]]]] = [
         ("typed return across the boundary", _typed_return),
         ("bridged generator function", _bridged_generator),
         ("bridged walker reporting a generator", _bridged_walker_generator),
         ("bridged function that raises", _bridged_raise),
         ("write inside an SSE stream", _stream_write),
         ("provider function at the canonical path", _canonical_provider_path),
         ("unknown function name", _unknown_name),

     ];

"""What a conformant row must also answer in each topology, so a regression
both topologies share cannot pass as agreement. The stream's write count is
held to equality only: both topologies lose it on main, and #10313 fixes it
in both."""
glob _EXPECTED: dict[str, dict[str, any]] = {
         "bridged generator function": {"status": 200, "result": {"items": [0, 1, 2]}},
         "write inside an SSE stream": {
             "status": 200,
             "events": ['data: "wrote"', "event: end", "data: {}"]
         },

     };

"""Rows that diverge today, pinned at what each topology answers on main.
When a row's outcomes stop matching these, the divergence moved: if the
topologies now agree, delete the row from here so it is held to equality."""
glob _KNOWN_DIVERGENT: dict[str, dict[str, dict[str, any]]] = {
         # #8173 clause 5 (types): colocated hands back the provider's own
         # class, which is not the consumer's boundary type.
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
         # #8173 clause 3 (streaming): colocated returns the generator object
         # as a report, the fleet fails to decode the streamed reply.
         "bridged walker reporting a generator": {
             "colocated": {"status": 200, "result": {"reports": ["generator"]}},
             "fleet": {"status": 500}
         },
         # #8173 clause 6 (failure): the fleet wraps the provider's message in
         # the RPC transport's error text.
         "bridged function that raises": {
             "colocated": {
                 "status": 200,
                 "type": "BridgeError",
                 "error_status": 0,
                 "detail_is_provider_message": True
             },
             "fleet": {
                 "status": 200,
                 "type": "BridgeError",
                 "error_status": 0,
                 "detail_is_provider_message": False
             }
         },
         # #8173 clause 2 (addressing): only the fleet serves a provider's
         # function at the canonical path.
         "provider function at the canonical path": {
             "colocated": {"status": 405},
             "fleet": {"status": 200}
         },
         # #8173 clauses 2 and 6: an unknown name is 405 colocated, 404 behind
         # the gateway.
         "unknown function name": {
             "colocated": {"status": 405},
             "fleet": {"status": 404}
         },

     };


test "every conformance row means the same thing colocated and as a fleet" {
    with TemporaryDirectory() as tmp {
        project = Path(tmp);
        shutil.copytree(
            _FIXTURE, project, dirs_exist_ok=True, ignore=shutil.ignore_patterns(".jac")
        );
        outcomes: dict[str, dict[str, dict[str, any]]] = {};
        for topology in ["colocated", "fleet"] {
            (server, base) = _serve(project, topology);
            try {
                for (name, probe) in _ROWS {
                    outcomes.setdefault(name, {})[topology] = probe(base);
                }
            } finally {
                stop_server(server);
            }
        }
        failures: list[str] = [];
        for (name, _probe) in _ROWS {
            seen = outcomes[name];
            if name in _KNOWN_DIVERGENT {
                if seen != _KNOWN_DIVERGENT[name] {
                    failures.append(
                        f"{name}: known divergence changed, now {seen}; if the "
                        "topologies agree, move the row out of _KNOWN_DIVERGENT"
                    );
                }
                continue;
            }
            if seen["colocated"] != seen["fleet"] {
                failures.append(
                    f"{name}: colocated {seen['colocated']} != fleet {seen['fleet']}"
                );
            }
            for (key, value) in _EXPECTED.get(name, {}).items() {
                for (topology, outcome) in seen.items() {
                    if outcome.get(key) != value {
                        failures.append(
                            f"{name}: {topology} answered {key}={outcome.get(key)!r}, "
                            f"expected {value!r}"
                        );
                    }
                }
            }
        }
        assert not failures , "\n".join(failures);
    }
}
