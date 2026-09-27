"""Native module declarations. C stores only CPython's opaque ABI records.

Declarations contain no Python objects and are constructed once during native
initialization. The immutable records can be shared by isolated interpreters.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyModule_AddObjectRef,
    PyObject,
    jacpy_release
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from c {
    obj ModuleHooks {
        has execute: Callable[[ptr[PyObject]], i32] = 0,
            traverse: Callable[[ptr[PyObject], ptr, ptr], i32] = 0,
            clear: Callable[[ptr[PyObject]], i32] = 0,
            free: Callable[[ptr[PyObject]], None] = 0;
    }  def jacpy_binding_module(
        name: str, doc: str, count: i64, hooks: ModuleHooks, state_count: i64
    ) -> ptr;  def jacpy_binding_method(
        handle: ptr,
        index: i64,
        name: str,
        keywords:
            Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]],
        positional: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]],
        flags: i64,
        doc: str
    ) -> i64;  def jacpy_binding_discard(handle: ptr);  def jacpy_binding_init(
        handle: ptr
    ) -> ptr[PyObject];  def jacpy_binding_state_count(module: ptr[PyObject]) -> i64;  def jacpy_binding_state_get(
        module: ptr[PyObject], index: i64
    ) -> ptr[PyObject];  def jacpy_binding_state_set(
        module: ptr[PyObject], index: i64, value: ptr[PyObject]
    );  def jacpy_binding_visit(
        value: ptr[PyObject], visitor: ptr, context: ptr
    ) -> i32;  def jacpy_binding_exception(
        name: str, base: str, doc: str
    ) -> ptr[PyObject];
}

import from c {
    def jacpy_binding_module_native_get(module: ptr[PyObject]) -> NativeState;  def jacpy_binding_module_native_set(
        module: ptr[PyObject], state: NativeState
    );  def jacpy_binding_module_native_clear(module: ptr[PyObject]);  def jacpy_binding_module_native_present(
        module: ptr[PyObject]
    ) -> i64;
}

def traverse_state(module: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        status = state.traverse_refs(visitor, context);
        if status != 0 {
            return status;
        }
    }
    for index in range(int(jacpy_binding_state_count(module))) {
        result = jacpy_binding_visit(
            jacpy_binding_state_get(module, i64(index)), visitor, context
        );
        if result != 0 {
            return result;
        }
    }
    return i32(0);
}

def clear_state(module: ptr[PyObject]) -> i32 {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        state.clear();
        jacpy_binding_module_native_clear(module);
    }
    for index in range(int(jacpy_binding_state_count(module))) {
        jacpy_binding_state_set(module, i64(index), NULL);
    }
    return i32(0);
}

def free_state(module: ptr[PyObject]) {
    clear_state(module);
}

import from c {
    obj MethodCallbacks {
        has keywords:
            Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            positional: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }
}

obj MethodDefinition {
    has name: str,
        callbacks: MethodCallbacks,
        doc: str,
        flags: i64 = 3;
}

def install_methods(handle: ptr, methods: list[MethodDefinition]) -> bool {
    for index in range(len(methods)) {
        method = methods[index];
        if jacpy_binding_method(
            handle,
            i64(index),
            method.name,
            method.callbacks.keywords,
            method.callbacks.positional,
            method.flags,
            method.doc
        )
            < 0 {
            return False;
        }
    }
    return True;
}

obj ModuleDefinition {
    has handle: ptr = NULL;

    def init(
        name: str,
        doc: str,
        methods: list[MethodDefinition],
        hooks: ModuleHooks = ModuleHooks(),
        state_count: int = 0
    ) {
        lifecycle = ModuleHooks(
            execute=hooks.execute,
            traverse=traverse_state,
            clear=clear_state,
            free=free_state
        );
        self.handle = jacpy_binding_module(
            name, doc, i64(len(methods)), lifecycle, i64(state_count)
        );
        if not self.handle {
            return;
        }
        if not install_methods(self.handle, methods) {
            jacpy_binding_discard(self.handle);
            self.handle = ptr();
        }
    }

    def initialize -> ptr[PyObject] {
        return jacpy_binding_init(self.handle);
    }
}

def add_state_owned(
    module: ptr[PyObject], index: int, name: str, value: ptr[PyObject]
) -> bool {
    if value == 0 {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), value);
    return add_owned(module, name, value);
}

def add_owned(module: ptr[PyObject], name: str, value: ptr[PyObject]) -> bool {
    if value == 0 {
        return False;
    }
    result = PyModule_AddObjectRef(module, name, value);
    jacpy_release(value);
    return result == 0;
}

import from c {
    def jacpy_binding_exception_with_base(
        name: str, base: ptr[PyObject], doc: str
    ) -> ptr[PyObject];
}
