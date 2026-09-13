"""Native module declarations. C stores only CPython's opaque ABI records.

Declarations contain no Python objects and are constructed once during native
initialization. The immutable records can be shared by isolated interpreters.
"""
import from jaclang.runtime.python.capi { jacpy_release }
import from c {
    obj ModuleHooks {
        has execute: Callable[[u64], i32] = 0;
    }  def jacpy_binding_module(
        name: str, doc: str, count: i64, hooks: ModuleHooks
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
    ) -> u64;
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
        hooks: ModuleHooks = ModuleHooks()
    ) {
        self.handle = jacpy_binding_module(name, doc, i64(len(methods)), hooks);
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

def add_owned(module: u64, name: str, value: u64) -> bool {
    if value == 0 {
        return False;
    }
    result = jacpy_binding_add(module, name, value);
    jacpy_release(value);
    return result == 0;
}
