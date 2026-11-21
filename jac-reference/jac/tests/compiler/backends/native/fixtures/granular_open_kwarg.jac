"""`open(path, encoding=...)` is a keyword the emitter does not model.

`_emit_open` reads its arguments positionally and drops anything past the
mode, so honouring the call would mean emitting a `fopen` that ignores the
encoding the source asked for. It refuses instead, which demotes the one
function that wrote it and leaves its siblings native.
"""

def reads_with_encoding -> int {
    with open("/tmp/jac_open_kwarg_probe.txt", 'r', encoding='utf-8') as f {
        return len(f.read());
    }
}


def reads_plain -> int {
    with open("/tmp/jac_open_kwarg_probe.txt", 'r') as f {
        return len(f.read());
    }
}
