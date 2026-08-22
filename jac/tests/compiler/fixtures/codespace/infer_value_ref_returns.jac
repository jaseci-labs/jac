"""A value-returning endpoint referenced as a client value (#8072).

The client forwarder is necessarily async, so it hands back a Promise where
the server function hands back an int. That is fine for a command handler and
wrong for, say, a sort comparator, so it is diagnosed rather than assumed.
"""

import os;
import from "vscode" { commands }

def:pub compare_tags(a: str, b: str) -> int {
    return len(a) - len(b);
}

def:pub activate(context: any) {
    context.subscriptions.push(commands.registerCommand("x.cmp", compare_tags));
}
