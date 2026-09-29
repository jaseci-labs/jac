"""Cell objects: Objects/cellobject.c in native Jac.

`PyCell_Type` is C data Jac defines under its C name, and `PyCell_New`,
`PyCell_Get` and `PyCell_Set` are C functions under theirs, so closures built
by the evaluator and the C API use them unchanged. The cell layout is
Include/cpython/cellobject.h's `PyCellObject`. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyArg_UnpackTuple,
    PyErr_BadInternalCall,
    PyErr_SetString,
    PyExc_ValueError,
    PyObject,
    PyObject_GC_Del,
    PyObject_GenericGetAttr,
    PyObject_RichCompare,
    PyUnicode_FromFormat,
    Py_NewRef,
    Py_NotImplemented,
    Py_XNewRef,
    _PyArg_NoKeywords,
    _PyObject_GC_New,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    PyCellObject,
    PyCellObject_SIZE,
    PyGetSetDef,
    PyTypeObject,
    PyVarObject,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object
}
import from jaclang.runtime.python.object_model.header {
    object_gc_track,
    object_gc_untrack,
    object_is_type,
    object_type,
    PyType_Type,
    rich_compare_values
}
import from jaclang.runtime.python.bindings.module { visit_reference }

import from c {
    glob:priv cell_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("cell_contents"),
                 get=cell_get_contents,
                 set=cell_set_contents
             ),
             PyGetSetDef()
         ]; glob PyCell_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("cell"),
             tp_basicsize=PyCellObject_SIZE,
             tp_dealloc=cell_dealloc,
             tp_repr=cell_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "cell([contents])\n--\n\n"
                 "Create a new cell object.\n\n"
                 "  contents\n"
                 "    the contents of the cell. If not specified, the cell will be empty,\n"
                 "    and \n further attempts to access its cell_contents attribute will\n"
                 "    raise a ValueError."
             ),
             tp_traverse=cell_traverse,
             tp_clear=cell_clear,
             tp_richcompare=cell_richcompare,
             tp_getset=addressof(cell_getsetlist),
             tp_new=cell_new
         );
}

"""The cell layout behind a handle."""
def cell_of(op: ptr[PyObject]) -> ptr[PyCellObject] {
    return ptr[PyCellObject](op);
}

"""PyCell_Check."""
def cell_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyCell_Type));
}

"""PyCell_GetRef: the contents as a new reference, or NULL when empty."""
def cell_get_ref(cell: ptr[PyCellObject]) -> ptr[PyObject] {
    return Py_XNewRef(cell.view(1)[0].ob_ref);
}

"""PyCell_SetTakeRef: store `value` (stealing it) and release the old contents."""
def cell_set_take_ref(cell: ptr[PyCellObject], value: ptr[PyObject]) {
    old = cell.view(1)[0].ob_ref;
    cell.view(1)[0].ob_ref = value;
    jacpy_release(old);
}

import from c {
    def PyCell_New(value: ptr[PyObject]) -> ptr[PyObject] {
        op = _PyObject_GC_New(ptr[PyObject](addressof(PyCell_Type)));
        if not op {
            return NULL;
        }
        cell_of(op).view(1)[0].ob_ref = Py_XNewRef(value);
        object_gc_track(op);
        return op;
    }  def PyCell_Get(op: ptr[PyObject]) -> ptr[PyObject] {
        if not cell_check(op) {
            PyErr_BadInternalCall();
            return NULL;
        }
        return cell_get_ref(cell_of(op));
    }  def PyCell_Set(op: ptr[PyObject], value: ptr[PyObject]) -> i32 {
        if not cell_check(op) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        cell_set_take_ref(cell_of(op), Py_XNewRef(value));
        return i32(0);
    }
}

def cell_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    value = NULL;
    if kwargs and _PyArg_NoKeywords("cell", kwargs) == 0 {
        return NULL;
    }
    # min = 0: we allow the cell to be empty
    if PyArg_UnpackTuple(args, "cell", 0, 1, &mut value) == 0 {
        return NULL;
    }
    return PyCell_New(value);
}

def cell_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    jacpy_release(cell_of(op).view(1)[0].ob_ref);
    PyObject_GC_Del(op);
}

def cell_compare_impl(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject] {
    if a and b {
        return PyObject_RichCompare(a, b, op);
    }
    return rich_compare_values(i64(not b), i64(not a), op);
}

def cell_richcompare(a: ptr[PyObject], b: ptr[PyObject], op: i32) -> ptr[PyObject] {
    # both arguments should be instances of PyCellObject
    if not cell_check(a) or not cell_check(b) {
        return Py_NewRef(Py_NotImplemented);
    }
    a_ref = cell_get_ref(cell_of(a));
    b_ref = cell_get_ref(cell_of(b));
    # compare cells by contents; empty cells come before anything else
    result = cell_compare_impl(a_ref, b_ref, op);
    jacpy_release(a_ref);
    jacpy_release(b_ref);
    return result;
}

def cell_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    ref = cell_get_ref(cell_of(op));
    if not ref {
        return PyUnicode_FromFormat("<cell at %p: empty>", op);
    }
    result = PyUnicode_FromFormat(
        "<cell at %p: %.80s object at %p>", op, object_type(ref).view(1)[0].tp_name, ref
    );
    jacpy_release(ref);
    return result;
}

def cell_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(cell_of(op).view(1)[0].ob_ref, visitor, arg);
}

def cell_clear(op: ptr[PyObject]) -> i32 {
    old = cell_of(op).view(1)[0].ob_ref;
    cell_of(op).view(1)[0].ob_ref = NULL;
    jacpy_release(old);
    return i32(0);
}

def cell_get_contents(op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    result = cell_get_ref(cell_of(op));
    if not result {
        PyErr_SetString(PyExc_ValueError, "Cell is empty");
        return NULL;
    }
    return result;
}

def cell_set_contents(op: ptr[PyObject], value: ptr[PyObject], _closure: ptr) -> i32 {
    cell_set_take_ref(cell_of(op), Py_XNewRef(value));
    return i32(0);
}
