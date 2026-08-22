# b6_raise_from paste index

Compact view of `b6_raise_from/goldens.json` for pasting into `compiler_slice.jac`.
Prefer `paste_ready.json` (source + hex bytes + decoded exception entries).

| Fixture | stack | code B | table B |
|---|---:|---:|---:|
| `top_level_raise_instance_from_instance` | 4 | 44 | 0 |
| `raise_instance_from_none` | 3 | 26 | 0 |
| `raise_from_inside_except_explicit_cause` | 5 | 98 | 8 |
| `implicit_chaining_inside_except` | 4 | 78 | 8 |
| `bare_raise_inside_except` | 4 | 58 | 8 |
| `raise_class_from_err` | 2 | 16 | 0 |
| `raise_instance_from_err` | 3 | 26 | 0 |
| `raise_from_inside_finally` | 6 | 100 | 8 |
