"""Simple Python test file for jac run command."""

print("Hello from Python!")
print("This is a test Python file.")

def main():
    """Main function to demonstrate execution."""
    result = 42
    print(f"Result: {result}")
    return result

if __name__ == "__main__":
    main()
    print("Python execution completed.")


from jaclang.tests.fixtures import py_namedexpr

py_namedexpr.walrus_example()