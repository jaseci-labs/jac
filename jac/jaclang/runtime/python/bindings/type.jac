"""Native declarations for Python heap types and their C ABI callbacks."""
import from jaclang.runtime.python.bindings.module { MethodDefinition, install_methods }

enum TypeFlags {
    DEFAULT = 0,
    IMMUTABLE = 256,
    BASETYPE = 1024,
    VECTORCALL = 2048,
    GC = 16384,
    MANAGED_WEAKREF = 8,
    DISALLOW_INSTANTIATION = 128,
    SEQUENCE = 32
}

enum TypeSlot { INIT = 60, NEW = 65 }

import from c {
    obj TypeHooks {
        has create: Callable[[u64, u64, u64], u64] = 0,
            initialize: Callable[[u64, u64, u64], i32] = 0,
            dealloc: Callable[[u64], None] = 0,
            traverse: Callable[[u64, u64, u64], i32] = 0,
            clear: Callable[[u64], i32] = 0,
            call: Callable[[u64, u64, u64], u64] = 0,
            repr: Callable[[u64], u64] = 0,
            vectorcall: Callable[[u64, u64, u64, u64], u64] = 0,
            iter: Callable[[u64], u64] = 0,
            next: Callable[[u64], u64] = 0,
            descriptor: Callable[[u64, u64, u64], u64] = 0,
            compare: Callable[[u64, u64, i32], u64] = 0,
            hash: Callable[[u64], i64] = 0,
            descriptor_set: Callable[[u64, u64, u64], i32] = 0,
            bit_or: Callable[[u64, u64], u64] = 0,
            length: Callable[[u64], i64] = 0,
            item: Callable[[u64, i64], u64] = 0,
            assign: Callable[[u64, i64, u64], i32] = 0,
            contains: Callable[[u64, u64], i32] = 0,
            concat: Callable[[u64, u64], u64] = 0,
            inplace_concat: Callable[[u64, u64], u64] = 0,
            repeat: Callable[[u64, i64], u64] = 0,
            inplace_repeat: Callable[[u64, i64], u64] = 0,
            mapping_length: Callable[[u64], i64] = 0,
            subscript: Callable[[u64, u64], u64] = 0,
            assign_subscript: Callable[[u64, u64, u64], i32] = 0,
            buffer: Callable[[u64, u64, i32], i32] = 0,
            release_buffer: Callable[[u64, u64], None] = 0,
            get_attribute: Callable[[u64, u64], u64] = 0,
            set_attribute: Callable[[u64, u64, u64], i32] = 0;
    }  def jacpy_binding_type(
        name: str,
        doc: str,
        count: i64,
        flags: u64,
        hooks: TypeHooks,
        property_count: i64,
        instance_dict: i64,
        unhashable: i64
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
        properties: (list[PropertyDefinition] | None) = None,
        instance_dict: bool = False,
        unhashable: bool = False
    ) {
        declarations: list[PropertyDefinition] = properties
            if properties is not None
            else [];
        self.handle = jacpy_binding_type(
            name,
            doc,
            i64(len(methods)),
            flags,
            hooks,
            i64(len(declarations)),
            i64(instance_dict),
            i64(unhashable)
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

import from c {
    def jacpy_binding_dict_visit(
        object: u64, definition: u64, visitor: u64, context: u64
    ) -> i32;  def jacpy_binding_dict_clear(object: u64, definition: u64);  def jacpy_binding_dict_present(
        object: u64
    ) -> i64;  def jacpy_binding_dict_peek(object: u64) -> u64;  def jacpy_binding_dict_get(
        object: u64, context: u64
    ) -> u64;  def jacpy_binding_dict_set(
        object: u64, value: u64, context: u64
    ) -> i32;  def jacpy_binding_dict_replace(object: u64, dictionary: u64) -> i64;  def jacpy_binding_method_bind(
        callable: u64, instance: u64
    ) -> u64;  def jacpy_binding_marker -> u64;
}

import from c {
    def jacpy_binding_generic_alias(type: u64, item: u64) -> u64;  def jacpy_binding_basicsize(
        object: u64
    ) -> i64;  def jacpy_binding_matches(object: u64, definition: u64) -> i64;  def jacpy_binding_base_new(
        base: u64, type: u64, args: u64, keywords: u64
    ) -> u64;  def jacpy_binding_base_init(
        base: u64, object: u64, args: u64, keywords: u64
    ) -> i32;  def jacpy_binding_base_traverse(
        base: u64, object: u64, visitor: u64, context: u64
    ) -> i32;  def jacpy_binding_base_clear(base: u64, object: u64) -> i32;  def jacpy_binding_base_dealloc(
        base: u64, object: u64
    );  def jacpy_binding_object_state(object: u64) -> u64;
}

import from c { def jacpy_binding_parent(type: u64, definition: u64) -> u64;  }

import from c { def jacpy_binding_type_matches(type: u64, definition: u64) -> i64;  }
