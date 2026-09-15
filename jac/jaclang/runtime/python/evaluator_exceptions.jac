"""Exception-table search from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. Indexing uses the pinned exception-table
encoding. The caller supplies valid code and stack-local scalar cursor storage.
"""

import from jaclang.runtime.python.references { PyObjectRef }

import from c {
    obj JacPyExceptionCursor { has offset: i64; }
    obj JacPyIntSlot { has value: i32; }
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_exception_table_size(code: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_exception_table_byte(code: &PyObjectRef, offset: i64) -> i32;
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_exception_varint(code: &PyObjectRef, cursor: &mut JacPyExceptionCursor) -> i32 {
    byte = jacpy_exception_table_byte(code, cursor.offset);
    value: i32 = byte & i32(63);
    while (byte & i32(64)) != 0 {
        cursor.offset = wrapping_add(cursor.offset, 1);
        byte = jacpy_exception_table_byte(code, cursor.offset);
        value = wrapping_shl(value, i32(6)) | (byte & i32(63));
    }
    cursor.offset = wrapping_add(cursor.offset, 1);
    return value;
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_exception_table_handler(code: &PyObjectRef, index: i32,
    level: &mut JacPyIntSlot, handler: &mut JacPyIntSlot, lasti: &mut JacPyIntSlot,
    cursor: &mut JacPyExceptionCursor) -> i32 {
    start: i64 = 0;
    end = jacpy_exception_table_size(code);
    if end > 40 {
        cursor.offset = start;
        offset = jacpy_exception_varint(code, cursor);
        if offset > index { return 0; }
        while wrapping_sub(end, start) > 40 {
            middle = wrapping_add(start, wrapping_sub(end, start) >> 1);
            while (jacpy_exception_table_byte(code, middle) & 128) == 0 {
                middle = wrapping_sub(middle, 1);
            }
            cursor.offset = middle;
            offset = jacpy_exception_varint(code, cursor);
            if offset > index { end = middle; } else { start = middle; }
        }
    }
    cursor.offset = start;
    while cursor.offset < end {
        offset = jacpy_exception_varint(code, cursor);
        if offset > index { break; }
        size = jacpy_exception_varint(code, cursor);
        if wrapping_add(offset, size) > index {
            handler.value = jacpy_exception_varint(code, cursor);
            depth_and_lasti = jacpy_exception_varint(code, cursor);
            level.value = depth_and_lasti >> 1;
            lasti.value = depth_and_lasti & 1;
            return 1;
        }
        while cursor.offset < end and (jacpy_exception_table_byte(code, cursor.offset) & 128) == 0 {
            cursor.offset = wrapping_add(cursor.offset, 1);
        }
    }
    return 0;
}
