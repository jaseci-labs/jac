/* Opaque CPython ABI storage for native Jac binding declarations.
 * No module names, signatures, argument policy, or implementation callbacks
 * belong here. Definitions are constructed once by native static initialization
 * and, like CPython's static PyModuleDefs, live for the process lifetime. */
#include <Python.h>
#include "internal/pycore_object.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>


_Static_assert(METH_VARARGS == 1 && METH_KEYWORDS == 2 && METH_NOARGS == 4 && METH_O == 8,
               "native binding calling conventions must match Python.h");

typedef struct {
    int32_t (*execute)(PyObject *);
    int32_t (*traverse)(PyObject *, visitproc, void *);
    int32_t (*clear)(PyObject *);
    void (*free)(PyObject *);
} JacModuleHooks;

typedef struct {
    char *name, *doc;
    PyMethodDef *entries;
} JacMethodTable;

typedef struct {
    JacMethodTable table;
    PyModuleDef definition;
    PyModuleDef_Slot slots[4];
    PyMethodDef methods[];
} JacModuleSpec;

typedef struct {
    void *native;
    PyObject *references[];
} JacModuleState;

static void discard_methods(JacMethodTable *table) {
    free(table->name);
    free(table->doc);
    for (PyMethodDef *method = table->entries; method->ml_name; method++) {
        free((void *)method->ml_name);
        free((void *)method->ml_doc);
    }
}

void jacpy_binding_discard(void *handle) {
    JacModuleSpec *spec = (handle);
    if (!spec) return;
    discard_methods(&spec->table);
    free(spec);
}

void *jacpy_binding_module(const char *name, const char *doc, int64_t count,
                             JacModuleHooks hooks, int64_t state_count) {
    JacModuleSpec *spec = calloc(1, sizeof(*spec) + (count + 1) * sizeof(PyMethodDef));
    if (!spec) return 0;
    PyModuleDef initial = {PyModuleDef_HEAD_INIT};
    spec->definition = initial;
    spec->table = (JacMethodTable){strdup(name), strdup(doc), spec->methods};
    spec->definition.m_name = spec->table.name;
    spec->definition.m_doc = spec->table.doc;
    spec->definition.m_size = sizeof(JacModuleState) + state_count * sizeof(PyObject *);
    spec->definition.m_traverse = (traverseproc)hooks.traverse;
    spec->definition.m_clear = (inquiry)hooks.clear;
    spec->definition.m_free = (freefunc)hooks.free;
    spec->definition.m_methods = spec->methods;
    spec->definition.m_slots = spec->slots;
    spec->slots[0] = (PyModuleDef_Slot){Py_mod_multiple_interpreters, Py_MOD_PER_INTERPRETER_GIL_SUPPORTED};
    spec->slots[1] = (PyModuleDef_Slot){Py_mod_gil, Py_MOD_GIL_USED};
    if (hooks.execute) spec->slots[2] = (PyModuleDef_Slot){Py_mod_exec, (void *)hooks.execute};
    if (!spec->definition.m_name || !spec->definition.m_doc) {
        jacpy_binding_discard((spec));
        return 0;
    }
    return (spec);
}

int64_t jacpy_binding_method(void *handle, int64_t index, const char *name,
        PyObject *(*keywords)(PyObject *, PyObject *, PyObject *),
        PyObject *(*positional)(PyObject *, PyObject *), int64_t flags, const char *doc) {
    JacMethodTable *table = (handle);
    PyMethodDef *method = &table->entries[index];
    char *owned_name = strdup(name), *owned_doc = strdup(doc);
    if (!owned_name || !owned_doc) { free(owned_name); free(owned_doc); return -1; }
    PyCFunction callback = flags & METH_KEYWORDS
        ? (PyCFunction)(void (*)(void))keywords : (PyCFunction)(void (*)(void))positional;
    *method = (PyMethodDef){owned_name, callback, (int)flags, owned_doc};
    return 0;
}

