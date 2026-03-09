"""Production test: Method calls on UnknownType must not silently pass.

When an expression has type Unknown, calling methods on it should
produce errors or warnings — not silently accept any method name.
This is a major source of missed bugs in practice.

Unknown source: bare generic list.pop() returns Unknown.

Expected errors: 4
  1. unknown_val.nonexistent()    — method call on Unknown should error
  2. unknown_val.strip()          — Unknown shouldn't have .strip
  3. unknown_val.append(1)        — Unknown shouldn't have .append
  4. val = unknown_val[0]         — Unknown shouldn't support indexing
"""

with entry {
    # Bare generic list — .pop() returns Unknown
    items: list = [1, 2, 3];
    unknown_val = items.pop();

    # Calling arbitrary methods on Unknown should NOT pass silently.
    # A production checker either:
    #   (a) errors because Unknown has no known methods, or
    #   (b) warns that type inference failed and methods are unchecked
    unknown_val.nonexistent();       # Error: no such method
    unknown_val.strip();             # Error: Unknown has no .strip
    unknown_val.append(1);           # Error: Unknown has no .append

    # Indexing Unknown should also not pass
    val = unknown_val[0];            # Error: Unknown not subscriptable
}
