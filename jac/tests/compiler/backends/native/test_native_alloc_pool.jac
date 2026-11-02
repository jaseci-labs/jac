"""Small objects recycle their blocks through per-size-class free lists.

The native runtime keeps one free list per 16-byte size class from 48 to 128
bytes, header included: a free pushes the block onto its class's list (up to
a cap) and an allocation pops one before it calls malloc, both inline. The
class sits in the top byte of the alloc-id word. Only a single-threaded
program pools; once a thread runs, blocks go back to malloc and free, and
every pooled block is a malloc block, so free takes it too.
"""

import os;
import from tests.support { assert_native_identity, NATIVE_FIXTURES }

glob FIXTURE: str = os.path.join(NATIVE_FIXTURES, "alloc_pool.jac");

test "pooled allocation agrees with the Python backend, before and after threads" {
    out = assert_native_identity(FIXTURE, profiles=["rc", "managed"]);
    assert out.splitlines()[0].endswith(" 516 t5") , out;
}
