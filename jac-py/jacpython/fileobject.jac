# P3.2e — PyFile_WriteObject flag helpers.
# Lift: Objects/_lifted/fileobject_core.jac

glob Py_PRINT_RAW: int = 1;

def file_print_raw(flags: int) -> bool {
    return (flags & Py_PRINT_RAW) != 0;
}

def file_write_uses_str(flags: int) -> bool {
    return file_print_raw(flags);
}

def file_write_uses_repr(flags: int) -> bool {
    return not file_print_raw(flags);
}
