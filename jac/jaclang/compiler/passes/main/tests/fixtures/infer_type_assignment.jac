with entry {
  some_int_inferred = 42;
  assigning_to_int: int = some_int_inferred; # <-- Ok
  assigning_to_str: str = some_int_inferred; # <-- Error
}
