#-------------------------------------------------------------------------------
# ToolCall Implementations
#-------------------------------------------------------------------------------
"""Execute the tool call and return a result message."""
impl ToolCall.__call__ -> ToolCallResultMsg {
    import from byllm.observability { get_observer, EventType }
    import time;
    observer = get_observer();

    observer.emit_event(EventType.TOOL_CALL_START,
        call_id=self.call_id, tool_name=self.tool.get_name(),
        args={k: str(v)[:500] for (k, v) in (self.args or {}).items()},
        is_finish_tool=self.tool.is_finish_tool());

    tool_start = time.monotonic();
    if self.args is not None {
        result = self.tool(**self.args);
    } else {
        raise ValueError("args is None, Expected a dictionary") ;
    }

    result_str = str(result);
    observer.emit_event(EventType.TOOL_CALL_END,
        call_id=self.call_id, tool_name=self.tool.get_name(),
        duration_ms=(time.monotonic() - tool_start) * 1000,
        result_length=len(result_str), result_preview=result_str[:200]);

    return ToolCallResultMsg(
        content=str(result), tool_call_id=self.call_id, name=self.tool.get_name(),
    );
}

"""Return the string representation of the tool call."""
impl ToolCall.__str__ -> str {
    params = ", ".join(f"{k}={v}" for (k, v) in self.args.items());
    return f"{self.tool.get_name()}({params})";
}

"""Check if this is a call to the finish tool."""
impl ToolCall.is_finish_call -> bool {
    return self.tool.is_finish_tool();
}

"""Get the output from the finish tool call."""
impl ToolCall.get_output -> object {
    assert (self.is_finish_call()) , "This method should only be called for finish tools.";
    return self.tool(**self.args);
}

#-------------------------------------------------------------------------------
# MockToolCall Implementations
#-------------------------------------------------------------------------------
"""Convert the mock tool call to a real ToolCall for testing."""
impl MockToolCall.to_tool_call -> ToolCall {
    args_parsed = Tool(self.tool).parse_arguments(self.args);
    return ToolCall(
        call_id="",  # Call ID is not used in mock calls.
        tool=Tool(self.tool),
        args=args_parsed,
    );
}
