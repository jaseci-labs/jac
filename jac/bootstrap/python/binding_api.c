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

#define H(p) ((uint64_t)(uintptr_t)(p))
#define P(h) ((void *)(uintptr_t)(h))

_Static_assert(METH_VARARGS == 1 && METH_KEYWORDS == 2 && METH_NOARGS == 4 && METH_O == 8,
               "native binding calling conventions must match Python.h");

typedef struct {
    int32_t (*execute)(uint64_t);
    int32_t (*traverse)(uint64_t, uint64_t, uint64_t);
    int32_t (*clear)(uint64_t);
    void (*free)(uint64_t);
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

void jacpy_binding_discard(uint64_t handle) {
    JacModuleSpec *spec = P(handle);
    if (!spec) return;
    discard_methods(&spec->table);
    free(spec);
}

uint64_t jacpy_binding_module(const char *name, const char *doc, int64_t count,
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
        jacpy_binding_discard(H(spec));
        return 0;
    }
    return H(spec);
}

int64_t jacpy_binding_method(uint64_t handle, int64_t index, const char *name,
        uint64_t (*keywords)(uint64_t, uint64_t, uint64_t),
        uint64_t (*positional)(uint64_t, uint64_t), int64_t flags, const char *doc) {
    JacMethodTable *table = P(handle);
    PyMethodDef *method = &table->entries[index];
    char *owned_name = strdup(name), *owned_doc = strdup(doc);
    if (!owned_name || !owned_doc) { free(owned_name); free(owned_doc); return -1; }
    PyCFunction callback = flags & METH_KEYWORDS
        ? (PyCFunction)(void (*)(void))keywords : (PyCFunction)(void (*)(void))positional;
    *method = (PyMethodDef){owned_name, callback, (int)flags, owned_doc};
    return 0;
}

uint64_t jacpy_binding_init(uint64_t handle) {
    if (!handle) return H(PyErr_NoMemory());
    JacModuleSpec *spec = P(handle);
    return H(PyModuleDef_Init(&spec->definition));
}

int64_t jacpy_binding_add(uint64_t module, const char *name, uint64_t value) {
    return PyModule_AddObjectRef(P(module), name, P(value));
}

/* Interpreter-local references. The Jac declaration controls their count,
 * meaning, initialization, traversal, and clearing. Get borrows; set retains. */
int64_t jacpy_binding_state_count(uint64_t module) {
    if (!PyModule_GetState(P(module))) return 0;
    return (PyModule_GetDef(P(module))->m_size - sizeof(JacModuleState)) / sizeof(PyObject *);
}
uint64_t jacpy_binding_state_get(uint64_t module, int64_t index) {
    JacModuleState *state = PyModule_GetState(P(module));
    return H(state->references[index]);
}
void jacpy_binding_state_set(uint64_t module, int64_t index, uint64_t value) {
    JacModuleState *state = PyModule_GetState(P(module));
    Py_XSETREF(state->references[index], Py_XNewRef((PyObject *)P(value)));
}
int32_t jacpy_binding_visit(uint64_t value, uint64_t visitor, uint64_t context) {
    return value ? ((visitproc)P(visitor))(P(value), P(context)) : 0;
}
uint64_t jacpy_binding_exception(const char *name, const char *base, const char *doc) {
    extern PyObject *jacpy_exception_type(const char *);
    return H(PyErr_NewExceptionWithDoc(name, *doc ? doc : NULL, *base ? jacpy_exception_type(base) : NULL, NULL));
}

/* Type callbacks use explicit C ABI records, just like module callbacks.
 * Native payload storage is relative to the defining type, including when
 * the Python class inherits an opaque built-in layout or is subclassed. */
