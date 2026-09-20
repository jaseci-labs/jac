import operator;
import sqlite3;

def literal_arguments -> bool {
    connection = sqlite3.connect(":memory:");
    row = connection.execute(
        "select ?, ?, ?", (17, "hé\x00tail", b"\x00\xff")
    ).fetchone();
    connection.close();
    shared = operator.add([1, 2], [3]);
    nested = operator.or_({"items": [shared, {"value": 42}]}, {})["items"];
    return row[0] == 17
        and row[1] == "hé\x00tail"
        and row[2] == b"\x00\xff"
        and nested[0] is shared
        and nested[1]["value"] == 42
        and operator.contains({1, 2, 3}, 2);
}

def builtin_arguments -> bool {
    value = operator.call(int, "123");
    return isinstance(value, int)
        and value == 123
        and isinstance(operator.add([1], [2]), list);
}

def slice_arguments -> bool {
    values = operator.add([1, 2], [3, 4]);
    reverse = values[::-1];
    middle = values[1:3];
    mapping = operator.or_({(1, 2): "pair"}, {});
    return len(reverse) == 4
        and reverse[0] == 4
        and reverse[3] == 1
        and len(middle) == 2
        and middle[0] == 2
        and middle[1] == 3
        and len(values[3:1]) == 0
        and mapping[1, 2] == "pair";
}

def invalid_slice -> int {
    values = operator.add([1], [2]);
    return len(values[::0]);
}
