"""Guaranteed tail calls: self, mutual and method recursion, and `tail` as a name."""

def is_even(n: int) -> bool {
    if n == 0 {
        return True;
    }
    return tail is_odd(n - 1);
}

def is_odd(n: int) -> bool {
    if n == 0 {
        return False;
    }
    return tail is_even(n - 1);
}

def sum_to(n: int, acc: int) -> int {
    if n == 0 {
        return acc;
    }
    return tail sum_to(n - 1, acc + n);
}

obj Walker {
    has step: int = 2;

    def advance(n: int, acc: int) -> int {
        if n <= 0 {
            return acc;
        }
        return tail self.advance(n - self.step, acc + 1);
    }
}

def tail_is_a_name(tail: int) -> int {
    return tail;
}

with entry {
    print(is_even(40), is_odd(40), is_even(17), is_odd(17));
    print(sum_to(50, 0));
    print(Walker().advance(21, 0));
    print(tail_is_a_name(5));
}
