import from c {
    def calloc(count: u64, size: u64) -> ptr;  def malloc(size: u64) -> ptr;  def free(
        p: ptr
    );  def strdup(text: ptr[u8]) -> ptr[u8];  def strlen(text: ptr[u8]) -> u64;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def jac_retain(value: ptr);  def jac_release(value: ptr);  def PyModuleDef_Init(
        definition: ptr[ModuleDef]
    ) -> ptr[PyObject];  def PyCFunction_NewEx(
        method: ptr[PyMethodDef], receiver: ptr[PyObject], module: ptr[PyObject]
    ) -> ptr[PyObject];  def PyModule_GetState(module: ptr[PyObject]) -> ptr;  def PyModule_GetDef(
        module: ptr[PyObject]
    ) -> ptr[ModuleDef];  def PyErr_NewExceptionWithDoc(
        name: ptr[u8], doc: ptr[u8], base: ptr[PyObject], dict_: ptr[PyObject]
    ) -> ptr[PyObject];  def PyType_FromModuleAndSpec(
        module: ptr[PyObject], spec: ptr[PyType_Spec], bases: ptr[PyObject]
    ) -> ptr[PyObject];  def PyType_GetModuleByDef(
        type: ptr[PyTypeObject], definition: ptr[ModuleDef]
    ) -> ptr[PyObject];  def PyObject_ClearWeakRefs(object_: ptr[PyObject]);  def PyType_GetBaseByToken(
        type: ptr[PyTypeObject], token: ptr, result: ptr[ptr[PyTypeObject]]
    ) -> i32;  def PyObject_GetTypeData(
        object_: ptr[PyObject], type: ptr[PyTypeObject]
    ) -> ptr;  def _PyObject_GetDictPtr(object_: ptr[PyObject]) -> ptr[ptr[PyObject]];  def PyObject_HashNotImplemented(
        object_: ptr[PyObject]
    ) -> i64;  def PyObject_GenericGetAttr(
        object_: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_GenericSetAttr(
        object_: ptr[PyObject], name: ptr[PyObject], value: ptr[PyObject]
    ) -> i32;  def PyVectorcall_Call(
        callable: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
    ) -> ptr[PyObject];  def PyBuffer_FillInfo(
        view: ptr[Py_buffer],
        o: ptr[PyObject],
        buf: ptr,
        len: i64,
        readonly: i32,
        flags: i32
    ) -> i32;  def PyObject_IS_GC(object_: ptr[PyObject]) -> i32;  def PyObject_GC_UnTrack(
        object_: ptr
    );  obj BindingModuleHooks {
        has execute: ptr,
            traverse: ptr,
            clear: ptr,
            free: ptr;
    }  obj BindingTypeHooks {
        has create: ptr,
            initialize: ptr,
            dealloc: ptr,
            traverse: ptr,
            clear: ptr,
            call: ptr,
            repr: ptr,
            vectorcall: ptr,
            iter: ptr,
            next: ptr,
            descriptor: ptr,
            compare: ptr,
            hash: ptr,
            descriptor_set: ptr,
            bit_or: ptr,
            length: ptr,
            item: ptr,
            assign: ptr,
            contains: ptr,
            concat: ptr,
            inplace_concat: ptr,
            repeat: ptr,
            inplace_repeat: ptr,
            mapping_length: ptr,
            subscript: ptr,
            assign_subscript: ptr,
            buffer: ptr,
            release_buffer: ptr,
            get_attribute: ptr,
            set_attribute: ptr,
            string: ptr,
            finalize: ptr,
            boolean: ptr;
    }  obj BindingBufferLayout {
        has address: ptr,
            count: i64,
            itemsize: i64,
            readonly: i64;
    }  obj BindingMethodTable {
        has name: ptr[u8],
            doc: ptr[u8],
            entries: ptr[PyMethodDef];
    }  obj BindingTypeSpec {
        has table: BindingMethodTable,
            definition: PyType_Spec,
            vectorcall: ptr,
            instance_dict: i64,
            field_count: i64,
            members: ptr[PyMemberDef],
            properties: ptr[PyGetSetDef],
            slots: ptr[PyType_Slot];
    }  obj BindingPayload {
        has state: ptr,
            vectorcall: ptr,
            dictionary: ptr[PyObject],
            weaklist: ptr[PyObject];
    }  obj BindingCalls {
        has visit_call: Callable[[ptr[PyObject], ptr], i32] = 0,
            dealloc: Callable[[ptr[PyObject]], None] = 0,
            traverse: Callable[[ptr[PyObject], ptr, ptr], i32] = 0;
    }
}

glob:priv PYMETHODDEF_SIZE: Final[u64] = u64(32),
     METHOD_TABLE_SIZE: Final[i64] = 24,
     MODULE_SPEC_DEFINITION: Final[i64] = 24,
     MODULE_SPEC_SLOTS: Final[i64] = 128,
     MODULE_SPEC_SIZE: Final[i64] = 192,
     TYPE_SPEC_DEFINITION: Final[i64] = 24,
     BindingTypeSpec_SIZE_BYTES: Final[i64] = 104,
     BUFFER_ITEMSIZE: Final[i64] = 24,
     PYMEMBERDEF_SIZE: Final[u64] = u64(40),
     PYGETSETDEF_SIZE: Final[u64] = u64(40),
     PYTYPE_SLOT_SIZE: Final[u64] = u64(16),
     TYPE_SLOT_CAPACITY: Final[u64] = u64(45),
     PAYLOAD_SIZE: Final[i64] = 32,
     PAYLOAD_VECTORCALL: Final[i64] = 8,
     PAYLOAD_DICTIONARY: Final[i64] = 16,
     PAYLOAD_WEAKLIST: Final[i64] = 24,
     METH_KEYWORDS_FLAG: Final[i64] = 2,
     METH_FASTCALL_FLAG: Final[i64] = 128,
     T_PYSSIZET: Final[i32] = 19,
     READONLY_FLAG: Final[i32] = 1,
     RELATIVE_OFFSET_FLAG: Final[i32] = 8,
     MOD_EXEC: Final[i32] = 2,
     MOD_MULTIPLE_INTERPRETERS: Final[i32] = 3,
     MOD_GIL: Final[i32] = 4,
     MOD_PER_INTERPRETER_GIL_SUPPORTED: Final[i64] = 2,
     MOD_GIL_USED: Final[i64] = 0,
     TYPE_WEAKLIST: Final[i64] = 1,
     TYPE_GENERIC_GETATTR: Final[i64] = 2,
     TYPE_GENERIC_SETATTR: Final[i64] = 4,
     PYBUF_FORMAT_FLAG: Final[i32] = 4,
     PYBUF_ND_FLAG: Final[i32] = 8,
     PYBUF_STRIDES_FLAG: Final[i32] = 24,
     PY_SSIZE_T_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF,
     SLOT_TP_NEW: Final[i32] = 65,
     SLOT_TP_INIT: Final[i32] = 60,
     SLOT_TP_DEALLOC: Final[i32] = 52,
     SLOT_TP_TRAVERSE: Final[i32] = 71,
     SLOT_TP_CLEAR: Final[i32] = 51,
     SLOT_TP_CALL: Final[i32] = 50,
     SLOT_TP_REPR: Final[i32] = 66,
     SLOT_TP_ITER: Final[i32] = 62,
     SLOT_TP_ITERNEXT: Final[i32] = 63,
     SLOT_TP_DESCR_GET: Final[i32] = 54,
     SLOT_TP_RICHCOMPARE: Final[i32] = 67,
     SLOT_TP_DESCR_SET: Final[i32] = 55,
     SLOT_NB_OR: Final[i32] = 31,
     SLOT_SQ_LENGTH: Final[i32] = 45,
     SLOT_SQ_ITEM: Final[i32] = 44,
     SLOT_SQ_ASS_ITEM: Final[i32] = 39,
     SLOT_SQ_CONTAINS: Final[i32] = 41,
     SLOT_SQ_CONCAT: Final[i32] = 40,
     SLOT_SQ_INPLACE_CONCAT: Final[i32] = 42,
     SLOT_SQ_REPEAT: Final[i32] = 46,
     SLOT_SQ_INPLACE_REPEAT: Final[i32] = 43,
     SLOT_MP_LENGTH: Final[i32] = 4,
     SLOT_MP_SUBSCRIPT: Final[i32] = 5,
     SLOT_MP_ASS_SUBSCRIPT: Final[i32] = 3,
     SLOT_BF_GETBUFFER: Final[i32] = 1,
     SLOT_BF_RELEASEBUFFER: Final[i32] = 2,
     SLOT_TP_GETATTRO: Final[i32] = 58,
     SLOT_TP_SETATTRO: Final[i32] = 69,
     SLOT_TP_STR: Final[i32] = 70,
     SLOT_TP_FINALIZE: Final[i32] = 80,
     SLOT_NB_BOOL: Final[i32] = 9,
     SLOT_TP_HASH: Final[i32] = 59,
     SLOT_TP_MEMBERS: Final[i32] = 72,
     SLOT_TP_METHODS: Final[i32] = 64,
     SLOT_TP_DOC: Final[i32] = 56,
     SLOT_TP_TOKEN: Final[i32] = 83,
     SLOT_TP_GETSET: Final[i32] = 73;

def type_spec(handle: ptr) -> ptr[BindingTypeSpec];

def module_methods(spec: ptr) -> ptr[PyMethodDef];

def module_definition(spec: ptr) -> ptr[ModuleDef];

def function_methods(table: ptr[BindingMethodTable]) -> ptr[PyMethodDef];

def text_or_null(text: ptr[u8]) -> ptr[u8];

def discard_methods(table: ptr[BindingMethodTable]);

def set_table(
    table: ptr[BindingMethodTable],
    name: ptr[u8],
    doc: ptr[u8],
    entries: ptr[PyMethodDef]
);

def put_slot(slots: ptr[PyType_Slot], index: i64, slot: i32, value: ptr) -> i64;

def put_member(
    members: ptr[PyMemberDef], index: i64, name: ptr[u8], offset: i64
) -> i64;

def heap_token(type: ptr[PyTypeObject]) -> ptr;

def native_payload(object_: ptr[PyObject], definition: ptr) -> ptr[ptr];

def binding_module_state(module: ptr[PyObject]) -> ptr[ptr];

def dict_slot(object_: ptr[PyObject]) -> ptr[ptr[PyObject]];

import from c {
    def jacpy_binding_discard(handle: ptr) {
        if not handle {
            return;
        }
        discard_methods(ptr[BindingMethodTable](handle));
        free(handle);
    }  def jacpy_binding_module(
        name: ptr[u8],
        doc: ptr[u8],
        count: i64,
        hooks: BindingModuleHooks,
        state_count: i64
    ) -> ptr {
        spec = calloc(
            u64(1), u64(MODULE_SPEC_SIZE) + u64(count + 1) * PYMETHODDEF_SIZE
        );
        if not spec {
            return ptr();
        }
        table = ptr[BindingMethodTable](spec);
        set_table(table, name, doc, module_methods(spec));
        definition = module_definition(spec);
        definition.view(1)[0].m_base.ob_base.ob_refcnt_full = _Py_STATIC_IMMORTAL_INITIAL_REFCNT;
        definition.view(1)[0].m_name = table.view(1)[0].name;
        definition.view(1)[0].m_doc = text_or_null(table.view(1)[0].doc);
        definition.view(1)[0].m_size = 8 + state_count * 8;
        definition.view(1)[0].m_traverse = int(hooks.traverse);
        definition.view(1)[0].m_clear = int(hooks.clear);
        definition.view(1)[0].m_free = int(hooks.free);
        definition.view(1)[0].m_methods = module_methods(spec);
        slots = ptr[PyModuleDef_Slot](ptr[u8](spec) + MODULE_SPEC_SLOTS);
        definition.view(1)[0].m_slots = slots;
        slots.view(1)[0].slot = MOD_MULTIPLE_INTERPRETERS;
        slots.view(1)[0].value = ptr(MOD_PER_INTERPRETER_GIL_SUPPORTED);
        (slots + 1).view(1)[0].slot = MOD_GIL;
        (slots + 1).view(1)[0].value = ptr(MOD_GIL_USED);
        if hooks.execute {
            (slots + 2).view(1)[0].slot = MOD_EXEC;
            (slots + 2).view(1)[0].value = hooks.execute;
        }
        if not table.view(1)[0].name or not table.view(1)[0].doc {
            jacpy_binding_discard(spec);
            return ptr();
        }
        return spec;
    }  def jacpy_binding_method(
        handle: ptr,
        index: i64,
        name: ptr[u8],
        keywords: ptr,
        positional: ptr,
        fast: ptr,
        fast_keywords: ptr,
        flags: i64,
        doc: ptr[u8]
    ) -> i64 {
        table = ptr[BindingMethodTable](handle);
        method = table.view(1)[0].entries + index;
        owned_name = strdup(name);
        owned_doc = strdup(doc);
        if not owned_name or not owned_doc {
            free(ptr(owned_name));
            free(ptr(owned_doc));
            return -1;
        }
        chosen = positional;
        if (flags & METH_FASTCALL_FLAG) != 0 {
            chosen = fast_keywords if (flags & METH_KEYWORDS_FLAG) != 0 else fast;
        } elif (flags & METH_KEYWORDS_FLAG) != 0 {
            chosen = keywords;
        }
        if owned_doc.view(1)[0] == u8(0) {
            free(ptr(owned_doc));
            owned_doc = ptr[u8]();
        }
        method.view(1)[0].ml_name = owned_name;
        method.view(1)[0].ml_meth = chosen;
        method.view(1)[0].ml_flags = i32.wrap(flags);
        method.view(1)[0].ml_doc = owned_doc;
        return 0;
    }  def jacpy_binding_init(handle: ptr) -> ptr[PyObject] {
        if not handle {
            return PyErr_NoMemory();
        }
        return PyModuleDef_Init(module_definition(handle));
    }  def jacpy_binding_functions_discard(handle: ptr) {
        if not handle {
            return;
        }
        discard_methods(ptr[BindingMethodTable](handle));
        free(handle);
    }  def jacpy_binding_functions(count: i64) -> ptr {
        table = ptr[BindingMethodTable](
            calloc(u64(1), u64(METHOD_TABLE_SIZE) + u64(count + 1) * PYMETHODDEF_SIZE)
        );
        if not table {
            return ptr();
        }
        set_table(table, ptr[u8](""), ptr[u8](""), function_methods(table));
        if not table.view(1)[0].name or not table.view(1)[0].doc {
            jacpy_binding_functions_discard(ptr(table));
            return ptr();
        }
        return ptr(table);
    }  def jacpy_binding_function(
        handle: ptr, index: i64, receiver: ptr[PyObject], module: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not handle {
            return PyErr_NoMemory();
        }
        methods = function_methods(ptr[BindingMethodTable](handle));
        return PyCFunction_NewEx(methods + index, receiver, module);
    }  def jacpy_binding_state_count(module: ptr[PyObject]) -> i64 {
        if not PyModule_GetState(module) {
            return 0;
        }
        return (PyModule_GetDef(module).view(1)[0].m_size - 8) // 8;
    }  def jacpy_binding_state_get(module: ptr[PyObject], index: i64) -> ptr[PyObject] {
        state = binding_module_state(module);
        return ptr[PyObject]((state + 1 + index).view(1)[0]);
    }  def jacpy_binding_state_set(
        module: ptr[PyObject], index: i64, value: ptr[PyObject]
    ) {
        slot = ptr[ptr[PyObject]](binding_module_state(module) + 1 + index);
        if value {
            object_incref(value);
        }
        old = slot.view(1)[0];
        slot.view(1)[0] = value;
        object_xdecref(old);
    }  def jacpy_binding_exception(
        name: ptr[u8], base: ptr[PyObject], doc: ptr[u8]
    ) -> ptr[PyObject] {
        return PyErr_NewExceptionWithDoc(name, text_or_null(doc), base, NULL);
    }  def jacpy_binding_type_discard(handle: ptr) {
        spec = type_spec(handle);
        if not spec {
            return;
        }
        discard_methods(ptr[BindingMethodTable](spec));
        members = spec.view(1)[0].members;
        if members {
            for index in range(spec.view(1)[0].field_count) {
                free(ptr((members + index).view(1)[0].name));
                free(ptr((members + index).view(1)[0].doc));
            }
            free(ptr(members));
        }
        properties = spec.view(1)[0].properties;
        if properties {
            property = properties;
            while property.view(1)[0].name {
                free(ptr(property.view(1)[0].name));
                free(ptr(property.view(1)[0].doc));
                property = property + 1;
            }
            free(ptr(properties));
        }
        free(handle);
    }  def jacpy_binding_type(
        name: ptr[u8],
        doc: ptr[u8],
        count: i64,
        flags: u64,
        hooks: BindingTypeHooks,
        property_count: i64,
        instance_dict: i64,
        unhashable: i64,
        field_count: i64,
        record_size: i64,
        options: i64
    ) -> ptr {
        spec = type_spec(
            calloc(
                u64(1),
                u64(BindingTypeSpec_SIZE_BYTES)
                    + TYPE_SLOT_CAPACITY * PYTYPE_SLOT_SIZE
                    + u64(count + 1) * PYMETHODDEF_SIZE
            )
        );
        if not spec {
            return ptr();
        }
        slots = ptr[PyType_Slot](spec + 1);
        methods = ptr[PyMethodDef](slots + i64(TYPE_SLOT_CAPACITY));
        table = ptr[BindingMethodTable](spec);
        set_table(table, name, doc, methods);
        spec.view(1)[0].slots = slots;
        spec.view(1)[0].properties = ptr[PyGetSetDef](
            calloc(u64(property_count + 1), PYGETSETDEF_SIZE)
        );
        spec.view(1)[0].field_count = field_count;
        members = ptr[PyMemberDef](calloc(u64(field_count + 4), PYMEMBERDEF_SIZE));
        spec.view(1)[0].members = members;
        if not table.view(1)[0].name
            or not table.view(1)[0].doc
            or not spec.view(1)[0].properties
            or not members {
            jacpy_binding_type_discard(ptr(spec));
            return ptr();
        }
        definition = ptr[PyType_Spec](ptr[u8](spec) + TYPE_SPEC_DEFINITION);
        definition.view(1)[0].name = table.view(1)[0].name;
        definition.view(1)[0].basicsize = i32(-8);
        definition.view(1)[0].itemsize = i32(0);
        definition.view(1)[0].flags = u32.wrap(flags);
        definition.view(1)[0].slots = slots;
        payload_basicsize = i32.wrap(-(PAYLOAD_SIZE + record_size));
        if record_size != 0 {
            definition.view(1)[0].basicsize = payload_basicsize;
        }
        member = field_count;
        if hooks.vectorcall {
            definition.view(1)[0].basicsize = payload_basicsize;
            spec.view(1)[0].vectorcall = hooks.vectorcall;
            member = put_member(
                members, member, ptr[u8]("__vectorcalloffset__"), PAYLOAD_VECTORCALL
            );
        }
        if instance_dict != 0 {
            definition.view(1)[0].basicsize = payload_basicsize;
            spec.view(1)[0].instance_dict = 1;
            member = put_member(
                members, member, ptr[u8]("__dictoffset__"), PAYLOAD_DICTIONARY
            );
        }
        if (options & TYPE_WEAKLIST) != 0 {
            definition.view(1)[0].basicsize = payload_basicsize;
            member = put_member(
                members, member, ptr[u8]("__weaklistoffset__"), PAYLOAD_WEAKLIST
            );
        }
        slot: i64 = 0;
        slot = put_slot(slots, slot, SLOT_TP_NEW, hooks.create);
        slot = put_slot(slots, slot, SLOT_TP_INIT, hooks.initialize);
        slot = put_slot(slots, slot, SLOT_TP_DEALLOC, hooks.dealloc);
        slot = put_slot(slots, slot, SLOT_TP_TRAVERSE, hooks.traverse);
        slot = put_slot(slots, slot, SLOT_TP_CLEAR, hooks.clear);
        slot = put_slot(slots, slot, SLOT_TP_CALL, hooks.call);
        slot = put_slot(slots, slot, SLOT_TP_REPR, hooks.repr);
        slot = put_slot(slots, slot, SLOT_TP_ITER, hooks.iter);
        slot = put_slot(slots, slot, SLOT_TP_ITERNEXT, hooks.next);
        slot = put_slot(slots, slot, SLOT_TP_DESCR_GET, hooks.descriptor);
        slot = put_slot(slots, slot, SLOT_TP_RICHCOMPARE, hooks.compare);
        slot = put_slot(slots, slot, SLOT_TP_DESCR_SET, hooks.descriptor_set);
        slot = put_slot(slots, slot, SLOT_NB_OR, hooks.bit_or);
        slot = put_slot(slots, slot, SLOT_SQ_LENGTH, hooks.length);
        slot = put_slot(slots, slot, SLOT_SQ_ITEM, hooks.item);
        slot = put_slot(slots, slot, SLOT_SQ_ASS_ITEM, hooks.assign);
        slot = put_slot(slots, slot, SLOT_SQ_CONTAINS, hooks.contains);
        slot = put_slot(slots, slot, SLOT_SQ_CONCAT, hooks.concat);
        slot = put_slot(slots, slot, SLOT_SQ_INPLACE_CONCAT, hooks.inplace_concat);
        slot = put_slot(slots, slot, SLOT_SQ_REPEAT, hooks.repeat);
        slot = put_slot(slots, slot, SLOT_SQ_INPLACE_REPEAT, hooks.inplace_repeat);
        slot = put_slot(slots, slot, SLOT_MP_LENGTH, hooks.mapping_length);
        slot = put_slot(slots, slot, SLOT_MP_SUBSCRIPT, hooks.subscript);
        slot = put_slot(slots, slot, SLOT_MP_ASS_SUBSCRIPT, hooks.assign_subscript);
        slot = put_slot(slots, slot, SLOT_BF_GETBUFFER, hooks.buffer);
        slot = put_slot(slots, slot, SLOT_BF_RELEASEBUFFER, hooks.release_buffer);
        slot = put_slot(slots, slot, SLOT_TP_GETATTRO, hooks.get_attribute);
        slot = put_slot(slots, slot, SLOT_TP_SETATTRO, hooks.set_attribute);
        slot = put_slot(slots, slot, SLOT_TP_STR, hooks.string);
        slot = put_slot(slots, slot, SLOT_TP_FINALIZE, hooks.finalize);
        if not hooks.get_attribute and (options & TYPE_GENERIC_GETATTR) != 0 {
            slot = put_slot(
                slots, slot, SLOT_TP_GETATTRO, ptr(PyObject_GenericGetAttr)
            );
        }
        if not hooks.set_attribute and (options & TYPE_GENERIC_SETATTR) != 0 {
            slot = put_slot(
                slots, slot, SLOT_TP_SETATTRO, ptr(PyObject_GenericSetAttr)
            );
        }
        slot = put_slot(slots, slot, SLOT_NB_BOOL, hooks.boolean);
        if unhashable != 0 {
            slot = put_slot(
                slots, slot, SLOT_TP_HASH, ptr(PyObject_HashNotImplemented)
            );
        } else {
            slot = put_slot(slots, slot, SLOT_TP_HASH, hooks.hash);
        }
        if hooks.vectorcall and not hooks.call {
            slot = put_slot(slots, slot, SLOT_TP_CALL, ptr(PyVectorcall_Call));
        }
        if member != 0 {
            slot = put_slot(slots, slot, SLOT_TP_MEMBERS, ptr(members));
        }
        slot = put_slot(slots, slot, SLOT_TP_METHODS, ptr(methods));
        if table.view(1)[0].doc.view(1)[0] != u8(0) {
            slot = put_slot(slots, slot, SLOT_TP_DOC, ptr(table.view(1)[0].doc));
        }
        slot = put_slot(slots, slot, SLOT_TP_TOKEN, ptr(spec));
        slot = put_slot(slots, slot, SLOT_TP_GETSET, ptr(spec.view(1)[0].properties));
        return ptr(spec);
    }  def jacpy_binding_property(
        handle: ptr,
        index: i64,
        name: ptr[u8],
        get: ptr,
        set: ptr,
        context: u64,
        doc: ptr[u8]
    ) -> i64 {
        spec = type_spec(handle);
        owned_name = strdup(name);
        owned_doc = strdup(doc);
        if not owned_name or not owned_doc {
            free(ptr(owned_name));
            free(ptr(owned_doc));
            return -1;
        }
        property = spec.view(1)[0].properties + index;
        property.view(1)[0].name = owned_name;
        property.view(1)[0].get = int(get);
        property.view(1)[0].set = int(set);
        if owned_doc.view(1)[0] != u8(0) {
            property.view(1)[0].doc = owned_doc;
        } else {
            property.view(1)[0].doc = ptr[u8]();
            free(ptr(owned_doc));
        }
        property.view(1)[0].closure = ptr(context);
        return 0;
    }  def jacpy_binding_member(
        handle: ptr,
        index: i64,
        name: ptr[u8],
        type: i64,
        offset: i64,
        readonly: i64,
        doc: ptr[u8],
        has_doc: i64
    ) -> i64 {
        spec = type_spec(handle);
        owned_name = strdup(name);
        owned_doc = ptr[u8]();
        if has_doc != 0 {
            owned_doc = strdup(doc);
        }
        if not owned_name or (has_doc != 0 and not owned_doc) {
            free(ptr(owned_name));
            free(ptr(owned_doc));
            return -1;
        }
        member = spec.view(1)[0].members + index;
        member.view(1)[0].name = owned_name;
        member.view(1)[0].type_ = i32.wrap(type);
        member.view(1)[0].offset = PAYLOAD_SIZE + offset;
        member.view(1)[0].flags = (READONLY_FLAG if readonly != 0 else i32(0))
            | RELATIVE_OFFSET_FLAG;
        member.view(1)[0].doc = owned_doc;
        return 0;
    }  def jacpy_binding_type_create(
        handle: ptr, module: ptr[PyObject], bases: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not handle {
            return PyErr_NoMemory();
        }
        return PyType_FromModuleAndSpec(
            module, ptr[PyType_Spec](ptr[u8](handle) + TYPE_SPEC_DEFINITION), bases
        );
    }  def jacpy_binding_owner(
        type: ptr[PyObject], module_definition_handle: ptr
    ) -> ptr[PyObject] {
        return PyType_GetModuleByDef(
            ptr[PyTypeObject](type), module_definition(module_definition_handle)
        );
    }  def jacpy_binding_basicsize(object_: ptr[PyObject]) -> i64 {
        return object_type(object_).view(1)[0].tp_basicsize;
    }  def jacpy_binding_allocate(type: ptr[PyObject]) -> ptr[PyObject] {
        cls = ptr[PyTypeObject](type);
        return cls.view(1)[0].tp_alloc(cls, 0);
    }  def jacpy_binding_free(object_: ptr[PyObject]) {
        type = object_type(object_);
        type.view(1)[0].tp_free(ptr(object_));
        object_decref(ptr[PyObject](type));
    }  def jacpy_binding_untrack(object_: ptr[PyObject]) {
        if PyObject_IS_GC(object_) != 0 {
            PyObject_GC_UnTrack(ptr(object_));
        }
    }  def jacpy_binding_clear_weakrefs(object_: ptr[PyObject]) {
        if object_type(object_).view(1)[0].tp_weaklistoffset != 0 {
            PyObject_ClearWeakRefs(object_);
        }
    }  def jacpy_binding_base(type: ptr[PyObject], definition: ptr) -> ptr[PyObject] {
        base = ptr[ptr[PyTypeObject]](__alloca(8));
        base.view(1)[0] = ptr[PyTypeObject]();
        found = PyType_GetBaseByToken(ptr[PyTypeObject](type), definition, base);
        if found == 0 {
            PyErr_SetString(
                PyExc_TypeError,
                ptr[u8]("object does not inherit the native binding type")
            );
        }
        return ptr[PyObject](base.view(1)[0]);
    }  def jacpy_binding_token(type: ptr[PyObject]) -> ptr {
        t = ptr[PyTypeObject](type);
        while t {
            token = heap_token(t);
            if token {
                return token;
            }
            t = t.view(1)[0].tp_base;
        }
        return ptr();
    }  def jacpy_binding_own_present(object_: ptr[PyObject]) -> i64 {
        definition = jacpy_binding_token(ptr[PyObject](object_type(object_)));
        if not definition {
            return 0;
        }
        slot = native_payload(object_, definition);
        if slot and slot.view(1)[0] {
            return 1;
        }
        return 0;
    }  def jacpy_binding_module_native_get(module: ptr[PyObject]) -> ptr {
        state = binding_module_state(module);
        if not state {
            return ptr();
        }
        value = state.view(1)[0];
        if value {
            jac_retain(value);
        }
        return value;
    }  def jacpy_binding_module_native_set(module: ptr[PyObject], value: ptr) {
        state = binding_module_state(module);
        previous = state.view(1)[0];
        if value {
            jac_retain(value);
        }
        state.view(1)[0] = value;
        if previous {
            jac_release(previous);
        }
    }  def jacpy_binding_module_native_clear(module: ptr[PyObject]) {
        if PyModule_GetState(module) {
            jacpy_binding_module_native_set(module, ptr());
        }
    }  def jacpy_binding_module_native_present(module: ptr[PyObject]) -> i64 {
        state = binding_module_state(module);
        if state and state.view(1)[0] {
            return 1;
        }
        return 0;
    }  def jacpy_binding_own_get(object_: ptr[PyObject]) -> ptr {
        definition = jacpy_binding_token(ptr[PyObject](object_type(object_)));
        if not definition {
            return ptr();
        }
        slot = native_payload(object_, definition);
        if not slot {
            return ptr();
        }
        state = slot.view(1)[0];
        if state {
            jac_retain(state);
        }
        return state;
    }  def jacpy_binding_native_get(object_: ptr[PyObject], definition: ptr) -> ptr {
        slot = native_payload(object_, definition);
        if not slot {
            return ptr();
        }
        state = slot.view(1)[0];
        if state {
            jac_retain(state);
        }
        return state;
    }  def jacpy_binding_native_set(
        object_: ptr[PyObject], definition: ptr, state: ptr
    ) -> i64 {
        slot = native_payload(object_, definition);
        if not slot {
            return -1;
        }
        previous = slot.view(1)[0];
        if state {
            jac_retain(state);
        }
        slot.view(1)[0] = state;
        vectorcall = type_spec(definition).view(1)[0].vectorcall;
        if vectorcall {
            ptr[BindingPayload](slot).view(1)[0].vectorcall = vectorcall;
        }
        if previous {
            jac_release(previous);
        }
        return 0;
    }  def jacpy_binding_native_clear(object_: ptr[PyObject], definition: ptr) {
        jacpy_binding_native_set(object_, definition, ptr());
    }  def jacpy_binding_native_present(
        object_: ptr[PyObject], definition: ptr
    ) -> i64 {
        slot = native_payload(object_, definition);
        if slot and slot.view(1)[0] {
            return 1;
        }
        return 0;
    }  def jacpy_binding_record(object_: ptr[PyObject], definition: ptr) -> ptr {
        slot = native_payload(object_, definition);
        if not slot {
            return ptr();
        }
        return ptr(ptr[u8](slot) + PAYLOAD_SIZE);
    }  def jacpy_binding_dict_visit(
        object_: ptr[PyObject], definition: ptr, visitor: ptr, context: ptr
    ) -> i32 {
        if type_spec(definition).view(1)[0].instance_dict == 0 {
            return 0;
        }
        slot = dict_slot(object_);
        if not slot or not slot.view(1)[0] {
            return 0;
        }
        calls = ptr[BindingCalls](
            __thread_local_block("jac_object_model_binding_api_call_slot", 24)
        );
        calls.view(1)[0].visit_call = int(visitor);
        return calls.view(1)[0].visit_call(slot.view(1)[0], context);
    }  def jacpy_binding_dict_clear(object_: ptr[PyObject], definition: ptr) {
        if type_spec(definition).view(1)[0].instance_dict == 0 {
            return;
        }
        slot = dict_slot(object_);
        if slot {
            old = slot.view(1)[0];
            slot.view(1)[0] = NULL;
            object_xdecref(old);
        }
    }  def jacpy_binding_dict_present(object_: ptr[PyObject]) -> i64 {
        slot = dict_slot(object_);
        if slot and slot.view(1)[0] {
            return 1;
        }
        return 0;
    }  def jacpy_binding_dict_peek(object_: ptr[PyObject]) -> ptr[PyObject] {
        slot = dict_slot(object_);
        if not slot {
            return NULL;
        }
        value = slot.view(1)[0];
        if value {
            object_incref(value);
        }
        return value;
    }  def jacpy_binding_dict_replace(
        object_: ptr[PyObject], dictionary: ptr[PyObject]
    ) -> i64 {
        slot = dict_slot(object_);
        if not slot {
            PyErr_SetString(
                PyExc_SystemError, ptr[u8]("instance has no dictionary slot")
            );
            return -1;
        }
        if dictionary {
            object_incref(dictionary);
        }
        old = slot.view(1)[0];
        slot.view(1)[0] = dictionary;
        object_xdecref(old);
        return 0;
    }  def jacpy_binding_type_matches(type: ptr[PyObject], definition: ptr) -> i64 {
        if heap_token(ptr[PyTypeObject](type)) == definition {
            return 1;
        }
        base = ptr[ptr[PyTypeObject]](__alloca(8));
        base.view(1)[0] = ptr[PyTypeObject]();
        found = PyType_GetBaseByToken(ptr[PyTypeObject](type), definition, base);
        object_xdecref(ptr[PyObject](base.view(1)[0]));
        return i64(found);
    }  def jacpy_binding_matches(object_: ptr[PyObject], definition: ptr) -> i64 {
        return jacpy_binding_type_matches(
            ptr[PyObject](object_type(object_)), definition
        );
    }  def jacpy_binding_base_new(
        base: ptr[PyObject],
        type: ptr[PyObject],
        args: ptr[PyObject],
        keywords: ptr[PyObject]
    ) -> ptr[PyObject] {
        return ptr[PyTypeObject](base).view(1)[0].tp_new(
            ptr[PyTypeObject](type), args, keywords
        );
    }  def jacpy_binding_base_init(
        base: ptr[PyObject],
        object_: ptr[PyObject],
        args: ptr[PyObject],
        keywords: ptr[PyObject]
    ) -> i32 {
        return ptr[PyTypeObject](base).view(1)[0].tp_init(object_, args, keywords);
    }  def jacpy_binding_base_traverse(
        base: ptr[PyObject], object_: ptr[PyObject], visitor: ptr, context: ptr
    ) -> i32 {
        calls = ptr[BindingCalls](
            __thread_local_block("jac_object_model_binding_api_call_slot", 24)
        );
        calls.view(1)[0].traverse = int(ptr[PyTypeObject](base).view(1)[0].tp_traverse);
        return calls.view(1)[0].traverse(object_, visitor, context);
    }  def jacpy_binding_base_clear(
        base: ptr[PyObject], object_: ptr[PyObject]
    ) -> i32 {
        return ptr[PyTypeObject](base).view(1)[0].tp_clear(object_);
    }  def jacpy_binding_base_dealloc(base: ptr[PyObject], object_: ptr[PyObject]) {
        ptr[PyTypeObject](base).view(1)[0].tp_dealloc(object_);
    }  def jacpy_binding_parent(type: ptr[PyObject], definition: ptr) -> ptr[PyObject] {
        base = ptr[PyTypeObject](jacpy_binding_base(type, definition));
        if not base {
            return NULL;
        }
        parent = base.view(1)[0].tp_base;
        object_decref(ptr[PyObject](base));
        return ptr[PyObject](parent);
    }  def jacpy_binding_buffer_fill(
        view: ptr[Py_buffer],
        object_: ptr[PyObject],
        layout: BindingBufferLayout,
        format: ptr[u8],
        flags: i32
    ) -> i32 {
        if not view {
            PyErr_SetString(
                PyExc_BufferError, ptr[u8]("view==NULL argument is obsolete")
            );
            return i32(-1);
        }
        if layout.count < 0
            or layout.itemsize <= 0
            or layout.count > PY_SSIZE_T_MAX // layout.itemsize {
            PyErr_SetString(
                PyExc_BufferError, ptr[u8]("invalid native buffer dimensions")
            );
            return i32(-1);
        }
        format_size = strlen(format) + u64(1);
        metadata = ptr[i64](malloc(u64(8) + format_size));
        if not metadata {
            PyErr_NoMemory();
            return i32(-1);
        }
        metadata.view(1)[0] = layout.count;
        memcpy(ptr(metadata + 1), ptr(format), format_size);
        if PyBuffer_FillInfo(
            view,
            object_,
            layout.address,
            layout.count * layout.itemsize,
            i32.wrap(layout.readonly),
            flags
        )
            < i32(0) {
            free(ptr(metadata));
            return i32(-1);
        }
        view.view(1)[0].itemsize = layout.itemsize;
        if (flags & PYBUF_FORMAT_FLAG) != i32(0) {
            view.view(1)[0].format_ = ptr[u8](metadata + 1);
        } else {
            view.view(1)[0].format_ = ptr[u8]();
        }
        if (flags & PYBUF_ND_FLAG) != i32(0) {
            view.view(1)[0].shape = metadata;
        } else {
            view.view(1)[0].shape = ptr[i64]();
        }
        if (flags & PYBUF_STRIDES_FLAG) == PYBUF_STRIDES_FLAG {
            view.view(1)[0].strides = ptr[i64](ptr[u8](view) + BUFFER_ITEMSIZE);
        } else {
            view.view(1)[0].strides = ptr[i64]();
        }
        view.view(1)[0].internal = ptr(metadata);
        return i32(0);
    }  def jacpy_binding_buffer_dispose(view: ptr[Py_buffer]) {
        if view {
            free(view.view(1)[0].internal);
            view.view(1)[0].internal = ptr();
        }
    }  def jacpy_binding_dealloc_guard(
        object_: ptr[PyObject], entry_item: ptr, body: ptr
    ) {
        PyObject_GC_UnTrack(ptr(object_));
        calls = ptr[BindingCalls](
            __thread_local_block("jac_object_model_binding_api_call_slot", 24)
        );
        calls.view(1)[0].dealloc = int(body);
        calls.view(1)[0].dealloc(object_);
    }
}

