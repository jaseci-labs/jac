"""Test: has variables reassigned inside cl def nested abilities should not produce unused warnings."""

def:pub get_items -> list {
    return [1, 2, 3];
}

cl def app -> str {
    has items: list = [],
        count: int = 0;

    can with entry {
        items = get_items();
    }

    can with count entry {
        print("Count changed: ", count);
    }

    var = 5;

    def foo() {
        var = 3;
    }

    return str(items) + str(count) + str(var);
}
