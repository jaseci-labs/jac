import from guarded { make, pick }

glob a: str = make("a"),
     b: bytes = make(b"a"),
     c: int = pick(1),
     d: str = pick("x");
