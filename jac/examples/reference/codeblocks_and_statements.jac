# Codeblocks and statements - Basic code organization

# Expression statement
with entry {
    print("Welcome to the world of Jaseci!");
}

# Function definition inside code block
def add(x: int, y: int) -> int {
    return (x + y);
}

# Function call
with entry {
    print(add(10, 89));
}

# Various statement types can appear in code blocks
glob x = 42;  # Assignment statement

with entry {
    if x > 0 {  # If statement

        print("Positive");
    }
}
