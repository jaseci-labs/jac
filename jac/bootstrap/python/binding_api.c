/* Opaque CPython ABI storage for native Jac binding declarations.
 * No module names, signatures, argument policy, or implementation callbacks
 * belong here. Definitions are constructed once by native static initialization
 * and, like CPython's static PyModuleDefs, live for the process lifetime. */
#include <Python.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

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
    spec->definition.m_size = state_count * sizeof(PyObject *);
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
    return PyModule_GetDef(P(module))->m_size / sizeof(PyObject *);
}
uint64_t jacpy_binding_state_get(uint64_t module, int64_t index) {
    PyObject **state = PyModule_GetState(P(module));
    return H(state[index]);
}
void jacpy_binding_state_set(uint64_t module, int64_t index, uint64_t value) {
    PyObject **state = PyModule_GetState(P(module));
    Py_XSETREF(state[index], Py_XNewRef((PyObject *)P(value)));
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
} JacTypeHooks;

typedef struct {
    JacMethodTable table;
    PyType_Spec definition;
    PyType_Slot slots[9];
    PyMethodDef methods[];
} JacTypeSpec;

void jacpy_binding_type_discard(uint64_t handle) {
    JacTypeSpec *spec = P(handle);
    if (!spec) return;
    discard_methods(&spec->table);
    free(spec);
}

uint64_t jacpy_binding_type(const char *name, const char *doc, int64_t count,
                           uint64_t flags, JacTypeHooks hooks) {
    JacTypeSpec *spec = calloc(1, sizeof(*spec) + (count + 1) * sizeof(PyMethodDef));
    if (!spec) return 0;
    spec->table = (JacMethodTable){strdup(name), strdup(doc), spec->methods};
    if (!spec->table.name || !spec->table.doc) {
        jacpy_binding_type_discard(H(spec));
        return 0;
    }
    spec->definition = (PyType_Spec){spec->table.name, -(int)sizeof(void *), 0, (unsigned int)flags, spec->slots};
    int slot = 0;
#define SLOT(field, id) if (hooks.field) spec->slots[slot++] = (PyType_Slot){id, (void *)hooks.field}
    SLOT(create, Py_tp_new);
    SLOT(initialize, Py_tp_init);
    SLOT(dealloc, Py_tp_dealloc);
    SLOT(traverse, Py_tp_traverse);
    SLOT(clear, Py_tp_clear);
#undef SLOT
    spec->slots[slot++] = (PyType_Slot){Py_tp_methods, spec->methods};
    spec->slots[slot++] = (PyType_Slot){Py_tp_doc, spec->table.doc};
    spec->slots[slot++] = (PyType_Slot){Py_tp_token, spec};
    return H(spec);
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
