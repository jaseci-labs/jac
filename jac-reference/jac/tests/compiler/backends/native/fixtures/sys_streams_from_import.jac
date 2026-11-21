"""Native sys streams reached through a from-import, an alias, and a module alias.
Byte counts go through a comparison for the same reason as in sys_streams.jac."""

import sys as s;
import from sys { stdout, stderr as err }

def write_out -> int {
    n = stdout.write("out-bytes\n");
    stdout.flush();
    return 10 if n == 10 else 0;
}

def write_err -> int {
    n = err.write("err-7\n");
    err.flush();
    return 6 if n == 6 else 0;
}

def print_err -> int {
    print("p-err", file=err);
    err.flush();
    return 1;
}

def print_module_alias_err -> int {
    print("s-err", file=s.stderr);
    s.stderr.flush();
    return 1;
}
