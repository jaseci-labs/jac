# Lambda with parenthesized typed parameters
with entry {
    add = lambda (x: int, y: int) -> int { x + y; };
    print(add(2, 3));
}