impl type_spec(handle: ptr) -> ptr[BindingTypeSpec] {
    return ptr[BindingTypeSpec](handle);
}

impl module_methods(spec: ptr) -> ptr[PyMethodDef] {
    return ptr[PyMethodDef](ptr[u8](spec) + MODULE_SPEC_SIZE);
}

impl module_definition(spec: ptr) -> ptr[ModuleDef] {
    return ptr[ModuleDef](ptr[u8](spec) + MODULE_SPEC_DEFINITION);
}

impl function_methods(table: ptr[BindingMethodTable]) -> ptr[PyMethodDef] {
    return ptr[PyMethodDef](table + 1);
}

impl text_or_null(text: ptr[u8]) -> ptr[u8] {
    if text and text.view(1)[0] != u8(0) {
        return text;
    }
    return ptr[u8]();
}

impl discard_methods(table: ptr[BindingMethodTable]) {
    free(ptr(table.view(1)[0].name));
    free(ptr(table.view(1)[0].doc));
    method = table.view(1)[0].entries;
    while method.view(1)[0].ml_name {
        free(ptr(method.view(1)[0].ml_name));
        free(ptr(method.view(1)[0].ml_doc));
        method = method + 1;
    }
}

impl set_table(
    table: ptr[BindingMethodTable],
    name: ptr[u8],
    doc: ptr[u8],
    entries: ptr[PyMethodDef]
) {
    table.view(1)[0].name = strdup(name);
    table.view(1)[0].doc = strdup(doc);
    table.view(1)[0].entries = entries;
}

