import re;

glob a: int = 5;

with entry {
    arguments = {
        x: None
        for x in re.findall(
            r'\{([A-Za-z0-9_]+)\}', "Apple {apple} pineapple {pineapple}"
        )
    };
    a: int = 5;
    if False {
        with open(f"Apple{apple}.txt") as f {
            # Fix syntax highlighting
            print(f.read());
        }
    }
    print(arguments);
    print("""This is a long
        line of code.""");
}

with entry {
    a = {"a": "apple", "b": "ball", "c": "cat"};
    y = {** a, "d": "dog", "e": "elephant"};
    print(y);
}
# Use before def error would be nice
