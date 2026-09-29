"""The _zoneinfo module: the ZoneInfo type, a datetime.tzinfo subclass."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    Py_NewRef,
    PyErr_Format,
    PyExc_AttributeError,
    PyModule_AddObjectRef,
    PyObject
}
import from jaclang.runtime.python.object_model.header { object_type }
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    jacpy_binding_module_native_set
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyDefinition,
    PropertyCallbacks
}
import from jaclang.runtime.python.bindings.payload {
    clear_payload,
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.zoneinfo {
    ZoneInfo_doc,
    ZoneInfo_methods,
    zoneinfo_ZoneInfo_new
}
import from jaclang.runtime.python.modules.zoneinfo {
    ZoneInfoModuleState,
    ZoneInfo_token,
    datetime_import,
    module_definition,
    populate_module_state,
    zoneinfo_fromutc,
    zoneinfo_init_subclass,
    zoneinfo_of,
    zoneinfo_reduce,
    zoneinfo_repr,
    zoneinfo_str
}

def:priv zoneinfo_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, ZoneInfo_token.handle);
}

def:priv zoneinfo_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, ZoneInfo_token.handle, visitor, context);
}

def:priv zoneinfo_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, ZoneInfo_token.handle);
}

# The read-only `key` member (Py_T_OBJECT_EX).
def:priv key(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    zone = zoneinfo_of(instance);
    if zone is None {
        return NULL;
    }
    if not zone.key {
        PyErr_Format(
            PyExc_AttributeError,
            "'%.200s' object has no attribute '%s'",
            object_type(instance).view(1)[0].tp_name,
            "key"
        );
        return NULL;
    }
    return Py_NewRef(zone.key);
}

glob:priv methods: list[MethodDefinition] = ZoneInfo_methods
         + [
             MethodDefinition(
                 "fromutc",
                 MethodCallbacks(positional=zoneinfo_fromutc),
                 "Given a datetime with local time in UTC, retrieve an adjusted datetime in local time.",
                 8
             ),
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=zoneinfo_reduce),
                 "Function for serialization with the pickle protocol.",
                 4
             ),
             MethodDefinition(
                 "__init_subclass__",
                 MethodCallbacks(keywords=zoneinfo_init_subclass),
                 "Function to initialize subclasses.",
                 19
             )
         ],
     zoneinfo_type = TypeDefinition(
         "zoneinfo.ZoneInfo",
         ZoneInfo_doc,
         methods,
         u64(
             TypeFlags.BASETYPE.value
                 | TypeFlags.GC.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.MANAGED_WEAKREF.value
         ),
         TypeHooks(
             create=zoneinfo_ZoneInfo_new,
             dealloc=zoneinfo_dealloc,
             traverse=zoneinfo_traverse,
             clear=zoneinfo_clear,
             repr=zoneinfo_repr,
             string=zoneinfo_str
         ),
         [PropertyDefinition("key", PropertyCallbacks(read=key))]
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
    ZoneInfo_token.handle = zoneinfo_type.handle;
    module_definition.handle = definition.handle;
    api = datetime_import();
    if api.is_null() {
        return i32(-1);
    }
    state = ZoneInfoModuleState(datetime_api=api);
    jacpy_binding_module_native_set(module, state);
    zoneinfo = zoneinfo_type.create(module, ptr[PyObject](api.view(1)[0].TZInfoType));
    if not zoneinfo {
        return i32(-1);
    }
    state.zoneinfo_type = zoneinfo;
    if PyModule_AddObjectRef(module, "ZoneInfo", zoneinfo) < 0
        or not populate_module_state(state) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_zoneinfo",
         "C implementation of the zoneinfo module",
         [],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__zoneinfo -> ptr[PyObject] {
    return definition.initialize();
}
