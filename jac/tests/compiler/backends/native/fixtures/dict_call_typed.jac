"""Dicts made by calling `dict(...)`, read as the typed dicts they are.

What comes out of the copy is used as its own type: a string's method on a
value read by key or met in a loop. Each needs the copy's value type.
"""

def cleaned(fields: dict[str, str]) -> str {
    copy = dict(fields);
    return copy.get("angle", "0").strip();
}

def turned(items: list[dict[str, str]], yaw: float) -> list[str] {
    made: list[str] = [];
    for item in items {
        fields = dict(item);
        try {
            faced = float(fields.get("angle", "0").strip());
        } except ValueError {
            faced = 0.0;
        }
        fields["angle"] = str(int((faced + yaw) % 360.0));
        made.append(
            fields["angle"] + "/" + str(len(fields)) + "/" + item.get("angle", "-")
        );
    }
    return made;
}

def longest(fields: dict[str, str]) -> int {
    copy = dict(fields);
    most = 0;
    for (name, value) in copy.items() {
        most = max(most, len(name) + len(value.strip()));
    }
    return most;
}

with entry {
    print(cleaned({"angle": " 90 "}) + "|", cleaned({}) + "|");
    print(turned([{"angle": " 300 "}, {"angle": "x"}, {}], 90.0));
    print(longest({"angle": " 90 ", "classname": "light"}), longest({}));
}
