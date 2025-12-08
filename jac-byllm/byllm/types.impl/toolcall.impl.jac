#-------------------------------------------------------------------------------
# ToolCall Implementations
#-------------------------------------------------------------------------------
impl ToolCall.__call__()  -> ToolCallResultMsg {
    if self.args is not None {
        result = self.tool(**self.args);
    } else {
        raise ValueError("args is None, Expected a dictionary") ;
    }
    return ToolCallResultMsg(
        role=MessageRole.TOOL,
        content=str(result),
        tool_call_id=self.call_id,
        name=self.tool.get_name(),
    );
}

impl ToolCall.__str__()  -> str {
    params = ", ".join(f"{k}={v}" for (k, v) in self.args.items());
    return f"{self.tool.get_name()}({params})";
}

impl ToolCall.is_finish_call()  -> bool {
    return self.tool.is_finish_tool();
}

impl ToolCall.get_output()  -> object {
    assert (self.is_finish_call()) , "This method should only be called for finish tools.";
    return self.tool(**self.args);
}

#-------------------------------------------------------------------------------
# MockToolCall Implementations
#-------------------------------------------------------------------------------
impl MockToolCall.to_tool_call()  -> ToolCall {
    args_parsed = Tool(self.tool).parse_arguments(self.args);
    return ToolCall(
        call_id="",  # Call ID is not used in mock calls.
        tool=Tool(self.tool),
        args=args_parsed,
    );
}
