"""Must-fail under --enforce-nogc: implicit heap crossing into a managed module (E1403).

The `managed(...)` wrapped call is the sanctioned form and must NOT error.
"""

import from e1403_lib { render }

glob data = [1, 2, 3];

with entry {
    print(render(managed(data)));
    print(render(data));
}
