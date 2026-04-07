"""Screenshot service — calls jaseci-builder-tools MCP server to capture URL screenshots."""

import httpx;
import os;

glob MCP_SERVER_URL: str = os.environ.get("JAC_MCP_SERVER_URL", "https://mcp.jaseci.org");

"""Capture a screenshot of a URL via the MCP take_screenshot tool.

Returns dict with 'success', 'image' (base64), 'mime_type' on success,
or 'success' False + 'error' on failure.
"""
def take_screenshot(
    url: str,
    viewport: str = "desktop",
    format: str = "jpeg",
    full_page: bool = False,
    delay: int = 0
) -> dict {
    print(f"[screenshot-service] take_screenshot called: url={url}, mcp={MCP_SERVER_URL}, delay={delay}");
    try {
        with httpx.Client(timeout=60.0) as client {
            print(f"[screenshot-service] Sending POST to {MCP_SERVER_URL}/mcp ...");
            resp = client.post(
                f"{MCP_SERVER_URL}/mcp",
                json={
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "tools/call",
                    "params": {
                        "name": "take_screenshot",
                        "arguments": {
                            "url": url,
                            "viewport": viewport,
                            "format": format,
                            "full_page": full_page,
                            "delay": delay
                        }
                    }
                }
            );
            print(f"[screenshot-service] Response status: {resp.status_code}");
            data = resp.json();
            result = data.get("result", {});
            if result.get("isError") {
                error_text = result.get("content", [{}])[0].get("text", "Unknown MCP error");
                print(f"[screenshot-service] MCP error: {error_text}");
                return {"success": False, "error": error_text};
            }
            content = result.get("content", [{}])[0];
            if content.get("type") == "image" {
                print(f"[screenshot-service] Success! Got image, mime={content.get('mimeType')}");
                return {
                    "success": True,
                    "image": content["data"],
                    "mime_type": content["mimeType"]
                };
            }
            err_msg = content.get("text", "Unexpected response type");
            print(f"[screenshot-service] Unexpected response: {err_msg}");
            return {"success": False, "error": err_msg};
        }
    } except Exception as e {
        print(f"[screenshot-service] Exception: {str(e)}");
        return {"success": False, "error": str(e)};
    }
}
