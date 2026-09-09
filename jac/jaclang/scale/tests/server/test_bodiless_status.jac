"""A 304 (or 204) answer carries no body, and no framing that implies one.

RFC 9110 forbids a message body on 1xx/204/304, and a browser enforces it:
Chrome fails a request with ERR_INVALID_HTTP_RESPONSE when a 304 arrives with
`Transfer-Encoding: chunked`. The gateway hit exactly that proxying a vite dev
server, whose every module response carries an ETag: the browser revalidated,
vite answered 304, and the gateway re-framed it as a chunked stream, so the
page could not load a single module.
"""

import http.client;
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.datatypes { Response, StreamingResponse }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.server.serving.server { ServingServer }


def _serve(app: ServingApp) -> ServingServer {
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    server.serve_background();
    assert server.bound_port , "test server did not bind";
    return server;
}


def _raw_get(port: int, path: str) -> tuple {
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=10);
    conn.request("GET", path);
    resp = conn.getresponse();
    body = resp.read();
    headers = {k.lower(): v for (k, v) in resp.getheaders()};
    conn.close();
    return (resp.status, headers, body);
}


test "a streamed 304 is framed as a bodiless response" {
    async def empty_stream -> any {
        if False {
            yield b"";
        }
    }

    def not_modified -> Response {
        return StreamingResponse(
            empty_stream(), status_code=304, headers={"ETag": 'W/"abc"'}
        );
    }
    app = ServingApp();
    app.add_endpoint(
        JEndPoint(method=HTTPMethod.GET, path="/mod.js", callback=not_modified)
    );
    server = _serve(app);
    try {
        (status, headers, body) = _raw_get(server.bound_port, "/mod.js");
        assert status == 304;
        assert "transfer-encoding" not in headers , (
            f"a 304 must not be chunked - a browser rejects the response "
            f"outright; got headers {headers}"
        );
        assert body == b"";
        assert headers.get("etag") == 'W/"abc"' , (
            "the validators the upstream sent still have to reach the client"
        );
    } finally {
        server.request_stop();
    }
}


test "a 204 is framed as a bodiless response too" {
    def no_content -> Response {
        return Response(content="", status_code=204);
    }
    app = ServingApp();
    app.add_endpoint(
        JEndPoint(method=HTTPMethod.GET, path="/gone", callback=no_content)
    );
    server = _serve(app);
    try {
        (status, headers, body) = _raw_get(server.bound_port, "/gone");
        assert status == 204;
        assert "transfer-encoding" not in headers;
        assert body == b"";
    } finally {
        server.request_stop();
    }
}


test "an ordinary streamed response is still chunked" {
    async def chunks -> any {
        yield b"one";
        yield b"two";
    }

    def streamed -> Response {
        return StreamingResponse(chunks(), status_code=200);
    }
    app = ServingApp();
    app.add_endpoint(
        JEndPoint(method=HTTPMethod.GET, path="/stream", callback=streamed)
    );
    server = _serve(app);
    try {
        (status, headers, body) = _raw_get(server.bound_port, "/stream");
        assert status == 200;
        assert headers.get("transfer-encoding") == "chunked";
        assert body == b"onetwo";
    } finally {
        server.request_stop();
    }
}
