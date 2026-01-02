"""Test overloaded __new__ methods for built-in types."""

with entry {
    # Test range() with different overloads
    # range(stop) - single argument overload
    for i in range(5) {
        print(i);
    }

    # range(start, stop) - two argument overload
    for i in range(0, 10) {
        print(i);
    }

    # range(start, stop, step) - three argument overload
    for i in range(0, 20, 2) {
        print(i);
    }

    # Test int() with different overloads
    # int() - no arguments
    x: int = int();

    # int(x) - single argument
    y: int = int("42");

    # int(x, base) - two arguments
    z: int = int("2a", 16);

    # Test str() with different overloads
    # str() - no arguments
    s1: str = str();

    # str(object) - single argument
    s2: str = str(123);

    # str(object, encoding) - two arguments (for bytes)
    s3: str = str(b"hello", "utf-8");

    # Test bool() with different overloads
    # bool(x) - single argument
    b1: bool = bool(1);
    b2: bool = bool(0);
    b3: bool = bool("text");

    # Test float() with different overloads
    # float(x) - single argument
    f1: float = float(3.14);
    f2: float = float("2.718");
}
