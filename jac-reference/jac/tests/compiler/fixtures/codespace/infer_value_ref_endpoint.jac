"""Client code that references a server-placed def:pub as a VALUE (#8072).

`activate` is pulled client by the npm import it uses; `run_current_file` is
vetoed out of the client pull by its `pub` access on a server-anchored module
(`import os` anchors it). The reference is a callback argument, not a call, so
the RPC call-site rewrite never sees it and the bare identifier reached the
bundle unbound -- `ReferenceError: run_current_file is not defined`.
"""

import os;
import from "vscode" { commands }

def:pub run_current_file {
    print("run");
}

def:pub activate(context: any) {
    context.subscriptions.push(commands.registerCommand("x.run", run_current_file));
}
