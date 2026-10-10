# Py_XINCREF / Py_XDECREF from Include/refcount.h (64-bit, GIL build), in
# native Jac so they inline into the ported objects instead of calling
# Py_IncRef / Py_DecRef across the C boundary.
#
# The refcount is the low 32 bits of ob_refcnt. INCREF leaves objects at or
# above _Py_IMMORTAL_INITIAL_REFCNT (3 << 30) alone; DECREF leaves immortal
# objects (bit 31 set, i.e. the low half negative as int32) alone and
# deallocates when the low half reaches zero. The +1/-1 cannot overflow (a
# live non-immortal refcount is in 1..3<<30), so they wrap like C's. The parameter is a bare `ptr`:
# each port declares its own opaque PyObject, which do not unify.

import from c {
    obj PyObject;
    obj PyRefHead {
        has ob_refcnt: i64 = 0;
    }

    def _Py_Dealloc(o: ptr[PyObject]) -> None;
}

def py_incref(o: ptr) -> None {
    if o == ptr() {
        return;
    }
    h = ptr[PyRefHead](o);
    rc = h.ob_refcnt;
    if (rc & 4294967295) >= 3221225472 {
        return;
    }
    h.ob_refcnt = wrapping_add(rc, 1);
}

def py_decref(o: ptr) -> None {
    if o == ptr() {
        return;
    }
    h = ptr[PyRefHead](o);
    rc = h.ob_refcnt;
    if (rc & 2147483648) != 0 {
        return;
    }
    rc = wrapping_sub(rc, 1);
    h.ob_refcnt = rc;
    if (rc & 4294967295) == 0 {
        _Py_Dealloc(ptr[PyObject](o));
    }
}
