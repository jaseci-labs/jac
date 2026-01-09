"""Separating Defs and Decls in a single File"""

# Declaration
def my_print(messag: str) -> str;

# Definition
impl my_print(message: str) -> str {
    output = f"from me: {message}";
    print("from me: {message}");
    return output;
}

# Declaration
obj MyPrinter {
    def my_print(messag: str) -> str;  # method declaration

}

impl MyPrinter.my_print(messag: str) -> str
# Definition
{
    output = f"from me: {message}";
    print("from me: {message}");
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
        output = f"from me: {message}";
        print("from me: {message}");
        return output;
    }
}
