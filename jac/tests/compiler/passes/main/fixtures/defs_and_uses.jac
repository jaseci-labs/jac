"""Separating Defs and Decls in a single File"""

# Declarations
def my_print(messag: str) -> str;

# Definitions
impl my_print(message: str) -> str {
    output = f"from me: {message}";
    print("from me: {message}");
    return output;
}

# Declaration
obj MyPrinter {
    has thing_to_print: str;

    def my_print(messag: str) -> str;  # method declaration

}

# Definition
impl MyPrinter.my_print(message: str) -> str {
    y = ".".join([i for i in range(10)]);
    output = f"from me: {message} {y}";
    print(f"from me: {output}");
    return output;
}

# Decl/Def Combined
def your_print(messag: str) -> str {
    output = f"from me: {message}";
    print("from me: {message}");
    return output;
}

# Decl/Def Combined
obj YourPrinter {
    def your_print(messag: str) -> str {
        output = f"from me: {messag}";
        print("from me: {message}");
        return output;
    }
}
