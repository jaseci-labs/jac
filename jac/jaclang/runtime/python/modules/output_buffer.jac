"""Growable output for streaming codecs, as a list of fixed bytes blocks.

Derived from CPython 3.14.6 Include/internal/pycore_blocks_output_buffer.h;
see ../LICENSE.cpython. A codec writes into the current block through a cursor
and a free count; finish() joins the used bytes, reusing a lone full block.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_AsString,
    PyBytes_Size,
    PyList_Append,
    PyList_GetItem,
    PyList_New,
    PyList_Size,
    PyObject,
    Py_NewRef,
    jacpy_buffer_new,
    jacpy_memory_copy,
    jacpy_offset,
    jacpy_release
}
import from jaclang.runtime.python.capi { object_error }

glob:priv KB: i64 = 1024,
     MB: i64 = 1024 * 1024,
     BLOCK_SIZES: list[i64] = [
         32 * KB,
         64 * KB,
         256 * KB,
         1 * MB,
         4 * MB,
         8 * MB,
         16 * MB,
         16 * MB,
         32 * MB,
         32 * MB,
         32 * MB,
         32 * MB,
         64 * MB,
         64 * MB,
         128 * MB,
         128 * MB,
         256 * MB
     ],
     SSIZE_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     UNABLE: str = "Unable to allocate output buffer.";

# The cursor into the newest block: where output goes and how much fits.
obj Cursor {
    has next_out: ptr[u8] = ptr[u8](),
        avail_out: i64 = 0;
}

obj BlocksOutputBuffer {
    has blocks: ptr[PyObject] = NULL,
        allocated: i64 = 0,
        max_length: i64 = -1;

    def:priv start(size: i64, cursor: Cursor, quiet: bool) -> i64 {
        block = jacpy_buffer_new(size);
        if not block {
            if not quiet {
                object_error("MemoryError", UNABLE);
            }
            return -1;
        }
        self.blocks = PyList_New(0);
        if not self.blocks or PyList_Append(self.blocks, block) < 0 {
            jacpy_release(block);
            return -1;
        }
        jacpy_release(block);
        self.allocated = size;
        cursor.next_out = PyBytes_AsString(block);
        cursor.avail_out = size;
        return size;
    }

    def init_and_grow(max_length: i64, cursor: Cursor) -> i64 {
        size = BLOCK_SIZES[0];
        if 0 <= max_length and max_length < size {
            size = max_length;
        }
        self.max_length = max_length;
        return self.start(size, cursor, True);
    }

    def init_with_size(size: i64, cursor: Cursor) -> i64 {
        self.max_length = -1;
        return self.start(size, cursor, False);
    }

    def grow(cursor: Cursor) -> i64 {
        if cursor.avail_out != 0 {
            object_error(
                "SystemError", "avail_out is non-zero in _BlocksOutputBuffer_Grow()."
            );
            return -1;
        }
        count = PyList_Size(self.blocks);
        size = BLOCK_SIZES[count] if count < len(BLOCK_SIZES) else BLOCK_SIZES[-1];
        if self.max_length >= 0 {
            rest = self.max_length - self.allocated;
            if size > rest {
                size = rest;
            }
        }
        if size > SSIZE_MAX - self.allocated {
            object_error("MemoryError", UNABLE);
            return -1;
        }
        block = jacpy_buffer_new(size);
        if not block {
            object_error("MemoryError", UNABLE);
            return -1;
        }
        if PyList_Append(self.blocks, block) < 0 {
            jacpy_release(block);
            return -1;
        }
        jacpy_release(block);
        self.allocated += size;
        cursor.next_out = PyBytes_AsString(block);
        cursor.avail_out = size;
        return size;
    }

    def data_size(avail_out: i64) -> i64 {
        return self.allocated - avail_out;
    }

    def finish(avail_out: i64) -> ptr[PyObject] {
        count = PyList_Size(self.blocks);
        if (count == 1 and avail_out == 0)
            or (
                count == 2 and PyBytes_Size(PyList_GetItem(self.blocks, 1)) == avail_out
            ) {
            block = Py_NewRef(PyList_GetItem(self.blocks, 0));
            self.discard();
            return block;
        }
        result = jacpy_buffer_new(self.allocated - avail_out);
        if not result {
            object_error("MemoryError", UNABLE);
            return NULL;
        }
        position: ptr = PyBytes_AsString(result);
        for index in range(count) {
            block = PyList_GetItem(self.blocks, index);
            size = PyBytes_Size(block);
            if index == count - 1 {
                size -= avail_out;
            }
            jacpy_memory_copy(position, PyBytes_AsString(block), size);
            position = jacpy_offset(position, size);
        }
        self.discard();
        return result;
    }

    def discard {
        jacpy_release(self.blocks);
        self.blocks = NULL;
    }
}
