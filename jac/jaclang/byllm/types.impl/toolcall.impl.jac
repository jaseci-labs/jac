impl ToolCall.__call__ -> ToolCallResultMsg {
    if self.args is not None {
        result = self.tool(**self.args);
    } else {
        raise ByLLMError("ToolCall.args is None, expected a dictionary");
    }
    return ToolCallResultMsg(
        content=normalize_tool_result(result),
        tool_call_id=self.call_id,
        name=self.tool.get_name(),
    );
}

impl ToolCall.__str__ -> str {
    params = ", ".join(f"{k}={v}" for (k, v) in self.args.items());
    return f"{self.tool.get_name()}({params})";
}

impl ToolCall.is_finish_call -> bool {
    return self.tool.is_finish_tool();
}

impl ToolCall.get_output -> object {
    assert (self.is_finish_call()) , "This method should only be called for finish tools.";
    return self.tool(**self.args);
}

impl MockToolCall.to_tool_call -> ToolCall {
    tool_obj = Tool(self.tool);
    args_parsed = tool_obj.parse_arguments(self.args);
    return ToolCall(call_id="", tool=tool_obj, args=args_parsed,);
}