typedef struct {
    uint64_t (*create)(uint64_t, uint64_t, uint64_t);
    int32_t (*initialize)(uint64_t, uint64_t, uint64_t);
    void (*dealloc)(uint64_t);
    int32_t (*traverse)(uint64_t, uint64_t, uint64_t);
    int32_t (*clear)(uint64_t);
    uint64_t (*call)(uint64_t, uint64_t, uint64_t);
    uint64_t (*repr)(uint64_t);
    uint64_t (*vectorcall)(uint64_t, uint64_t, uint64_t, uint64_t);
    uint64_t (*iter)(uint64_t);
    uint64_t (*next)(uint64_t);
    uint64_t (*descriptor)(uint64_t, uint64_t, uint64_t);
    uint64_t (*compare)(uint64_t, uint64_t, int32_t);
    int64_t (*hash)(uint64_t);
    int32_t (*descriptor_set)(uint64_t, uint64_t, uint64_t);
    uint64_t (*bit_or)(uint64_t, uint64_t);
    int64_t (*length)(uint64_t);
    uint64_t (*item)(uint64_t, int64_t);
    int32_t (*assign)(uint64_t, int64_t, uint64_t);
    int32_t (*contains)(uint64_t, uint64_t);
    uint64_t (*concat)(uint64_t, uint64_t);
    uint64_t (*inplace_concat)(uint64_t, uint64_t);
    uint64_t (*repeat)(uint64_t, int64_t);
    uint64_t (*inplace_repeat)(uint64_t, int64_t);
    int64_t (*mapping_length)(uint64_t);
    uint64_t (*subscript)(uint64_t, uint64_t);
    int32_t (*assign_subscript)(uint64_t, uint64_t, uint64_t);
    int32_t (*buffer)(uint64_t, uint64_t, int32_t);
    void (*release_buffer)(uint64_t, uint64_t);
    uint64_t (*get_attribute)(uint64_t, uint64_t);
    int32_t (*set_attribute)(uint64_t, uint64_t, uint64_t);
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

void jacpy_binding_type_discard(uint64_t handle) {
    JacTypeSpec *spec = P(handle);
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

uint64_t jacpy_binding_type(const char *name, const char *doc, int64_t count,
                           uint64_t flags, JacTypeHooks hooks, int64_t property_count,
                           int64_t instance_dict, int64_t unhashable) {
    JacTypeSpec *spec = calloc(1, sizeof(*spec) + (count + 1) * sizeof(PyMethodDef));
    if (!spec) return 0;
    spec->table = (JacMethodTable){strdup(name), strdup(doc), spec->methods};
    spec->properties = calloc(property_count + 1, sizeof(PyGetSetDef));
    if (!spec->table.name || !spec->table.doc || !spec->properties) {
        jacpy_binding_type_discard(H(spec));
        return 0;
    }
    spec->definition = (PyType_Spec){spec->table.name, -(int)sizeof(void *), 0, (unsigned int)flags, spec->slots};
    int member = 0;
    if (hooks.vectorcall) {
        spec->definition.basicsize = -(int)sizeof(JacInstancePayload);
        spec->vectorcall = (vectorcallfunc)hooks.vectorcall;
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
    return H(spec);
}

int64_t jacpy_binding_property(uint64_t handle, int64_t index, const char *name,
        uint64_t (*get)(uint64_t, uint64_t),
        int32_t (*set)(uint64_t, uint64_t, uint64_t), uint64_t context, const char *doc) {
    JacTypeSpec *spec = P(handle);
    char *owned_name = strdup(name), *owned_doc = strdup(doc);
    if (!owned_name || !owned_doc) { free(owned_name); free(owned_doc); return -1; }
    spec->properties[index] = (PyGetSetDef){owned_name, (getter)get, (setter)set, owned_doc, P(context)};
    return 0;
}

uint64_t jacpy_binding_type_create(uint64_t handle, uint64_t module, uint64_t bases) {
    if (!handle) return H(PyErr_NoMemory());
    JacTypeSpec *spec = P(handle);
    return H(PyType_FromModuleAndSpec(P(module), &spec->definition, P(bases)));
}
uint64_t jacpy_binding_owner(uint64_t type, uint64_t module_definition) {
    JacModuleSpec *spec = P(module_definition);
    return H(PyType_GetModuleByDef(P(type), &spec->definition));
}
uint64_t jacpy_binding_typeof(uint64_t object) { return H(Py_TYPE((PyObject *)P(object))); }
int64_t jacpy_binding_basicsize(uint64_t object) { return Py_TYPE((PyObject *)P(object))->tp_basicsize; }
uint64_t jacpy_binding_allocate(uint64_t type) { return H(((PyTypeObject *)P(type))->tp_alloc(P(type), 0)); }
void jacpy_binding_free(uint64_t object) {
    PyTypeObject *type = Py_TYPE((PyObject *)P(object));
    type->tp_free(P(object));
    Py_DECREF(type);
}
uint64_t jacpy_binding_slot(uint64_t type, int64_t slot) { return H(PyType_GetSlot(P(type), (int)slot)); }
void jacpy_binding_untrack(uint64_t object) {
    if (PyObject_IS_GC((PyObject *)P(object))) PyObject_GC_UnTrack(P(object));
}
void jacpy_binding_clear_weakrefs(uint64_t object) {
    if (Py_TYPE((PyObject *)P(object))->tp_weaklistoffset) PyObject_ClearWeakRefs(P(object));
}
uint64_t jacpy_binding_generic_alias(uint64_t type, uint64_t argument) {
    return H(Py_GenericAlias(P(type), P(argument)));
}

uint64_t jacpy_binding_base(uint64_t type, uint64_t definition) {
    PyTypeObject *base = NULL;
    int found = PyType_GetBaseByToken(P(type), P(definition), &base);
    if (!found) PyErr_SetString(PyExc_TypeError, "object does not inherit the native binding type");
    return H(base);
}

static void **native_payload(uint64_t object, uint64_t definition) {
    PyTypeObject *base = P(jacpy_binding_base(jacpy_binding_typeof(object), definition));
    if (!base) return NULL;
    void **slot = PyObject_GetTypeData(P(object), base);
    Py_DECREF(base);
    return slot;
}

extern void jac_retain(void *);
extern void jac_release(void *);

void *jacpy_binding_module_native_get(uint64_t module) {
    JacModuleState *state = PyModule_GetState(P(module));
    void *value = state ? state->native : NULL;
    if (value) jac_retain(value);
    return value;
}
void jacpy_binding_module_native_set(uint64_t module, void *value) {
    JacModuleState *state = PyModule_GetState(P(module));
    void *previous = state->native;
    if (value) jac_retain(value);
    state->native = value;
    if (previous) jac_release(previous);
}
void jacpy_binding_module_native_clear(uint64_t module) {
    if (PyModule_GetState(P(module))) jacpy_binding_module_native_set(module, NULL);
}
int64_t jacpy_binding_module_native_present(uint64_t module) {
    JacModuleState *state = PyModule_GetState(P(module));
    return state && state->native;
}

void *jacpy_binding_native_get(uint64_t object, uint64_t definition) {
    void **slot = native_payload(object, definition);
    if (!slot) return NULL;
    void *state = *slot;
    if (state) jac_retain(state);
    return state;
}
int64_t jacpy_binding_native_set(uint64_t object, uint64_t definition, void *state) {
    void **slot = native_payload(object, definition);
    if (!slot) return -1;
    void *previous = *slot;
    if (state) jac_retain(state);
    *slot = state;
    JacTypeSpec *spec = P(definition);
    if (spec->vectorcall) ((JacInstancePayload *)slot)->vectorcall = spec->vectorcall;
    if (previous) jac_release(previous);
    return 0;
}
void jacpy_binding_native_clear(uint64_t object, uint64_t definition) {
    (void)jacpy_binding_native_set(object, definition, NULL);
}
int64_t jacpy_binding_native_present(uint64_t object, uint64_t definition) {
    void **slot = native_payload(object, definition);
    return slot && *slot;
}

int64_t jacpy_binding_vector_count(uint64_t count) { return PyVectorcall_NARGS((size_t)count); }
uint64_t jacpy_binding_vector_item(uint64_t arguments, int64_t index) {
    return H(((PyObject *const *)P(arguments))[index]);
}

/* Dictionary and descriptor primitives keep CPython's object layout opaque.
 * Relative dictionary slots preserve lazy allocation, including the distinction
 * between an untouched instance and an explicitly created empty dictionary. */
int32_t jacpy_binding_dict_visit(uint64_t object, uint64_t definition,
                                 uint64_t visitor, uint64_t context) {
    JacTypeSpec *spec = P(definition);
    if (!spec->instance_dict) return 0;
    PyObject **dict = _PyObject_GetDictPtr(P(object));
    return dict ? jacpy_binding_visit(H(*dict), visitor, context) : 0;
}
void jacpy_binding_dict_clear(uint64_t object, uint64_t definition) {
    JacTypeSpec *spec = P(definition);
    if (!spec->instance_dict) return;
    PyObject **dict = _PyObject_GetDictPtr(P(object));
    if (dict) Py_CLEAR(*dict);
}
int64_t jacpy_binding_dict_present(uint64_t object) {
    PyObject **dict = _PyObject_GetDictPtr(P(object));
    return dict && *dict;
}
uint64_t jacpy_binding_dict_peek(uint64_t object) {
    PyObject **dict = _PyObject_GetDictPtr(P(object));
    return H(dict ? Py_XNewRef(*dict) : NULL);
}
uint64_t jacpy_binding_dict_get(uint64_t object, uint64_t context) {
    return H(PyObject_GenericGetDict(P(object), P(context)));
}
int32_t jacpy_binding_dict_set(uint64_t object, uint64_t value, uint64_t context) {
    return PyObject_GenericSetDict(P(object), P(value), P(context));
}
int64_t jacpy_binding_dict_replace(uint64_t object, uint64_t dictionary) {
    PyObject **dict = _PyObject_GetDictPtr(P(object));
    if (!dict) { PyErr_SetString(PyExc_SystemError, "instance has no dictionary slot"); return -1; }
    Py_XSETREF(*dict, Py_XNewRef((PyObject *)P(dictionary)));
    return 0;
}
uint64_t jacpy_binding_method_bind(uint64_t callable, uint64_t instance) {
    return H(PyMethod_New(P(callable), P(instance)));
}
uint64_t jacpy_binding_marker(void) { return H(PyObject_CallNoArgs((PyObject *)&PyBaseObject_Type)); }

/* Invoke inherited opaque built-in slots without duplicating their layouts. */
int64_t jacpy_binding_type_matches(uint64_t type, uint64_t definition) {
    PyTypeObject *base = NULL;
    int found = PyType_GetBaseByToken(P(type), P(definition), &base);
    Py_XDECREF(base);
    return found;
}
int64_t jacpy_binding_matches(uint64_t object, uint64_t definition) {
    return jacpy_binding_type_matches(H(Py_TYPE((PyObject *)P(object))), definition);
}
uint64_t jacpy_binding_base_new(uint64_t base, uint64_t type, uint64_t args, uint64_t keywords) {
    return H(((PyTypeObject *)P(base))->tp_new(P(type), P(args), P(keywords)));
}
int32_t jacpy_binding_base_init(uint64_t base, uint64_t object, uint64_t args, uint64_t keywords) {
    return ((PyTypeObject *)P(base))->tp_init(P(object), P(args), P(keywords));
}
int32_t jacpy_binding_base_traverse(uint64_t base, uint64_t object, uint64_t visitor, uint64_t context) {
    return ((PyTypeObject *)P(base))->tp_traverse(P(object), (visitproc)P(visitor), P(context));
}
int32_t jacpy_binding_base_clear(uint64_t base, uint64_t object) {
    return ((PyTypeObject *)P(base))->tp_clear(P(object));
}
void jacpy_binding_base_dealloc(uint64_t base, uint64_t object) {
    ((PyTypeObject *)P(base))->tp_dealloc(P(object));
}
uint64_t jacpy_binding_object_state(uint64_t object) { return H(_PyObject_GetState(P(object))); }

uint64_t jacpy_binding_parent(uint64_t type, uint64_t definition) {
    PyTypeObject *base = P(jacpy_binding_base(type, definition));
    if (!base) return 0;
    PyTypeObject *parent = base->tp_base;
    Py_DECREF(base);
    return H(parent); /* borrowed from the input type's retained base chain */
}

/* Contiguous one-dimensional buffer metadata belongs to the individual export,
 * so format and shape pointers remain valid independently of later callbacks. */
typedef struct {
    uint64_t address;
    int64_t count, itemsize;
    int64_t readonly;
} JacBufferLayout;
typedef struct { Py_ssize_t shape; char format[]; } JacBufferExport;
int32_t jacpy_binding_buffer_fill(uint64_t view_handle, uint64_t object,
                                  JacBufferLayout layout, const char *format, int32_t flags) {
    Py_buffer *view = P(view_handle);
    if (!view) { PyErr_SetString(PyExc_BufferError, "view==NULL argument is obsolete"); return -1; }
    if (layout.count < 0 || layout.itemsize <= 0 || layout.count > PY_SSIZE_T_MAX / layout.itemsize) {
        PyErr_SetString(PyExc_BufferError, "invalid native buffer dimensions"); return -1;
    }
    size_t format_size = strlen(format) + 1;
    JacBufferExport *metadata = malloc(sizeof(*metadata) + format_size);
    if (!metadata) { PyErr_NoMemory(); return -1; }
    metadata->shape = layout.count;
    memcpy(metadata->format, format, format_size);
    if (PyBuffer_FillInfo(view, P(object), P(layout.address), layout.count * layout.itemsize,
                          (int)layout.readonly, flags) < 0) { free(metadata); return -1; }
    view->itemsize = layout.itemsize;
    view->format = flags & PyBUF_FORMAT ? metadata->format : NULL;
    view->shape = flags & PyBUF_ND ? &metadata->shape : NULL;
    view->strides = (flags & PyBUF_STRIDES) == PyBUF_STRIDES ? &view->itemsize : NULL;
    view->internal = metadata;
    return 0;
}
void jacpy_binding_buffer_dispose(uint64_t view_handle) {
    Py_buffer *view = P(view_handle);
    if (view) { free(view->internal); view->internal = NULL; }
}

/* Keep deeply linked Python ownership chains within CPython's destruction
 * budget. The entry callback is the actual tp_dealloc; body disposes once. */
void jacpy_binding_dealloc_guard(uint64_t object, void (*entry)(uint64_t),
                                 void (*body)(uint64_t)) {
    PyObject *op = P(object);
    PyObject_GC_UnTrack(op);
    Py_TRASHCAN_BEGIN(op, (destructor)entry)
    body(object);
    Py_TRASHCAN_END
}

uint64_t jacpy_binding_exception_with_base(const char *name, uint64_t base, const char *doc) {
    return H(PyErr_NewExceptionWithDoc(name, *doc ? doc : NULL, P(base), NULL));
}
