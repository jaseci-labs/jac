"""Fixture: a module-level violation has no owning callable to demote.

The module-level `import collections` feeds a glob initializer, so no
method or free function can absorb the violation as a seam: the module
must keep the whole-module E5090 refusal, and the diagnostic must name
the construct.
"""

import collections;

glob CACHE = collections.OrderedDict();

def sibling(x: int) -> int {
    return x;
}

with entry {
    print(sibling(1));
}
