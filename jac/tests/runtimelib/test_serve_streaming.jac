"""Server-Sent Events streaming for generator-returning `def:pub` endpoints.

A `def:pub` function whose result is a generator (e.g. `-> Iterator[dict]`, the
shape used by `jac ai --ui`'s `agent_stream`) is a stream, not a single value.
The JSON transport cannot encode a generator -- it raised "Object of type
generator is not JSON serializable" -- so the base server must instead emit each
yielded item as a canonical `data: {json}\n\n` SSE frame, terminated by
`event: end`. This guards that path end to end through JacTestClient (no socket).
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.testing { JacTestClient }

test "function returning an iterator streams as SSE instead of crashing" {
    with TemporaryDirectory() as tmp {
        app = Path(tmp) / "stream_app.jac";
        app.write_text(
            'import from typing { Iterator }\n'
            'def:pub stream_numbers -> Iterator[dict] {\n'
            '    for i in range(3) {\n'
            '        yield {"n": i};\n'
            '    }\n'
            '}\n'
        );
        client = JacTestClient.from_file(str(app), base_path=tmp);
        try {
            resp = client.post("/function/stream_numbers", json={});
            # Streamed, not JSON-enveloped: SSE content type + per-item frames.
            assert resp.status_code == 200 , f"status {resp.status_code}: {resp.text}";
            assert "text/event-stream" in resp.headers.get("Content-Type", "");
            assert 'data: {"n": 0}' in resp.text;
            assert 'data: {"n": 1}' in resp.text;
            assert 'data: {"n": 2}' in resp.text;
            # Clean terminator, and crucially NOT the pre-fix crash.
            assert "event: end" in resp.text;
            assert "not JSON serializable" not in resp.text;
        } finally {
            client.close();
        }
    }
}
