"""Test cases where assignments should NOT be extracted.

This fixture combines scenarios where extraction should not happen:
- Non-pure expressions (function calls, attribute access, indexing)
- Named entry block (should never be modified)
- File already uses glob (no with entry to extract from)
"""

def some_function()  -> int {
    return 42;
}

class Obj {
    has attr: int = 10;
}

glob obj = Obj();
glob arr = [1, 2, 3];

# === Section 1: Non-pure expressions (should stay in with entry) ===
with entry {
    # Function call - not pure
    result = some_function();

    # Attribute access - not pure (could trigger __getattr__)
    value = obj.attr;

    # Index access - not pure (could trigger __getitem__)
    item = arr[0];
}

# === Section 2: Named entry block (should never be modified) ===
with entry:__main__ {
    print("This is the main entry point");
    named_x = 5;
}

# === Section 3: Already uses glob (no changes needed) ===
glob existing_x = 5;
glob existing_y = "hello";
glob existing_z = [1, 2, 3];

def main() {
    print(existing_x, existing_y, existing_z);
}
