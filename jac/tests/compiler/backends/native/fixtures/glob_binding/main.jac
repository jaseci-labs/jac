"""Imports a global named TABLE from the second of two modules that define one,
and FIRST through a module that only re-exports it."""

import from first_reexport { FIRST }
import from second_table { SECOND, TABLE, ESC, NONE_GLOB, NONE_DECL, Box }

def table_size -> i64 {
    return i64(len(TABLE)) + FIRST + SECOND;
}

def starts_escaped(seq: str) -> bool {
    return seq.startswith(ESC) and seq[0] == ESC and seq.startswith(ESC + "[");
}

def all_none -> bool {
    return NONE_GLOB is None and NONE_DECL is None and Box.EMPTY is None;
}
