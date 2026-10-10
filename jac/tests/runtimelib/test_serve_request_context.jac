"""Every transport runs a walker or function in a request context of its own.

The HTTP path gets a fresh context, and with it a fresh session, from the
request-context middleware. A websocket message is not an HTTP request, so it
never passed through that middleware: the executor took the process-global
context as the call's parent and ran the walker on the process-global session.
Whatever non-request code had read through that session (a background thread
polling the graph is enough) left a transaction open on it, and every websocket
call then read through that old snapshot, so a user registered after it began
had no root as far as the websocket walker could see (#9863).

Pinned here: a websocket walker and a websocket function each run on a session
that is not the process-global one, on the database the HTTP path uses, and see
data committed after the process-global session began reading; a stream whose
delivery is cut off is closed before its scope ends, and one that cannot be
closed has its request's work aborted, so in neither case does the scope
commit unfinished work; and the executor refuses to run a call that no
transport has given a request scope.
"""

import asyncio;
import os;
import threading;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.scale.server.inprocess {
    PreparedInProcessRuntime,
    prepare_inprocess_runtime
}
import from jaclang.scale.server.websocket_ext { WebSocketExtension }
import from jaclang.scale.websocket.websocket { _ws_stream_result }
import from jaclang.server.request_scope { RequestScope }
import from jaclang.server.serving.datatypes { WebSocketDisconnect }
import from jaclang.testing.testkit { ServingTestClient }

# Hash throwaway fixture credentials at minimum scrypt cost so it does not dominate test time.
with entry {
    os.environ.setdefault('JAC_SERVE_AUTH_PASSWORD_HASH_COST', '10');
}


glob _APP: str = (
         'import from jaclang { JacRuntime }\n'
         '\n'
         'node Note {\n'
         '    has text: str = "";\n'
         '}\n'
         '\n'
         '@restspec(protocol=APIProtocol.WEBSOCKET)\n'
         'async walker:protect ws_notes {\n'
         '    has text: str = "";\n'
         '\n'
         '    async can go with Root entry {\n'
         '        if self.text {\n'
         '            here ++> Note(text=self.text);\n'
         '        }\n'
         '        report sorted([n.text for n in [here -->[?:Note]]]);\n'
         '    }\n'
         '}\n'
         '\n'
         '@restspec(protocol=APIProtocol.WEBSOCKET)\n'
         'def:protect ws_probe -> dict[str, int] {\n'
         '    return {\n'
         '        "session": id(JacRuntime.get_context().mem),\n'
         '        "notes": len([root -->[?:Note]])\n'
         '    };\n'
         '}\n'
         '\n'
         '@restspec(protocol=APIProtocol.WEBSOCKET)\n'
         'def:protect ws_stream_note(text: str = "") {\n'
         '    def chunks -> Generator[int, None, None] {\n'
         '        yield len([root -->[?:Note]]);\n'
         '        root ++> Note(text=text);\n'
         '        yield len([root -->[?:Note]]);\n'
         '    }\n'
         '    report chunks();\n'
         '}\n'
         '\n'
         'walker:protect notes {\n'
         '    can go with Root entry {\n'
         '        report sorted([n.text for n in [here -->[?:Note]]]);\n'
         '    }\n'
         '}\n'
     );


"""Serve the fixture app in-process with the websocket routes registered.
Without a manifest the app is a standalone file, whose database is named
after the served file rather than the project."""
def _serve(project_dir: str, manifest: bool = True) -> PreparedInProcessRuntime {
    if manifest {
        (Path(project_dir) / "jac.toml").write_text(
            '[project]\nname = "request-context-test"\nversion = "1.0.0"\n',
            encoding="utf-8"
        );
    }
    app = Path(project_dir) / "app.jac";
    app.write_text(_APP, encoding="utf-8");
    return prepare_inprocess_runtime(
        str(app),
        project_dir,
        endpoint_profile="desktop",
        setup_background_services=False,
        extensions=[WebSocketExtension()]
    );
}


def _client(runtime: PreparedInProcessRuntime) -> ServingTestClient {
    client = runtime.client;
    assert isinstance(client, ServingTestClient);
    return client;
}


def _register_and_login(runtime: PreparedInProcessRuntime, username: str) -> str {
    password = "Passw0rd!123";
    registered = _client(runtime).post(
        "/user/register",
        json={
            "identities": [{"type": "username", "value": username}],
            "credential": {"type": "password", "password": password}
        }
    );
    assert registered.status_code in (200, 201) , f"register failed: {registered.text}";
    logged_in = _client(runtime).post(
        "/user/login",
        json={
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": password}
        }
    );
    return str(logged_in.json()["data"]["token"]);
}


def _http_notes(runtime: PreparedInProcessRuntime, token: str) -> list[str] {
    resp = _client(runtime).post(
        "/walker/notes", json={}, headers={"Authorization": f"Bearer {token}"}
    );
    assert resp.status_code == 200 , f"HTTP walker failed: {resp.text}";
    return list(resp.json()["data"]["reports"][0]);
}


