import sqlite3;
import operator;

def text_value -> str {
    connection = sqlite3.connect(":memory:");
    value = connection.execute("select 'hé🙂' || char(0) || 'tail'").fetchone()[0];
    connection.close();
    return value;
}

def bytes_value -> bytes {
    connection = sqlite3.connect(":memory:");
    value = connection.execute("select x'0001ff7f'").fetchone()[0];
    connection.close();
    return value;
}

def roundtrip_bytes -> bytes {
    return operator.add(b"\x00\xff", b"\x7f\x01");
}

def roundtrip_text -> str {
    return operator.add("hé🙂\x00", "tail");
}

def buffers -> bool {
    return text_value() == "hé🙂\x00tail"
        and bytes_value() == b"\x00\x01\xff\x7f"
        and roundtrip_bytes() == b"\x00\xff\x7f\x01"
        and roundtrip_text() == "hé🙂\x00tail";
}

def invalid_text -> str {
    connection = sqlite3.connect(":memory:");
    value = connection.execute("select 17").fetchone()[0];
    connection.close();
    return value;
}

def invalid_bytes -> bytes {
    connection = sqlite3.connect(":memory:");
    value = connection.execute("select 'not bytes'").fetchone()[0];
    connection.close();
    return value;
}

def invalid(text: bool) -> bool {
    if text {
        return len(invalid_text()) != 0;
    }
    return len(invalid_bytes()) != 0;
}
