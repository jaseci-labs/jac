"""What `by` calls, as neojac's stdjac.by declares it: a plugin that gives a result
(`By`), one that answers as it goes (`ByStreams`) and one that chooses a walker's way
(`ByChooser`), the call they are given, and what a streamed call says as it works.
"""

obj ByTool {
    has name: str,
        call: Callable[[dict[str, any]], any],
        doc: str = "",
        schema: dict[str, any] = {};
}

obj ByCall {
    has name: str,
        doc: str = "",
        args: dict[str, any] = {},
        arg_docs: dict[str, str] = {},
        result_schema: dict[str, any] = {},
        decode: Callable[[any], any] | None = None,
        tools: list[ByTool] = [];
}

obj ByError(Exception) {}

obj By {
    def invoke(call: ByCall) -> any abst;
}

obj ByUsage {
    has requests: int = 0,
        input_tokens: int = 0,
        output_tokens: int = 0,
        cache_read_tokens: int = 0,
        cache_write_tokens: int = 0,
        seconds: float = 0.0,
        model: str = "";

    def add(more: ByUsage) -> None {
        self.requests += more.requests;
        self.input_tokens += more.input_tokens;
        self.output_tokens += more.output_tokens;
        self.cache_read_tokens += more.cache_read_tokens;
        self.cache_write_tokens += more.cache_write_tokens;
        self.seconds += more.seconds;
        if more.model != "" {
            self.model = more.model;
        }
    }
}

enum ByEventKind: str {
    TEXT = "text",
    TOOL_CALL = "tool_call",
    TOOL_RESULT = "tool_result",
    USAGE = "usage",
    DONE = "done",
}

obj ByEvent {
    has kind: ByEventKind,
        text: str = "",
        tool: str = "",
        call_id: str = "",
        args: dict[str, any] = {},
        result: str = "",
        usage: ByUsage | None = None,
        value: any = None;
}

obj ByChoice {
    has name: str,
        asker: dict[str, any] = {},
        at: dict[str, any] = {},
        options: list[dict[str, any]] = [];
}

obj ByChooser {
    def choose(choice: ByChoice) -> list[int] abst;
}

obj ByWay {
    has of: Callable[[any], dict[str, any] | None];
}

obj ByStreams {
    def stream(call: ByCall) -> Iterator[ByEvent] abst;
}