def _ws_call(
    runtime: PreparedInProcessRuntime, path: str, token: str, payload: dict[str, any]
) -> dict[str, any] {
    with _client(runtime).websocket_connect(f"{path}?token={token}") as ws {
        ws.send_json(payload);
        return dict(ws.receive_json());
    }
}


"""What a background thread polling the graph does: read through the
process-global context, outside any request."""
def _read_through_global_context {
    assert Jac.peek_context() is Jac.exec_ctx , (
        "the test body must run outside any request context"
    );
    seen = len([root-->]);
    assert seen >= 0;
}


"""Scale-runtime marking is process-wide; undo it so later files see the
environment they started with."""
def _restore_env(name: str, prior: (str | None)) {
    if prior is None {
        os.environ.pop(name, None);
    } else {
        os.environ[name] = prior;
    }
}


test "a websocket walker sees a user registered after the process-global session began reading" {
    prior = os.environ.get("JAC_SCALE_RUNTIME");
    with TemporaryDirectory() as project {
        runtime = _serve(project);
        try {
            # Control: with nothing read through the global context yet, a
            # new user's websocket call works.
            early = _register_and_login(runtime, "early_user");
            control = _ws_call(runtime, "/ws/walker/ws_notes", early, {});
            assert control.get("ok") is True , f"websocket walker failed: {control}";

            _read_through_global_context();
            late = _register_and_login(runtime, "late_user");
            assert _http_notes(runtime, late) == [];

            first = _ws_call(runtime, "/ws/walker/ws_notes", late, {"text": "one"});
            assert first.get("ok") is True , f"websocket walker failed: {first}";
            assert first["data"]["reports"][0] == ["one"] , f"got {first}";

            # The write is committed: HTTP sees it, and so does the next frame.
            assert _http_notes(runtime, late) == ["one"];
            second = _ws_call(runtime, "/ws/walker/ws_notes", late, {"text": "two"});
            assert second.get("ok") is True , f"websocket walker failed: {second}";
            assert second["data"]["reports"][0] == ["one", "two"] , f"got {second}";
        } finally {
            runtime.close();
            _restore_env("JAC_SCALE_RUNTIME", prior);
        }
    }
}


test "a websocket function runs on a session of its own, not the process-global one" {
    prior = os.environ.get("JAC_SCALE_RUNTIME");
    with TemporaryDirectory() as project {
        runtime = _serve(project);
        try {
            _read_through_global_context();
            global_session = Jac.get_context().mem;
            token = _register_and_login(runtime, "function_user");

            probed = _ws_call(runtime, "/ws/function/ws_probe", token, {});
            assert probed.get("ok") is True , f"websocket function failed: {probed}";
            probe = probed["data"]["result"];
            assert probe["notes"] == 0 , f"got {probed}";
            assert probe["session"] != id(global_session) , (
                "the websocket function ran on the process-global session"
            );
        } finally {
            runtime.close();
            _restore_env("JAC_SCALE_RUNTIME", prior);
        }
    }
}


test "a websocket stream runs inside its request scope and commits when it ends" {
    prior = os.environ.get("JAC_SCALE_RUNTIME");
    with TemporaryDirectory() as project {
        runtime = _serve(project);
        try {
            token = _register_and_login(runtime, "stream_user");
            frames: list[dict[str, any]] = [];
            with _client(runtime).websocket_connect(
                f"/ws/function/ws_stream_note?token={token}"
            ) as ws {
                ws.send_json({"text": "streamed"});
                while not frames or frames[-1].get("type") != "done" {
                    frames.append(dict(ws.receive_json()));
                    assert len(frames) <= 3 , f"unexpected frames: {frames}";
                }
                # The connection's next frame is answered only after the
                # stream's scope has closed, so no timing is involved below.
                ws.send_json({"type": "ping"});
                ws.receive_json();
            }
            assert frames[-1] == {"ok": True, "type": "done"} , f"got {frames}";
            assert [f["data"] for f in frames[:-1]] == [0, 1] , f"got {frames}";
            assert _http_notes(runtime, token) == ["streamed"] , (
                "the stream's write was not committed when the stream ended"
            );
        } finally {
            runtime.close();
            _restore_env("JAC_SCALE_RUNTIME", prior);
        }
    }
}


node StreamNote {
    has text: str = "";
}


"""A request scope on the project's database, opened the way a transport
opens one per message."""
def _open_scope(project: str) -> RequestScope {
    return RequestScope.open(project, str(Path(project) / "app.jac"));
}


"""What a stream's body does to the graph: save a node through whichever
request context is in force while it runs. Returns the node's id."""
def _write_note(text: str) -> UUID {
    note = StreamNote(text=text);
    Jac.save(note);
    return note.__jac__.ensure_id();
}


"""Whether the database holds the node, read through a scope of its own, so
only committed state counts."""
def _committed(project: str, note_id: UUID) -> bool {
    with _open_scope(project) as context {
        return context.mem.get(note_id) is not None;
    }
}


async def _client_gone(payload: dict[str, any]) {
    raise WebSocketDisconnect(code=1006);
}


async def _client_listening(payload: dict[str, any]) {}


