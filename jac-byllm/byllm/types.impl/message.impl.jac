#-------------------------------------------------------------------------------
# Message Implementations
#-------------------------------------------------------------------------------
"""Convert the message to a dictionary for LLM API calls."""
impl Message.to_dict()  -> dict[str, object] {
    if isinstance(self.content, str) {
        return {"role": self.role.value, "content": self.content,};
    }
    media_contents = [];
    for media in self.content {
        media_contents.extend(media.to_dict());
        return {"role": self.role.value, "content": media_contents,};
    }
}

#-------------------------------------------------------------------------------
# ToolCallResult Implementations
#-------------------------------------------------------------------------------
"""Set the role to TOOL for tool call result messages."""
impl ToolCallResultMsg.postinit()  -> None {
    self.role = MessageRole.TOOL;  # Maybe this should be an assertion?
}

"""Convert the tool call result message to a dictionary."""
impl ToolCallResultMsg.to_dict()  -> dict[str, object] {
    return {
        "role": self.role.value,
        "content": self.content,
        "tool_call_id": self.tool_call_id,
        "name": self.name,

    };
}
