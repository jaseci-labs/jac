"""The _sqlite3 module: Connection, Cursor, Row, Blob, PrepareProtocol, Statement,
the DB-API exceptions and the SQLite constants."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyExc_Exception,
    PyLong_FromLong,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyObject,
    PyObject_CallFinalizerFromDealloc,
    PyUnicode_InternFromString,
    PyDict_New,
    PyImport_ImportModuleAttrString,
    jacpy_release
}
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    add_owned,
    jacpy_binding_exception,
    jacpy_binding_module_native_set,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyDefinition,
    PropertyCallbacks,
    jacpy_binding_record
}
import from jaclang.runtime.python.bindings.payload {
    clear_payload,
    dispose_payload,
    traverse_payload,
    jacpy_binding_native_present
}
import from jaclang.runtime.python.bindings.clinic.sqlite3 {
    Blob_methods,
    Connection_methods,
    Cursor_getset,
    Cursor_methods,
    Row_methods,
    module_methods,
    pysqlite_connect_doc,
    pysqlite_connection_init_init,
    pysqlite_cursor_init_init,
    pysqlite_row_new_new
}
import from jaclang.runtime.python.modules.sqlite3 {
    Blob_token,
    CONNECTION_MEMBERS,
    CONNECTION_RECORD_SIZE,
    CURSOR_MEMBERS,
    CURSOR_RECORD_SIZE,
    Connection_token,
    Cursor_token,
    ENABLE_LOAD_EXTENSION,
    ERROR_CODES,
    INTEGER_CONSTANTS,
    LEGACY_TRANSACTION_CONTROL,
    PrepareProtocol_token,
    Row_token,
    SqliteState,
    Statement_token,
    blob_ass_subscript,
    blob_close_on_dealloc,
    blob_length,
    blob_subscript,
    connection_call,
    connection_finalize,
    connection_get_autocommit,
    connection_get_in_transaction,
    connection_get_isolation_level,
    connection_get_row_factory,
    connection_get_sig,
    connection_get_text_factory,
    connection_get_total_changes,
    connection_set_autocommit,
    connection_set_isolation_level,
    connection_set_row_factory,
    connection_set_text_factory,
    cursor_iternext,
    cursor_of,
    cursor_self_iter,
    initialize_library,
    library_version,
    module_definition,
    prepare_protocol_init,
    pysqlite_connect,
    row_hash,
    row_item,
    row_iter,
    row_length,
    row_richcompare,
    row_subscript,
    statement_finalize,
    threadsafety
}

def:priv connection_dealloc(instance: ptr[PyObject]) {
    if PyObject_CallFinalizerFromDealloc(instance) < 0 {
        return;
    }
    dispose_payload(instance, Connection_token.handle);
}

def:priv connection_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(instance, Connection_token.handle, visitor, context);
}

def:priv connection_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, Connection_token.handle);
}

# The cursor's state owns the references of its member record, so the state
# exists before the object goes away.
def:priv cursor_dealloc(instance: ptr[PyObject]) {
    cursor_of(instance);
    dispose_payload(instance, Cursor_token.handle);
}

def:priv cursor_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    if jacpy_binding_native_present(instance, Cursor_token.handle) != 0 {
        return traverse_payload(instance, Cursor_token.handle, visitor, context);
    }
    # Before the state exists only the member record holds references.
    status = traverse_payload(instance, Cursor_token.handle, visitor, context);
    if status != 0 {
        return status;
    }
    record = ptr[ptr[PyObject]](jacpy_binding_record(instance, Cursor_token.handle));
    for slot in [0, 1, 2, 4] {
        status = visit_reference((record + slot).view(1)[0], visitor, context);
        if status != 0 {
            return status;
        }
    }
    return i32(0);
}

def:priv cursor_clear(instance: ptr[PyObject]) -> i32 {
    cursor_of(instance);
    return clear_payload(instance, Cursor_token.handle);
}

def:priv row_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, Row_token.handle);
}

def:priv row_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, Row_token.handle, visitor, context);
}

def:priv row_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, Row_token.handle);
}

def:priv statement_dealloc(instance: ptr[PyObject]) {
    statement_finalize(instance);
    dispose_payload(instance, Statement_token.handle);
}

def:priv statement_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(instance, Statement_token.handle, visitor, context);
}

def:priv prepare_protocol_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, PrepareProtocol_token.handle);
}

def:priv prepare_protocol_traverse(
    instance: ptr[PyObject], visitor: ptr, context: ptr
) -> i32 {
    return traverse_payload(instance, PrepareProtocol_token.handle, visitor, context);
}

def:priv blob_dealloc(instance: ptr[PyObject]) {
    blob_close_on_dealloc(instance);
    dispose_payload(instance, Blob_token.handle);
}

def:priv blob_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, Blob_token.handle, visitor, context);
}

def:priv blob_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, Blob_token.handle);
}

# Connection's methods, without the loadable-extension pair when the build
# does not define PY_SQLITE_ENABLE_LOAD_EXTENSION.
def:priv connection_methods -> list[MethodDefinition] {
    methods: list[MethodDefinition] = [];
    for method in Connection_methods {
        if ENABLE_LOAD_EXTENSION
            or method.name not in ["enable_load_extension", "load_extension"] {
            methods.append(method);
        }
    }
    return methods;
}

glob:priv GC_TYPE: u64 = u64(TypeFlags.GC.value | TypeFlags.IMMUTABLE.value),
     connection_type = TypeDefinition(
         "sqlite3.Connection",
         "SQLite database connection object.",
         connection_methods(),
         GC_TYPE | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             initialize=pysqlite_connection_init_init,
             dealloc=connection_dealloc,
             traverse=connection_traverse,
             clear=connection_clear,
             call=connection_call,
             finalize=connection_finalize
         ),
         [
             PropertyDefinition(
                 "isolation_level",
                 PropertyCallbacks(
                     read=connection_get_isolation_level,
                     write=connection_set_isolation_level
                 )
             ),
             PropertyDefinition(
                 "total_changes", PropertyCallbacks(read=connection_get_total_changes)
             ),
             PropertyDefinition(
                 "in_transaction", PropertyCallbacks(read=connection_get_in_transaction)
             ),
             PropertyDefinition(
                 "autocommit",
                 PropertyCallbacks(
                     read=connection_get_autocommit, write=connection_set_autocommit
                 )
             ),
             PropertyDefinition(
                 "__text_signature__", PropertyCallbacks(read=connection_get_sig)
             ),
             PropertyDefinition(
                 "row_factory",
                 PropertyCallbacks(
                     read=connection_get_row_factory, write=connection_set_row_factory
                 )
             ),
             PropertyDefinition(
                 "text_factory",
                 PropertyCallbacks(
                     read=connection_get_text_factory, write=connection_set_text_factory
                 )
             )
         ],
         members=CONNECTION_MEMBERS,
         record_size=CONNECTION_RECORD_SIZE
     ),
     cursor_type = TypeDefinition(
         "sqlite3.Cursor",
         "SQLite database cursor class.",
         Cursor_methods,
         GC_TYPE | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             initialize=pysqlite_cursor_init_init,
             dealloc=cursor_dealloc,
             traverse=cursor_traverse,
             clear=cursor_clear,
             iter=cursor_self_iter,
             next=cursor_iternext
         ),
         Cursor_getset,
         members=CURSOR_MEMBERS,
         record_size=CURSOR_RECORD_SIZE,
         weaklist=True
     ),
     row_type = TypeDefinition(
         "sqlite3.Row",
         "",
         Row_methods,
         GC_TYPE | u64(TypeFlags.BASETYPE.value),
         TypeHooks(
             create=pysqlite_row_new_new,
             dealloc=row_dealloc,
             traverse=row_traverse,
             clear=row_clear,
             hash=row_hash,
             compare=row_richcompare,
             iter=row_iter,
             mapping_length=row_length,
             subscript=row_subscript,
             length=row_length,
             item=row_item
         )
     ),
     statement_type = TypeDefinition(
         "sqlite3.Statement",
         "",
         [],
         GC_TYPE | u64(TypeFlags.DISALLOW_INSTANTIATION.value),
         TypeHooks(dealloc=statement_dealloc, traverse=statement_traverse)
     ),
     prepare_protocol_type = TypeDefinition(
         "sqlite3.PrepareProtocol",
         "PEP 246 style object adaption protocol type.",
         [],
         GC_TYPE,
         TypeHooks(
             initialize=prepare_protocol_init,
             dealloc=prepare_protocol_dealloc,
             traverse=prepare_protocol_traverse
         )
     ),
     blob_type = TypeDefinition(
         "sqlite3.Blob",
         "",
         Blob_methods,
         GC_TYPE | u64(TypeFlags.DISALLOW_INSTANTIATION.value),
         TypeHooks(
             dealloc=blob_dealloc,
             traverse=blob_traverse,
             clear=blob_clear,
             mapping_length=blob_length,
             subscript=blob_subscript,
             assign_subscript=blob_ass_subscript
         ),
         weaklist=True
     );

# A new exception class sqlite3.<name> added to the module; its reference
# stays with the caller.
def:priv add_exception(
    module: ptr[PyObject], name: str, base: ptr[PyObject]
) -> ptr[PyObject] {
    exception = jacpy_binding_exception("sqlite3." + name, base, "");
    if not exception {
        return NULL;
    }
    if PyModule_AddObjectRef(module, name, exception) < 0 {
        jacpy_release(exception);
        return NULL;
    }
    return exception;
}

def:priv execute(module: ptr[PyObject]) -> i32 {
    module_definition.handle = definition.handle;
    Connection_token.handle = connection_type.handle;
    Cursor_token.handle = cursor_type.handle;
    Row_token.handle = row_type.handle;
    Blob_token.handle = blob_type.handle;
    Statement_token.handle = statement_type.handle;
    PrepareProtocol_token.handle = prepare_protocol_type.handle;
    if not initialize_library() {
        return i32(-1);
    }
    state = SqliteState();
    jacpy_binding_module_native_set(module, state);
    state.RowType = row_type.create(module);
    state.CursorType = cursor_type.create(module);
    state.ConnectionType = connection_type.create(module);
    state.StatementType = statement_type.create(module);
    state.PrepareProtocolType = prepare_protocol_type.create(module);
    state.BlobType = blob_type.create(module);
    if not state.RowType
        or not state.CursorType
        or not state.ConnectionType
        or not state.StatementType
        or not state.PrepareProtocolType
        or not state.BlobType {
        return i32(-1);
    }
    for (name, type) in [
        ("Blob", state.BlobType),
        ("Connection", state.ConnectionType),
        ("Cursor", state.CursorType),
        ("PrepareProtocol", state.PrepareProtocolType),
        ("Row", state.RowType)
    ] {
        if PyModule_AddObjectRef(module, name, type) < 0 {
            return i32(-1);
        }
    }
    # The DB-API exception hierarchy.
    state.Error = add_exception(module, "Error", PyExc_Exception);
    if not state.Error {
        return i32(-1);
    }
    state.Warning = add_exception(module, "Warning", PyExc_Exception);
    if not state.Warning {
        return i32(-1);
    }
    state.InterfaceError = add_exception(module, "InterfaceError", state.Error);
    if not state.InterfaceError {
        return i32(-1);
    }
    state.DatabaseError = add_exception(module, "DatabaseError", state.Error);
    if not state.DatabaseError {
        return i32(-1);
    }
    state.InternalError = add_exception(module, "InternalError", state.DatabaseError);
    if not state.InternalError {
        return i32(-1);
    }
    state.OperationalError = add_exception(
        module, "OperationalError", state.DatabaseError
    );
    if not state.OperationalError {
        return i32(-1);
    }
    state.ProgrammingError = add_exception(
        module, "ProgrammingError", state.DatabaseError
    );
    if not state.ProgrammingError {
        return i32(-1);
    }
    state.IntegrityError = add_exception(module, "IntegrityError", state.DatabaseError);
    if not state.IntegrityError {
        return i32(-1);
    }
    state.DataError = add_exception(module, "DataError", state.DatabaseError);
    if not state.DataError {
        return i32(-1);
    }
    state.NotSupportedError = add_exception(
        module, "NotSupportedError", state.DatabaseError
    );
    if not state.NotSupportedError {
        return i32(-1);
    }
    # Interned strings.
    state.str___adapt__ = PyUnicode_InternFromString("__adapt__");
    state.str___conform__ = PyUnicode_InternFromString("__conform__");
    state.str_executescript = PyUnicode_InternFromString("executescript");
    state.str_finalize = PyUnicode_InternFromString("finalize");
    state.str_inverse = PyUnicode_InternFromString("inverse");
    state.str_step = PyUnicode_InternFromString("step");
    state.str_upper = PyUnicode_InternFromString("upper");
    state.str_value = PyUnicode_InternFromString("value");
    if not state.str___adapt__
        or not state.str___conform__
        or not state.str_executescript
        or not state.str_finalize
        or not state.str_inverse
        or not state.str_step
        or not state.str_upper
        or not state.str_value {
        return i32(-1);
    }
    for (name, value) in ERROR_CODES + INTEGER_CONSTANTS {
        if PyModule_AddIntConstant(module, name, value) < 0 {
            return i32(-1);
        }
    }
    if not add_owned(module, "sqlite_version", library_version()) {
        return i32(-1);
    }
    if PyModule_AddIntConstant(
        module, "LEGACY_TRANSACTION_CONTROL", i64(LEGACY_TRANSACTION_CONTROL)
    )
        < 0 {
        return i32(-1);
    }
    level = threadsafety(state);
    if level < 0 or PyModule_AddIntConstant(module, "threadsafety", i64(level)) < 0 {
        return i32(-1);
    }
    # The microprotocols layer: the adapters registry.
    state.psyco_adapters = PyDict_New();
    if not state.psyco_adapters
        or PyModule_AddObjectRef(module, "adapters", state.psyco_adapters) < 0 {
        return i32(-1);
    }
    # The default converters.
    state.converters = PyDict_New();
    if not state.converters
        or PyModule_AddObjectRef(module, "converters", state.converters) < 0 {
        return i32(-1);
    }
    state.lru_cache = PyImport_ImportModuleAttrString("functools", "lru_cache");
    if not state.lru_cache {
        return i32(-1);
    }
    return i32(0);
}

glob:priv methods: list[MethodDefinition] = module_methods
         + [
             MethodDefinition(
                 "connect",
                 MethodCallbacks(fast_keywords=pysqlite_connect),
                 pysqlite_connect_doc,
                 130
             )
         ],
     definition = ModuleDefinition(
         "_sqlite3", "", methods, ModuleHooks(execute=execute)
     );

def:pub PyInit__sqlite3 -> ptr[PyObject] {
    return definition.initialize();
}
