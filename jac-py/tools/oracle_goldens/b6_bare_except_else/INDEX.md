# b6_bare_except_else paste index

Compact view of `b6_bare_except_else/goldens.json` for pasting into `compiler_slice.jac`.
Prefer `paste_ready.json` (source + hex bytes + decoded exception entries).

| Fixture | stack | code B | table B |
|---|---:|---:|---:|
| `bare_except_body` | 4 | 42 | 8 |
| `typed_then_bare_except` | 4 | 68 | 12 |
| `bare_except_reraise` | 4 | 38 | 8 |
| `try_else_normal` | 4 | 56 | 12 |
| `try_except_else_exception` | 4 | 66 | 12 |
| `try_except_else_finally` | 4 | 72 | 28 |
| `try_without_except_or_finally` | None | 0 | 0 |
| `tuple_except_as` | 4 | 90 | 20 |
