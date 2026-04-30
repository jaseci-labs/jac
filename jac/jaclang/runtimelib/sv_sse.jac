"""SSE consumer for sv-to-sv RPC calls that return iterators.

When an sv-imported `def:pub` function returns a generator, jac-scale's
serve.endpoints wraps it in a StreamingResponse with a text/event-stream
body framed by jac_scale.microservices._sse.sse_frame_stream:

    data: {json}\n\n
    data: {json}\n\n
    event: end\ndata: {}\n\n          # graceful close
    # or
    event: error\ndata: {err}\n\n     # producer raised mid-stream

The default sv_service_call (and jac-scale's plugin override) calls
into this module when it sees Content-Type: text/event-stream on the
response. We return a Python generator that yields parsed event dicts.
The generator owns the httpx connection's lifetime — closing it (or
exhausting it) releases the connection.

Connection lifetime:

  - On normal end (`event: end`), the generator returns cleanly and
    `finally` closes the response and the underlying client.
  - On `event: error`, the generator raises `RuntimeError` with the
    producer's error payload — caller's `for ... in ...` loop sees
    the exception, and `finally` still closes the connection.
  - On consumer disconnect (caller calls `close()` on the generator
    or stops iterating), `finally` still closes the connection.

Errors and timeouts during transport (network drop, server hang)
propagate as httpx exceptions out of the iterator.
"""

import json;
import logging;
import from typing { Any, Iterator }


glob _logger: logging.Logger = logging.getLogger("jaclang.runtimelib.sv_sse");


"""Iterate the SSE body line-by-line, accumulating per-message
lines into (event_type, raw_data_string) tuples per the WHATWG
EventSource spec we care about.

Only the fields we use (`event`, `data`) are tracked; `id`, `retry`,
and other fields are ignored. Multi-line `data:` is supported by
joining with newlines, matching the spec.

Yields: (event_name: str, data_text: str)
"""
def _parse_sse(line_iter: Any) -> Iterator[tuple[str, str]] {
    event: str = "message";
    data_lines: list[str] = [];
    for raw in line_iter {
        # httpx returns str when iter_lines() is used; bytes from
        # iter_raw(). Be defensive.
        line: str = raw.decode("utf-8") if isinstance(raw, bytes) else raw;
        # Strip CR for CRLF servers; do not strip LF (already handled).
        line = line.rstrip("\r");
        if line == "" {
            # Message terminator. Only emit if this message had at least
            # one `data:` line — per spec, a message with no data is a
            # "do-nothing" beat.
            if data_lines {
                yield (event, "\n".join(data_lines));
            }
            event = "message";
            data_lines = [];
            continue;
        }
        if line.startswith(":") {
            # SSE comment — ignore (often used as a keep-alive)
            continue;
        }
        if line.startswith("data:") {
            # Accept both `data: foo` and `data:foo` per spec.
            payload: str = line[5:];
            if payload.startswith(" ") {
                payload = payload[1:];
            }
            data_lines.append(payload);
        } elif line.startswith("event:") {
            event_payload: str = line[6:];
            if event_payload.startswith(" ") {
                event_payload = event_payload[1:];
            }
            event = event_payload;
        }
        # else: id:, retry:, unknown — ignored
    }
    # Trailing message without a final blank line (some producers
    # close the connection right after the last `data:` line).
    if data_lines {
        yield (event, "\n".join(data_lines));
    }
}


"""Consume an httpx streaming Response as an event iterator.

The Response MUST already have been opened (i.e. the caller already
called `stream_cm.__enter__()` and is responsible for `__exit__()`
when the iterator is exhausted or dropped). This split exists because
the caller has to inspect `Content-Type` to decide whether the
response is SSE at all — by then the context manager is already
entered, and httpx doesn't support a second enter.

Args:
    resp: an entered httpx.Response (has working iter_lines()).
    func_label: identifier shown in error messages (`module.func` form).

Yields: parsed event dicts as they arrive.

Raises: RuntimeError with the producer's error payload if the stream
    closes with `event: error`; httpx exceptions for transport issues.
"""
def consume_sse_stream(resp: Any, func_label: str) -> Iterator[dict] {
    for (event_name, data_text) in _parse_sse(resp.iter_lines()) {
        if event_name == "end" {
            return;
        }
        if event_name == "error" {
            payload: dict = {};
            try {
                payload = json.loads(data_text) if data_text else {};
            } except Exception {
                payload = {"message": data_text};
            }
            msg = payload.get("message", "stream producer failed");
            raise RuntimeError(f"sv-to-sv stream '{func_label}' raised: {msg}");
        }
        # Default "message" event — payload is the JSON of one item.
        # Drop malformed payloads with a warning rather than killing the
        # stream; one bad event shouldn't take out the whole turn.
        try {
            yield json.loads(data_text);
        } except Exception as je {
            _logger.warning(
                f"sv-to-sv stream '{func_label}': dropped malformed event ({je})"
            );
        }
    }
}
