"""Module with functions and walkers to be imported for serve testing."""

# An importable function
def multiply_numbers(a: int, b: int) -> int {
    return a * b;
}

# Another importable function
def format_message(prefix: str, message: str) -> str {
    return f"{prefix}: {message}";
}

# An importable node
node ImportedItem {
    has name: str;
    has value: int = 0;
}

# An importable walker
walker ImportedWalker {
    has item_name: str;

    can create_item with `root entry {
        item = here ++> ImportedItem(name=self.item_name);
        created = item[0] if item else None;
        if created {
            report created;
        }
    }
}

# Another importable walker
walker ImportedCounter {
    has count: int = 0;

    can count_items with `root entry {
        visit [-->];
    }

    can increment with ImportedItem entry {
        self.count += 1;
    }
}
