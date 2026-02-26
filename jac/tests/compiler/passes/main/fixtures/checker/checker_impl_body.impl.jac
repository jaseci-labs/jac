
# Function impl
impl process_data{
    x: int = 10;
    x = "wrong";  # <-- Error: Cannot assign str to int
}

# Archetype method impl
impl DataProcessor.process(val: int) -> int {
    result: int = val * 2;
    result = "wrong";  # <-- Error: Cannot assign str to int
    return result;
}

# Enum impl
impl Status{
    PENDING: int = "wrong",  # <-- Error: Cannot assign str to int
    ACTIVE = 2,
    DONE = 3
}
