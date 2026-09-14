"""Native module declarations. C stores only CPython's opaque ABI records.

Declarations contain no Python objects and are constructed once during native
initialization. The immutable records can be shared by isolated interpreters.
"""
import from jaclang.runtime.python.capi { jacpy_release }
import from jaclang.runtime.python.bindings.state { NativeState }
import from c {
    obj ModuleHooks {
        has execute: Callable[[u64], i32] = 0,
            traverse: Callable[[u64, u64, u64], i32] = 0,
            clear: Callable[[u64], i32] = 0,
            free: Callable[[u64], None] = 0;
    }  def jacpy_binding_module(
        name: str, doc: str, count: i64, hooks: ModuleHooks, state_count: i64
    ) -> u64;  def jacpy_binding_add(module: u64, name: str, value: u64) -> i64;  def jacpy_binding_method(
        module: u64,
        index: i64,
        name: str,
        keywords: Callable[[u64, u64, u64], u64],
        positional: Callable[[u64, u64], u64],
        flags: i64,
        doc: str
    ) -> i64;  def jacpy_binding_discard(module: u64);  def jacpy_binding_init(
        module: u64
    ) -> u64;  def jacpy_binding_state_count(module: u64) -> i64;  def jacpy_binding_state_get(
        module: u64, index: i64
    ) -> u64;  def jacpy_binding_state_set(module: u64, index: i64, value: u64);  def jacpy_binding_visit(
        value: u64, visitor: u64, context: u64
    ) -> i32;  def jacpy_binding_exception(name: str, base: str, doc: str) -> u64;
}

import from c {
    def jacpy_binding_module_native_get(module: u64) -> NativeState;  def jacpy_binding_module_native_set(
        module: u64, state: NativeState
    );  def jacpy_binding_module_native_clear(module: u64);  def jacpy_binding_module_native_present(
        module: u64
    ) -> i64;
}

def traverse_state(module: u64, visitor: u64, context: u64) -> i32 {
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

def clear_state(module: u64) -> i32 {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        state.clear();
        jacpy_binding_module_native_clear(module);
    }
    for index in range(int(jacpy_binding_state_count(module))) {
        jacpy_binding_state_set(module, i64(index), 0);
    }
    return i32(0);
}

def free_state(module: u64) {
    clear_state(module);
}

import from c {
    obj MethodCallbacks {
        has keywords: Callable[[u64, u64, u64], u64] = 0,
            positional: Callable[[u64, u64], u64] = 0;
    }
}

obj MethodDefinition {
    has name: str,
        callbacks: MethodCallbacks,
        doc: str,
        flags: i64 = 3;
}

def install_methods(handle: u64, methods: list[MethodDefinition]) -> bool {
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
    has handle: u64 = 0;

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
        if self.handle == 0 {
            return;
        }
        if not install_methods(self.handle, methods) {
            jacpy_binding_discard(self.handle);
            self.handle = 0;
        }
    }

    def initialize -> u64 {
        return jacpy_binding_init(self.handle);
    }
}

def add_state_owned(module: u64, index: int, name: str, value: u64) -> bool {
    if value == 0 {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), value);
    return add_owned(module, name, value);
}

def add_owned(module: u64, name: str, value: u64) -> bool {
    if value == 0 {
        return False;
    }
    result = jacpy_binding_add(module, name, value);
    jacpy_release(value);
    return result == 0;
}

import from c {
    def jacpy_binding_exception_with_base(name: str, base: u64, doc: str) -> u64;
}
