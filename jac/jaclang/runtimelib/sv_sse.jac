import json;
import logging;
import from typing { Iterator }


glob _logger: logging.Logger = logging.getLogger("jaclang.runtimelib.sv_sse");


def _parse_sse(line_iter: any) -> Iterator[tuple[str, str]] {
    event: str = "message";
    data_lines: list[str] = [];
    for raw in line_iter {
        line: str = raw.decode("utf-8") if isinstance(raw, bytes) else raw;

        line = line.rstrip("\r");
        if line == "" {
            if data_lines {
                yield (event, "\n".join(data_lines));
            }
            event = "message";
            data_lines = [];
            continue;
        }
        if line.startswith(":") {
            continue;
        }
        if line.startswith("data:") {
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
    }

    if data_lines {
        yield (event, "\n".join(data_lines));
    }
}


def consume_sse_stream(resp: any, func_label: str) -> Iterator[dict] {
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

        try {
            yield json.loads(data_text);
        } except Exception as je {
            _logger.warning(
                f"sv-to-sv stream '{func_label}': dropped malformed event ({je})"
            );
        }
    }
}
