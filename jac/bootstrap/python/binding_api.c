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
    PyModuleDef definition;
    PyModuleDef_Slot slots[4];
    PyMethodDef methods[];
} JacModuleSpec;

void jacpy_binding_discard(uint64_t handle) {
    JacModuleSpec *spec = P(handle);
    if (!spec) return;
    free((void *)spec->definition.m_name);
    free((void *)spec->definition.m_doc);
    for (PyMethodDef *method = spec->methods; method->ml_name; method++) {
        free((void *)method->ml_name);
        free((void *)method->ml_doc);
    }
    free(spec);
}

uint64_t jacpy_binding_module(const char *name, const char *doc, int64_t count,
                             JacModuleHooks hooks, int64_t state_count) {
    JacModuleSpec *spec = calloc(1, sizeof(*spec) + (count + 1) * sizeof(PyMethodDef));
    if (!spec) return 0;
    PyModuleDef initial = {PyModuleDef_HEAD_INIT};
    spec->definition = initial;
    spec->definition.m_name = strdup(name);
    spec->definition.m_doc = strdup(doc);
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
    JacModuleSpec *spec = P(handle);
    PyMethodDef *method = &spec->methods[index];
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
uint64_t jacpy_binding_exception(const char *name, const char *base) {
    extern PyObject *jacpy_exception_type(const char *);
    return H(PyErr_NewException(name, *base ? jacpy_exception_type(base) : NULL, NULL));
}
