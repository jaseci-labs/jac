"""Tests for multimodal tool result support (byllm/types.jac + message.impl.jac).

One test per helper added for the fix.  Each proves the *new* behavior
(Media survives the path); back-compat for string-returning tools is
covered by the existing test_parallel.jac suite.
"""

import from jaclang.byllm.types {
    ToolCallResultMsg,
    Text,
    Image,
    normalize_tool_result,
    content_preview,
    reroute_tool_images_to_user_message
}


test "normalize_tool_result keeps a Media or a list of only Media, and stringifies the rest" {
    image = Image(url="https://example.com/x.png");
    items = [Text(text="ok"), image];
    assert normalize_tool_result(items) == items;
    assert normalize_tool_result(image) == [image];
    assert normalize_tool_result([]) == "[]";
    assert normalize_tool_result([image, "caption"]) == str([image, "caption"]);
    assert normalize_tool_result(3) == "3";
}


test "ToolCallResultMsg.to_dict serializes Media to image_url block" {
    msg = ToolCallResultMsg(
        content=[Text(text="PASS"), Image(url="https://example.com/x.png")],
        tool_call_id="call_1",
        name="browser_validate"
    );
    blocks = msg.to_dict()["content"];
    assert blocks[0] == {"type": "text", "text": "PASS"};
    assert blocks[1]["type"] == "image_url";
    assert blocks[1]["image_url"]["url"] == "https://example.com/x.png";
}


test "content_preview yields text without leaking base64" {
    preview = content_preview(
        [Text(text="PASS"), Image(url="data:image/png;base64,iVBORw0KGgoLONGBLOB")], 500
    );
    assert "PASS" in preview;
    assert "[image]" in preview;
    assert "iVBORw0KGgo" not in preview;
}


test "reroute: tool image moves into a labelled user message before the next non-tool" {
    msgs = [
        {"role": "user", "content": "look"},
        {
            "role": "tool",
            "tool_call_id": "call_1",
            "name": "browser_validate",
            "content": [
                {"type": "text", "text": "PASS"},
                {"type": "image_url", "image_url": {"url": "https://example.com/x.png"}}
            ]
        },
        {"role": "assistant", "content": "ok"}
    ];
    out = reroute_tool_images_to_user_message(msgs);
    assert out[1]["role"] == "tool" and out[1]["tool_call_id"] == "call_1";
    assert out[1]["content"] == "PASS";
    assert out[2]["role"] == "user";
    assert "Tool result for browser_validate" in out[2]["content"][0]["text"];
    assert out[2]["content"][1]["image_url"]["url"] == "https://example.com/x.png";
    assert out[3]["role"] == "assistant";
}


test "reroute: consecutive tool messages flush ONE trailing user msg with all images" {
    msgs = [
        {"role": "assistant", "content": None, "tool_calls": []},
        {
            "role": "tool",
            "tool_call_id": "a",
            "name": "t1",
            "content": [
                {"type": "text", "text": "A"},
                {"type": "image_url", "image_url": {"url": "u1"}}
            ]
        },
        {
            "role": "tool",
            "tool_call_id": "b",
            "name": "t2",
            "content": "text-only result"
        },
        {
            "role": "tool",
            "tool_call_id": "c",
            "name": "t3",
            "content": [{"type": "image_url", "image_url": {"url": "u3"}}]
        }
    ];
    out = reroute_tool_images_to_user_message(msgs);
    assert out[1]["role"] == "tool" and out[1]["content"] == "A";
    assert out[2]["role"] == "tool" and out[2]["content"] == "text-only result";
    assert out[3]["role"] == "tool" and "image attached" in out[3]["content"];
    assert out[4]["role"] == "user";
    user_content = out[4]["content"];
    assert isinstance(user_content, list);
    img_urls = [
        b["image_url"]["url"]
        for b in user_content
        if isinstance(b, dict) and b.get("type") == "image_url"
    ];
    assert img_urls == ["u1", "u3"];
}


test "reroute: a file block leaves the tool message and follows it in a user message" {
    file_block = {
        "type": "file",
        "file": {
            "file_data": "data:application/pdf;base64,JVBERi0=",
            "filename": "a.pdf"
        }
    };
    msgs = [
        {"role": "assistant", "content": None, "tool_calls": []},
        {
            "role": "tool",
            "tool_call_id": "call_1",
            "name": "fetch_brief",
            "content": [{"type": "text", "text": "PASS"}, file_block]
        },
        {
            "role": "tool",
            "tool_call_id": "call_2",
            "name": "fetch_spec",
            "content": [file_block]
        }
    ];
    out = reroute_tool_images_to_user_message(msgs);
    assert out[1]["content"] == "PASS";
    assert out[2]["role"] == "tool" and "document attached" in out[2]["content"];
    assert out[3]["role"] == "user";
    assert [
        b
        for b in out[3]["content"]
        if b.get("type") == "file"
    ]
        == [file_block, file_block];
}
