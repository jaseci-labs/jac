"""Capsules, which wrap a C pointer for passing between extension modules:
Objects/capsule.c in native Jac.

`PyCapsule_Type` is C data Jac defines under its C name, and the capsule API
(`PyCapsule_New`, `PyCapsule_GetPointer`, `PyCapsule_Import`, ...) and
`_PyCapsule_SetTraverse` are C functions under theirs. The object layout,
`PyCapsule`, comes from layouts.jac; its destructor, traverse and clear
callbacks are C function pointers C code stores and Jac calls. See
../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Format,
    PyErr_NoMemory,
    PyErr_SetString,
    PyExc_AttributeError,
    PyExc_ImportError,
    PyExc_ValueError,
    PyImport_ImportModule,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyObject_GC_Del,
    PyObject_GC_IsTracked,
    PyObject_GC_Track,
    PyObject_GC_UnTrack,
    PyObject_GetAttrString,
    PyUnicode_FromFormat,
    _PyObject_GC_New,
    jacpy_release
}
import from jaclang.runtime.python.layouts {
    PyCapsule,
    PyCapsule_SIZE,
    PyTypeObject,
    PyVarObject,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object
}
import from jaclang.runtime.python.object_model.header { PyType_Type, object_is_type }

import from c {
    def strcmp(left: ptr[u8], right: ptr[u8]) -> i32;  def strlen(
        text: ptr[u8]
    ) -> u64;  def strchr(text: ptr[u8], character: i32) -> ptr[u8];  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  glob PyCapsule_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("PyCapsule"),
             tp_basicsize=PyCapsule_SIZE,
             tp_dealloc=capsule_dealloc,
             tp_repr=capsule_repr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "Capsule objects let you wrap a C \"void *\" pointer in a Python\n"
                 "object.  They're a way of passing data through the Python interpreter\n"
                 "without creating your own custom type.\n\n"
                 "Capsules are used for communication between extension modules.\n"
                 "They provide a way for an extension module to export a C interface\n"
                 "to other extension modules, so that extension modules can use the\n"
                 "Python import mechanism to link to one another.\n"
             ),
             tp_traverse=capsule_traverse,
             tp_clear=capsule_clear
         );
}

"""The capsule layout behind a handle."""
def capsule_of(op: ptr[PyObject]) -> ptr[PyCapsule] {
    return ptr[PyCapsule](op);
}

"""PyCapsule_CheckExact."""
def capsule_check_exact(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyCapsule_Type));
}

"""is_legal_capsule: whether `op` is a capsule holding a pointer; otherwise
ValueError "<caller> called with invalid PyCapsule object"."""
def is_legal_capsule(op: ptr[PyObject], invalid_capsule: str) -> bool {
    if op and capsule_check_exact(op) and capsule_of(op).view(1)[0].pointer {
        return True;
    }
    PyErr_SetString(PyExc_ValueError, invalid_capsule);
    return False;
}

"""Two capsule names match when both are NULL or their text is equal."""
def name_matches(name1: ptr[u8], name2: ptr[u8]) -> bool {
    # if either is NULL, they're only the same if they're both NULL.
    if not name1 or not name2 {
        return name1 == name2;
    }
    return strcmp(name1, name2) == 0;
}

import from c {
    def PyCapsule_New(pointer: ptr, name: ptr[u8], destructor: ptr) -> ptr[PyObject] {
        if not pointer {
            PyErr_SetString(PyExc_ValueError, "PyCapsule_New called with null pointer");
            return NULL;
        }
        op = _PyObject_GC_New(ptr[PyObject](addressof(PyCapsule_Type)));
        if not op {
            return NULL;
        }
        capsule = capsule_of(op);
        capsule.view(1)[0].pointer = pointer;
        capsule.view(1)[0].name = name;
        capsule.view(1)[0].context = ptr();
        capsule.view(1)[0].destructor = int(destructor);
        capsule.view(1)[0].traverse_func = 0;
        capsule.view(1)[0].clear_func = 0;
        # Only track the object by the GC when _PyCapsule_SetTraverse() is called
        return op;
    }  def PyCapsule_IsValid(op: ptr[PyObject], name: ptr[u8]) -> i32 {
        return i32(
            bool(op)
                and capsule_check_exact(op)
                and bool(capsule_of(op).view(1)[0].pointer)
                and name_matches(capsule_of(op).view(1)[0].name, name)
        );
    }  def PyCapsule_GetPointer(op: ptr[PyObject], name: ptr[u8]) -> ptr {
        if not is_legal_capsule(
            op, "PyCapsule_GetPointer called with invalid PyCapsule object"
        ) {
            return ptr();
        }
        capsule = capsule_of(op);
        if not name_matches(name, capsule.view(1)[0].name) {
            PyErr_SetString(
                PyExc_ValueError, "PyCapsule_GetPointer called with incorrect name"
            );
            return ptr();
        }
        return capsule.view(1)[0].pointer;
    }  def PyCapsule_GetName(op: ptr[PyObject]) -> ptr[u8] {
        if not is_legal_capsule(
            op, "PyCapsule_GetName called with invalid PyCapsule object"
        ) {
            return ptr[u8]();
        }
        return capsule_of(op).view(1)[0].name;
    }  def PyCapsule_GetDestructor(op: ptr[PyObject]) -> ptr {
        if not is_legal_capsule(
            op, "PyCapsule_GetDestructor called with invalid PyCapsule object"
        ) {
            return ptr();
        }
        return ptr(int(capsule_of(op).view(1)[0].destructor));
    }  def PyCapsule_GetContext(op: ptr[PyObject]) -> ptr {
        if not is_legal_capsule(
            op, "PyCapsule_GetContext called with invalid PyCapsule object"
        ) {
            return ptr();
        }
        return capsule_of(op).view(1)[0].context;
    }  def PyCapsule_SetPointer(op: ptr[PyObject], pointer: ptr) -> i32 {
        if not is_legal_capsule(
            op, "PyCapsule_SetPointer called with invalid PyCapsule object"
        ) {
            return i32(-1);
        }
        if not pointer {
            PyErr_SetString(
                PyExc_ValueError, "PyCapsule_SetPointer called with null pointer"
            );
            return i32(-1);
        }
        capsule_of(op).view(1)[0].pointer = pointer;
        return i32(0);
    }  def PyCapsule_SetName(op: ptr[PyObject], name: ptr[u8]) -> i32 {
        if not is_legal_capsule(
            op, "PyCapsule_SetName called with invalid PyCapsule object"
        ) {
            return i32(-1);
        }
        capsule_of(op).view(1)[0].name = name;
        return i32(0);
    }  def PyCapsule_SetDestructor(op: ptr[PyObject], destructor: ptr) -> i32 {
        if not is_legal_capsule(
            op, "PyCapsule_SetDestructor called with invalid PyCapsule object"
        ) {
            return i32(-1);
        }
        capsule_of(op).view(1)[0].destructor = int(destructor);
        return i32(0);
    }  def PyCapsule_SetContext(op: ptr[PyObject], context: ptr) -> i32 {
        if not is_legal_capsule(
            op, "PyCapsule_SetContext called with invalid PyCapsule object"
        ) {
            return i32(-1);
        }
        capsule_of(op).view(1)[0].context = context;
        return i32(0);
    }  def _PyCapsule_SetTraverse(
        op: ptr[PyObject], traverse_func: ptr, clear_func: ptr
    ) -> i32 {
        if not is_legal_capsule(
            op, "_PyCapsule_SetTraverse called with invalid PyCapsule object"
        ) {
            return i32(-1);
        }
        if not traverse_func or not clear_func {
            PyErr_SetString(
                PyExc_ValueError, "_PyCapsule_SetTraverse() called with NULL callback"
            );
            return i32(-1);
        }
        if PyObject_GC_IsTracked(op) == 0 {
            PyObject_GC_Track(op);
        }
        capsule = capsule_of(op);
        capsule.view(1)[0].traverse_func = int(traverse_func);
        capsule.view(1)[0].clear_func = int(clear_func);
        return i32(0);
    }  def PyCapsule_Import(name: ptr[u8], _no_block: i32) -> ptr {
        module = NULL;
        return_value = ptr();
        name_length = strlen(name) + u64(1);
        name_dup = ptr[u8](PyMem_Malloc(name_length));
        if not name_dup {
            PyErr_NoMemory();
            return ptr();
        }
        memcpy(name_dup, name, name_length);
        trace = name_dup;
        while trace {
            dot = strchr(trace, i32(46));
            if dot {
                dot.view(1)[0] = u8(0);
                dot += 1;
            }
            if not module {
                module = PyImport_ImportModule(trace);
                if not module {
                    PyErr_Format(
                        PyExc_ImportError,
                        "PyCapsule_Import could not import module \"%s\"",
                        trace
                    );
                }
            } else {
                attribute = PyObject_GetAttrString(module, trace);
                jacpy_release(module);
                module = attribute;
            }
            if not module {
                break;
            }
            trace = dot;
        }
        if module {
            # compare attribute name to module.name by hand
            if PyCapsule_IsValid(module, name) != 0 {
                return_value = capsule_of(module).view(1)[0].pointer;
            } else {
                PyErr_Format(
                    PyExc_AttributeError, "PyCapsule_Import \"%s\" is not valid", name
                );
            }
        }
        jacpy_release(module);
        PyMem_Free(name_dup);
        return return_value;
    }
}

def capsule_dealloc(op: ptr[PyObject]) {
    capsule = capsule_of(op);
    PyObject_GC_UnTrack(op);
    if int(capsule.view(1)[0].destructor) != 0 {
        capsule.view(1)[0].destructor(op);
    }
    PyObject_GC_Del(op);
}

def capsule_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    capsule = capsule_of(op);
    quote = ptr[u8]("");
    name = ptr[u8]("NULL");
    if capsule.view(1)[0].name {
        quote = ptr[u8]("\"");
        name = capsule.view(1)[0].name;
    }
    return PyUnicode_FromFormat(
        "<capsule object %s%s%s at %p>", quote, name, quote, op
    );
}

def capsule_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    # Capsule object is only tracked by the GC
    # if _PyCapsule_SetTraverse() is called, but
    # this can still be manually triggered by gc.get_referents()
    capsule = capsule_of(op);
    if int(capsule.view(1)[0].traverse_func) != 0 {
        return capsule.view(1)[0].traverse_func(op, int(visitor), arg);
    }
    return i32(0);
}

def capsule_clear(op: ptr[PyObject]) -> i32 {
    # Capsule object is only tracked by the GC
    # if _PyCapsule_SetTraverse() is called
    return capsule_of(op).view(1)[0].clear_func(op);
}
