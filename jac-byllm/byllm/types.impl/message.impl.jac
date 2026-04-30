#-------------------------------------------------------------------------------
# Message Implementations
#-------------------------------------------------------------------------------
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

"""Convert the message to a dictionary for LLM API calls."""
impl Message.to_dict -> dict[str, object] {
    if isinstance(self.content, str) {
        return {"role": self.role.value, "content": self.content,};
    }
    media_contents = [];
    for media in self.content {
        # Pre-serialized blocks from a round-tripped Message — pass through.
        if isinstance(media, dict) {
            media_contents.append(media);
            continue;
        }
        semstr = "";
        if isinstance(media, tuple) {
            semstr = media[1] or "";
            media = media[0];
        }
        #TODO: make sure the semstr make into the to_dict representation
        if semstr {
            media_dict = media.to_dict();
            media_dict["description"] = semstr;
            media_contents.append(media_dict);
        } else {
            media_contents.extend(media.to_dict());
        }
    }
    return {"role": self.role.value, "content": media_contents};
}

#-------------------------------------------------------------------------------
# ToolCallResult Implementations
#-------------------------------------------------------------------------------
"""Set the role to TOOL for tool call result messages."""
impl ToolCallResultMsg.postinit -> None {
    self.role = MessageRole.TOOL;  # Maybe this should be an assertion?
}

"""Convert the tool call result message to a dictionary."""
impl ToolCallResultMsg.to_dict -> dict[str, object] {
    return {
        "role": self.role.value,
        "content": self.content,
        "tool_call_id": self.tool_call_id,
        "name": self.name,

    };
}
