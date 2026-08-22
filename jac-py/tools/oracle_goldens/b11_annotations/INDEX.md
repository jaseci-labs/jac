# b11_annotations paste index

Compact view of `b11_annotations/goldens.json` for pasting into slice tests.
Prefer `paste_ready.json` (source + hex bytes + decoded exception entries);
`nested` entries there carry each `__annotate__` / type-alias code object.

| Fixture | code objs | stack | code B | table B |
|---|---:|---:|---:|---:|
| `module_annotated_with_value` | 2 | 2 | 30 | 0 |
| `module_bare_annotation` | 2 | 2 | 26 | 0 |
| `class_body_annotations` | 3 | 4 | 26 | 0 |
| `function_local_annotated` | 2 | 1 | 12 | 0 |
| `function_local_bare_annotation` | 2 | 1 | 12 | 0 |
| `annotated_attribute_target` | 2 | 1 | 12 | 0 |
| `annotated_subscript_target` | 2 | 1 | 12 | 0 |
| `type_alias_simple` | 2 | 4 | 24 | 0 |
| `type_alias_parametrized` | 3 | 2 | 22 | 0 |
| `plain_assign_control` | 1 | 1 | 10 | 0 |
