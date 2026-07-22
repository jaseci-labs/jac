"""Entry module that reaches a sibling package through a relative import.

`services/` has no `__init__.jac`, so it resolves as an implicit Jac namespace
package. The leading dot only resolves if the entry module itself was given a
package context when it was loaded.
"""

import from .services.greeter { greet }

def entry_greeting -> str {
    return greet();
}
