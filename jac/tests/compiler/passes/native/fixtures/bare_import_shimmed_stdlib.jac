"""The bare spelling of an na_stdlib-shimmed import, with no entry block.

`import keyword;` binds the bundled Jac shim, whose `kwlist` is a module-level
table built at runtime. A module with no `with entry` emits no `jac_entry`, so
nothing chains the shim's initializer -- reading `kwlist` from a JIT'd unit is
what #8228 crashed on.
"""

import keyword;


def run -> int {
    return 1 if keyword.iskeyword("class") else 0;
}
