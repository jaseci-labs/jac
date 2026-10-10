"""Public functions an importer never imports by name, and reuses the names of."""
def burst(amount: int) -> int {
    return amount + 1;
}

def shared(amount: int) -> int {
    return amount + 2;
}

def spark(amount: int) -> int {
    return amount + 3;
}

def flare(amount: int) -> int {
    return amount + 4;
}

def ember(amount: int) -> int {
    return amount + 5;
}

def other(amount: int) -> int {
    return burst(amount) * shared(amount) + spark(amount) + flare(amount);
}

def named(amount: int) -> int {
    return amount * 10;
}
