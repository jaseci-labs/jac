import inspect;
import logging;
import from json { dumps, loads }


glob _logger: logging.Logger = logging.getLogger("jaclang.server.serving.sse");


def _sse_json_default(o: any) -> str;

def format_sse_event(data_text: str, event: (str | None) = None) -> str;

def sse_frame_stream(source: any) -> AsyncIterator[str];

async def _sse_frame_stream_inner(source: any) -> AsyncIterator[str];

def parse_sse(line_iter: any) -> Iterator[tuple[str, str]];

def consume_sse_events(line_iter: any, func_label: str) -> Iterator[dict[str, any]];
