"""Simple Python test file for jac run command."""

from tests.language.fixtures import py_namedexpr

print("Hello from Python!")
print("This is a test Python file.")


def main() -> int:
    """Main function to demonstrate execution."""
    result = 42
    print(f"Result: {result}")
    return result


if __name__ == "__main__":
    main()
    print("Python execution completed.")

py_namedexpr.walrus_example()
