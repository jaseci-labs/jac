"""Native declarations for Python heap types and their C ABI callbacks."""
import from jaclang.runtime.python.bindings.module { MethodDefinition, install_methods }

enum TypeFlags {
    DEFAULT = 0,
    IMMUTABLE = 256,
    BASETYPE = 1024,
    GC = 16384,
    MANAGED_WEAKREF = 8
}

enum TypeSlot { INIT = 60, NEW = 65 }

import from c {
    obj TypeHooks {
        has create: Callable[[u64, u64, u64], u64] = 0,
            initialize: Callable[[u64, u64, u64], i32] = 0,
            dealloc: Callable[[u64], None] = 0,
            traverse: Callable[[u64, u64, u64], i32] = 0,
            clear: Callable[[u64], i32] = 0,
            call: Callable[[u64, u64, u64], u64] = 0;
    }  def jacpy_binding_type(
        name: str,
        doc: str,
        count: i64,
        flags: u64,
        hooks: TypeHooks,
        property_count: i64
    ) -> u64;  def jacpy_binding_type_discard(handle: u64);  def jacpy_binding_type_create(
        handle: u64, module: u64, bases: u64
    ) -> u64;  def jacpy_binding_owner(type: u64, module_definition: u64) -> u64;  def jacpy_binding_typeof(
        object: u64
    ) -> u64;  def jacpy_binding_allocate(type: u64) -> u64;  def jacpy_binding_free(
        object: u64
    );  def jacpy_binding_slot(type: u64, slot: i64) -> u64;  def jacpy_binding_base(
        type: u64, definition: u64
    ) -> u64;  def jacpy_binding_property(
        handle: u64,
        index: i64,
        name: str,
        read: Callable[[u64, u64], u64],
        write: Callable[[u64, u64, u64], i32],
        context: u64,
        doc: str
    ) -> i64;
}

obj PropertyDefinition {
    has name: str,
        read: Callable[[u64, u64], u64],
        context: u64 = 0,
        write: Callable[[u64, u64, u64], i32] = 0,
        doc: str = "";
}

obj TypeDefinition {
    has handle: u64 = 0;

    def init(
        name: str,
        doc: str,
        methods: list[MethodDefinition],
        flags: u64,
        hooks: TypeHooks,
        properties: (list[PropertyDefinition] | None) = None
    ) {
        declarations: list[PropertyDefinition] = properties
            if properties is not None
            else [];
        self.handle = jacpy_binding_type(
            name, doc, i64(len(methods)), flags, hooks, i64(len(declarations))
        );
        if self.handle != 0 and not install_methods(self.handle, methods) {
            jacpy_binding_type_discard(self.handle);
            self.handle = 0;
        }
        if self.handle == 0 {
            return;
        }
        for index in range(len(declarations)) {
            property = declarations[index];
            if jacpy_binding_property(
                self.handle,
                i64(index),
                property.name,
                property.read,
                property.write,
                property.context,
                property.doc
            )
                < 0 {
                jacpy_binding_type_discard(self.handle);
                self.handle = 0;
                return;
            }
        }
    }

    def create(module: u64, bases: u64 = 0) -> u64 {
        return jacpy_binding_type_create(self.handle, module, bases);
    }
}
