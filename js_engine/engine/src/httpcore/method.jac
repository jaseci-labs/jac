"""HTTP method enum and helpers for js_engine.

Bun reference: `bun/src/http/Method.zig`
"""

enum:pub HTTPMethod {
    GET = 0,
    POST = 1,
    PUT = 2,
    DELETE = 3,
    HEAD = 4,
    OPTIONS = 5,
    PATCH = 6,
    CONNECT = 7,
    TRACE = 8
}

def:pub method_from_str(s: str) -> HTTPMethod {
    name: str = s.strip().upper();
    if name == "GET" {
        return HTTPMethod.GET;
    }
    if name == "POST" {
        return HTTPMethod.POST;
    }
    if name == "PUT" {
        return HTTPMethod.PUT;
    }
    if name == "DELETE" {
        return HTTPMethod.DELETE;
    }
    if name == "HEAD" {
        return HTTPMethod.HEAD;
    }
    if name == "OPTIONS" {
        return HTTPMethod.OPTIONS;
    }
    if name == "PATCH" {
        return HTTPMethod.PATCH;
    }
    if name == "CONNECT" {
        return HTTPMethod.CONNECT;
    }
    if name == "TRACE" {
        return HTTPMethod.TRACE;
    }
    return HTTPMethod.GET;
}

def:pub method_to_str(m: HTTPMethod) -> str {
    if m == HTTPMethod.GET {
        return "GET";
    }
    if m == HTTPMethod.POST {
        return "POST";
    }
    if m == HTTPMethod.PUT {
        return "PUT";
    }
    if m == HTTPMethod.DELETE {
        return "DELETE";
    }
    if m == HTTPMethod.HEAD {
        return "HEAD";
    }
    if m == HTTPMethod.OPTIONS {
        return "OPTIONS";
    }
    if m == HTTPMethod.PATCH {
        return "PATCH";
    }
    if m == HTTPMethod.CONNECT {
        return "CONNECT";
    }
    return "TRACE";
}

def:pub method_has_body(m: HTTPMethod) -> bool {
    if m == HTTPMethod.GET {
        return False;
    }
    if m == HTTPMethod.HEAD {
        return False;
    }
    return True;
}
