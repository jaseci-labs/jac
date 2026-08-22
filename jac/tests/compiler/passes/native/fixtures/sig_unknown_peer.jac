"""A module with no native layout of its own, holding the annotated class.

The module-level `import collections` feeds a glob initializer, so nothing
owns the violation and the whole module is refused -- exactly the position
`type_evaluator.jac` is in. `Peer` therefore never gets a native struct, and
any signature that names it is un-lowerable in the module that imports it.
"""

import collections;

glob CACHE = collections.OrderedDict();

obj Peer {
    has tag: int = 0;
}
