"""Module with functions and walkers to be imported for serve testing."""

# An importable function
def:protect multiply_numbers(a: int, b: int) -> int {
    return a * b;
}

# Another importable function
def:protect format_message(prefix: str, message: str) -> str {
    return f"{prefix}: {message}";
}

# An importable node
node ImportedItem {
    has name: str;
    has value: int = 0;
}

# An importable walker
walker:protect ImportedWalker {
    has item_name: str;

    can create_item with Root entry {
        item = here ++> ImportedItem(name=self.item_name);
        report item;
    }
}

# Another importable walker
walker:protect ImportedCounter {
    has count: int = 0;

    can count_items with Root entry {
        visit [-->];
    }

    can increment with ImportedItem entry {
        self.count += 1;
    }
}