PyObject *jacpy_binding_init(void *handle) {
    if (!handle) return (PyErr_NoMemory());
    JacModuleSpec *spec = (handle);
    return (PyModuleDef_Init(&spec->definition));
}


/* Interpreter-local references. The Jac declaration controls their count,
 * meaning, initialization, traversal, and clearing. Get borrows; set retains. */
int64_t jacpy_binding_state_count(PyObject *module) {
    if (!PyModule_GetState((module))) return 0;
    return (PyModule_GetDef((module))->m_size - sizeof(JacModuleState)) / sizeof(PyObject *);
}
PyObject *jacpy_binding_state_get(PyObject *module, int64_t index) {
    JacModuleState *state = PyModule_GetState((module));
    return (state->references[index]);
}
void jacpy_binding_state_set(PyObject *module, int64_t index, PyObject *value) {
    JacModuleState *state = PyModule_GetState((module));
    Py_XSETREF(state->references[index], Py_XNewRef((PyObject *)(value)));
}
int32_t jacpy_binding_visit(PyObject *value, visitproc visitor, void *context) {
    return value ? ((visitproc)(visitor))((value), (context)) : 0;
}
PyObject *jacpy_binding_exception(const char *name, const char *base, const char *doc) {
    extern PyObject *jacpy_exception_type(const char *);
    return (PyErr_NewExceptionWithDoc(name, *doc ? doc : NULL, *base ? jacpy_exception_type(base) : NULL, NULL));
}

/* Type callbacks use explicit C ABI records, just like module callbacks.
 * Native payload storage is relative to the defining type, including when
 * the Python class inherits an opaque built-in layout or is subclassed. */
typedef struct {
    PyObject *(*create)(PyObject *, PyObject *, PyObject *);
    int32_t (*initialize)(PyObject *, PyObject *, PyObject *);
    void (*dealloc)(PyObject *);
    int32_t (*traverse)(PyObject *, visitproc, void *);
    int32_t (*clear)(PyObject *);
    PyObject *(*call)(PyObject *, PyObject *, PyObject *);
    PyObject *(*repr)(PyObject *);
    vectorcallfunc vectorcall;
    PyObject *(*iter)(PyObject *);
    PyObject *(*next)(PyObject *);
    PyObject *(*descriptor)(PyObject *, PyObject *, PyObject *);
    PyObject *(*compare)(PyObject *, PyObject *, int32_t);
    int64_t (*hash)(PyObject *);
    int32_t (*descriptor_set)(PyObject *, PyObject *, PyObject *);
    PyObject *(*bit_or)(PyObject *, PyObject *);
    int64_t (*length)(PyObject *);
    PyObject *(*item)(PyObject *, int64_t);
    int32_t (*assign)(PyObject *, int64_t, PyObject *);
    int32_t (*contains)(PyObject *, PyObject *);
    PyObject *(*concat)(PyObject *, PyObject *);
    PyObject *(*inplace_concat)(PyObject *, PyObject *);
    PyObject *(*repeat)(PyObject *, int64_t);
    PyObject *(*inplace_repeat)(PyObject *, int64_t);
    int64_t (*mapping_length)(PyObject *);
    PyObject *(*subscript)(PyObject *, PyObject *);
    int32_t (*assign_subscript)(PyObject *, PyObject *, PyObject *);
    int32_t (*buffer)(PyObject *, Py_buffer *, int32_t);
    void (*release_buffer)(PyObject *, Py_buffer *);
    PyObject *(*get_attribute)(PyObject *, PyObject *);
    int32_t (*set_attribute)(PyObject *, PyObject *, PyObject *);
} JacTypeHooks;

typedef struct {
    void *state;
    vectorcallfunc vectorcall;
    PyObject *dictionary;
} JacInstancePayload;

