"""The _zoneinfo module: the ZoneInfo type, a datetime.tzinfo subclass."""

import from jaclang.runtime.python.cpython_api { PyModule_AddObjectRef, PyObject }

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
    jacpy_binding_record
}
import from jaclang.runtime.python.bindings.payload {
    clear_payload,
    dispose_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.clinic.zoneinfo {
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
    zoneinfo_reduce,
    zoneinfo_repr,
    zoneinfo_str
}
import from jaclang.runtime.python.bindings.members {
    MemberField,
    MemberType,
    record_clear
}

# The record holds the state's key borrowed: zeroed before the state goes.
def:priv zoneinfo_dealloc(instance: ptr[PyObject]) {
    record_clear(jacpy_binding_record(instance, ZoneInfo_token.handle), 8);
    dispose_payload(instance, ZoneInfo_token.handle);
}

def:priv zoneinfo_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, ZoneInfo_token.handle, visitor, context);
}

def:priv zoneinfo_clear(instance: ptr[PyObject]) -> i32 {
    record_clear(jacpy_binding_record(instance, ZoneInfo_token.handle), 8);
    return clear_payload(instance, ZoneInfo_token.handle);
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
         "",
         methods,
         u64(TypeFlags.BASETYPE.value | TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=zoneinfo_ZoneInfo_new,
             dealloc=zoneinfo_dealloc,
             traverse=zoneinfo_traverse,
             clear=zoneinfo_clear,
             repr=zoneinfo_repr,
             string=zoneinfo_str
         ),
         members=[MemberField("key", MemberType.OBJECT_EX.value, 0, readonly=True)],
         record_size=8,
         weaklist=True,
         generic_getattr=True
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
