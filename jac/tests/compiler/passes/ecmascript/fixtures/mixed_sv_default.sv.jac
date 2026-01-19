# .sv.jac file - server is default context
# Tests that cl blocks in .sv.jac files generate JavaScript correctly

cl {
    import from "lodash" { debounce }

    glob client_var = "shared";

    def client_func() -> str {
        return "from client";
    }
}

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