typedef struct {
    JacMethodTable table;
    PyType_Spec definition;
    PyType_Slot slots[35];
    vectorcallfunc vectorcall;
    int instance_dict;
    PyMemberDef members[3];
    PyGetSetDef *properties;
    PyMethodDef methods[];
} JacTypeSpec;

void jacpy_binding_type_discard(void *handle) {
    JacTypeSpec *spec = (handle);
    if (!spec) return;
    discard_methods(&spec->table);
    if (spec->properties) {
        for (PyGetSetDef *property = spec->properties; property->name; property++) {
            free((void *)property->name);
            free((void *)property->doc);
        }
        free(spec->properties);
    }
    free(spec);
}

void *jacpy_binding_type(const char *name, const char *doc, int64_t count,
                           uint64_t flags, JacTypeHooks hooks, int64_t property_count,
                           int64_t instance_dict, int64_t unhashable) {
    JacTypeSpec *spec = calloc(1, sizeof(*spec) + (count + 1) * sizeof(PyMethodDef));
    if (!spec) return 0;
    spec->table = (JacMethodTable){strdup(name), strdup(doc), spec->methods};
    spec->properties = calloc(property_count + 1, sizeof(PyGetSetDef));
    if (!spec->table.name || !spec->table.doc || !spec->properties) {
        jacpy_binding_type_discard((spec));
        return 0;
    }
    spec->definition = (PyType_Spec){spec->table.name, -(int)sizeof(void *), 0, (unsigned int)flags, spec->slots};
    int member = 0;
    if (hooks.vectorcall) {
        spec->definition.basicsize = -(int)sizeof(JacInstancePayload);
        spec->vectorcall = hooks.vectorcall;
        spec->members[member++] = (PyMemberDef){"__vectorcalloffset__", Py_T_PYSSIZET,
            offsetof(JacInstancePayload, vectorcall), Py_READONLY | Py_RELATIVE_OFFSET};
    }
    if (instance_dict) {
        spec->definition.basicsize = -(int)sizeof(JacInstancePayload);
        spec->instance_dict = 1;
        spec->members[member++] = (PyMemberDef){"__dictoffset__", Py_T_PYSSIZET,
            offsetof(JacInstancePayload, dictionary), Py_READONLY | Py_RELATIVE_OFFSET};
    }
    int slot = 0;
#define SLOT(field, id) if (hooks.field) spec->slots[slot++] = (PyType_Slot){id, (void *)hooks.field}
    SLOT(create, Py_tp_new);
    SLOT(initialize, Py_tp_init);
    SLOT(dealloc, Py_tp_dealloc);
    SLOT(traverse, Py_tp_traverse);
    SLOT(clear, Py_tp_clear);
    SLOT(call, Py_tp_call);
    SLOT(repr, Py_tp_repr);
    SLOT(iter, Py_tp_iter);
    SLOT(next, Py_tp_iternext);
    SLOT(descriptor, Py_tp_descr_get);
    SLOT(compare, Py_tp_richcompare);
    SLOT(descriptor_set, Py_tp_descr_set);
    SLOT(bit_or, Py_nb_or);
    SLOT(length, Py_sq_length);
    SLOT(item, Py_sq_item);
    SLOT(assign, Py_sq_ass_item);
    SLOT(contains, Py_sq_contains);
    SLOT(concat, Py_sq_concat);
    SLOT(inplace_concat, Py_sq_inplace_concat);
    SLOT(repeat, Py_sq_repeat);
    SLOT(inplace_repeat, Py_sq_inplace_repeat);
    SLOT(mapping_length, Py_mp_length);
    SLOT(subscript, Py_mp_subscript);
    SLOT(assign_subscript, Py_mp_ass_subscript);
    SLOT(buffer, Py_bf_getbuffer);
    SLOT(release_buffer, Py_bf_releasebuffer);
    SLOT(get_attribute, Py_tp_getattro);
    SLOT(set_attribute, Py_tp_setattro);
    if (unhashable) spec->slots[slot++] = (PyType_Slot){Py_tp_hash, PyObject_HashNotImplemented};
    else { SLOT(hash, Py_tp_hash); }
#undef SLOT
    if (hooks.vectorcall) {
        if (!hooks.call) spec->slots[slot++] = (PyType_Slot){Py_tp_call, PyVectorcall_Call};
    }
    if (member) spec->slots[slot++] = (PyType_Slot){Py_tp_members, spec->members};
    spec->slots[slot++] = (PyType_Slot){Py_tp_methods, spec->methods};
    if (*spec->table.doc) spec->slots[slot++] = (PyType_Slot){Py_tp_doc, spec->table.doc};
    spec->slots[slot++] = (PyType_Slot){Py_tp_token, spec};
    spec->slots[slot++] = (PyType_Slot){Py_tp_getset, spec->properties};
    return (spec);
}

