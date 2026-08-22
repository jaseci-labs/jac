# P3.2d — memoryview flag / nbytes helpers.
# Lift: Objects/_lifted/memoryobject_core.jac

glob PyBUF_WRITABLE: int = 1,
     PyBUF_C_CONTIGUOUS: int = 0x0020 | 0x0010 | 0x0008;

def memoryview_flags_writable(flags: int) -> bool {
    return (flags & PyBUF_WRITABLE) != 0;
}

def memoryview_nbytes(length: int, itemsize: int) -> int {
    return length * itemsize;
}

def memoryview_ndim_ok(ndim: int) -> bool {
    return ndim >= 0;
}
