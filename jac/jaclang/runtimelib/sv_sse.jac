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

def sv_http_post(url: str, path: str, args: dict) -> tuple {
    import http.client;
    import from urllib.parse { urlparse }
    parsed = urlparse(url);
    conn = http.client.HTTPConnection(parsed.hostname, parsed.port or 80, timeout=30);
    conn.request(
        "POST",
        path,
        body=json.dumps(args),
        headers={"Content-Type": "application/json", "Accept": "application/json"}
    );
    return (conn.getresponse(), conn);
}


obj SSELineReader {
    has resp: any;

    def iter_lines -> any {
        for raw in iter(self.resp.readline, b"") {
            yield raw.rstrip(b"\r\n");
        }
    }
}


def wrap_sse_keepalive_conn(resp: any, conn: any, func_label: str) -> any {
    try {
        for ev in consume_sse_stream(SSELineReader(resp=resp), func_label) {
            yield ev;
        }
    } finally {
        try {
            conn.close();
        } except Exception {
            ;
        }
    }
}


def wrap_sse_keepalive(stream_cm: any, resp: any, client: any, func_label: str) -> any {
    try {
        for ev in consume_sse_stream(resp, func_label) {
            yield ev;
        }
    } finally {
        try {
            stream_cm.__exit__(None, None, None);
        } except Exception {
            ;
        }
        if client {
            try {
                client.close();
            } except Exception {
                ;
            }
        }
    }
}
