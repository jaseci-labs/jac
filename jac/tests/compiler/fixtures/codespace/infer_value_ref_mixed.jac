"""One endpoint reached both as a value and as a call from client code (#8072).

Both positions resolve to the same client binding; the forwarder is emitted
once.
"""

import os;
import from "vscode" { commands }

def:pub push_tag(tag: str) {
    print(tag);
}

def:pub activate(context: any) {
    context.subscriptions.push(commands.registerCommand("x.push", push_tag));
    push_tag(tag="y");
}
