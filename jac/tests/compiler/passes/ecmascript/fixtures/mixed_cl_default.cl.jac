# .cl.jac file - client is default context
# Tests that sv blocks in .cl.jac files generate Python correctly

import from "lodash" { debounce }

glob client_var = "shared";

def client_func() -> str {
    return "from client";
}

sv {
    import from os { path }

    glob server_var = "shared";

    def server_func() -> str {
        return "from server";
    }

    walker MyWalker {
        can process with `root entry {
            report "done";
        }
    }
}
