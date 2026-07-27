impl Message.from_dict(d: dict) -> Message | LiteLLMMessage | dict {
    if "tool_call_id" in d {
        return ToolCallResultMsg(
            content=d.get("content", ""),
            tool_call_id=d.get("tool_call_id", ""),
            name=d.get("name", "")
        );
    }
    if d.get("tool_calls") {
        try {
            return LiteLLMMessage(**d);
        } except Exception {
            return d;
        }
    }
    role_str = d.get("role", "user");
    try {
        role = MessageRole(role_str);
    } except Exception {
        role = MessageRole.USER;
    }
    return Message(role=role, content=d.get("content", ""));
}

impl Message.to_dict -> dict[str, object] {
    if isinstance(self.content, str) {
        return {"role": self.role.value, "content": self.content};
    }
    return {"role": self.role.value, "content": serialize_media_content(self.content)};
}

impl ToolCallResultMsg.postinit -> None {
    self.role = MessageRole.TOOL;
}

impl ToolCallResultMsg.to_dict -> dict[str, object] {
    content_out = (
        self.content
            if isinstance(self.content, str)
            else serialize_media_content(self.content)
    );
    return {
        "role": self.role.value,
        "content": content_out,
        "tool_call_id": self.tool_call_id,
        "name": self.name,

    };
}
