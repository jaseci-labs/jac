import from import_sym { foo }

with entry {
    a: str = foo();  # <-- Ok
    b: int = foo();  # <-- Error
}