int64_t jacpy_binding_property(void *handle, int64_t index, const char *name,
        PyObject *(*get)(PyObject *, PyObject *),
        int32_t (*set)(PyObject *, PyObject *, PyObject *), uint64_t context, const char *doc) {
    JacTypeSpec *spec = (handle);
    char *owned_name = strdup(name), *owned_doc = strdup(doc);
    if (!owned_name || !owned_doc) { free(owned_name); free(owned_doc); return -1; }
    spec->properties[index] = (PyGetSetDef){owned_name, (getter)get, (setter)set, owned_doc, (void *)(uintptr_t)context};
    return 0;
}

PyObject *jacpy_binding_type_create(void *handle, PyObject *module, PyObject *bases) {
    if (!handle) return (PyErr_NoMemory());
    JacTypeSpec *spec = (handle);
    return (PyType_FromModuleAndSpec((module), &spec->definition, (bases)));
}
PyObject *jacpy_binding_owner(PyObject *type, void *module_definition) {
    JacModuleSpec *spec = (module_definition);
    return PyType_GetModuleByDef((PyTypeObject *)type, &spec->definition);
}
int64_t jacpy_binding_basicsize(PyObject *object) { return Py_TYPE((PyObject *)(object))->tp_basicsize; }
PyObject *jacpy_binding_allocate(PyObject *type) { return ((PyTypeObject *)type)->tp_alloc((PyTypeObject *)type, 0); }
void jacpy_binding_free(PyObject *object) {
    PyTypeObject *type = Py_TYPE((PyObject *)(object));
    type->tp_free((object));
    Py_DECREF(type);
}
void jacpy_binding_untrack(PyObject *object) {
    if (PyObject_IS_GC((PyObject *)(object))) PyObject_GC_UnTrack((object));
}
void jacpy_binding_clear_weakrefs(PyObject *object) {
    if (Py_TYPE((PyObject *)(object))->tp_weaklistoffset) PyObject_ClearWeakRefs((object));
}

PyObject *jacpy_binding_base(PyObject *type, void *definition) {
    PyTypeObject *base = NULL;
    int found = PyType_GetBaseByToken((PyTypeObject *)type, definition, &base);
    if (!found) PyErr_SetString(PyExc_TypeError, "object does not inherit the native binding type");
    return (PyObject *)base;
}

static void **native_payload(PyObject *object, void *definition) {
    PyTypeObject *base = (PyTypeObject *)jacpy_binding_base((PyObject *)Py_TYPE(object), definition);
    if (!base) return NULL;
    void **slot = PyObject_GetTypeData((object), base);
    Py_DECREF(base);
    return slot;
}

extern void jac_retain(void *);
extern void jac_release(void *);

