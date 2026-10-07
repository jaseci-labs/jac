"""Tests for Phase 6.3 — HTTP headers, methods, and MIME types."""

import from engine.src.httpcore.headers {
    Headers,
    HEADERS_GUARD_IMMUTABLE,
    headers_create,
    headers_append,
    headers_set,
    headers_get,
    headers_has,
    headers_delete,
    headers_entries,
    headers_from_dict,
    headers_to_raw
}
import from engine.src.httpcore.method {
    HTTPMethod,
    method_from_str,
    method_to_str,
    method_has_body
}
import from engine.src.httpcore.mime_type {
    mime_from_extension,
    mime_from_path,
    mime_is_text,
    mime_charset
}

glob _ok: int = 0,
     _err: int = 0;

def check(label: str, ok: bool) {
    if ok {
        _ok = _ok + 1;
        print("OK  " + label);
    } else {
        _err = _err + 1;
        print("FAIL " + label);
    }
}

with entry {
    print("=== Phase 6.3: HTTP Headers / Methods / MIME Types ===");

    h1: Headers = headers_create();
    check("1 headers_create default guard", h1.guard == "none");
    check("2 headers_create default entries empty", len(h1.entries) == 0);

    headers_append(h1, "Content-Type", "text/plain");
    headers_append(h1, "X-Test", "1");
    check("3 headers_append count", len(h1.entries) == 2);
    check(
        "4 headers_get case-insensitive",
        headers_get(h1, "content-type") == "text/plain"
    );
    check("5 headers_has true", headers_has(h1, "X-TEST"));

    headers_set(h1, "content-type", "text/html");
    check("6 headers_set replaces existing", len(h1.entries) == 2);
    check("7 headers_set value", headers_get(h1, "Content-Type") == "text/html");

    raw1: str = headers_to_raw(h1);
    check(
        "8 headers_to_raw contains content-type",
        raw1.find("content-type: text/html") >= 0
    );
    check("9 headers_to_raw contains x-test", raw1.find("X-Test: 1") >= 0);

    h2: Headers = headers_from_dict({"content-type": "text/html", "accept": "*/*"});
    check(
        "10 headers_from_dict get content-type",
        headers_get(h2, "Content-Type") == "text/html"
    );
    check("11 headers_entries count", len(headers_entries(h2)) == 2);

    headers_delete(h2, "ACCEPT");
    check("12 headers_delete removed accept", not headers_has(h2, "accept"));

    h3: Headers = Headers(guard=HEADERS_GUARD_IMMUTABLE);
    headers_append(h3, "X-Nope", "1");
    headers_set(h3, "Content-Type", "application/json");
    headers_delete(h3, "Content-Type");
    check("13 immutable guard blocks mutation", len(h3.entries) == 0);

    m_get: HTTPMethod = method_from_str("get");
    m_post: HTTPMethod = method_from_str(" POST ");
    check("14 method_from_str GET", m_get == HTTPMethod.GET);
    check("15 method_from_str POST", m_post == HTTPMethod.POST);
    check("16 method_to_str PATCH", method_to_str(HTTPMethod.PATCH) == "PATCH");
    check("17 method_has_body GET false", not method_has_body(HTTPMethod.GET));
    check("18 method_has_body HEAD false", not method_has_body(HTTPMethod.HEAD));
    check("19 method_has_body POST true", method_has_body(HTTPMethod.POST));

    check(
        "20 mime_from_extension .ts",
        mime_from_extension(".ts") == "application/typescript"
    );
    check(
        "21 mime_from_extension no-dot",
        mime_from_extension("json") == "application/json"
    );
    check(
        "22 mime_from_path index.html",
        mime_from_path("/srv/www/index.html") == "text/html"
    );
    check(
        "23 mime_from_path fallback",
        mime_from_path("README") == "application/octet-stream"
    );
    check("24 mime_is_text html", mime_is_text("text/html; charset=utf-8"));
    check("25 mime_is_text json", mime_is_text("application/json"));
    check("26 mime_is_text png false", not mime_is_text("image/png"));
    check("27 mime_charset utf-8", mime_charset("text/html; charset=utf-8") == "utf-8");
    check("28 mime_charset absent empty", mime_charset("application/json") == "");

    print(
        "HTTP core tests: "
            + _http_int_to_str(_ok)
            + " passed, "
            + _http_int_to_str(_err)
            + " failed"
    );
    if _err == 0 {
        print("OK all http core tests passed");
    }
}

def _http_int_to_str(n: int) -> str {
    if n == 0 {
        return "0";
    }
    out: str = "";
    rem: int = n;
    while rem > 0 {
        digit: int = rem % 10;
        out = chr(48 + digit) + out;
        rem = rem // 10;
    }
    return out;
}
