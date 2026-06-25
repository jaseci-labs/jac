"""Bundled native `urllib.request` cross-backend equivalence fixture
(issues #6404 / #6940, Phase 3: transport + HTTP over libcurl).

The owning `test_urllib_equivalence` suite stands up a loopback HTTP server,
publishes its port in `JAC_URLLIB_TEST_PORT`, and pins two `urlopen`
implementations congruent -- for a direct GET and for a redirect both follow:

  - sv (py): CPython's real `urllib.request.urlopen` (via `import urllib.request`),
    returning a rich dict (status/body/length/content-type) that also serves as a
    hard sv-side guard.
  - na: the bundled `na_stdlib/urllib/request.na.jac` Mechanism-F module (libcurl
    floor + pure-Jac surface), via `import from urllib.request { urlopen }`. The
    native functions return plain `int`s (status, body length) -- the scalar
    fields the native pathway marshals across a module boundary reliably today --
    which the suite compares to the py reference. (Cross-module access to
    `bytes`/header object fields, and boxing multiple object-derived values into a
    `dict[str, any]`, are documented native follow-ups; see the bundled module.)

Unlike a pure-Jac bundled module (e.g. `os.path`), this one binds libcurl through
the native FFI, so it cannot run under the sv/Python interpreter -- hence the two
backends import their `urlopen` from distinct places rather than sharing one
binding. The base URL is built inline in each function (not via a shared helper)
so the native functions stay fully native -- a plain `def` helper would be a
Python symbol native code could only reach through the JIT interop bridge.
ES/JS opts out (no libcurl floor).
"""

import os;
import urllib.request;


def urllib_py -> dict {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT");
    resp = urllib.request.urlopen(base + "/hello");
    body = resp.read();
    return {
        "status": resp.status,
        "body": body.decode(),
        "body_length": len(body),
        "content_type": resp.getheader("Content-Type"),

    };
}


def urllib_redirect_py -> dict {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT");
    resp = urllib.request.urlopen(base + "/redirect");
    body = resp.read();
    return {"status": resp.status, "body": body.decode(), "body_length": len(body),};
}


na {
    import from urllib.request { urlopen }

    def urlopen_status_na -> int {
        base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT");
        resp = urlopen(base + "/hello");
        return resp.status;
    }

    def urlopen_body_length_na -> int {
        base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT");
        resp = urlopen(base + "/hello");
        return resp.body_length;
    }

    def urlopen_redirect_status_na -> int {
        base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT");
        resp = urlopen(base + "/redirect");
        return resp.status;
    }

    def urlopen_redirect_body_length_na -> int {
        base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT");
        resp = urlopen(base + "/redirect");
        return resp.body_length;
    }
}
