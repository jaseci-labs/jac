# .jac file - client is default context
# Tests that sv blocks in .jac files generate Python correctly

import from "lodash" { debounce }

glob client_var = "shared";

def client_func() -> str {
    return "from client";
}


import from os { path }

glob server_var = "shared";

def server_func() -> str {
    return "from server";
}

walker MyWalker {
    can process with Root entry {
        report "done";
    }
}
