# P3.2e — vectorcall nargs helpers.
# Lift: Objects/_lifted/call_core.jac

def vectorcall_nargs_plain(nargs: int) -> int {
    return nargs;
}

def vectorcall_args_ok(nargs: int, min_args: int) -> bool {
    return nargs >= min_args;
}

def vectorcall_kwargs_present(nkwargs: int) -> bool {
    return nkwargs > 0;
}
