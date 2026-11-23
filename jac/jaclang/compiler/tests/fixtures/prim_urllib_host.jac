"""Server reference for the native HTTP transport equivalence tests."""

import os;
import urllib.request;


def urllib_py -> dict[str, any] {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    resp = urllib.request.urlopen(base + "/hello");
    body = resp.read();
    return {
        "status": resp.status,
        "body": body.decode(),
        "body_length": len(body),
        "content_type": resp.getheader("Content-Type"),

    };
}


def urllib_redirect_py -> dict[str, any] {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    resp = urllib.request.urlopen(base + "/redirect");
    body = resp.read();
    return {"status": resp.status, "body": body.decode(), "body_length": len(body),};
}

def urllib_request_data_py -> dict[str, any] {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    req = urllib.request.Request(base + "/echo", method="POST");
    resp = urllib.request.urlopen(req, data=b"payload");
    body = resp.read();
    return {"body": body.decode(),};
}
