"""Build and send HTTP responses."""
import from http.server { BaseHTTPRequestHandler }
import from jaclang.runtimelib.server.types { JsonValue, StatusCode }

"""Build and send HTTP responses."""
obj ResponseBuilder {
    static def send_json(
        handler: BaseHTTPRequestHandler,
        status: StatusCode,
        data: dict[(str, JsonValue)]
    ) -> None;

    static def send_html(
        handler: BaseHTTPRequestHandler, status: StatusCode, body: str
    ) -> None;

    static def send_javascript(handler: BaseHTTPRequestHandler, code: str) -> None;
    static def send_css(handler: BaseHTTPRequestHandler, css: str) -> None;
    static def _add_cors_headers(handler: BaseHTTPRequestHandler) -> None;
    static def _add_custom_headers(handler: BaseHTTPRequestHandler) -> None;
}
