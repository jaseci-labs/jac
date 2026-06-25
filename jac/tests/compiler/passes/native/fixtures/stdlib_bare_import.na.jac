"""Flat `import <bundled na_stdlib module>;` + `module.func(...)` member calls
(issue #6964). Before the fix, only `import from json { dumps }` reached a
bundled na_stdlib module; the flat `import json;` form was rejected by the
native capability gate and `json.dumps(...)` never lowered. This pins the
ergonomic Python-shaped form across the function-style bundled modules
(json / zlib / hashlib), routed to the same linked free functions the
import-from form uses.
"""

import json;
import zlib;
import hashlib;


def json_dumps_via_namespace() -> str {
    d: dict[str, any] = {"name": "llvm", "n": 3};
    return json.dumps(d);
}

def json_loads_field() -> str {
    back: any = json.loads("{\"name\": \"llvm\", \"libs\": [\"a\", \"b\"]}");
    nm: str = back["name"];
    return nm;
}

def json_loads_arr_len() -> int {
    back: any = json.loads("{\"name\": \"llvm\", \"libs\": [\"a\", \"b\"]}");
    libs: any = back["libs"];
    return len(libs);
}

def zlib_roundtrip_len() -> int {
    src: bytes = b"hello native hello native";
    c: bytes = zlib.compress(src);
    d: bytes = zlib.decompress(c);
    return len(d);
}

def zlib_crc() -> int {
    return zlib.crc32(b"hello native hello native");
}

def hashlib_hello() -> str {
    h = hashlib.sha256();
    h.update(b"hello");
    return h.hexdigest();
}
