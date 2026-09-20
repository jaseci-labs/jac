"""Uuid: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

import uuid;


def uuid_py -> dict[any, any] {
    u = uuid.uuid4();
    s = str(u);
    var = s[19];
    return {
        "hex_len": len(u.hex),
        "str_len": len(s),
        "version": u.version,
        "dash8": 1 if s[8] == "-" else 0,
        "dash13": 1 if s[13] == "-" else 0,
        "dash18": 1 if s[18] == "-" else 0,
        "dash23": 1 if s[23] == "-" else 0,
        "ver4": 1 if s[14] == "4" else 0,
        "variant_ok": 1
            if (var == "8" or var == "9" or var == "a" or var == "b")
            else 0,
        "two_differ": 1 if uuid.uuid4().hex != uuid.uuid4().hex else 0,

    };
}


def uuid_cl -> dict[any, any] {
    return {};
}


def uuid_na -> dict[str, any] {
    u = uuid.uuid4();
    s = str(u);
    var = s[19];
    return {
        "hex_len": len(u.hex),
        "str_len": len(s),
        "version": u.version,
        "dash8": 1 if s[8] == "-" else 0,
        "dash13": 1 if s[13] == "-" else 0,
        "dash18": 1 if s[18] == "-" else 0,
        "dash23": 1 if s[23] == "-" else 0,
        "ver4": 1 if s[14] == "4" else 0,
        "variant_ok": 1
            if (var == "8" or var == "9" or var == "a" or var == "b")
            else 0,
        "two_differ": 1 if uuid.uuid4().hex != uuid.uuid4().hex else 0,

    };
}
