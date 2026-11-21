"""A plain client call to a server endpoint, the position that always worked.

Kept as the regression control for #8072: binding the endpoint client-side
must not disturb the call-site rewrite that carries Jac's calling convention
(keyword arguments, spreads, boundary types) across the wire.
"""

import os;
import from "vscode" { commands }

def:pub push_tag(tag: str) {
    print(tag);
}

def:pub activate(context: any) {
    commands.executeCommand("noop");
    push_tag(tag="x");
}
