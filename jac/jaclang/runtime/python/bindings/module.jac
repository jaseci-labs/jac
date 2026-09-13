"""Native module declarations. C stores only CPython's opaque ABI records.

Declarations contain no Python objects and are constructed once during native
initialization. The immutable records can be shared by isolated interpreters.
"""
import from jaclang.runtime.python.capi { jacpy_release }
import from c {
    obj ModuleHooks {
        has execute: Callable[[u64], i32] = 0;
        has traverse: Callable[[u64, u64, u64], i32] = 0;
        has clear: Callable[[u64], i32] = 0;
        has free: Callable[[u64], None] = 0;
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
    ) -> i32;  def jacpy_binding_exception(name: str, base: str) -> u64;
}

def traverse_state(module: u64, visitor: u64, context: u64) -> i32 {
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
    for index in range(int(jacpy_binding_state_count(module))) {
        jacpy_binding_state_set(module, i64(index), 0);
    }
    return i32(0);
}

def free_state(module: u64) {
    clear_state(module);
}

obj MethodDefinition {
    has name: str,
        callback: Callable[[u64, u64, u64], u64],
        doc: str,
        positional: Callable[[u64, u64], u64] = 0,
        flags: i64 = 3;
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
        for index in range(len(methods)) {
            method = methods[index];
            if jacpy_binding_method(
                self.handle,
                i64(index),
                method.name,
                method.callback,
                method.positional,
                method.flags,
                method.doc
            )
                < 0 {
                jacpy_binding_discard(self.handle);
                self.handle = 0;
                return;
            }
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
