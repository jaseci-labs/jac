"""A `type` alias right-hand side is a declaration, not a run-time use.

`ModuleFacts.is_erased_type_decl` drops a type declaration from native glob
lowering, so the alias below emits nothing that could read the Python module
it names, and the module-import gate must not refuse it.
"""

import threading;


type EventLike = threading.Event;


def run -> int {
    return 4;
}
