impl image_resp_kind(resp_type: type | None) -> str {
    if resp_type is Image {
        return "one";
    }
    if get_origin(resp_type) is list and get_args(resp_type) == (Image, ) {
        return "many";
    }
    return "";
}

impl serialize_media_content(content: list[any]) -> list[dict[str, any]] {
    blocks: list[dict[str, any]] = [];
    for item in content {
        if isinstance(item, dict) {
            blocks.append(item);
            continue;
        }
        semstring = "";
        if isinstance(item, tuple) {
            semstring = item[1] or "";
            item = item[0];
        }
        if semstring {
            blocks.append({"type": "text", "text": semstring});
        }
        blocks.extend(item.to_dict());
    }
    return blocks;
}

impl as_media_list(value: any) -> list[Media] | None {
    if isinstance(value, Media) {
        return [value];
    }
    if (
        isinstance(value, list)
        and value
        and all(isinstance(elem, Media) for elem in value)
    ) {
        return value;
    }
    return None;
}


impl normalize_tool_result(value: any) -> str | list[Media] {
    media = as_media_list(value);
    return str(value) if media is None else media;
}

impl content_preview(content: any, max_len: int) -> str {
    if isinstance(content, str) {
        return content[:max_len];
    }
    if not isinstance(content, list) {
        return str(content)[:max_len];
    }
    parts: list[str] = [];
    for item in content {
        if isinstance(item, str) {
            parts.append(item);
        } elif isinstance(item, Text) {
            parts.append(item.text);
        } else {
            kind = type(item).__name__.lower();
            parts.append(f"[{kind}]");
        }
    }
    return " ".join(parts)[:max_len];
}

impl reroute_tool_images_to_user_message(
    messages: list[dict[str, object] | LiteLLMMessage]
) -> list[dict[str, object] | LiteLLMMessage] {
    if not any(_tool_msg_has_image(m) for m in messages) {
        return messages;
    }

    out: list[dict[str, object] | LiteLLMMessage] = [];
    pending: list[dict[str, any]] = [];

    for msg in messages {
        if isinstance(msg, dict) and _tool_msg_has_image(msg) {
            (stripped, images) = _split_tool_msg_images(msg);
            out.append(stripped);
            name = msg.get("name", "tool");
            call_id = msg.get("tool_call_id", "");
            pending.append(
                {"type": "text", "text": f"[Tool result for {name} (id {call_id})]:"}
            );
            pending.extend(images);
        } elif _is_tool_msg(msg) {
            out.append(msg);
        } else {
            if pending {
                out.append({"role": "user", "content": pending});
                pending = [];
            }
            out.append(msg);
        }
    }
    if pending {
        out.append({"role": "user", "content": pending});
    }
    return out;
}

impl _is_tool_msg(msg: object) -> bool {
    return isinstance(msg, dict) and msg.get("role") == "tool";
}

impl _tool_msg_has_image(msg: object) -> bool {
    if not (isinstance(msg, dict) and msg.get("role") == "tool") {
        return False;
    }
    content = msg.get("content");
    if not isinstance(content, list) {
        return False;
    }
    for block in content {
        if isinstance(block, dict) and block.get("type") in TOOL_MEDIA_BLOCKS {
            return True;
        }
    }
    return False;
}

impl _split_tool_msg_images(
    msg: dict[str, any]
) -> tuple[dict[str, any], list[dict[str, any]]] {
    content = msg.get("content");
    if not isinstance(content, list) {
        return (msg, []);
    }
    text_blocks: list[dict[str, any]] = [];
    media_blocks: list[dict[str, any]] = [];
    for block in content {
        if isinstance(block, dict) and block.get("type") in TOOL_MEDIA_BLOCKS {
            media_blocks.append(block);
        } else {
            text_blocks.append(block);
        }
    }
    if not media_blocks {
        return (msg, []);
    }
    text_only = all(
        isinstance(b, dict) and b.get("type") == "text" for b in text_blocks
    );
    stripped_content: str | list[any] = "";
    if text_only {
        stripped_content = " ".join(b.get("text", "") for b in text_blocks).strip();
        if not stripped_content {
            noun = "document"
                if all(b.get("type") == "file" for b in media_blocks)
                else "image";
            stripped_content = f"({noun} attached in following user message)";
        }
    } else {
        stripped_content = text_blocks;
    }
    return ({** msg, "content": stripped_content}, media_blocks);
}

impl response_dict(value: object) -> dict[str, any] {
    if isinstance(value, dict) {
        return value;
    }
    dump = value?.model_dump;
    result = dump() if callable(dump) else None;
    if not isinstance(result, dict) {
        raise TypeError(
            f'Expected a model response mapping, got {type(value).__name__}'
        );
    }
    return result;
}
