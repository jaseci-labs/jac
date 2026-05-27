"""Tests for multimodal tool result support (byllm/types.jac + message.impl.jac).

Three focused tests, one per helper added for the fix:
  1. normalize_tool_result preserves list[Media] (no stringification)
  2. ToolCallResultMsg.to_dict serializes Media to provider content blocks
  3. content_preview extracts text from multimodal content (no base64 leak)
"""

import from byllm.types {
    Message,
    MessageRole,
    ToolCallResultMsg,
    Text,
    Image,
    normalize_tool_result,
    content_preview
}


# ---------------------------------------------------------------------------
# 1. normalize_tool_result preserves Media (was: str(result) → "[Image(...)]")
# ---------------------------------------------------------------------------
test "normalize preserves list of Media" {
    items = [Text(text="ok"), Image(url="https://example.com/x.png")];
    normalized = normalize_tool_result(items);
    assert isinstance(normalized, list);
    assert len(normalized) == 2;
    assert isinstance(normalized[0], Text);
    assert isinstance(normalized[1], Image);
}

test "normalize wraps a single Media" {
    normalized = normalize_tool_result(Image(url="https://example.com/x.png"));
    assert isinstance(normalized, list);
    assert len(normalized) == 1;
    assert isinstance(normalized[0], Image);
}

test "normalize passes strings through unchanged" {
    assert normalize_tool_result("hello") == "hello";
}


# ---------------------------------------------------------------------------
# 2. ToolCallResultMsg.to_dict serializes Media (was: dumped raw Python objects)
# ---------------------------------------------------------------------------
test "tool result with image serializes to image_url block" {
    msg = ToolCallResultMsg(
        content=[Text(text="PASS"), Image(url="https://example.com/x.png")],
        tool_call_id="call_1",
        name="browser_validate"
    );
    out = msg.to_dict();
    assert out["role"] == "tool";
    assert out["tool_call_id"] == "call_1";
    assert out["name"] == "browser_validate";

    blocks = out["content"];
    assert isinstance(blocks, list);
    assert blocks[0] == {"type": "text", "text": "PASS"};
    assert blocks[1]["type"] == "image_url";
    assert blocks[1]["image_url"]["url"] == "https://example.com/x.png";
}

test "tool result with string content still passes through" {
    msg = ToolCallResultMsg(
        content="plain text result",
        tool_call_id="call_2",
        name="some_tool"
    );
    out = msg.to_dict();
    assert out["content"] == "plain text result";
}


# ---------------------------------------------------------------------------
# 3. content_preview keeps stream-event "result is a string" contract
# ---------------------------------------------------------------------------
test "content_preview returns text portion, marks images" {
    content = [
        Text(text="PASS — page rendered"),
        Image(url="data:image/png;base64,iVBORw0KGgo_LONG_BASE64_BLOB")
    ];
    preview = content_preview(content, 500);
    assert isinstance(preview, str);
    assert "PASS — page rendered" in preview;
    assert "[image]" in preview;
    # The base64 must NOT leak into the preview.
    assert "iVBORw0KGgo" not in preview;
}

test "content_preview truncates string content" {
    long_str = "x" * 1000;
    assert content_preview(long_str, 100) == "x" * 100;
}
