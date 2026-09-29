"""Native declarations for Python heap types and their C ABI callbacks."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    Py_buffer,
    Py_TYPE,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyType_GetSlot
}
import from jaclang.runtime.python.bindings.module { MethodDefinition, install_methods }
import from jaclang.runtime.python.bindings.members { MemberField }

enum TypeFlags {
    DEFAULT = 0,
    IMMUTABLE = 256,
    BASETYPE = 1024,
    VECTORCALL = 2048,
    GC = 16384,
    MANAGED_WEAKREF = 8,
    DISALLOW_INSTANTIATION = 128,
    SEQUENCE = 32,
    METHOD_DESCRIPTOR = 131072
}

enum TypeSlot { DESCR_GET = 54, INIT = 60, NEW = 65 }

import from c {
    obj TypeHooks {
        has create:
            Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            initialize:
                Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0,
            dealloc: Callable[[ptr[PyObject]], None] = 0,
            traverse: Callable[[ptr[PyObject], ptr, ptr], i32] = 0,
            clear: Callable[[ptr[PyObject]], i32] = 0,
            call:
                Callable[
                    [ptr[PyObject], ptr[PyObject], ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            repr: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            vectorcall:
                Callable[
                    [ptr[PyObject], ptr, ptr[PyObject], ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            iter: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            next: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            descriptor:
                Callable[
                    [ptr[PyObject], ptr[PyObject], ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            compare: Callable[[ptr[PyObject], ptr[PyObject], i32], ptr[PyObject]] = 0,
            hash: Callable[[ptr[PyObject]], i64] = 0,
            descriptor_set:
                Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0,
            bit_or: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            length: Callable[[ptr[PyObject]], i64] = 0,
            item: Callable[[ptr[PyObject], i64], ptr[PyObject]] = 0,
            assign: Callable[[ptr[PyObject], i64, ptr[PyObject]], i32] = 0,
            contains: Callable[[ptr[PyObject], ptr[PyObject]], i32] = 0,
            concat: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            inplace_concat: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            repeat: Callable[[ptr[PyObject], i64], ptr[PyObject]] = 0,
            inplace_repeat: Callable[[ptr[PyObject], i64], ptr[PyObject]] = 0,
            mapping_length: Callable[[ptr[PyObject]], i64] = 0,
            subscript: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            assign_subscript:
                Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0,
            buffer: Callable[[ptr[PyObject], ptr[Py_buffer], i32], i32] = 0,
            release_buffer: Callable[[ptr[PyObject], ptr[Py_buffer]], None] = 0,
            get_attribute: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            set_attribute:
                Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0,
            string: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            finalize: Callable[[ptr[PyObject]], None] = 0;
    }  def jacpy_binding_type(
        name: str,
        doc: str,
        count: i64,
        flags: u64,
        hooks: TypeHooks,
        property_count: i64,
        instance_dict: i64,
        unhashable: i64,
        field_count: i64,
        record_size: i64,
        options: i64
    ) -> ptr;  def jacpy_binding_member(
        handle: ptr,
        index: i64,
        name: str,
        type: i64,
        offset: i64,
        readonly: i64,
        doc: str,
        has_doc: i64
    ) -> i64;  def jacpy_binding_record(
        object: ptr[PyObject], definition: ptr
    ) -> ptr;  def jacpy_binding_type_discard(handle: ptr);  def jacpy_binding_type_create(
        handle: ptr, module: ptr[PyObject], bases: ptr[PyObject]
    ) -> ptr[PyObject];  def jacpy_binding_owner(
        type: ptr[PyObject], module_definition: ptr
    ) -> ptr[PyObject];  def jacpy_binding_allocate(
        type: ptr[PyObject]
    ) -> ptr[PyObject];  def jacpy_binding_free(object: ptr[PyObject]);  def jacpy_binding_base(
        type: ptr[PyObject], definition: ptr
    ) -> ptr[PyObject];  def jacpy_binding_property(
        handle: ptr,
        index: i64,
        name: str,
        read: Callable[[ptr[PyObject], u64], ptr[PyObject]],
        write: Callable[[ptr[PyObject], ptr[PyObject], u64], i32],
        context: u64,
        doc: str
    ) -> i64;
}

import from c {
    obj PropertyCallbacks {
        has read: Callable[[ptr[PyObject], u64], ptr[PyObject]] = 0,
            write: Callable[[ptr[PyObject], ptr[PyObject], u64], i32] = 0;
    }
}

obj PropertyDefinition {
    has name: str,
        callbacks: PropertyCallbacks,
        context: u64 = 0,
        doc: str = "";
}

obj TypeDefinition {
    has handle: ptr = NULL;

    def init(
        name: str,
        doc: str,
        methods: list[MethodDefinition],
        flags: u64,
        hooks: TypeHooks,
        properties: (list[PropertyDefinition] | None) = None,
        instance_dict: bool = False,
        unhashable: bool = False,
        members: (list[MemberField] | None) = None,
        record_size: int = 0,
        weaklist: bool = False,
        generic_getattr: bool = False,
        generic_setattr: bool = False
    ) {
        declarations: list[PropertyDefinition] = properties
            if properties is not None
            else [];
        fields: list[MemberField] = members if members is not None else [];
        self.handle = jacpy_binding_type(
            name,
            doc,
            i64(len(methods)),
            flags,
            hooks,
            i64(len(declarations)),
            i64(instance_dict),
            i64(unhashable),
            i64(len(fields)),
            i64(record_size),
            # JAC_TYPE_WEAKLIST, JAC_TYPE_GENERIC_GETATTR, JAC_TYPE_GENERIC_SETATTR.
            i64(int(weaklist) | int(generic_getattr) << 1 | int(generic_setattr) << 2)
        );
        if self.handle and not install_methods(self.handle, methods) {
            jacpy_binding_type_discard(self.handle);
            self.handle = ptr();
        }
        if not self.handle {
            return;
        }
        for index in range(len(fields)) {
            field = fields[index];
            if jacpy_binding_member(
                self.handle,
                i64(index),
                field.name,
                i64(field.kind),
                i64(field.offset),
                i64(field.readonly),
                field.doc or "",
                i64(field.doc is not None)
            )
                < 0 {
                jacpy_binding_type_discard(self.handle);
                self.handle = ptr();
                return;
            }
        }
        for index in range(len(declarations)) {
            property = declarations[index];
            if jacpy_binding_property(
                self.handle,
                i64(index),
                property.name,
                property.callbacks.read,
                property.callbacks.write,
                property.context,
                property.doc
            )
                < 0 {
                jacpy_binding_type_discard(self.handle);
                self.handle = ptr();
                return;
            }
        }
    }

    def create(module: ptr[PyObject], bases: ptr[PyObject] = 0) -> ptr[PyObject] {
        return jacpy_binding_type_create(self.handle, module, bases);
    }
}

import from c {
    def jacpy_binding_dict_visit(
        object: ptr[PyObject], definition: ptr, visitor: ptr, context: ptr
    ) -> i32;  def jacpy_binding_dict_clear(object: ptr[PyObject], definition: ptr);  def jacpy_binding_dict_present(
        object: ptr[PyObject]
    ) -> i64;  def jacpy_binding_dict_peek(object: ptr[PyObject]) -> ptr[PyObject];  def jacpy_binding_dict_replace(
        object: ptr[PyObject], dictionary: ptr[PyObject]
    ) -> i64;
}

import from c {
    def jacpy_binding_basicsize(object: ptr[PyObject]) -> i64;  def jacpy_binding_matches(
        object: ptr[PyObject], definition: ptr
    ) -> i64;  def jacpy_binding_base_new(
        base: ptr[PyObject],
        type: ptr[PyObject],
        args: ptr[PyObject],
        keywords: ptr[PyObject]
    ) -> ptr[PyObject];  def jacpy_binding_base_init(
        base: ptr[PyObject],
        object: ptr[PyObject],
        args: ptr[PyObject],
        keywords: ptr[PyObject]
    ) -> i32;  def jacpy_binding_base_traverse(
        base: ptr[PyObject], object: ptr[PyObject], visitor: ptr, context: ptr
    ) -> i32;  def jacpy_binding_base_clear(
        base: ptr[PyObject], object: ptr[PyObject]
    ) -> i32;  def jacpy_binding_base_dealloc(
        base: ptr[PyObject], object: ptr[PyObject]
    );
}

import from c {
    def jacpy_binding_parent(type: ptr[PyObject], definition: ptr) -> ptr[PyObject];
}

import from c {
    def jacpy_binding_type_matches(type: ptr[PyObject], definition: ptr) -> i64;
    # The binding definition nearest to `type` along its tp_base chain.
    def jacpy_binding_token(type: ptr[PyObject]) -> ptr;
}

import from c {
    # A cell holding a tp_descr_get slot, so the slot can be called.
    obj DescriptorGetSlot {
        has call:
            Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }
}

# type(descriptor)->tp_descr_get(descriptor, instance, owner), called directly
# as C code calls the slot. A new reference, or NULL with the exception set;
# NULL with no exception when the type has no __get__.
def descriptor_get(
    descriptor: ptr[PyObject], instance: ptr[PyObject], owner: ptr[PyObject]
) -> ptr[PyObject] {
    slot = PyType_GetSlot(Py_TYPE(descriptor), i32(TypeSlot.DESCR_GET.value));
    if not slot {
        return NULL;
    }
    cell = ptr[u64](PyMem_Malloc(8));
    if not cell {
        return NULL;
    }
    cell.view(1)[0] = u64(int(slot));
    result = ptr[DescriptorGetSlot](cell).view(1)[0].call(descriptor, instance, owner);
    PyMem_Free(cell);
    return result;
}
