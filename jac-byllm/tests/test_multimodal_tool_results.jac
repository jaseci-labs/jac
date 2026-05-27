"""Tests for multimodal tool result support (byllm/types.jac + message.impl.jac).

One test per helper added for the fix.  Each proves the *new* behavior
(Media survives the path); back-compat for string-returning tools is
covered by the existing test_parallel.jac suite.
"""

import from byllm.types {
    ToolCallResultMsg,
    Text,
    Image,
    normalize_tool_result,
    content_preview
}


test "normalize_tool_result preserves list[Media]" {
    items = [Text(text="ok"), Image(url="https://example.com/x.png")];
    out = normalize_tool_result(items);
    assert out == items;
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
