"""Production test: Method calls on UnknownType must not silently pass.

When an expression has type Unknown, calling methods on it should
produce errors or warnings — not silently accept any method name.
This is a major source of missed bugs in practice.

Unknown source: subscripting a non-subscriptable instance yields a
genuine, undiagnosed Unknown.

Expected errors: 4
  1. unknown_val.nonexistent()    — method call on Unknown should error
  2. unknown_val.strip()          — Unknown shouldn't have .strip
  3. unknown_val.append(1)        — Unknown shouldn't have .append
  4. val = unknown_val[0]         — Unknown shouldn't support indexing
"""

obj UnBox {
    has v: int = 0;
}

with entry {
    # Subscripting a plain object resolves to nothing: genuine Unknown.
    unknown_val = UnBox()[0];

    # Calling arbitrary methods on Unknown should NOT pass silently.
    unknown_val.nonexistent();       # Error: no such method
    unknown_val.strip();             # Error: Unknown has no .strip
    unknown_val.append(1);           # Error: Unknown has no .append

    # Indexing Unknown should also not pass
    val = unknown_val[0];            # Error: Unknown not subscriptable
}
