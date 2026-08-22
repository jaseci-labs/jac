# b6_try_except_finally paste index

Compact view of `b6_try_except_finally/goldens.json` for pasting into `compiler_slice.jac`.
Prefer `paste_ready.json` (source + hex bytes + decoded exception entries).

| Fixture | stack | code B | table B |
|---|---:|---:|---:|
| `try_except_finally_normal` | 4 | 68 | 24 |
| `try_except_finally_raised_caught` | 4 | 88 | 24 |
| `try_except_finally_raised_unmatched` | 4 | 88 | 24 |
| `try_except_as_finally` | 4 | 102 | 28 |
| `return_inside_try_finally` | 4 | 28 | 4 |
| `exception_inside_handler_finally` | 4 | 92 | 16 |
| `nested_try_except_finally` | 4 | 126 | 52 |
| `try_finally_loop_break_continue` | 5 | 114 | 16 |
