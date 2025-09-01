import from checker_imported {
    some_int as alias
}

glob i: int = alias;  # <-- Ok
glob s: str = alias;  # <-- Error