void *jacpy_binding_module_native_get(PyObject *module) {
    JacModuleState *state = PyModule_GetState((module));
    void *value = state ? state->native : NULL;
    if (value) jac_retain(value);
    return value;
}
void jacpy_binding_module_native_set(PyObject *module, void *value) {
    JacModuleState *state = PyModule_GetState((module));
    void *previous = state->native;
    if (value) jac_retain(value);
    state->native = value;
    if (previous) jac_release(previous);
}
void jacpy_binding_module_native_clear(PyObject *module) {
    if (PyModule_GetState((module))) jacpy_binding_module_native_set(module, NULL);
}
int64_t jacpy_binding_module_native_present(PyObject *module) {
    JacModuleState *state = PyModule_GetState((module));
    return state && state->native;
}

void *jacpy_binding_native_get(PyObject *object, void *definition) {
    void **slot = native_payload(object, definition);
    if (!slot) return NULL;
    void *state = *slot;
    if (state) jac_retain(state);
    return state;
}
int64_t jacpy_binding_native_set(PyObject *object, void *definition, void *state) {
    void **slot = native_payload(object, definition);
    if (!slot) return -1;
    void *previous = *slot;
    if (state) jac_retain(state);
    *slot = state;
    JacTypeSpec *spec = (definition);
    if (spec->vectorcall) ((JacInstancePayload *)slot)->vectorcall = spec->vectorcall;
    if (previous) jac_release(previous);
    return 0;
}
void jacpy_binding_native_clear(PyObject *object, void *definition) {
    (void)jacpy_binding_native_set(object, definition, NULL);
}
int64_t jacpy_binding_native_present(PyObject *object, void *definition) {
    void **slot = native_payload(object, definition);
    return slot && *slot;
}

PyObject *jacpy_binding_vector_item(PyObject *const *arguments, int64_t index) {
    return (((PyObject *const *)(arguments))[index]);
}

/* Dictionary and descriptor primitives keep CPython's object layout opaque.
 * Relative dictionary slots preserve lazy allocation, including the distinction
 * between an untouched instance and an explicitly created empty dictionary. */
int32_t jacpy_binding_dict_visit(PyObject *object, void *definition,
                                 visitproc visitor, void *context) {
    JacTypeSpec *spec = (definition);
    if (!spec->instance_dict) return 0;
    PyObject **dict = _PyObject_GetDictPtr((object));
    return dict ? jacpy_binding_visit((*dict), visitor, context) : 0;
}
void jacpy_binding_dict_clear(PyObject *object, void *definition) {
    JacTypeSpec *spec = (definition);
    if (!spec->instance_dict) return;
    PyObject **dict = _PyObject_GetDictPtr((object));
    if (dict) Py_CLEAR(*dict);
}
int64_t jacpy_binding_dict_present(PyObject *object) {
    PyObject **dict = _PyObject_GetDictPtr((object));
    return dict && *dict;
}
PyObject *jacpy_binding_dict_peek(PyObject *object) {
    PyObject **dict = _PyObject_GetDictPtr((object));
    return (dict ? Py_XNewRef(*dict) : NULL);
}
int64_t jacpy_binding_dict_replace(PyObject *object, PyObject *dictionary) {
    PyObject **dict = _PyObject_GetDictPtr((object));
    if (!dict) { PyErr_SetString(PyExc_SystemError, "instance has no dictionary slot"); return -1; }
    Py_XSETREF(*dict, Py_XNewRef((PyObject *)(dictionary)));
    return 0;
}
PyObject *jacpy_binding_marker(void) { return (PyObject_CallNoArgs((PyObject *)&PyBaseObject_Type)); }

