"""A server-pinned function with no endpoint access, used as a client value.

`log_it` is pinned server by jac.toml and is not `pub`, so there is no RPC
endpoint to forward to: no client binding can exist for it. Emitting the bare
identifier would ship a guaranteed ReferenceError, so codegen must fail.
"""

import from "vscode" { commands }

def log_it {
    print("logged");
}

def:pub activate(context: any) {
    context.subscriptions.push(commands.registerCommand("x.log", log_it));
}
