import os;

def whitespace_checks -> bool {
    fields: dict[str, str] = {"origin": " 12\t-34\n56 "};
    parts = fields.get("origin", "0 0 0").split();
    assert parts == ["12", "-34", "56"];
    assert "".split() == [];
    assert " \t\r\n\v\f".split() == [];
    assert "a\x00b c".split() == ["a\x00b", "c"];
    assert "\u0085a\u00a0b\u1680c\u2003d\u2028e\u202ff\u205fg\u3000".split()
        == ["a", "b", "c", "d", "e", "f", "g"];
    assert "  a b  ".split(None, 0) == ["a b  "];
    assert "  a b  ".split(None, 1) == ["a", "b  "];
    assert " a b ".split(None, -2) == ["a", "b"];
    assert "  a b  ".rsplit(None, 0) == ["  a b"];
    assert "  a b  ".rsplit(None, 1) == ["  a", "b"];
    assert "\u3000a\u00a0b\u2003".rsplit() == ["a", "b"];
    return True;
}

def byte_write(value: int) -> int {
    data = bytearray(b"\x00\x00");
    data[0] = value;
    data[-1] = value;
    return int(data[0]) + int(data[1]);
}

def byte_bad(value: int) -> bool {
    data = bytearray(b"\x00");
    try {
        data[0] = value;
    } except ValueError {
        return data[0] == 0;
    }
    return False;
}

def directory_checks(path: str) -> bool {
    names = sorted(os.listdir(path));
    return names == [".hidden", "PAK0.PAK", "subdir", "é.txt"];
}

def directory_error(path: str) -> int {
    try {
        os.listdir(path);
    } except FileNotFoundError {
        return 1;
    } except NotADirectoryError {
        return 2;
    } except ValueError {
        return 3;
    }
    return 0;
}

def directory_default -> bool {
    return len(os.listdir()) > 0;
}
