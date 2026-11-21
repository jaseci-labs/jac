---
description: Docstrings - where a docstring is written (before the declaration it documents), the module's docstring and __doc__, and what a stray string is.
keywords: docstring
grammar: docstring_target
---
# Docstrings

```ebnf
docstring_target ::= STRING (test_decl | enum_decl | type_alias | global_vars | comptime_element | impl_def | module_code | decorated)
```

A docstring is a string literal written immediately before the declaration it documents.

- **The module's docstring** is a string that opens the file. It is the module's `__doc__`.
- **A declaration's docstring** precedes a function, an archetype, an enum, a `glob`, a type alias,
  an `impl`, a `test` or a `with entry` block. Inside an archetype's body it precedes a member.
- A string at the top level that precedes anything else, such as an `import`, documents nothing and
  is warned of (W0060): the program still builds.
- A file that opens with one string followed by a declaration gives that string to the module. To
  document both, write two strings.

In Python a function's docstring is the first statement of its body. Here it is written before the
`def`; a string as the first statement of a body is an expression statement and needs its `;`.

```jac
"""Area helpers."""

"""The largest side the helpers accept."""
glob limit: int = 100;

"""The area of a square of side `n`."""
def area(n: int) -> int {
    return n * n;
}

with entry {
    print(__doc__);
    print(area(3) <= limit);
}
```

```output
Area helpers.
True
```

```jac
# expect: W0060
"""About this module."""

"""About the import."""
import os;

with entry {
    print(os.sep);
}
```

## Differences from Python

- A docstring is written before its declaration, not as the first statement of a body.
- A string at the top level that documents nothing is warned of (W0060), not an expression.
