"""Imports a global named TABLE from the second of two modules that define one,
and FIRST through a module that only re-exports it."""

import from first_reexport { FIRST }
import from second_table { SECOND, TABLE }

def table_size -> i64 {
    return i64(len(TABLE)) + FIRST + SECOND;
}