/* Invoke inherited opaque built-in slots without duplicating their layouts. */
int64_t jacpy_binding_type_matches(PyObject *type, void *definition) {
    PyTypeObject *base = NULL;
    int found = PyType_GetBaseByToken((PyTypeObject *)type, definition, &base);
    Py_XDECREF(base);
    return found;
}
int64_t jacpy_binding_matches(PyObject *object, void *definition) {
    return jacpy_binding_type_matches((PyObject *)Py_TYPE(object), definition);
}
PyObject *jacpy_binding_base_new(PyObject *base, PyObject *type, PyObject *args, PyObject *keywords) {
    return ((PyTypeObject *)base)->tp_new((PyTypeObject *)type, args, keywords);
}
int32_t jacpy_binding_base_init(PyObject *base, PyObject *object, PyObject *args, PyObject *keywords) {
    return ((PyTypeObject *)(base))->tp_init((object), (args), (keywords));
}
int32_t jacpy_binding_base_traverse(PyObject *base, PyObject *object, visitproc visitor, void *context) {
    return ((PyTypeObject *)(base))->tp_traverse((object), (visitproc)(visitor), (context));
}
int32_t jacpy_binding_base_clear(PyObject *base, PyObject *object) {
    return ((PyTypeObject *)(base))->tp_clear((object));
}
void jacpy_binding_base_dealloc(PyObject *base, PyObject *object) {
    ((PyTypeObject *)(base))->tp_dealloc((object));
}

PyObject *jacpy_binding_parent(PyObject *type, void *definition) {
    PyTypeObject *base = (PyTypeObject *)jacpy_binding_base(type, definition);
    if (!base) return 0;
    PyTypeObject *parent = base->tp_base;
    Py_DECREF(base);
    return (PyObject *)parent; /* borrowed from the input type's retained base chain */
}

/* Contiguous one-dimensional buffer metadata belongs to the individual export,
 * so format and shape pointers remain valid independently of later callbacks. */
typedef struct {
    void *address;
    int64_t count, itemsize;
    int64_t readonly;
} JacBufferLayout;
typedef struct { Py_ssize_t shape; char format[]; } JacBufferExport;
int32_t jacpy_binding_buffer_fill(Py_buffer *view_handle, PyObject *object,
                                  JacBufferLayout layout, const char *format, int32_t flags) {
    Py_buffer *view = (view_handle);
    if (!view) { PyErr_SetString(PyExc_BufferError, "view==NULL argument is obsolete"); return -1; }
    if (layout.count < 0 || layout.itemsize <= 0 || layout.count > PY_SSIZE_T_MAX / layout.itemsize) {
        PyErr_SetString(PyExc_BufferError, "invalid native buffer dimensions"); return -1;
    }
    size_t format_size = strlen(format) + 1;
    JacBufferExport *metadata = malloc(sizeof(*metadata) + format_size);
    if (!metadata) { PyErr_NoMemory(); return -1; }
    metadata->shape = layout.count;
    memcpy(metadata->format, format, format_size);
    if (PyBuffer_FillInfo(view, (object), (layout.address), layout.count * layout.itemsize,
                          (int)layout.readonly, flags) < 0) { free(metadata); return -1; }
    view->itemsize = layout.itemsize;
    view->format = flags & PyBUF_FORMAT ? metadata->format : NULL;
    view->shape = flags & PyBUF_ND ? &metadata->shape : NULL;
    view->strides = (flags & PyBUF_STRIDES) == PyBUF_STRIDES ? &view->itemsize : NULL;
    view->internal = metadata;
    return 0;
}
void jacpy_binding_buffer_dispose(Py_buffer *view_handle) {
    Py_buffer *view = (view_handle);
    if (view) { free(view->internal); view->internal = NULL; }
}

/* Keep deeply linked Python ownership chains within CPython's destruction
 * budget. The entry callback is the actual tp_dealloc; body disposes once. */
void jacpy_binding_dealloc_guard(PyObject *object, void (*entry)(PyObject *),
                                 void (*body)(PyObject *)) {
    PyObject *op = object;
    PyObject_GC_UnTrack(op);
    Py_TRASHCAN_BEGIN(op, (destructor)entry)
    body(object);
    Py_TRASHCAN_END
}

PyObject *jacpy_binding_exception_with_base(const char *name, PyObject *base, const char *doc) {
    return (PyErr_NewExceptionWithDoc(name, *doc ? doc : NULL, (base), NULL));
}
