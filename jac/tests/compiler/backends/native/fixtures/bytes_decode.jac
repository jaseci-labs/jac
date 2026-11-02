"""bytes.decode honours its encoding and errors arguments natively.

Every result is printed through `encode("utf-8", "surrogatepass")`, which
spells out the exact code points (lone surrogates included) as bytes.
"""

def spelled(text: &str) -> bytes {
    return text.encode("utf-8", "surrogatepass");
}

def decode_with(data: &bytes, encoding: &str, errors: &str) -> str {
    try {
        return str(spelled(data.decode(encoding, errors)));
    } except UnicodeDecodeError as e {
        return f"UnicodeDecodeError: {e}";
    } except LookupError as e {
        return f"LookupError: {e}";
    } except TypeError as e {
        return f"TypeError: {e}";
    }
}

def literal_forms(data: &bytes) -> list[str] {
    out: list[str] = [];
    out.append(str(spelled(data.decode("utf-8", "replace"))));
    out.append(str(spelled(data.decode("utf-8", errors="replace"))));
    out.append(str(spelled(data.decode(encoding="utf-8", errors="ignore"))));
    out.append(str(spelled(data.decode(errors="backslashreplace"))));
    out.append(str(spelled(data.decode("utf-8", "surrogateescape"))));
    out.append(str(spelled(data.decode("latin-1"))));
    out.append(str(spelled(data.decode(encoding="iso-8859-1", errors="strict"))));
    out.append(str(spelled(data.decode("ascii", "replace"))));
    out.append(str(spelled(data.decode("US-ASCII", errors="surrogateescape"))));
    try {
        out.append(str(spelled(data.decode())));
    } except UnicodeDecodeError as e {
        out.append(f"strict: {e}");
    }
    try {
        out.append(str(spelled(data.decode("ascii"))));
    } except ValueError as e {
        out.append(f"ascii: {e}");
    }
    try {
        out.append(str(spelled(data.decode("utf-8", "surrogatepass"))));
    } except UnicodeError as e {
        out.append(f"surrogatepass: {e}");
    }
    try {
        out.append(str(spelled(data.decode("utf-8", errors="no-such-handler"))));
    } except LookupError as e {
        out.append(f"handler: {e}");
    }
    try {
        out.append(str(spelled(data.decode("utf-8", "xmlcharrefreplace"))));
    } except TypeError as e {
        out.append(f"encode-only: {e}");
    }
    return out;
}

def unknown_literal_codec(data: &bytes) -> str {
    try {
        return data.decode("no-such-codec");
    } except LookupError as e {
        return f"{e}";
    }
}

def sweep {
    samples = [
        b"",
        b"plain ascii",
        b"caf\xc3\xa9 \xe2\x82\xac \xf0\x9f\x98\x80",
        b"ab\xffcd",
        b"\x80\xff",
        b"\xc0\xaf",
        b"\xe2",
        b"\xe2\x82",
        b"\xe2\x28\xa1",
        b"\xe0\x80\x80",
        b"\xe0\xa0\x80",
        b"\xed\xa0\x80x",
        b"\xed\xb3\xbf",
        b"\xef\xbf\xbf",
        b"\xf0\x9f\x98",
        b"\xf0\x90\x80\x80",
        b"\xf4\x8f\xbf\xbf",
        b"\xf4\x90\x80\x80",
        b"\xf5\x80",
        b"\xf0\x9f\x98\x80x\xf0\x9f",
        b"ab\xff\xfe"
    ];
    encodings = [
        "utf-8",
        "UTF8",
        "u8",
        " utf--8 ",
        "utf.8",
        "latin-1",
        "ISO-8859-1",
        "l1",
        "ascii",
        "us-ascii",
        "ANSI_X3.4-1968",
        "ansi.x3.4.1968",
        "no-such-codec"
    ];
    handlers = [
        "strict",
        "ignore",
        "replace",
        "backslashreplace",
        "surrogateescape",
        "surrogatepass",
        "namereplace",
        "Replace"
    ];
    for data in samples {
        print(literal_forms(data));
        for encoding in encodings {
            for errors in handlers {
                print(encoding, errors, decode_with(data, encoding, errors));
            }
        }
    }
}

with entry {
    sweep();
    print(unknown_literal_codec(b"abc"));
}