impl put_slot(slots: ptr[PyType_Slot], index: i64, slot: i32, value: ptr) -> i64 {
    if not value {
        return index;
    }
    (slots + index).view(1)[0].slot = slot;
    (slots + index).view(1)[0].pfunc = value;
    return index + 1;
}

impl put_member(
    members: ptr[PyMemberDef], index: i64, name: ptr[u8], offset: i64
) -> i64 {
    member = members + index;
    member.view(1)[0].name = name;
    member.view(1)[0].type_ = T_PYSSIZET;
    member.view(1)[0].offset = offset;
    member.view(1)[0].flags = READONLY_FLAG | RELATIVE_OFFSET_FLAG;
    member.view(1)[0].doc = ptr[u8]();
    return index + 1;
}

impl heap_token(type: ptr[PyTypeObject]) -> ptr {
    if type_has_feature(type, Py_TPFLAGS_HEAPTYPE) {
        return ptr[PyHeapTypeObject](type).view(1)[0].ht_token;
    }
    return ptr();
}

impl native_payload(object_: ptr[PyObject], definition: ptr) -> ptr[ptr] {
    type = object_type(object_);
    if heap_token(type) == definition {
        base_size = type.view(1)[0].tp_base.view(1)[0].tp_basicsize;
        return ptr[ptr](ptr[u8](object_) + ((base_size + 15) & ~i64(15)));
    }
    base = ptr[PyTypeObject](jacpy_binding_base(ptr[PyObject](type), definition));
    if not base {
        return ptr[ptr]();
    }
    slot = ptr[ptr](PyObject_GetTypeData(object_, base));
    object_decref(ptr[PyObject](base));
    return slot;
}

impl binding_module_state(module: ptr[PyObject]) -> ptr[ptr] {
    return ptr[ptr](PyModule_GetState(module));
}

impl dict_slot(object_: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return _PyObject_GetDictPtr(object_);
}
