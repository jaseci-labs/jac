"""Gap #40: WhileStmt condition not validated.

No exit_while_stmt handler exists. The condition expression and all
sub-expressions within it are never type-evaluated by the checker.
This means type errors in while conditions are silently missed.

Expected errors:
  1. Calling nonexistent method in while condition
  2. Using wrong argument type in condition function call
  3. Binary operation with incompatible types in condition
  4. Chained conditions with type errors
"""

obj Counter {
    has count: int = 0;

    def increment -> int {
        self.count += 1;
        return self.count;
    }

    def is_done -> bool {
        return self.count >= 10;
    }
}

def check_int(x: int) -> bool {
    return x > 0;
}

with entry {
    c = Counter();

    # Case 1: Calling nonexistent method
    while c.nonexistent_method() {  # Error: no such method on Counter
        break;
    }

    # Case 2: Using wrong argument type in condition function call
    while check_int("not_a_number") {  # Error: str -> int param
        break;
    }

    # Case 3: Binary operation with incompatible types in condition
    name: str = "hello";
    while name > 5 {                  # Error: str > int comparison
        break;
    }

    # Case 4: Chained conditions with type errors
    x: int = 10;
    while x > 0 and check_int("bad") {  # Error: str -> int in nested call
        x -= 1;
    }

    # --- Cases that SHOULD be valid ---
    while c.count < 10 {               # Ok
        c.increment();
    }

    while not c.is_done() {            # Ok
        c.increment();
    }

    while True {                        # Ok
        break;
    }
}
