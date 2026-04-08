"""Production test: Passing Unknown values as typed function arguments.

When an Unknown value is passed to a function with typed parameters,
the checker should either error or warn — not silently accept it.
This is critical because it can mask bugs where wrong types flow
through the program undetected.

Unknown source: magic method resolution on Any-typed values fails,
producing genuine Unknown (e.g. Any + 1 -> Unknown).

Expected errors: 3
  1. process_int(unknown_val)      — Unknown passed to int param
  2. process_str(unknown_val)      — Unknown passed to str param
  3. process_list(unknown_val)     — Unknown passed to list[int] param
"""

def process_int(x: int) -> int {
    return x + 1;
}

def process_str(s: str) -> str {
    return s.upper();
}

def process_list(lst: list[int]) -> int {
    return sum(lst);
}

with entry {
    # Any + int -> Unknown (magic method __add__ unresolved on Any)
    items: list = [1, 2, 3];
    any_val = items.pop();
    unknown_val = any_val + 1;

    # Passing Unknown to typed parameters should not pass silently
    process_int(unknown_val);      # Error: Unknown -> int param
    process_str(unknown_val);      # Error: Unknown -> str param
    process_list(unknown_val);     # Error: Unknown -> list[int] param
}
