import from . { checker_imported }

glob ok: int = checker_imported.some_int; # Ok

glob err: str = checker_imported.some_int; # Error - cannot assign int to str
