# Standard .jac file - must be explicit about everything
# Tests that explicit cl/sv blocks work correctly

cl {
    import from "lodash" { debounce }

    glob client_var = "shared";

    def client_func() -> str {
        return "from client";
    }
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
