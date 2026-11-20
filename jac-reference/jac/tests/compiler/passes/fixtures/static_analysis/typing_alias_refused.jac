"""Every import shape that binds a deprecated typing alias must be refused (E1123).

The aliases are the PEP 585 twins of builtins jac already subscripts directly:
`List`/`Dict`/`Tuple`/`Set`/`FrozenSet`/`Type` say nothing `list`/`dict`/`tuple`/
`set`/`frozenset`/`type` do not, so like `Any` before them they are refused at
the import rather than tolerated as a second spelling.

Five statements, six refusals:
  - a lone `{ List }` import
  - `Dict` in the middle of a multi-name list
  - the `as` alias form, which binds the deprecated name just as surely
  - `Set` and `FrozenSet` together in one list (two refusals from one statement)
  - `Type`, the one whose builtin twin is not a container

The sibling names (`Optional`, `cast`) are the control: only the deprecated
aliases draw E1123, the rest of these stay importable. Ambient names
(`Callable`, ...) are deliberately absent from the import lists -- their
import is its own refusal (E1125, redundant_typing_imports.jac) -- and
`Callable` is used ambient in the body instead.
"""

import from typing { List }
import from typing { Optional, Dict, cast }
import from typing { Tuple as Pair }
import from typing { Set, FrozenSet }
import from typing { Type }

def uses(
    a: List[int],
    b: Dict[str, int],
    c: Pair[int, int],
    d: Set[int],
    e: FrozenSet[int],
    f: Type[int],
    g: Optional[int],
    cb: Callable[[], None]
) {
    print(a, b, c, d, e, f, cast(int, g), cb);
}
