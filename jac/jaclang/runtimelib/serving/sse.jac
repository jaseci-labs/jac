import inspect;
import logging;
import from collections.abc { AsyncIterator, Iterator }
import from json { dumps, loads }


glob _logger: logging.Logger = logging.getLogger("jaclang.runtimelib.serving.sse");


def _sse_json_default(o: any) -> str {
    return str(o);
}

def format_sse_event(data_text: str, event: (str | None) = None) -> str {
    prefix = f"event: {event}\n" if event else '';
    lines = ''.join([f"data: {line}\n" for line in data_text.split('\n')]);
    return f"{prefix}{lines}\n";
}

def sse_frame_stream(source: any) -> AsyncIterator[str] {
    if not (
        inspect.isgenerator(source)
        or inspect.isasyncgen(source)
        or hasattr(source, '__aiter__')
    ) {
        raise TypeError(
            "sse_frame_stream expects a generator or async generator, got "
                + type(source).__name__
        );
    }
    return _sse_frame_stream_inner(source);
}

async def _sse_frame_stream_inner(source: any) -> AsyncIterator[str] {
    try {
        if inspect.isasyncgen(source) or hasattr(source, '__aiter__') {
            async for item in source {
                yield format_sse_event(dumps(item, default=_sse_json_default));
            }
        } else {
            for item in source {
                yield format_sse_event(dumps(item, default=_sse_json_default));
            }
        }
        yield format_sse_event('{}', event='end');
    } except Exception as e {
        _logger.exception("SSE stream producer failed");
        yield format_sse_event(
            dumps(
                {'error_type': type(e).__name__, 'message': str(e)},
                default=_sse_json_default
            ),
            event='error'
        );
    }
}

def parse_sse(line_iter: any) -> Iterator[tuple[str, str]] {
    event: str = 'message';
    data_lines: list[str] = [];
    for raw in line_iter {
        line: str = raw.decode('utf-8') if isinstance(raw, bytes) else raw;
        line = line.rstrip('\r');
        if line == '' {
            if data_lines {
                yield (event, '\n'.join(data_lines));
            }
            event = 'message';
            data_lines = [];
            continue;
        }
        if line.startswith(':') {
            continue;
        }
        if line.startswith('data:') {
            payload: str = line[5:];
            if payload.startswith(' ') {
                payload = payload[1:];
            }
            data_lines.append(payload);
        } elif line.startswith('event:') {
            event_payload: str = line[6:];
            if event_payload.startswith(' ') {
                event_payload = event_payload[1:];
            }
            event = event_payload;
        }
    }
    if data_lines {
        yield (event, '\n'.join(data_lines));
    }
}

def consume_sse_events(line_iter: any, func_label: str) -> Iterator[dict] {
    for (event_name, data_text) in parse_sse(line_iter) {
        if event_name == 'end' {
            return;
        }
        if event_name == 'error' {
            payload: dict = {};
            try {
                payload = loads(data_text) if data_text else {};
            } except Exception {
                payload = {'message': data_text};
            }
            msg = payload.get('message', 'stream producer failed');
            raise RuntimeError(f"stream '{func_label}' raised: {msg}");
        }
        try {
            yield loads(data_text);
        } except Exception as je {
            _logger.warning(f"stream '{func_label}': dropped malformed event ({je})");
        }
    }
}
