"""ResponseBuilder implementations."""
import json;
import from http.server { BaseHTTPRequestHandler }
import from jaclang.project.config { get_config }
import from jaclang.runtimelib.server.response_builder { ResponseBuilder }
import from jaclang.runtimelib.server.types { JsonValue, StatusCode }

"""Send JSON response with CORS headers."""
impl ResponseBuilder.send_json(
    handler: BaseHTTPRequestHandler, status: StatusCode, data: dict[(str, JsonValue)]
) -> None {
    handler.send_response(status);
    handler.send_header('Content-Type', 'application/json');
    ResponseBuilder._add_cors_headers(handler);
    ResponseBuilder._add_custom_headers(handler);
    handler.end_headers();
    handler.wfile.write(json.dumps(data).encode());
}

"""Send HTML response with CORS headers."""
impl ResponseBuilder.send_html(
    handler: BaseHTTPRequestHandler, status: StatusCode, body: str
) -> None {
    payload = body.encode('utf-8');
    handler.send_response(status);
    handler.send_header('Content-Type', 'text/html; charset=utf-8');
    handler.send_header('Content-Length', str(len(payload)));
    ResponseBuilder._add_cors_headers(handler);
    ResponseBuilder._add_custom_headers(handler);
    handler.end_headers();
    handler.wfile.write(payload);
}

"""Send JavaScript response."""
impl ResponseBuilder.send_javascript(
    handler: BaseHTTPRequestHandler, code: str
) -> None {
    payload = code.encode('utf-8');
    handler.send_response(200);
    handler.send_header('Content-Type', 'application/javascript; charset=utf-8');
    handler.send_header('Content-Length', str(len(payload)));
    handler.send_header('Cache-Control', 'no-cache');
    ResponseBuilder._add_cors_headers(handler);
    ResponseBuilder._add_custom_headers(handler);
    handler.end_headers();
    handler.wfile.write(payload);
}

"""Send CSS response."""
impl ResponseBuilder.send_css(handler: BaseHTTPRequestHandler, css: str) -> None {
    payload = css.encode('utf-8');
    handler.send_response(200);
    handler.send_header('Content-Type', 'text/css; charset=utf-8');
    handler.send_header('Content-Length', str(len(payload)));
    handler.send_header('Cache-Control', 'no-cache');
    ResponseBuilder._add_cors_headers(handler);
    ResponseBuilder._add_custom_headers(handler);
    handler.end_headers();
    handler.wfile.write(payload);
}

"""Add CORS headers to response."""
impl ResponseBuilder._add_cors_headers(handler: BaseHTTPRequestHandler) -> None {
    handler.send_header('Access-Control-Allow-Origin', '*');
    handler.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    handler.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

"""Add security headers to response."""
impl ResponseBuilder._add_custom_headers(handler: BaseHTTPRequestHandler) -> None {
    config = get_config();
    if config
    and config.environments
    and "response" in config.environments
    and "headers" in config.environments["response"] {
        for (header_name, header_value) in config.environments["response"]["headers"].items() {
            handler.send_header(header_name, header_value);
        }
    }
}

