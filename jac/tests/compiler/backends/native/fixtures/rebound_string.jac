"""A local reused for objects and strings keeps value-based string operations."""
obj Label {
    has value: str;
}

def:pub rebound_string -> int {
    values = [Label(value="na" + "me")];
    for key in values {
        assert key.value == "name";
    }
    for label in values {
        key = label.value;
        if key != "name" {
            return 1;
        }
        if key < "name" or key > "name" {
            return 2;
        }
        if not (key <= "name" and key >= "name") {
            return 3;
        }
        if "am" not in key {
            return 4;
        }
        if key + "!" != "name!" {
            return 5;
        }
    }
    return 0;
}
