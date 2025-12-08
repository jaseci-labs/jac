#-------------------------------------------------------------------------------
# Message Implementations
#-------------------------------------------------------------------------------
impl Message.to_dict()  -> dict[
    str,
    object
] {
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
impl ToolCallResultMsg.postinit()  -> None {
    self.role = MessageRole.TOOL;  # Maybe this should be an assertion?
}

impl ToolCallResultMsg.to_dict()  -> dict[str, object] {
    return {
        "role": self.role.value,
        "content": self.content,
        "tool_call_id": self.tool_call_id,
        "name": self.name,

    };
}