"""Deliver `source` the way the websocket loop does: bound to the call's
context inside the message's request scope, each chunk handed to `send`. The
bound stream stays referenced until the scope has closed, so garbage
collection cannot stand in for the delivery code closing it."""
async def _deliver(project: str, source: any, send: any) {
    scope = _open_scope(project);
    stream: any = None;
    with scope as context {
        stream = await ExecutionContext(_parent=context).bind_stream(source);
        try {
            await _ws_stream_result(send, stream, scope.abort);
        } except WebSocketDisconnect {}
    }
}


test "a stream delivered to its end has its write committed when its scope closes" {
    written: list[UUID] = [];
    def chunks -> Generator[str, None, None] {
        written.append(_write_note("finished"));
        yield 'first';
        yield 'second';
    }
    with TemporaryDirectory() as project {
        asyncio.run(_deliver(project, chunks(), _client_listening));
        assert len(written) == 1;
        assert _committed(project, written[0]) , (
            "a stream that ran to its end lost its write"
        );
    }
}


test "a websocket stream cut off mid-delivery does not have its write committed" {
    written: list[UUID] = [];
    def chunks -> Generator[str, None, None] {
        written.append(_write_note("unfinished"));
        yield 'first';
        yield 'second';
    }
    with TemporaryDirectory() as project {
        asyncio.run(_deliver(project, chunks(), _client_gone));
        assert len(written) == 1;
        assert not _committed(project, written[0]) , (
            "the stream was left suspended and its scope committed the work "
            "it had done before the client went away"
        );
    }
}


test "an async websocket stream cut off mid-delivery does not have its write committed" {
    written: list[UUID] = [];
    async def chunks -> AsyncGenerator[str, None] {
        written.append(_write_note("unfinished"));
        yield 'first';
        yield 'second';
    }
    with TemporaryDirectory() as project {
        asyncio.run(_deliver(project, chunks(), _client_gone));
        assert len(written) == 1;
        assert not _committed(project, written[0]) , (
            "the stream was left suspended and its scope committed the work "
            "it had done before the client went away"
        );
    }
}


test "a stream that cannot be closed has its request's work aborted, not committed" {
    running = threading.Event();
    release = threading.Event();
    written: list[UUID] = [];
    # The body is still executing in its worker thread when delivery is
    # cancelled, so closing it raises "generator already executing".
    def chunks -> Generator[str, None, None] {
        written.append(_write_note("still running"));
        running.set();
        release.`wait(30);
        yield 'never delivered';
    }
    def body_running -> bool {
        return running.`wait(30);
    }
    async def cancel_while_running(project: str) {
        loop = asyncio.get_running_loop();
        scope = _open_scope(project);
        stream: any = None;
        try {
            with scope as context {
                stream = await ExecutionContext(_parent=context).bind_stream(chunks());
                delivery = asyncio.ensure_future(
                    _ws_stream_result(_client_listening, stream, scope.abort)
                );
                assert await loop.run_in_executor(None, body_running);
                delivery.cancel();
                try {
                    await delivery;
                } except asyncio.CancelledError {}
            }
        } finally {
            release.set();
        }
    }
    with TemporaryDirectory() as project {
        asyncio.run(cancel_while_running(project));
        assert len(written) == 1;
        assert not _committed(project, written[0]) , (
            "the stream could not be closed and its scope committed the work "
            "it had done"
        );
    }
}


test "a websocket call uses the database the HTTP path uses for a standalone file" {
    prior = os.environ.get("JAC_SCALE_RUNTIME");
    with TemporaryDirectory() as project {
        runtime = _serve(project, manifest=False);
        try {
            token = _register_and_login(runtime, "standalone_user");
            assert _http_notes(runtime, token) == [];
            written = _ws_call(runtime, "/ws/walker/ws_notes", token, {"text": "one"});
            assert written.get("ok") is True , f"websocket walker failed: {written}";
            assert _http_notes(runtime, token) == ["one"];
        } finally {
            runtime.close();
            _restore_env("JAC_SCALE_RUNTIME", prior);
        }
    }
}


test "the executor refuses a call no transport has given a request scope" {
    prior = os.environ.get("JAC_SCALE_RUNTIME");
    with TemporaryDirectory() as project {
        runtime = _serve(project);
        try {
            server = runtime.server;
            token = _register_and_login(runtime, "scoped_user");
            user_id = str(server.user_manager.validate_jwt_token(token));
            walker_cls = server.get_walkers()["notes"];

            refused: (RuntimeError | None) = None;
            try {
                asyncio.run(
                    server.execution_manager.spawn_walker(walker_cls, {}, user_id)
                );
            } except RuntimeError as e {
                refused = e;
            }
            assert refused is not None , (
                "a walker ran with no request scope open, on the "
                "process-global context"
            );
            assert "request scope" in str(refused) , str(refused);

            async def scoped -> dict[str, any] {
                with server.request_scope() {
                    return await server.execution_manager.spawn_walker(
                        walker_cls, {}, user_id
                    );
                }
            }
            assert asyncio.run(scoped())["reports"] == [[]];
        } finally {
            runtime.close();
            _restore_env("JAC_SCALE_RUNTIME", prior);
        }
    }
}
