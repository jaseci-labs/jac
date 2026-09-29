"""The _sqlite3 module: connections, cursors, rows and blobs over SQLite.

Derived from CPython 3.14.6 Modules/_sqlite/ (module.c, connection.c,
cursor.c, statement.c, row.c, blob.c, prepare_protocol.c, microprotocols.c,
util.c); see ../LICENSE.cpython. SQLite runs with the GIL released; the
callbacks it makes into Python (user functions, aggregates, window functions,
collations, the authorizer, progress and trace handlers, destructors) take the
GIL first, and their contexts are C records SQLite keeps pointers to.
"""

import from jaclang.runtime.python.object_model.slice {
    PySlice_AdjustIndices,
    PySlice_Unpack
}

import from jaclang.runtime.python.cpython_api {
    NULL,
    Py_NewRef,
    Py_None,
    Py_NotImplemented,
    Py_TYPE,
    PyByteArray_FromObject,
    PyBytes_AsString,
    PyCallable_Check,
    PyDict_GetItemRef,
    PyDict_Size,
    PyDict_GetItemWithError,
    PyDict_New,
    PyDict_SetItem,
    PyDict_SetItemString,
    PyErr_Clear,
    PyErr_ExceptionMatches,
    PyErr_Format,
    PyErr_FormatUnraisable,
    PyErr_GetRaisedException,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_Print,
    PyErr_ResourceWarning,
    PyErr_WarnEx,
    PyErr_SetObject,
    PyErr_SetRaisedException,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_AttributeError,
    PyExc_DeprecationWarning,
    PyExc_Exception,
    PyExc_ImportError,
    PyExc_IndexError,
    PyExc_MemoryError,
    PyExc_OverflowError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyExc_UnicodeDecodeError,
    PyExc_ValueError,
    PyExc_Warning,
    PyFloat_AsDouble,
    PyFloat_FromDouble,
    PyGILState_Ensure,
    PyGILState_Release,
    PyImport_ImportModuleAttrString,
    PyIndex_Check,
    PyInterpreterState_Get,
    PyIter_Check,
    PyIter_Next,
    PyList_Append,
    PyList_GetItem,
    PyList_New,
    PyList_Size,
    PyLong_AsInt,
    PyLong_AsLong,
    PyLong_AsLongAndOverflow,
    PyLong_AsLongLongAndOverflow,
    PyLong_AsUInt32,
    PyLong_FromLong,
    PyLong_FromLongLong,
    PyLong_FromUInt32,
    PyLong_FromUnsignedLong,
    PyMapping_GetOptionalItem,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_RawFree,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyModule_AddStringConstant,
    PyNumber_AsSsize_t,
    PyObject,
    PyObject_Call,
    PyObject_CallFunction,
    PyObject_CallFunctionObjArgs,
    PyObject_CallMethodObjArgs,
    PyObject_CallNoArgs,
    PyObject_CallOneArg,
    PyObject_CallObject,
    PyObject_CallFinalizerFromDealloc,
    PyObject_CheckBuffer,
    PyObject_GetAttr,
    PyObject_GetItem,
    PyObject_GetIter,
    PyObject_GetOptionalAttr,
    PyObject_Hash,
    PyObject_IsTrue,
    PyObject_RichCompare,
    PyObject_RichCompareBool,
    PyObject_SetAttrString,
    PySequence_Check,
    PySequence_GetItem,
    PySequence_Size,
    PySys_Audit,
    PyThread_get_thread_ident,
    PyTuple_GetItem,
    PyTuple_New,
    PyTuple_Pack,
    PyTuple_SetItem,
    PyTuple_Size,
    PyType_GetModule,
    PyUnicode_AsUTF8AndSize,
    PyUnicode_CompareWithASCIIString,
    PyUnicode_DecodeASCII,
    PyUnicode_DecodeUTF8Stateful,
    PyUnicode_FSConverter,
    PyUnicode_FromString,
    PyUnicode_InternFromString,
    PyObject_Vectorcall,
    PyWeakref_GetRef,
    PyWeakref_NewRef,
    _PyErr_ChainExceptions1,
    _PyErr_FormatFromCause,
    _PyUnicode_AsUTF8NoNUL,
    _PyWeakref_IsDead,
    _Py_IsInterpreterFinalizing,
    jacpy_buffer_new,
    jacpy_bytes_from_memory,
    jacpy_is_bytearray,
    jacpy_is_dict,
    jacpy_is_exact_float,
    jacpy_is_exact_list,
    jacpy_is_exact_long,
    jacpy_is_exact_tuple,
    jacpy_is_exact_unicode,
    jacpy_is_float,
    jacpy_is_list,
    jacpy_is_long,
    jacpy_is_slice,
    jacpy_is_tuple,
    jacpy_is_unicode,
    jacpy_memory_copy,
    jacpy_release,
    jacpy_type_check,
    PyBool_Type,
    PyByteArray_Type,
    PyBytes_Type,
    PyFloat_Type,
    PyLong_Type,
    PyUnicode_Type
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.object_model.header { object_type }
import from jaclang.runtime.python.capi {
    boundary_failure,
    c_string_copy,
    c_string_length,
    c_string_text,
    object_error,
    text_value
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_module_native_get,
    jacpy_binding_module_native_present,
    visit_reference
}
import from jaclang.runtime.python.bindings.type {
    jacpy_binding_allocate,
    jacpy_binding_matches,
    jacpy_binding_owner,
    jacpy_binding_record
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.members { MemberField }
import from jaclang.runtime.python.bindings.arguments { ArgumentFormat }
import from jaclang.runtime.python.bindings.converters {
    ClassToken,
    bad_argument,
    borrowed_false,
    borrowed_none,
    borrowed_true
}

import from c {
    # SQLite's opaque handles.
    obj sqlite3_db;  obj sqlite3_stmt;  obj sqlite3_context;  obj sqlite3_value;  obj sqlite3_blob;  obj sqlite3_backup;
    # callback_context: what a user callback's C record holds. SQLite keeps
    # its address, so it lives in raw memory; `module` keeps the module state
    # alive while SQLite can still call back.
    obj callback_context {
        has callable: ptr[PyObject],
            module: ptr[PyObject],
            refcount: i64;
    }  def free(address: ptr);
}

import from sqlite3 {
    def sqlite3_libversion_number -> i32;  def sqlite3_libversion -> ptr[u8];  def sqlite3_initialize -> i32;  def sqlite3_threadsafe -> i32;  def sqlite3_errstr(
        code: i32
    ) -> ptr[u8];  def sqlite3_errcode(db: ptr[sqlite3_db]) -> i32;  def sqlite3_extended_errcode(
        db: ptr[sqlite3_db]
    ) -> i32;  def sqlite3_errmsg(db: ptr[sqlite3_db]) -> ptr[u8];  def sqlite3_complete(
        sql: str
    ) -> i32;  def sqlite3_open_v2(
        filename: ptr[u8], db: &mut ptr[sqlite3_db], flags: i32, vfs: ptr[u8]
    ) -> i32;  def sqlite3_busy_timeout(db: ptr[sqlite3_db], ms: i32) -> i32;  def sqlite3_close(
        db: ptr[sqlite3_db]
    ) -> i32;  def sqlite3_close_v2(db: ptr[sqlite3_db]) -> i32;  def sqlite3_prepare_v2(
        db: ptr[sqlite3_db],
        sql: ptr[u8],
        length: i32,
        statement: &mut ptr[sqlite3_stmt],
        tail: &mut ptr[u8]
    ) -> i32;  def sqlite3_step(statement: ptr[sqlite3_stmt]) -> i32;  def sqlite3_reset(
        statement: ptr[sqlite3_stmt]
    ) -> i32;  def sqlite3_finalize(statement: ptr[sqlite3_stmt]) -> i32;  def sqlite3_exec(
        db: ptr[sqlite3_db], sql: str, callback: ptr, argument: ptr, errmsg: ptr
    ) -> i32;  def sqlite3_get_autocommit(db: ptr[sqlite3_db]) -> i32;  def sqlite3_limit(
        db: ptr[sqlite3_db], category: i32, value: i32
    ) -> i32;  def sqlite3_total_changes(db: ptr[sqlite3_db]) -> i32;  def sqlite3_changes(
        db: ptr[sqlite3_db]
    ) -> i32;  def sqlite3_last_insert_rowid(db: ptr[sqlite3_db]) -> i64;  def sqlite3_interrupt(
        db: ptr[sqlite3_db]
    );  def sqlite3_db_config(db: ptr[sqlite3_db], op: i32, *args: any) -> i32;  def sqlite3_trace_v2(
        db: ptr[sqlite3_db],
        mask: u32,
        callback: Callable[[u32, ptr, ptr, ptr], i32],
        context: ptr
    ) -> i32;  def sqlite3_progress_handler(
        db: ptr[sqlite3_db],
        instructions: i32,
        callback: Callable[[ptr], i32],
        context: ptr
    );  def sqlite3_set_authorizer(
        db: ptr[sqlite3_db],
        callback: Callable[[ptr, i32, ptr[u8], ptr[u8], ptr[u8], ptr[u8]], i32],
        context: ptr
    ) -> i32;  def sqlite3_create_function_v2(
        db: ptr[sqlite3_db],
        name: str,
        narg: i32,
        flags: i32,
        context: ptr,
        function: Callable[[ptr[sqlite3_context], i32, ptr[ptr[sqlite3_value]]], None],
        step: Callable[[ptr[sqlite3_context], i32, ptr[ptr[sqlite3_value]]], None],
        final: Callable[[ptr[sqlite3_context]], None],
        destroy: Callable[[ptr], None]
    ) -> i32;  def sqlite3_create_window_function(
        db: ptr[sqlite3_db],
        name: str,
        narg: i32,
        flags: i32,
        context: ptr,
        step: Callable[[ptr[sqlite3_context], i32, ptr[ptr[sqlite3_value]]], None],
        final: Callable[[ptr[sqlite3_context]], None],
        value: Callable[[ptr[sqlite3_context]], None],
        inverse: Callable[[ptr[sqlite3_context], i32, ptr[ptr[sqlite3_value]]], None],
        destroy: Callable[[ptr], None]
    ) -> i32;  def sqlite3_create_collation_v2(
        db: ptr[sqlite3_db],
        name: str,
        flags: i32,
        context: ptr,
        compare: Callable[[ptr, i32, ptr, i32, ptr], i32],
        destroy: Callable[[ptr], None]
    ) -> i32;  def sqlite3_user_data(context: ptr[sqlite3_context]) -> ptr;  def sqlite3_aggregate_context(
        context: ptr[sqlite3_context], size: i32
    ) -> ptr;  def sqlite3_context_db_handle(
        context: ptr[sqlite3_context]
    ) -> ptr[sqlite3_db];  def sqlite3_result_null(context: ptr[sqlite3_context]);  def sqlite3_result_int64(
        context: ptr[sqlite3_context], value: i64
    );  def sqlite3_result_double(context: ptr[sqlite3_context], value: f64);  def sqlite3_result_text(
        context: ptr[sqlite3_context], text: ptr[u8], length: i32, destructor: i64
    );  def sqlite3_result_blob(
        context: ptr[sqlite3_context], data: ptr, length: i32, destructor: i64
    );  def sqlite3_result_error(
        context: ptr[sqlite3_context], message: str, length: i32
    );  def sqlite3_result_error_nomem(context: ptr[sqlite3_context]);  def sqlite3_result_error_toobig(
        context: ptr[sqlite3_context]
    );  def sqlite3_value_type(value: ptr[sqlite3_value]) -> i32;  def sqlite3_value_int64(
        value: ptr[sqlite3_value]
    ) -> i64;  def sqlite3_value_double(value: ptr[sqlite3_value]) -> f64;  def sqlite3_value_text(
        value: ptr[sqlite3_value]
    ) -> ptr[u8];  def sqlite3_value_blob(value: ptr[sqlite3_value]) -> ptr;  def sqlite3_value_bytes(
        value: ptr[sqlite3_value]
    ) -> i32;  def sqlite3_expanded_sql(statement: ptr[sqlite3_stmt]) -> ptr[u8];  def sqlite3_db_handle(
        statement: ptr[sqlite3_stmt]
    ) -> ptr[sqlite3_db];  def sqlite3_free(address: ptr);  def sqlite3_malloc64(
        size: u64
    ) -> ptr;  def sqlite3_blob_open(
        db: ptr[sqlite3_db],
        database: str,
        table: str,
        column: str,
        row: i64,
        flags: i32,
        blob: &mut ptr[sqlite3_blob]
    ) -> i32;  def sqlite3_blob_close(blob: ptr[sqlite3_blob]) -> i32;  def sqlite3_blob_bytes(
        blob: ptr[sqlite3_blob]
    ) -> i32;  def sqlite3_blob_read(
        blob: ptr[sqlite3_blob], buffer: ptr, length: i32, offset: i32
    ) -> i32;  def sqlite3_blob_write(
        blob: ptr[sqlite3_blob], buffer: ptr, length: i32, offset: i32
    ) -> i32;  def sqlite3_backup_init(
        destination: ptr[sqlite3_db],
        destination_name: str,
        source: ptr[sqlite3_db],
        source_name: str
    ) -> ptr[sqlite3_backup];  def sqlite3_backup_step(
        backup: ptr[sqlite3_backup], pages: i32
    ) -> i32;  def sqlite3_backup_remaining(backup: ptr[sqlite3_backup]) -> i32;  def sqlite3_backup_pagecount(
        backup: ptr[sqlite3_backup]
    ) -> i32;  def sqlite3_backup_finish(backup: ptr[sqlite3_backup]) -> i32;  def sqlite3_sleep(
        ms: i32
    ) -> i32;  def sqlite3_serialize(
        db: ptr[sqlite3_db], schema: str, size: &mut i64, flags: u32
    ) -> ptr[u8];  def sqlite3_deserialize(
        db: ptr[sqlite3_db],
        schema: str,
        data: ptr,
        size: i64,
        capacity: i64,
        flags: u32
    ) -> i32;  def sqlite3_column_count(statement: ptr[sqlite3_stmt]) -> i32;  def sqlite3_data_count(
        statement: ptr[sqlite3_stmt]
    ) -> i32;  def sqlite3_column_name(
        statement: ptr[sqlite3_stmt], column: i32
    ) -> ptr[u8];  def sqlite3_column_decltype(
        statement: ptr[sqlite3_stmt], column: i32
    ) -> ptr[u8];  def sqlite3_column_type(
        statement: ptr[sqlite3_stmt], column: i32
    ) -> i32;  def sqlite3_column_int64(
        statement: ptr[sqlite3_stmt], column: i32
    ) -> i64;  def sqlite3_column_double(
        statement: ptr[sqlite3_stmt], column: i32
    ) -> f64;  def sqlite3_column_text(
        statement: ptr[sqlite3_stmt], column: i32
    ) -> ptr[u8];  def sqlite3_column_blob(
        statement: ptr[sqlite3_stmt], column: i32
    ) -> ptr;  def sqlite3_column_bytes(
        statement: ptr[sqlite3_stmt], column: i32
    ) -> i32;  def sqlite3_bind_parameter_count(statement: ptr[sqlite3_stmt]) -> i32;  def sqlite3_bind_parameter_name(
        statement: ptr[sqlite3_stmt], index: i32
    ) -> ptr[u8];  def sqlite3_bind_null(
        statement: ptr[sqlite3_stmt], index: i32
    ) -> i32;  def sqlite3_bind_int64(
        statement: ptr[sqlite3_stmt], index: i32, value: i64
    ) -> i32;  def sqlite3_bind_double(
        statement: ptr[sqlite3_stmt], index: i32, value: f64
    ) -> i32;  def sqlite3_bind_text(
        statement: ptr[sqlite3_stmt],
        index: i32,
        text: ptr[u8],
        length: i32,
        destructor: i64
    ) -> i32;  def sqlite3_bind_blob(
        statement: ptr[sqlite3_stmt],
        index: i32,
        data: ptr,
        length: i32,
        destructor: i64
    ) -> i32;  def sqlite3_stmt_readonly(statement: ptr[sqlite3_stmt]) -> i32;  def sqlite3_stmt_busy(
        statement: ptr[sqlite3_stmt]
    ) -> i32;
}

# sqlite3.h (SQLite 3.53.4) values the module uses and publishes.
glob:priv SQLITE_OK: i32 = 0,
     SQLITE_ERROR: i32 = 1,
     SQLITE_INTERNAL: i32 = 2,
     SQLITE_PERM: i32 = 3,
     SQLITE_ABORT: i32 = 4,
     SQLITE_BUSY: i32 = 5,
     SQLITE_LOCKED: i32 = 6,
     SQLITE_NOMEM: i32 = 7,
     SQLITE_READONLY: i32 = 8,
     SQLITE_INTERRUPT: i32 = 9,
     SQLITE_IOERR: i32 = 10,
     SQLITE_CORRUPT: i32 = 11,
     SQLITE_NOTFOUND: i32 = 12,
     SQLITE_FULL: i32 = 13,
     SQLITE_CANTOPEN: i32 = 14,
     SQLITE_PROTOCOL: i32 = 15,
     SQLITE_EMPTY: i32 = 16,
     SQLITE_SCHEMA: i32 = 17,
     SQLITE_TOOBIG: i32 = 18,
     SQLITE_CONSTRAINT: i32 = 19,
     SQLITE_MISMATCH: i32 = 20,
     SQLITE_MISUSE: i32 = 21,
     SQLITE_RANGE: i32 = 25,
     SQLITE_ROW: i32 = 100,
     SQLITE_DONE: i32 = 101,
     SQLITE_DENY: i32 = 1,
     SQLITE_OPEN_READWRITE: i32 = 2,
     SQLITE_OPEN_CREATE: i32 = 4,
     SQLITE_OPEN_URI: i32 = 64,
     SQLITE_UTF8: i32 = 1,
     SQLITE_DETERMINISTIC: i32 = 2048,
     SQLITE_TRACE_STMT: u32 = 1,
     SQLITE_INTEGER: i32 = 1,
     SQLITE_FLOAT: i32 = 2,
     SQLITE_TEXT: i32 = 3,
     SQLITE_BLOB: i32 = 4,
     SQLITE_NULL: i32 = 5,
     SQLITE_LIMIT_SQL_LENGTH: i32 = 1,
     SQLITE_LIMIT_FUNCTION_ARG: i32 = 6,
     SQLITE_SERIALIZE_NOCOPY: u32 = 1,
     SQLITE_DESERIALIZE_FREEONCLOSE: u32 = 1,
     SQLITE_DESERIALIZE_RESIZEABLE: u32 = 2,
     # SQLITE_TRANSIENT, ((sqlite3_destructor_type)-1): SQLite copies the data.
     SQLITE_TRANSIENT: i64 = -1,
     INT_MAX: i64 = 2147483647,
     PY_EQ: i32 = 2,
     PY_NE: i32 = 3;

# The connection's transaction control (enum autocommit_mode).
glob LEGACY_TRANSACTION_CONTROL: i32 = -1;
glob:priv AUTOCOMMIT_LEGACY: i32 = -1,
     AUTOCOMMIT_ENABLED: i32 = 1,
     AUTOCOMMIT_DISABLED: i32 = 0,
     PARSE_DECLTYPES: i32 = 1,
     PARSE_COLNAMES: i32 = 2,
     BLOB_SEEK_START: i32 = 0,
     BLOB_SEEK_CUR: i32 = 1,
     BLOB_SEEK_END: i32 = 2;

# PY_SQLITE_ENABLE_LOAD_EXTENSION: JacPython builds, like CPython's default
# configure, leave loadable extensions disabled (the vendored SQLite omits
# them), so Connection has no enable_load_extension() or load_extension().
glob ENABLE_LOAD_EXTENSION: bool = False;

# The SQLite result codes the module publishes (error_codes[]).
glob ERROR_CODES: list[tuple[str, i64]] = [
         ("SQLITE_ABORT", 4),
         ("SQLITE_AUTH", 23),
         ("SQLITE_BUSY", 5),
         ("SQLITE_CANTOPEN", 14),
         ("SQLITE_CONSTRAINT", 19),
         ("SQLITE_CORRUPT", 11),
         ("SQLITE_DONE", 101),
         ("SQLITE_EMPTY", 16),
         ("SQLITE_ERROR", 1),
         ("SQLITE_FORMAT", 24),
         ("SQLITE_FULL", 13),
         ("SQLITE_INTERNAL", 2),
         ("SQLITE_INTERRUPT", 9),
         ("SQLITE_IOERR", 10),
         ("SQLITE_LOCKED", 6),
         ("SQLITE_MISMATCH", 20),
         ("SQLITE_MISUSE", 21),
         ("SQLITE_NOLFS", 22),
         ("SQLITE_NOMEM", 7),
         ("SQLITE_NOTADB", 26),
         ("SQLITE_NOTFOUND", 12),
         ("SQLITE_OK", 0),
         ("SQLITE_PERM", 3),
         ("SQLITE_PROTOCOL", 15),
         ("SQLITE_RANGE", 25),
         ("SQLITE_READONLY", 8),
         ("SQLITE_ROW", 100),
         ("SQLITE_SCHEMA", 17),
         ("SQLITE_TOOBIG", 18),
         ("SQLITE_NOTICE", 27),
         ("SQLITE_WARNING", 28),
         ("SQLITE_ABORT_ROLLBACK", 516),
         ("SQLITE_BUSY_RECOVERY", 261),
         ("SQLITE_CANTOPEN_FULLPATH", 782),
         ("SQLITE_CANTOPEN_ISDIR", 526),
         ("SQLITE_CANTOPEN_NOTEMPDIR", 270),
         ("SQLITE_CORRUPT_VTAB", 267),
         ("SQLITE_IOERR_ACCESS", 3338),
         ("SQLITE_IOERR_BLOCKED", 2826),
         ("SQLITE_IOERR_CHECKRESERVEDLOCK", 3594),
         ("SQLITE_IOERR_CLOSE", 4106),
         ("SQLITE_IOERR_DELETE", 2570),
         ("SQLITE_IOERR_DELETE_NOENT", 5898),
         ("SQLITE_IOERR_DIR_CLOSE", 4362),
         ("SQLITE_IOERR_DIR_FSYNC", 1290),
         ("SQLITE_IOERR_FSTAT", 1802),
         ("SQLITE_IOERR_FSYNC", 1034),
         ("SQLITE_IOERR_LOCK", 3850),
         ("SQLITE_IOERR_NOMEM", 3082),
         ("SQLITE_IOERR_RDLOCK", 2314),
         ("SQLITE_IOERR_READ", 266),
         ("SQLITE_IOERR_SEEK", 5642),
         ("SQLITE_IOERR_SHMLOCK", 5130),
         ("SQLITE_IOERR_SHMMAP", 5386),
         ("SQLITE_IOERR_SHMOPEN", 4618),
         ("SQLITE_IOERR_SHMSIZE", 4874),
         ("SQLITE_IOERR_SHORT_READ", 522),
         ("SQLITE_IOERR_TRUNCATE", 1546),
         ("SQLITE_IOERR_UNLOCK", 2058),
         ("SQLITE_IOERR_WRITE", 778),
         ("SQLITE_LOCKED_SHAREDCACHE", 262),
         ("SQLITE_READONLY_CANTLOCK", 520),
         ("SQLITE_READONLY_RECOVERY", 264),
         ("SQLITE_CONSTRAINT_CHECK", 275),
         ("SQLITE_CONSTRAINT_COMMITHOOK", 531),
         ("SQLITE_CONSTRAINT_FOREIGNKEY", 787),
         ("SQLITE_CONSTRAINT_FUNCTION", 1043),
         ("SQLITE_CONSTRAINT_NOTNULL", 1299),
         ("SQLITE_CONSTRAINT_PRIMARYKEY", 1555),
         ("SQLITE_CONSTRAINT_TRIGGER", 1811),
         ("SQLITE_CONSTRAINT_UNIQUE", 2067),
         ("SQLITE_CONSTRAINT_VTAB", 2323),
         ("SQLITE_READONLY_ROLLBACK", 776),
         ("SQLITE_IOERR_MMAP", 6154),
         ("SQLITE_NOTICE_RECOVER_ROLLBACK", 539),
         ("SQLITE_NOTICE_RECOVER_WAL", 283),
         ("SQLITE_BUSY_SNAPSHOT", 517),
         ("SQLITE_IOERR_GETTEMPPATH", 6410),
         ("SQLITE_WARNING_AUTOINDEX", 284),
         ("SQLITE_CANTOPEN_CONVPATH", 1038),
         ("SQLITE_IOERR_CONVPATH", 6666),
         ("SQLITE_CONSTRAINT_ROWID", 2579),
         ("SQLITE_READONLY_DBMOVED", 1032),
         ("SQLITE_AUTH_USER", 279),
         ("SQLITE_IOERR_VNODE", 6922),
         ("SQLITE_IOERR_AUTH", 7178),
         ("SQLITE_OK_LOAD_PERMANENTLY", 256),
         ("SQLITE_IOERR_BEGIN_ATOMIC", 7434),
         ("SQLITE_IOERR_COMMIT_ATOMIC", 7690),
         ("SQLITE_IOERR_ROLLBACK_ATOMIC", 7946),
         ("SQLITE_ERROR_MISSING_COLLSEQ", 257),
         ("SQLITE_ERROR_RETRY", 513),
         ("SQLITE_READONLY_CANTINIT", 1288),
         ("SQLITE_READONLY_DIRECTORY", 1544),
         ("SQLITE_CORRUPT_SEQUENCE", 523),
         ("SQLITE_LOCKED_VTAB", 518),
         ("SQLITE_CANTOPEN_DIRTYWAL", 1294),
         ("SQLITE_ERROR_SNAPSHOT", 769),
         ("SQLITE_CANTOPEN_SYMLINK", 1550),
         ("SQLITE_CONSTRAINT_PINNED", 2835),
         ("SQLITE_OK_SYMLINK", 512),
         ("SQLITE_BUSY_TIMEOUT", 773),
         ("SQLITE_CORRUPT_INDEX", 779),
         ("SQLITE_IOERR_DATA", 8202),
         ("SQLITE_IOERR_CORRUPTFS", 8458)
     ];
# The integer constants add_integer_constants() publishes.
glob INTEGER_CONSTANTS: list[tuple[str, i64]] = [
         ("PARSE_DECLTYPES", 1),
         ("PARSE_COLNAMES", 2),
         ("SQLITE_DENY", 1),
         ("SQLITE_IGNORE", 2),
         ("SQLITE_CREATE_INDEX", 1),
         ("SQLITE_CREATE_TABLE", 2),
         ("SQLITE_CREATE_TEMP_INDEX", 3),
         ("SQLITE_CREATE_TEMP_TABLE", 4),
         ("SQLITE_CREATE_TEMP_TRIGGER", 5),
         ("SQLITE_CREATE_TEMP_VIEW", 6),
         ("SQLITE_CREATE_TRIGGER", 7),
         ("SQLITE_CREATE_VIEW", 8),
         ("SQLITE_DELETE", 9),
         ("SQLITE_DROP_INDEX", 10),
         ("SQLITE_DROP_TABLE", 11),
         ("SQLITE_DROP_TEMP_INDEX", 12),
         ("SQLITE_DROP_TEMP_TABLE", 13),
         ("SQLITE_DROP_TEMP_TRIGGER", 14),
         ("SQLITE_DROP_TEMP_VIEW", 15),
         ("SQLITE_DROP_TRIGGER", 16),
         ("SQLITE_DROP_VIEW", 17),
         ("SQLITE_INSERT", 18),
         ("SQLITE_PRAGMA", 19),
         ("SQLITE_READ", 20),
         ("SQLITE_SELECT", 21),
         ("SQLITE_TRANSACTION", 22),
         ("SQLITE_UPDATE", 23),
         ("SQLITE_ATTACH", 24),
         ("SQLITE_DETACH", 25),
         ("SQLITE_ALTER_TABLE", 26),
         ("SQLITE_REINDEX", 27),
         ("SQLITE_ANALYZE", 28),
         ("SQLITE_CREATE_VTABLE", 29),
         ("SQLITE_DROP_VTABLE", 30),
         ("SQLITE_FUNCTION", 31),
         ("SQLITE_SAVEPOINT", 32),
         ("SQLITE_RECURSIVE", 33),
         ("SQLITE_LIMIT_LENGTH", 0),
         ("SQLITE_LIMIT_SQL_LENGTH", 1),
         ("SQLITE_LIMIT_COLUMN", 2),
         ("SQLITE_LIMIT_EXPR_DEPTH", 3),
         ("SQLITE_LIMIT_COMPOUND_SELECT", 4),
         ("SQLITE_LIMIT_VDBE_OP", 5),
         ("SQLITE_LIMIT_FUNCTION_ARG", 6),
         ("SQLITE_LIMIT_ATTACHED", 7),
         ("SQLITE_LIMIT_LIKE_PATTERN_LENGTH", 8),
         ("SQLITE_LIMIT_VARIABLE_NUMBER", 9),
         ("SQLITE_LIMIT_TRIGGER_DEPTH", 10),
         ("SQLITE_LIMIT_WORKER_THREADS", 11),
         ("SQLITE_DBCONFIG_ENABLE_FKEY", 1002),
         ("SQLITE_DBCONFIG_ENABLE_TRIGGER", 1003),
         ("SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER", 1004),
         ("SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION", 1005),
         ("SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE", 1006),
         ("SQLITE_DBCONFIG_ENABLE_QPSG", 1007),
         ("SQLITE_DBCONFIG_TRIGGER_EQP", 1008),
         ("SQLITE_DBCONFIG_RESET_DATABASE", 1009),
         ("SQLITE_DBCONFIG_DEFENSIVE", 1010),
         ("SQLITE_DBCONFIG_WRITABLE_SCHEMA", 1011),
         ("SQLITE_DBCONFIG_DQS_DDL", 1014),
         ("SQLITE_DBCONFIG_DQS_DML", 1013),
         ("SQLITE_DBCONFIG_LEGACY_ALTER_TABLE", 1012),
         ("SQLITE_DBCONFIG_ENABLE_VIEW", 1015),
         ("SQLITE_DBCONFIG_LEGACY_FILE_FORMAT", 1016),
         ("SQLITE_DBCONFIG_TRUSTED_SCHEMA", 1017)
     ];

# The handle of the module definition, which the binding fills in, so a type
# finds its module as PyType_GetModuleByDef() does.
obj DefinitionHandle {
    has handle: ptr = ptr();
}

glob module_definition = DefinitionHandle(),
     Connection_token = ClassToken(),
     Cursor_token = ClassToken(),
     Row_token = ClassToken(),
     Blob_token = ClassToken(),
     Statement_token = ClassToken(),
     PrepareProtocol_token = ClassToken();

# pysqlite_state.
obj SqliteState(NativeState) {
    has DataError: ptr[PyObject] = NULL,
        DatabaseError: ptr[PyObject] = NULL,
        Error: ptr[PyObject] = NULL,
        IntegrityError: ptr[PyObject] = NULL,
        InterfaceError: ptr[PyObject] = NULL,
        InternalError: ptr[PyObject] = NULL,
        NotSupportedError: ptr[PyObject] = NULL,
        OperationalError: ptr[PyObject] = NULL,
        ProgrammingError: ptr[PyObject] = NULL,
        Warning: ptr[PyObject] = NULL,
        # Column types (uppercase) to converter functions.
        converters: ptr[PyObject] = NULL,
        lru_cache: ptr[PyObject] = NULL,
        # The adapters registry.
        psyco_adapters: ptr[PyObject] = NULL,
        base_type_adapted: bool = False,
        enable_callback_tracebacks: bool = False,
        BlobType: ptr[PyObject] = NULL,
        ConnectionType: ptr[PyObject] = NULL,
        CursorType: ptr[PyObject] = NULL,
        PrepareProtocolType: ptr[PyObject] = NULL,
        RowType: ptr[PyObject] = NULL,
        StatementType: ptr[PyObject] = NULL,
        str___adapt__: ptr[PyObject] = NULL,
        str___conform__: ptr[PyObject] = NULL,
        str_executescript: ptr[PyObject] = NULL,
        str_finalize: ptr[PyObject] = NULL,
        str_inverse: ptr[PyObject] = NULL,
        str_step: ptr[PyObject] = NULL,
        str_upper: ptr[PyObject] = NULL,
        str_value: ptr[PyObject] = NULL;

    def visited -> list[ptr[PyObject]] {
        return [
            self.DataError,
            self.DatabaseError,
            self.Error,
            self.IntegrityError,
            self.InterfaceError,
            self.InternalError,
            self.NotSupportedError,
            self.OperationalError,
            self.ProgrammingError,
            self.Warning,
            self.BlobType,
            self.ConnectionType,
            self.CursorType,
            self.PrepareProtocolType,
            self.RowType,
            self.StatementType,
            self.converters,
            self.lru_cache,
            self.psyco_adapters
        ];
    }

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        for value in self.visited() {
            status = visit_reference(value, visitor, context);
            if status != 0 {
                return status;
            }
        }
        return i32(0);
    }

    def clear {
        references = self.visited()
            + [
                self.str___adapt__,
                self.str___conform__,
                self.str_executescript,
                self.str_finalize,
                self.str_inverse,
                self.str_step,
                self.str_upper,
                self.str_value
            ];
        self.DataError = NULL;
        self.DatabaseError = NULL;
        self.Error = NULL;
        self.IntegrityError = NULL;
        self.InterfaceError = NULL;
        self.InternalError = NULL;
        self.NotSupportedError = NULL;
        self.OperationalError = NULL;
        self.ProgrammingError = NULL;
        self.Warning = NULL;
        self.BlobType = NULL;
        self.ConnectionType = NULL;
        self.CursorType = NULL;
        self.PrepareProtocolType = NULL;
        self.RowType = NULL;
        self.StatementType = NULL;
        self.converters = NULL;
        self.lru_cache = NULL;
        self.psyco_adapters = NULL;
        self.str___adapt__ = NULL;
        self.str___conform__ = NULL;
        self.str_executescript = NULL;
        self.str_finalize = NULL;
        self.str_inverse = NULL;
        self.str_step = NULL;
        self.str_upper = NULL;
        self.str_value = NULL;
        for value in references {
            jacpy_release(value);
        }
    }

    def drop {
        self.clear();
    }
}

# pysqlite_get_state(): the state of a _sqlite3 module object.
def module_state(module: ptr[PyObject]) -> (SqliteState | None) {
    if module and jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, SqliteState) {
            return state;
        }
    }
    if not PyErr_Occurred() {
        object_error(PyExc_SystemError, "_sqlite3 module state is unavailable");
    }
    return None;
}

# pysqlite_get_state_by_type(): the state of the module defining `type`.
def state_by_type(type: ptr[PyObject]) -> (SqliteState | None) {
    return module_state(jacpy_binding_owner(type, module_definition.handle));
}

def:priv state_of(instance: ptr[PyObject]) -> (SqliteState | None) {
    return state_by_type(Py_TYPE(instance));
}

# PyUnicode_FromStringAndSize() over C memory: a strict UTF-8 decode.
def:priv unicode_from_memory(address: ptr, size: i64) -> ptr[PyObject] {
    return PyUnicode_DecodeUTF8Stateful(address, size, ptr[u8](), None);
}

# PyBytes_FromStringAndSize() over C memory.
def:priv bytes_from_memory(address: ptr, size: i64) -> ptr[PyObject] {
    if size == 0 {
        return jacpy_buffer_new(0);
    }
    return jacpy_bytes_from_memory(address, size);
}

def:priv tp_name(value: ptr[PyObject]) -> ptr[u8] {
    return object_type(value).view(1)[0].tp_name;
}

# Py_BEGIN_ALLOW_THREADS / Py_END_ALLOW_THREADS around one SQLite call.
def:priv step_unlocked(statement: ptr[sqlite3_stmt]) -> i32 {
    thread = PyEval_SaveThread();
    rc = sqlite3_step(statement);
    PyEval_RestoreThread(thread);
    return rc;
}

# ------------------------------------------------------------------- util.c

# get_exception_class(): the class a result code raises; NULL when none is
# to be raised (SQLITE_OK clears the error, SQLITE_NOMEM sets MemoryError).
def:priv get_exception_class(state: SqliteState, errorcode: i32) -> ptr[PyObject] {
    if errorcode == SQLITE_OK {
        PyErr_Clear();
        return NULL;
    }
    if errorcode == SQLITE_INTERNAL or errorcode == SQLITE_NOTFOUND {
        return state.InternalError;
    }
    if errorcode == SQLITE_NOMEM {
        return PyErr_NoMemory();
    }
    if errorcode
        in [
            SQLITE_ERROR,
            SQLITE_PERM,
            SQLITE_ABORT,
            SQLITE_BUSY,
            SQLITE_LOCKED,
            SQLITE_READONLY,
            SQLITE_INTERRUPT,
            SQLITE_IOERR,
            SQLITE_FULL,
            SQLITE_CANTOPEN,
            SQLITE_PROTOCOL,
            SQLITE_EMPTY,
            SQLITE_SCHEMA
        ] {
        return state.OperationalError;
    }
    if errorcode == SQLITE_CORRUPT {
        return state.DatabaseError;
    }
    if errorcode == SQLITE_TOOBIG {
        return state.DataError;
    }
    if errorcode == SQLITE_CONSTRAINT or errorcode == SQLITE_MISMATCH {
        return state.IntegrityError;
    }
    if errorcode == SQLITE_MISUSE or errorcode == SQLITE_RANGE {
        return state.InterfaceError;
    }
    return state.DatabaseError;
}

# pysqlite_error_name(): the name of a result code, or "" for none.
def error_name(code: i64) -> str {
    for (name, value) in ERROR_CODES {
        if value == code {
            return name;
        }
    }
    return "";
}

def:priv raise_exception(type: ptr[PyObject], errcode: i32, errmsg: ptr[u8]) {
    message = c_string_text(errmsg);
    if not message {
        return;
    }
    exc = PyObject_CallOneArg(type, message);
    jacpy_release(message);
    if not exc {
        return;
    }
    code = PyLong_FromLong(i64(errcode));
    if not code {
        jacpy_release(exc);
        return;
    }
    rc = PyObject_SetAttrString(exc, "sqlite_errorcode", code);
    jacpy_release(code);
    if rc < 0 {
        jacpy_release(exc);
        return;
    }
    known = error_name(i64(errcode));
    name = PyUnicode_FromString(known)
        if known
        else PyUnicode_InternFromString("unknown");
    if not name {
        jacpy_release(exc);
        return;
    }
    rc = PyObject_SetAttrString(exc, "sqlite_errorname", name);
    jacpy_release(name);
    if rc < 0 {
        jacpy_release(exc);
        return;
    }
    PyErr_SetObject(type, exc);
    jacpy_release(exc);
}

def set_error_from_code(state: SqliteState, code: i32) {
    exc_class = get_exception_class(state, code);
    if not exc_class {
        return;
    }
    raise_exception(exc_class, code, sqlite3_errstr(code));
}

# set_error_from_db(): the DB-API exception for the connection's last error.
def set_error_from_db(state: SqliteState, db: ptr[sqlite3_db]) {
    exc_class = get_exception_class(state, sqlite3_errcode(db));
    if not exc_class {
        return;
    }
    # sqlite3_errmsg() always returns an UTF-8 encoded message.
    raise_exception(exc_class, sqlite3_extended_errcode(db), sqlite3_errmsg(db));
}

# _pysqlite_long_as_int64(): -1 with the exception set on failure.
def long_as_int64(value: ptr[PyObject]) -> i64 {
    overflow: i32 = 0;
    result = PyLong_AsLongLongAndOverflow(value, &mut overflow);
    if result == -1 and PyErr_Occurred() {
        return -1;
    }
    if overflow == 0 {
        return result;
    }
    object_error(
        PyExc_OverflowError, "Python int too large to convert to SQLite INTEGER"
    );
    return -1;
}

# --------------------------------------------------------- microprotocols.c

def microprotocols_add(
    state: SqliteState, type: ptr[PyObject], proto: ptr[PyObject], cast: ptr[PyObject]
) -> i32 {
    key = PyTuple_Pack(2, type, proto);
    if not key {
        return i32(-1);
    }
    rc = PyDict_SetItem(state.psyco_adapters, key, cast);
    jacpy_release(key);
    return rc;
}

# pysqlite_microprotocols_adapt(): the registry's adapter, then the
# protocol's __adapt__, then the object's __conform__, then `alt`.
def microprotocols_adapt(
    state: SqliteState, value: ptr[PyObject], proto: ptr[PyObject], alt: ptr[PyObject]
) -> ptr[PyObject] {
    key = PyTuple_Pack(2, Py_TYPE(value), proto);
    if not key {
        return NULL;
    }
    adapter = NULL;
    if PyDict_GetItemRef(state.psyco_adapters, key, &mut adapter) < 0 {
        jacpy_release(key);
        return NULL;
    }
    jacpy_release(key);
    if adapter {
        adapted = PyObject_CallOneArg(adapter, value);
        jacpy_release(adapter);
        return adapted;
    }
    # Try to have the protocol adapt this object.
    if PyObject_GetOptionalAttr(proto, state.str___adapt__, &mut adapter) < 0 {
        return NULL;
    }
    if adapter {
        adapted = PyObject_CallOneArg(adapter, value);
        jacpy_release(adapter);
        if adapted == Py_None {
            jacpy_release(adapted);
        } elif adapted or PyErr_ExceptionMatches(PyExc_TypeError) == 0 {
            return adapted;
        } else {
            PyErr_Clear();
        }
    }
    # And finally try to have the object adapt itself.
    adapter = NULL;
    if PyObject_GetOptionalAttr(value, state.str___conform__, &mut adapter) < 0 {
        return NULL;
    }
    if adapter {
        adapted = PyObject_CallOneArg(adapter, proto);
        jacpy_release(adapter);
        if adapted == Py_None {
            jacpy_release(adapted);
        } elif adapted or PyErr_ExceptionMatches(PyExc_TypeError) == 0 {
            return adapted;
        } else {
            PyErr_Clear();
        }
    }
    if alt {
        return Py_NewRef(alt);
    }
    object_error(state.ProgrammingError, "can't adapt");
    return NULL;
}

# ---------------------------------------------------- object field records

import from c {
    # The Connection fields published as member descriptors: the module's
    # exception classes, borrowed.
    obj connection_members {
        has Warning: ptr[PyObject],
            Error: ptr[PyObject],
            InterfaceError: ptr[PyObject],
            DatabaseError: ptr[PyObject],
            DataError: ptr[PyObject],
            OperationalError: ptr[PyObject],
            IntegrityError: ptr[PyObject],
            InternalError: ptr[PyObject],
            ProgrammingError: ptr[PyObject],
            NotSupportedError: ptr[PyObject];
    }
    # The Cursor fields published as member descriptors; the object
    # references are owned.
    obj cursor_members {
        has connection: ptr[PyObject],
            description: ptr[PyObject],
            lastrowid: ptr[PyObject],
            rowcount: i64,
            row_factory: ptr[PyObject];
    }
}

# Py_T_OBJECT and Py_T_LONG member types, and the record layouts.
glob:priv T_OBJECT: int = 6,
     T_LONG: int = 2;

glob CONNECTION_RECORD_SIZE: int = 80,
     CONNECTION_MEMBERS: list[MemberField] = [
         MemberField(name="Warning", kind=T_OBJECT, offset=0, readonly=True),
         MemberField(name="Error", kind=T_OBJECT, offset=8, readonly=True),
         MemberField(name="InterfaceError", kind=T_OBJECT, offset=16, readonly=True),
         MemberField(name="DatabaseError", kind=T_OBJECT, offset=24, readonly=True),
         MemberField(name="DataError", kind=T_OBJECT, offset=32, readonly=True),
         MemberField(name="OperationalError", kind=T_OBJECT, offset=40, readonly=True),
         MemberField(name="IntegrityError", kind=T_OBJECT, offset=48, readonly=True),
         MemberField(name="InternalError", kind=T_OBJECT, offset=56, readonly=True),
         MemberField(name="ProgrammingError", kind=T_OBJECT, offset=64, readonly=True),
         MemberField(name="NotSupportedError", kind=T_OBJECT, offset=72, readonly=True)
     ],
     CURSOR_RECORD_SIZE: int = 40,
     CURSOR_MEMBERS: list[MemberField] = [
         MemberField(name="connection", kind=T_OBJECT, offset=0, readonly=True),
         MemberField(name="description", kind=T_OBJECT, offset=8, readonly=True),
         MemberField(name="lastrowid", kind=T_OBJECT, offset=16, readonly=True),
         MemberField(name="rowcount", kind=T_LONG, offset=24, readonly=True),
         MemberField(name="row_factory", kind=T_OBJECT, offset=32)
     ];

# ------------------------------------------------------------- statement.c

# pysqlite_Statement.
obj StatementState(NativeState) {
    has st: ptr[sqlite3_stmt] = ptr[sqlite3_stmt](),
        is_dml: bool = False;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
}

def statement_of(instance: ptr[PyObject]) -> (StatementState | None) {
    if jacpy_binding_native_present(instance, Statement_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, Statement_token.handle);
        if isinstance(state, StatementState) {
            return state;
        }
    }
    return None;
}

# stmt_dealloc(): finalize the statement with the GIL released.
def statement_finalize(instance: ptr[PyObject]) {
    statement = statement_of(instance);
    if statement is not None and not statement.st.is_null() {
        st = statement.st;
        statement.st = ptr[sqlite3_stmt]();
        thread = PyEval_SaveThread();
        sqlite3_finalize(st);
        PyEval_RestoreThread(thread);
    }
}

# lstrip_sql(): the first character of `sql` that is not whitespace or a
# comment, or NULL when there is none (a loop borrowed from SQLite).
def:priv lstrip_sql(sql: ptr[u8]) -> ptr[u8] {
    pos = sql;
    while pos.view(1)[0] != 0 {
        c = pos.view(1)[0];
        if c == 32 or c == 9 or c == 12 or c == 10 or c == 13 {
            pos += 1;
            continue;
        }
        if c == 45 {
            # Skip line comments.
            if (pos + 1).view(1)[0] == 45 {
                pos += 2;
                while pos.view(1)[0] != 0 and pos.view(1)[0] != 10 {
                    pos += 1;
                }
                if pos.view(1)[0] == 0 {
                    return ptr[u8]();
                }
                continue;
            }
            return pos;
        }
        if c == 47 {
            # Skip C style comments.
            if (pos + 1).view(1)[0] == 42 {
                pos += 2;
                while pos.view(1)[0] != 0
                    and (pos.view(1)[0] != 42 or (pos + 1).view(1)[0] != 47) {
                    pos += 1;
                }
                if pos.view(1)[0] == 0 {
                    return ptr[u8]();
                }
                pos += 2;
                continue;
            }
            return pos;
        }
        return pos;
    }
    return ptr[u8]();
}

# PyOS_strnicmp(p, word, len(word)) == 0 for an ASCII keyword.
def:priv starts_with_keyword(p: ptr[u8], word: str) -> bool {
    for i in range(len(word)) {
        c = int((p + i).view(1)[0]);
        if c == 0 {
            return False;
        }
        if c >= 65 and c <= 90 {
            c += 32;
        }
        if c != ord(word[i]) {
            return False;
        }
    }
    return True;
}

# pysqlite_statement_create().
def statement_create(
    con_object: ptr[PyObject], con: ConnectionState, sql: ptr[PyObject]
) -> ptr[PyObject] {
    state = con.state;
    size: i64 = 0;
    sql_cstr = PyUnicode_AsUTF8AndSize(sql, &mut size);
    if sql_cstr.is_null() {
        return NULL;
    }
    db = con.db;
    max_length = sqlite3_limit(db, SQLITE_LIMIT_SQL_LENGTH, i32(-1));
    if size > i64(max_length) {
        object_error(state.DataError, "query string is too large");
        return NULL;
    }
    if i64(c_string_length(sql_cstr)) != size {
        object_error(state.ProgrammingError, "the query contains a null character");
        return NULL;
    }
    stmt = ptr[sqlite3_stmt]();
    tail = ptr[u8]();
    thread = PyEval_SaveThread();
    rc = sqlite3_prepare_v2(db, sql_cstr, i32(size + 1), &mut stmt, &mut tail);
    PyEval_RestoreThread(thread);
    if rc != SQLITE_OK {
        set_error_from_db(state, db);
        return NULL;
    }
    if not lstrip_sql(tail).is_null() {
        object_error(
            state.ProgrammingError, "You can only execute one statement at a time."
        );
        sqlite3_finalize(stmt);
        return NULL;
    }
    # Determine if the statement is a DML statement. SELECT is the only
    # exception. See #9924.
    is_dml = False;
    p = lstrip_sql(sql_cstr);
    if not p.is_null() {
        is_dml = starts_with_keyword(p, "insert")
            or starts_with_keyword(p, "update")
            or starts_with_keyword(p, "delete")
            or starts_with_keyword(p, "replace");
    }
    instance = jacpy_binding_allocate(state.StatementType);
    if not instance {
        sqlite3_finalize(stmt);
        return NULL;
    }
    statement = StatementState(st=stmt, is_dml=is_dml);
    if jacpy_binding_native_set(instance, Statement_token.handle, statement) < 0 {
        sqlite3_finalize(stmt);
        statement.st = ptr[sqlite3_stmt]();
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

# The cursor's statement object's state; a blank one (no sqlite3_stmt) when
# the object is not a statement.
def:priv current_statement(cur: CursorState) -> StatementState {
    statement = statement_of(cur.statement) if cur.statement else None;
    return statement if statement is not None else StatementState();
}

def:priv stmt_reset(statement: StatementState) -> i32 {
    rc = SQLITE_OK;
    if not statement.st.is_null() {
        thread = PyEval_SaveThread();
        rc = sqlite3_reset(statement.st);
        PyEval_RestoreThread(thread);
    }
    return rc;
}

# Reset the statement object `instance` (a pysqlite_Statement), if any.
def:priv reset_statement_object(instance: ptr[PyObject]) -> i32 {
    if not instance {
        return SQLITE_OK;
    }
    statement = statement_of(instance);
    return stmt_reset(statement) if statement is not None else SQLITE_OK;
}

# ------------------------------------------------------------ connection.c

# pysqlite_Connection, apart from the exception fields of its record.
obj ConnectionState(NativeState) {
    has state: SqliteState = SqliteState(),
        db: ptr[sqlite3_db] = ptr[sqlite3_db](),
        # The type detection mode: 0, PARSE_DECLTYPES, PARSE_COLNAMES or both.
        detect_types: i32 = 0,
        # None for autocommit, otherwise the isolation level.
        isolation_level: (str | None) = None,
        autocommit: i32 = 0,
        check_same_thread: bool = False,
        initialized: bool = False,
        # The thread the connection was created in.
        thread_ident: u64 = 0,
        statement_cache: ptr[PyObject] = NULL,
        # Lists of weak references to cursors and blobs of this connection.
        cursors: ptr[PyObject] = NULL,
        blobs: ptr[PyObject] = NULL,
        created_cursors: int = 0,
        row_factory: ptr[PyObject] = NULL,
        # How TEXT values become Python objects: str, bytes, bytearray or a
        # callable.
        text_factory: ptr[PyObject] = NULL,
        # The contexts of the trace, progress and authorizer callbacks.
        trace_ctx: ptr[callback_context] = ptr[callback_context](),
        progress_ctx: ptr[callback_context] = ptr[callback_context](),
        authorizer_ctx: ptr[callback_context] = ptr[callback_context]();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        for value in [
            self.statement_cache,
            self.cursors,
            self.blobs,
            self.row_factory,
            self.text_factory
        ] {
            status = visit_reference(value, visitor, context);
            if status != 0 {
                return status;
            }
        }
        for ctx in [self.trace_ctx, self.progress_ctx, self.authorizer_ctx] {
            if not ctx.is_null() {
                record = ctx.view(1);
                status = visit_reference(record[0].callable, visitor, context);
                if status == 0 {
                    status = visit_reference(record[0].module, visitor, context);
                }
                if status != 0 {
                    return status;
                }
            }
        }
        return i32(0);
    }

    # connection_clear().
    def clear {
        references = [
            self.statement_cache,
            self.cursors,
            self.blobs,
            self.row_factory,
            self.text_factory
        ];
        self.statement_cache = NULL;
        self.cursors = NULL;
        self.blobs = NULL;
        self.row_factory = NULL;
        self.text_factory = NULL;
        for value in references {
            jacpy_release(value);
        }
        for ctx in [self.trace_ctx, self.progress_ctx, self.authorizer_ctx] {
            clear_callback_context(ctx);
        }
    }
}

# The ConnectionState of a Connection instance, created on first use as the
# zeroed C struct would be; None with the error set when it cannot be.
def connection_of(instance: ptr[PyObject]) -> (ConnectionState | None) {
    if jacpy_binding_native_present(instance, Connection_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, Connection_token.handle);
        if isinstance(state, ConnectionState) {
            return state;
        }
    }
    if PyErr_Occurred() {
        return None;
    }
    fresh = ConnectionState();
    if jacpy_binding_native_set(instance, Connection_token.handle, fresh) < 0 {
        return None;
    }
    return fresh;
}

def:priv connection_fields(instance: ptr[PyObject]) -> ptr[connection_members] {
    return ptr[connection_members](
        jacpy_binding_record(instance, Connection_token.handle)
    );
}

# ---------------------------------------------- callback contexts (C records)

# create_callback_context(): the context owns a reference to the module of
# the defining class, so the module state outlives the callback.
def:priv create_callback_context(
    cls: ptr[PyObject], callable: ptr[PyObject]
) -> ptr[callback_context] {
    ctx = ptr[callback_context](PyMem_Malloc(24));
    if ctx.is_null() {
        PyErr_NoMemory();
        return ctx;
    }
    module = PyType_GetModule(cls);
    record = ctx.view(1);
    record[0].refcount = 1;
    record[0].callable = Py_NewRef(callable);
    record[0].module = Py_NewRef(module);
    return ctx;
}

def:priv free_callback_context(ctx: ptr[callback_context]) {
    record = ctx.view(1);
    jacpy_release(record[0].callable);
    jacpy_release(record[0].module);
    PyMem_Free(ctx);
}

def:priv incref_callback_context(ctx: ptr[callback_context]) {
    record = ctx.view(1);
    record[0].refcount = record[0].refcount + 1;
}

def:priv decref_callback_context(ctx: ptr[callback_context]) {
    record = ctx.view(1);
    record[0].refcount = record[0].refcount - 1;
    if record[0].refcount == 0 {
        free_callback_context(ctx);
    }
}

def:priv clear_callback_context(ctx: ptr[callback_context]) {
    if not ctx.is_null() {
        record = ctx.view(1);
        callable = record[0].callable;
        module = record[0].module;
        record[0].callable = NULL;
        record[0].module = NULL;
        jacpy_release(callable);
        jacpy_release(module);
    }
}

# set_callback_context(): the new context; the replaced one is released.
def:priv replace_callback_context(
    previous: ptr[callback_context], ctx: ptr[callback_context]
) -> ptr[callback_context] {
    if not previous.is_null() {
        decref_callback_context(previous);
    }
    return ctx;
}

def:priv free_callback_contexts(con: ConnectionState) {
    trace = con.trace_ctx;
    progress = con.progress_ctx;
    authorizer = con.authorizer_ctx;
    con.trace_ctx = ptr[callback_context]();
    con.progress_ctx = ptr[callback_context]();
    con.authorizer_ctx = ptr[callback_context]();
    replace_callback_context(trace, ptr[callback_context]());
    replace_callback_context(progress, ptr[callback_context]());
    replace_callback_context(authorizer, ptr[callback_context]());
}

# destructor_callback(): SQLite may call it without the GIL.
def:priv destructor_callback(ctx: ptr) {
    if ctx {
        gil = PyGILState_Ensure();
        decref_callback_context(ptr[callback_context](ctx));
        PyGILState_Release(gil);
    }
}

# The callback's module state, without raising.
def:priv context_state(ctx: ptr[callback_context]) -> (SqliteState | None) {
    module = ctx.view(1)[0].module;
    if module and jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, SqliteState) {
            return state;
        }
    }
    return None;
}

def:priv print_or_clear_traceback(ctx: ptr[callback_context]) {
    state = context_state(ctx);
    if state is not None and state.enable_callback_tracebacks {
        PyErr_FormatUnraisable(
            "Exception ignored on sqlite3 callback %R", ctx.view(1)[0].callable
        );
    } else {
        PyErr_Clear();
    }
}

# set_sqlite_error(): the SQLite error code for the pending Python exception.
def:priv set_sqlite_error(context: ptr[sqlite3_context], message: str) {
    if PyErr_ExceptionMatches(PyExc_MemoryError) != 0 {
        sqlite3_result_error_nomem(context);
    } elif PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
        sqlite3_result_error_toobig(context);
    } else {
        sqlite3_result_error(context, message, i32(-1));
    }
    print_or_clear_traceback(ptr[callback_context](sqlite3_user_data(context)));
}

# _pysqlite_set_result(): 0, or -1 with the exception set.
def:priv set_result(context: ptr[sqlite3_context], py_val: ptr[PyObject]) -> i32 {
    if py_val == Py_None {
        sqlite3_result_null(context);
    } elif jacpy_is_long(py_val) != 0 {
        value = long_as_int64(py_val);
        if value == -1 and PyErr_Occurred() {
            return i32(-1);
        }
        sqlite3_result_int64(context, value);
    } elif jacpy_is_float(py_val) != 0 {
        real = PyFloat_AsDouble(py_val);
        if real == -1.0 and PyErr_Occurred() {
            return i32(-1);
        }
        sqlite3_result_double(context, real);
    } elif jacpy_is_unicode(py_val) != 0 {
        size: i64 = 0;
        text = PyUnicode_AsUTF8AndSize(py_val, &mut size);
        if text.is_null() {
            return i32(-1);
        }
        if size > INT_MAX {
            object_error(PyExc_OverflowError, "string is longer than INT_MAX bytes");
            return i32(-1);
        }
        sqlite3_result_text(context, text, i32(size), SQLITE_TRANSIENT);
    } elif PyObject_CheckBuffer(py_val) != 0 {
        view = BufferArgument();
        if not view.export(py_val, 0) {
            return i32(-1);
        }
        if view.size() > INT_MAX {
            object_error(PyExc_OverflowError, "BLOB longer than INT_MAX bytes");
            view.close();
            return i32(-1);
        }
        sqlite3_result_blob(
            context, view.address(), i32(view.size()), SQLITE_TRANSIENT
        );
        view.close();
    } else {
        ctx = ptr[callback_context](sqlite3_user_data(context));
        state = context_state(ctx);
        PyErr_Format(
            state.ProgrammingError if state is not None else PyExc_SystemError,
            "User-defined functions cannot return '%s' values to SQLite",
            tp_name(py_val)
        );
        return i32(-1);
    }
    return i32(0);
}

# _pysqlite_build_py_params(): the SQL arguments as a tuple of Python values.
def:priv build_py_params(
    context: ptr[sqlite3_context], argc: i32, argv: ptr[ptr[sqlite3_value]]
) -> ptr[PyObject] {
    args = PyTuple_New(i64(argc));
    if not args {
        return NULL;
    }
    values = argv.view(int(argc)) if argc > 0 else argv.view(0);
    for i in range(int(argc)) {
        cur_value = values[i];
        kind = sqlite3_value_type(cur_value);
        cur_py_value = NULL;
        if kind == SQLITE_INTEGER {
            cur_py_value = PyLong_FromLongLong(sqlite3_value_int64(cur_value));
        } elif kind == SQLITE_FLOAT {
            cur_py_value = PyFloat_FromDouble(sqlite3_value_double(cur_value));
        } elif kind == SQLITE_TEXT {
            db = sqlite3_context_db_handle(context);
            text = sqlite3_value_text(cur_value);
            if text.is_null() and sqlite3_errcode(db) == SQLITE_NOMEM {
                PyErr_NoMemory();
                jacpy_release(args);
                return NULL;
            }
            size = i64(sqlite3_value_bytes(cur_value));
            cur_py_value = unicode_from_memory(text, size);
        } elif kind == SQLITE_BLOB {
            db = sqlite3_context_db_handle(context);
            blob = sqlite3_value_blob(cur_value);
            if not blob and sqlite3_errcode(db) == SQLITE_NOMEM {
                PyErr_NoMemory();
                jacpy_release(args);
                return NULL;
            }
            size = i64(sqlite3_value_bytes(cur_value));
            cur_py_value = bytes_from_memory(blob, size);
        } else {
            cur_py_value = Py_NewRef(Py_None);
        }
        if not cur_py_value {
            jacpy_release(args);
            return NULL;
        }
        PyTuple_SetItem(args, i64(i), cur_py_value);
    }
    return args;
}

def:priv func_callback(
    context: ptr[sqlite3_context], argc: i32, argv: ptr[ptr[sqlite3_value]]
) {
    gil = PyGILState_Ensure();
    py_retval = NULL;
    args = build_py_params(context, argc, argv);
    if args {
        ctx = ptr[callback_context](sqlite3_user_data(context));
        incref_callback_context(ctx);
        py_retval = PyObject_CallObject(ctx.view(1)[0].callable, args);
        decref_callback_context(ctx);
        jacpy_release(args);
    }
    ok = False;
    if py_retval {
        ok = set_result(context, py_retval) == 0;
        jacpy_release(py_retval);
    }
    if not ok {
        set_sqlite_error(context, "user-defined function raised exception");
    }
    PyGILState_Release(gil);
}

def:priv step_callback(
    context: ptr[sqlite3_context], argc: i32, params: ptr[ptr[sqlite3_value]]
) {
    gil = PyGILState_Ensure();
    ctx = ptr[callback_context](sqlite3_user_data(context));
    incref_callback_context(ctx);
    stepmethod = NULL;
    function_result = NULL;
    slot = ptr[ptr[PyObject]](sqlite3_aggregate_context(context, i32(8)));
    if slot.is_null() {
        PyErr_NoMemory();
        set_sqlite_error(context, "unable to allocate SQLite aggregate context");
    } else {
        ready = True;
        if not slot.view(1)[0] {
            instance = PyObject_CallNoArgs(ctx.view(1)[0].callable);
            slot.view(1)[0] = instance;
            if not instance {
                set_sqlite_error(
                    context, "user-defined aggregate's '__init__' method raised error"
                );
                ready = False;
            }
        }
        state = context_state(ctx);
        if ready and state is not None {
            stepmethod = PyObject_GetAttr(slot.view(1)[0], state.str_step);
            if not stepmethod {
                set_sqlite_error(
                    context, "user-defined aggregate's 'step' method not defined"
                );
            } else {
                args = build_py_params(context, argc, params);
                if args {
                    function_result = PyObject_CallObject(stepmethod, args);
                    jacpy_release(args);
                    if not function_result {
                        set_sqlite_error(
                            context,
                            "user-defined aggregate's 'step' method raised error"
                        );
                    }
                }
            }
        }
    }
    decref_callback_context(ctx);
    jacpy_release(stepmethod);
    jacpy_release(function_result);
    PyGILState_Release(gil);
}

def:priv final_callback(context: ptr[sqlite3_context]) {
    gil = PyGILState_Ensure();
    slot = ptr[ptr[PyObject]](sqlite3_aggregate_context(context, i32(0)));
    # With no slot, no rows matched and step never ran; with an empty one,
    # the aggregate's __init__ raised.
    if not slot.is_null() and slot.view(1)[0] {
        # Keep the exception (if any) of the last call to step, value, or
        # inverse.
        exc = PyErr_GetRaisedException();
        ctx = ptr[callback_context](sqlite3_user_data(context));
        incref_callback_context(ctx);
        state = context_state(ctx);
        instance = slot.view(1)[0];
        function_result = PyObject_CallMethodObjArgs(instance, state.str_finalize, NULL)
            if state is not None
            else NULL;
        decref_callback_context(ctx);
        jacpy_release(instance);
        ok = False;
        if function_result {
            ok = set_result(context, function_result) == 0;
            jacpy_release(function_result);
        }
        if not ok {
            attr_err = PyErr_ExceptionMatches(PyExc_AttributeError) != 0;
            _PyErr_ChainExceptions1(exc);
            # SQLite does not propagate errors of the finalize callback to
            # sqlite3_step(), so execute*() does not raise OperationalError.
            set_sqlite_error(
                context,
                "user-defined aggregate's 'finalize' method not defined"
                    if attr_err
                    else "user-defined aggregate's 'finalize' method raised error"
            );
        } else {
            PyErr_SetRaisedException(exc);
        }
    }
    PyGILState_Release(gil);
}

# inverse(): removes a row from the current window of an aggregate window
# function.
def:priv inverse_callback(
    context: ptr[sqlite3_context], argc: i32, params: ptr[ptr[sqlite3_value]]
) {
    gil = PyGILState_Ensure();
    ctx = ptr[callback_context](sqlite3_user_data(context));
    incref_callback_context(ctx);
    slot = ptr[ptr[PyObject]](sqlite3_aggregate_context(context, i32(8)));
    state = context_state(ctx);
    method = NULL;
    if state is not None {
        method = PyObject_GetAttr(slot.view(1)[0], state.str_inverse);
    }
    if not method {
        set_sqlite_error(
            context, "user-defined aggregate's 'inverse' method not defined"
        );
    } else {
        args = build_py_params(context, argc, params);
        if not args {
            set_sqlite_error(
                context,
                "unable to build arguments for user-defined aggregate's 'inverse' method"
            );
        } else {
            res = PyObject_CallObject(method, args);
            jacpy_release(args);
            if not res {
                set_sqlite_error(
                    context, "user-defined aggregate's 'inverse' method raised error"
                );
            }
            jacpy_release(res);
        }
    }
    decref_callback_context(ctx);
    jacpy_release(method);
    PyGILState_Release(gil);
}

# value(): the current value of an aggregate window function.
def:priv value_callback(context: ptr[sqlite3_context]) {
    gil = PyGILState_Ensure();
    ctx = ptr[callback_context](sqlite3_user_data(context));
    incref_callback_context(ctx);
    slot = ptr[ptr[PyObject]](sqlite3_aggregate_context(context, i32(8)));
    state = context_state(ctx);
    res = PyObject_CallMethodObjArgs(slot.view(1)[0], state.str_value, NULL)
        if state is not None
        else NULL;
    decref_callback_context(ctx);
    if not res {
        attr_err = PyErr_ExceptionMatches(PyExc_AttributeError) != 0;
        set_sqlite_error(
            context,
            "user-defined aggregate's 'value' method not defined"
                if attr_err
                else "user-defined aggregate's 'value' method raised error"
        );
    } else {
        rc = set_result(context, res);
        jacpy_release(res);
        if rc < 0 {
            set_sqlite_error(
                context,
                "unable to set result from user-defined aggregate's 'value' method"
            );
        }
    }
    PyGILState_Release(gil);
}

def:priv authorizer_callback(
    ctx_vp: ptr,
    action: i32,
    arg1: ptr[u8],
    arg2: ptr[u8],
    dbname: ptr[u8],
    access_attempt_source: ptr[u8]
) -> i32 {
    gil = PyGILState_Ensure();
    rc = SQLITE_DENY;
    ctx = ptr[callback_context](ctx_vp);
    incref_callback_context(ctx);
    ret = PyObject_CallFunction(
        ctx.view(1)[0].callable,
        "issss",
        action,
        arg1,
        arg2,
        dbname,
        access_attempt_source
    );
    if not ret {
        print_or_clear_traceback(ctx);
        rc = SQLITE_DENY;
    } else {
        if jacpy_is_long(ret) != 0 {
            rc = PyLong_AsInt(ret);
            if rc == -1 and PyErr_Occurred() {
                print_or_clear_traceback(ctx);
                rc = SQLITE_DENY;
            }
        } else {
            rc = SQLITE_DENY;
        }
        jacpy_release(ret);
    }
    decref_callback_context(ctx);
    PyGILState_Release(gil);
    return rc;
}

def:priv progress_callback(ctx_vp: ptr) -> i32 {
    gil = PyGILState_Ensure();
    ctx = ptr[callback_context](ctx_vp);
    incref_callback_context(ctx);
    rc = i32(-1);
    ret = PyObject_CallNoArgs(ctx.view(1)[0].callable);
    if ret {
        rc = PyObject_IsTrue(ret);
        jacpy_release(ret);
    }
    if rc < 0 {
        print_or_clear_traceback(ctx);
    }
    decref_callback_context(ctx);
    PyGILState_Release(gil);
    return rc;
}

# The trace callback's return value is ignored by SQLite; it returns 0.
def:priv trace_callback(kind: u32, ctx_vp: ptr, stmt: ptr, sql: ptr) -> i32 {
    if kind != SQLITE_TRACE_STMT {
        return i32(0);
    }
    gil = PyGILState_Ensure();
    ctx = ptr[callback_context](ctx_vp);
    incref_callback_context(ctx);
    state = context_state(ctx);
    py_statement = NULL;
    expanded_sql = sqlite3_expanded_sql(ptr[sqlite3_stmt](stmt));
    skipped = False;
    if expanded_sql.is_null() {
        db = sqlite3_db_handle(ptr[sqlite3_stmt](stmt));
        if sqlite3_errcode(db) == SQLITE_NOMEM {
            PyErr_NoMemory();
            skipped = True;
        } else {
            object_error(
                state.DataError if state is not None else PyExc_SystemError,
                "Expanded SQL string exceeds the maximum string length"
            );
            print_or_clear_traceback(ctx);
            # Fall back to the unexpanded SQL.
            py_statement = c_string_text(ptr[u8](sql));
        }
    } else {
        py_statement = c_string_text(expanded_sql);
        sqlite3_free(expanded_sql);
    }
    if not skipped {
        if py_statement {
            ret = PyObject_CallOneArg(ctx.view(1)[0].callable, py_statement);
            jacpy_release(py_statement);
            jacpy_release(ret);
        }
        if PyErr_Occurred() {
            print_or_clear_traceback(ctx);
        }
    }
    decref_callback_context(ctx);
    PyGILState_Release(gil);
    return i32(0);
}

def:priv collation_callback(
    context: ptr, text1_length: i32, text1_data: ptr, text2_length: i32, text2_data: ptr
) -> i32 {
    gil = PyGILState_Ensure();
    ctx = ptr[callback_context](context);
    incref_callback_context(ctx);
    result: i32 = 0;
    string1 = NULL;
    string2 = NULL;
    retval = NULL;
    # This callback may run several times per sqlite3_step(); bail out when
    # the previous call failed.
    if not PyErr_Occurred() {
        string1 = unicode_from_memory(text1_data, i64(text1_length));
        if string1 {
            string2 = unicode_from_memory(text2_data, i64(text2_length));
        }
        if string1 and string2 {
            retval = PyObject_CallFunctionObjArgs(
                ctx.view(1)[0].callable, string1, string2, NULL
            );
        }
        if retval {
            overflow: i32 = 0;
            longval = PyLong_AsLongAndOverflow(retval, &mut overflow);
            if longval == -1 and PyErr_Occurred() {
                PyErr_Clear();
                result = 0;
            } elif overflow != 0 {
                result = overflow;
            } elif longval > 0 {
                result = 1;
            } elif longval < 0 {
                result = i32(-1);
            }
        }
    }
    decref_callback_context(ctx);
    jacpy_release(string1);
    jacpy_release(string2);
    jacpy_release(retval);
    PyGILState_Release(gil);
    return result;
}

# ------------------------------------------------------ connection methods

def:priv allowed_isolation_level(level: str) -> (str | None) {
    folded = "".join([chr(ord(c) - 32) if c >= "a" and c <= "z" else c for c in level]);
    for candidate in ["", "DEFERRED", "IMMEDIATE", "EXCLUSIVE"] {
        if folded == candidate {
            return candidate;
        }
    }
    return None;
}

# isolation_level_converter(): None, or one of the allowed levels; raises
# boundary_failure with the exception set.
def convert_isolation_level_converter(
    value: ptr[PyObject], fname: str, label: str
) -> (str | None) {
    if value == Py_None {
        return None;
    }
    if jacpy_is_unicode(value) == 0 {
        object_error(PyExc_TypeError, "isolation_level must be str or None");
        raise boundary_failure();
    }
    if _PyUnicode_AsUTF8NoNUL(value).is_null() {
        raise boundary_failure();
    }
    level = allowed_isolation_level(text_value(value));
    if level is None {
        object_error(
            PyExc_ValueError,
            "isolation_level string must be '', 'DEFERRED', 'IMMEDIATE', or 'EXCLUSIVE'"
        );
        raise boundary_failure();
    }
    return level;
}

# autocommit_converter() for a value, or None with ValueError set.
def:priv autocommit_value(value: ptr[PyObject]) -> (i32 | None) {
    if value == borrowed_true() {
        return AUTOCOMMIT_ENABLED;
    }
    if value == borrowed_false() {
        return AUTOCOMMIT_DISABLED;
    }
    if jacpy_is_long(value) != 0
        and PyLong_AsLong(value) == i64(LEGACY_TRANSACTION_CONTROL) {
        return AUTOCOMMIT_LEGACY;
    }
    object_error(
        PyExc_ValueError,
        "autocommit must be True, False, or sqlite3.LEGACY_TRANSACTION_CONTROL"
    );
    return None;
}

def convert_autocommit_converter(value: ptr[PyObject], fname: str, label: str) -> i32 {
    mode = autocommit_value(value);
    if mode is None {
        raise boundary_failure();
    }
    return mode;
}

def convert_sqlite3_int64_converter(
    value: ptr[PyObject], fname: str, label: str
) -> i64 {
    if jacpy_is_long(value) == 0 {
        object_error(PyExc_TypeError, "expected 'int'");
        raise boundary_failure();
    }
    result = long_as_int64(value);
    if PyErr_Occurred() {
        raise boundary_failure();
    }
    return result;
}

# The default `factory` of Connection.__init__: the module's Connection type.
def clinic_state_ConnectionType(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = state_of(receiver);
    if state is None {
        raise boundary_failure();
    }
    return state.ConnectionType;
}

# The default `proto` of adapt(): the module's PrepareProtocol type.
def clinic_state_PrepareProtocolType(module: ptr[PyObject]) -> ptr[PyObject] {
    state = module_state(module);
    if state is None {
        raise boundary_failure();
    }
    return state.PrepareProtocolType;
}

# object(subclass_of='clinic_state()->ConnectionType').
def subclass_clinic_state_ConnectionType(value: ptr[PyObject], fname: str, label: str) {
    if jacpy_binding_matches(value, Connection_token.handle) == 0 {
        bad_argument(fname, label, "sqlite3.Connection", value);
    }
}

# object(subclass_of='clinic_state()->CursorType').
def subclass_clinic_state_CursorType(value: ptr[PyObject], fname: str, label: str) {
    if jacpy_binding_matches(value, Cursor_token.handle) == 0 {
        bad_argument(fname, label, "sqlite3.Cursor", value);
    }
}

# C's (int)(value) for a finite double in range.
def:priv double_to_int(value: f64) -> i32 {
    if value != value {
        return i32(0);
    }
    if value >= 2147483647.0 {
        return i32(2147483647);
    }
    if value <= -2147483648.0 {
        return i32(-2147483648);
    }
    return i32(int(value));
}

def:priv new_statement_cache(
    instance: ptr[PyObject], state: SqliteState, maxsize: i32
) -> ptr[PyObject] {
    size = PyLong_FromLong(i64(maxsize));
    if not size {
        return NULL;
    }
    inner = PyObject_CallOneArg(state.lru_cache, size);
    jacpy_release(size);
    if not inner {
        return NULL;
    }
    result = PyObject_CallOneArg(inner, instance);
    jacpy_release(inner);
    return result;
}

# connection_exec_stmt(): run one statement with the GIL released.
def:priv connection_exec_stmt(con: ConnectionState, sql: str) -> i32 {
    text = c_string_copy(sql);
    if text.is_null() {
        PyErr_NoMemory();
        return i32(-1);
    }
    thread = PyEval_SaveThread();
    stmt = ptr[sqlite3_stmt]();
    tail = ptr[u8]();
    rc = sqlite3_prepare_v2(con.db, text, i32(len(sql) + 1), &mut stmt, &mut tail);
    if rc == SQLITE_OK {
        sqlite3_step(stmt);
        rc = sqlite3_finalize(stmt);
    }
    PyEval_RestoreThread(thread);
    PyMem_RawFree(text);
    if rc != SQLITE_OK {
        set_error_from_db(con.state, con.db);
        return i32(-1);
    }
    return i32(0);
}

def:priv remove_callbacks(db: ptr[sqlite3_db]) {
    sqlite3_trace_v2(db, SQLITE_TRACE_STMT, 0, ptr());
    sqlite3_progress_handler(db, i32(0), 0, ptr());
    sqlite3_set_authorizer(db, 0, ptr());
}

def:priv connection_close(con: ConnectionState) -> i32 {
    if con.db.is_null() {
        return i32(0);
    }
    rc = i32(0);
    if con.autocommit == AUTOCOMMIT_DISABLED and sqlite3_get_autocommit(con.db) == 0 {
        if connection_exec_stmt(con, "ROLLBACK") < 0 {
            rc = i32(-1);
        }
    }
    db = con.db;
    con.db = ptr[sqlite3_db]();
    # The v2 close call always returns SQLITE_OK for a valid database.
    thread = PyEval_SaveThread();
    sqlite3_close_v2(db);
    PyEval_RestoreThread(thread);
    free_callback_contexts(con);
    return rc;
}

# connection_finalize(): close an unclosed connection, with a
# ResourceWarning, without calling back into Python at interpreter teardown.
def connection_finalize(instance: ptr[PyObject]) {
    if jacpy_binding_native_present(instance, Connection_token.handle) == 0 {
        return;
    }
    con = connection_of(instance);
    if con is None {
        PyErr_Clear();
        return;
    }
    exc = PyErr_GetRaisedException();
    teardown = _Py_IsInterpreterFinalizing(PyInterpreterState_Get()) != 0;
    if teardown and not con.db.is_null() {
        remove_callbacks(con.db);
    }
    if not con.db.is_null() {
        if PyErr_ResourceWarning(instance, 1, "unclosed database in %R", instance)
            != 0 {
            # Spurious errors can appear at shutdown.
            if PyErr_ExceptionMatches(PyExc_Warning) != 0 {
                PyErr_FormatUnraisable(
                    "Exception ignored while finalizing database connection %R",
                    instance
                );
            }
        }
    }
    if connection_close(con) < 0 {
        if teardown {
            PyErr_Clear();
        } else {
            PyErr_FormatUnraisable(
                "Exception ignored while closing database %R", instance
            );
        }
    }
    PyErr_SetRaisedException(exc);
}

# pysqlite_check_thread().
def:priv check_thread(con: ConnectionState) -> bool {
    if con.check_same_thread {
        current = PyThread_get_thread_ident();
        if current != con.thread_ident {
            PyErr_Format(
                con.state.ProgrammingError,
                "SQLite objects created in a thread can only be used in that same thread. The object was created in thread id %lu and this is thread id %lu.",
                con.thread_ident,
                current
            );
            return False;
        }
    }
    return True;
}

# pysqlite_check_connection().
def:priv check_connection(instance: ptr[PyObject], con: ConnectionState) -> bool {
    if not con.initialized {
        state = state_of(instance);
        if state is not None {
            object_error(
                state.ProgrammingError, "Base Connection.__init__ not called."
            );
        }
        return False;
    }
    if con.db.is_null() {
        object_error(
            con.state.ProgrammingError, "Cannot operate on a closed database."
        );
        return False;
    }
    return True;
}

# The connection of `instance` when it is usable from this thread.
def:priv usable_connection(instance: ptr[PyObject]) -> (ConnectionState | None) {
    con = connection_of(instance);
    if con is None or not check_thread(con) or not check_connection(instance, con) {
        return None;
    }
    return con;
}

def pysqlite_connection_init_impl(
    receiver: ptr[PyObject],
    database: ptr[PyObject],
    timeout: f64,
    detect_types: i32,
    isolation_level: (str | None),
    check_same_thread: bool,
    factory: ptr[PyObject],
    cache_size: i32,
    uri: bool,
    autocommit: i32
) -> i32 {
    if PySys_Audit("sqlite3.connect", "O", database) < 0 {
        return i32(-1);
    }
    bytes = NULL;
    if PyUnicode_FSConverter(database, &mut bytes) == 0 {
        return i32(-1);
    }
    con = connection_of(receiver);
    if con is None {
        jacpy_release(bytes);
        return i32(-1);
    }
    if con.initialized {
        con.initialized = False;
        con.clear();
        if connection_close(con) < 0 {
            jacpy_release(bytes);
            return i32(-1);
        }
    }
    # Create and configure the SQLite database object.
    db = ptr[sqlite3_db]();
    flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE;
    if uri {
        flags = flags | SQLITE_OPEN_URI;
    }
    thread = PyEval_SaveThread();
    rc = sqlite3_open_v2(PyBytes_AsString(bytes), &mut db, flags, ptr[u8]());
    if rc == SQLITE_OK {
        sqlite3_busy_timeout(db, double_to_int(timeout * 1000.0));
    }
    PyEval_RestoreThread(thread);
    jacpy_release(bytes);
    if db.is_null() and rc == SQLITE_NOMEM {
        PyErr_NoMemory();
        return i32(-1);
    }
    state = state_of(receiver);
    if state is None {
        sqlite3_close(db);
        return i32(-1);
    }
    if rc != SQLITE_OK {
        set_error_from_db(state, db);
        sqlite3_close(db);
        return i32(-1);
    }
    # Create the LRU statement cache.
    statement_cache = new_statement_cache(receiver, state, cache_size);
    if not statement_cache {
        sqlite3_close(db);
        return i32(-1);
    }
    cursors = PyList_New(0);
    if not cursors {
        jacpy_release(statement_cache);
        sqlite3_close(db);
        return i32(-1);
    }
    blobs = PyList_New(0);
    if not blobs {
        jacpy_release(statement_cache);
        jacpy_release(cursors);
        sqlite3_close(db);
        return i32(-1);
    }
    # Init connection state members.
    con.db = db;
    con.state = state;
    con.detect_types = detect_types;
    con.isolation_level = isolation_level;
    con.autocommit = autocommit;
    con.check_same_thread = check_same_thread;
    con.thread_ident = PyThread_get_thread_ident();
    con.statement_cache = statement_cache;
    con.cursors = cursors;
    con.blobs = blobs;
    con.created_cursors = 0;
    con.row_factory = Py_NewRef(Py_None);
    con.text_factory = Py_NewRef(addressof(PyUnicode_Type));
    con.trace_ctx = ptr[callback_context]();
    con.progress_ctx = ptr[callback_context]();
    con.authorizer_ctx = ptr[callback_context]();
    # Borrowed references.
    fields = connection_fields(receiver).view(1);
    fields[0].Warning = state.Warning;
    fields[0].Error = state.Error;
    fields[0].InterfaceError = state.InterfaceError;
    fields[0].DatabaseError = state.DatabaseError;
    fields[0].DataError = state.DataError;
    fields[0].OperationalError = state.OperationalError;
    fields[0].IntegrityError = state.IntegrityError;
    fields[0].InternalError = state.InternalError;
    fields[0].ProgrammingError = state.ProgrammingError;
    fields[0].NotSupportedError = state.NotSupportedError;
    if PySys_Audit("sqlite3.connect/handle", "O", receiver) < 0 {
        # Not closed here: dealloc cleans up.
        return i32(-1);
    }
    con.initialized = True;
    if autocommit == AUTOCOMMIT_DISABLED {
        if connection_exec_stmt(con, "BEGIN") < 0 {
            return i32(-1);
        }
    }
    return i32(0);
}

# The implementation behind the connect() clone of Connection.__init__; the
# binding forwards connect() to the factory as C does.
def pysqlite_connect_impl(
    receiver: ptr[PyObject],
    database: ptr[PyObject],
    timeout: f64,
    detect_types: i32,
    isolation_level: (str | None),
    check_same_thread: bool,
    factory: ptr[PyObject],
    cache_size: i32,
    uri: bool,
    autocommit: i32
) -> ptr[PyObject] {
    object_error(PyExc_SystemError, "connect() is bound by the module binding");
    return NULL;
}

# connect(): forward the arguments to `factory` (5th positional or keyword).
def pysqlite_connect(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    state = module_state(module);
    if state is None {
        return NULL;
    }
    factory = state.ConnectionType;
    factory_pos = 5;
    if nargs > 1 and nargs <= 8 {
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "Passing more than 1 positional argument to sqlite3.connect() is deprecated. Parameters 'timeout', 'detect_types', 'isolation_level', 'check_same_thread', 'factory', 'cached_statements' and 'uri' will become keyword-only parameters in Python 3.15.",
            1
        )
            != 0 {
            return NULL;
        }
    }
    if nargs > factory_pos {
        factory = args.view(int(nargs))[factory_pos];
    } elif kwnames {
        count = PyTuple_Size(kwnames);
        stack = args.view(int(nargs + count));
        for i in range(int(count)) {
            item = PyTuple_GetItem(kwnames, i64(i));
            if PyUnicode_CompareWithASCIIString(item, "factory") == 0 {
                factory = stack[int(nargs) + i];
                break;
            }
        }
    }
    return PyObject_Vectorcall(factory, args, u64(nargs), kwnames);
}

def pysqlite_connection_cursor_impl(
    receiver: ptr[PyObject], factory: ptr[PyObject]
) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    if not factory {
        factory = con.state.CursorType;
    }
    cursor = PyObject_CallOneArg(factory, receiver);
    if not cursor {
        return NULL;
    }
    if jacpy_type_check(cursor, con.state.CursorType) == 0 {
        PyErr_Format(
            PyExc_TypeError, "factory must return a cursor, not %.100s", tp_name(cursor)
        );
        jacpy_release(cursor);
        return NULL;
    }
    if drop_unused_cursor_references(con) < 0 {
        jacpy_release(cursor);
        return NULL;
    }
    if con.row_factory != Py_None {
        fields = cursor_fields(cursor).view(1);
        previous = fields[0].row_factory;
        fields[0].row_factory = Py_NewRef(con.row_factory);
        jacpy_release(previous);
    }
    return cursor;
}

def:priv drop_unused_cursor_references(con: ConnectionState) -> i32 {
    # Only needed once in a while.
    con.created_cursors += 1;
    if con.created_cursors - 1 < 200 {
        return i32(0);
    }
    con.created_cursors = 0;
    new_list = PyList_New(0);
    if not new_list {
        return i32(-1);
    }
    for i in range(int(PyList_Size(con.cursors))) {
        weakref = PyList_GetItem(con.cursors, i64(i));
        if _PyWeakref_IsDead(weakref) != 0 {
            continue;
        }
        if PyList_Append(new_list, weakref) != 0 {
            jacpy_release(new_list);
            return i32(-1);
        }
    }
    previous = con.cursors;
    con.cursors = new_list;
    jacpy_release(previous);
    return i32(0);
}

def connection_get_row_factory(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    con = connection_of(instance);
    if con is None {
        return NULL;
    }
    return Py_NewRef(con.row_factory if con.row_factory else Py_None);
}

def connection_set_row_factory(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if not value {
        object_error(PyExc_AttributeError, "cannot delete row_factory attribute");
        return i32(-1);
    }
    con = connection_of(instance);
    if con is None {
        return i32(-1);
    }
    previous = con.row_factory;
    con.row_factory = Py_NewRef(value);
    jacpy_release(previous);
    return i32(0);
}

def connection_get_text_factory(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    con = connection_of(instance);
    if con is None {
        return NULL;
    }
    return Py_NewRef(con.text_factory if con.text_factory else Py_None);
}

def connection_set_text_factory(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    if not value {
        object_error(PyExc_AttributeError, "cannot delete text_factory attribute");
        return i32(-1);
    }
    con = connection_of(instance);
    if con is None {
        return i32(-1);
    }
    previous = con.text_factory;
    con.text_factory = Py_NewRef(value);
    jacpy_release(previous);
    return i32(0);
}

def blobopen_impl(
    receiver: ptr[PyObject], table: str, col: str, row: i64, readonly: bool, name: str
) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    blob = ptr[sqlite3_blob]();
    thread = PyEval_SaveThread();
    rc = sqlite3_blob_open(
        con.db, name, table, col, row, i32(0 if readonly else 1), &mut blob
    );
    PyEval_RestoreThread(thread);
    if rc == SQLITE_MISUSE {
        set_error_from_code(con.state, rc);
        return NULL;
    } elif rc != SQLITE_OK {
        set_error_from_db(con.state, con.db);
        return NULL;
    }
    instance = jacpy_binding_allocate(con.state.BlobType);
    if not instance {
        sqlite3_blob_close(blob);
        return NULL;
    }
    state = BlobState(connection=Py_NewRef(receiver), blob=blob);
    if jacpy_binding_native_set(instance, Blob_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    # Add the blob to the connection's blobs list.
    weakref = PyWeakref_NewRef(instance, NULL);
    if not weakref {
        jacpy_release(instance);
        return NULL;
    }
    rc = PyList_Append(con.blobs, weakref);
    jacpy_release(weakref);
    if rc < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def pysqlite_connection_close_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    con = connection_of(receiver);
    if con is None or not check_thread(con) {
        return NULL;
    }
    if not con.initialized {
        state = state_of(receiver);
        if state is not None {
            object_error(
                state.ProgrammingError, "Base Connection.__init__ not called."
            );
        }
        return NULL;
    }
    close_all_blobs(con);
    previous = con.statement_cache;
    con.statement_cache = NULL;
    jacpy_release(previous);
    if connection_close(con) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def pysqlite_connection_commit_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    if con.autocommit == AUTOCOMMIT_LEGACY {
        if sqlite3_get_autocommit(con.db) == 0 {
            if connection_exec_stmt(con, "COMMIT") < 0 {
                return NULL;
            }
        }
    } elif con.autocommit == AUTOCOMMIT_DISABLED {
        if connection_exec_stmt(con, "COMMIT") < 0 {
            return NULL;
        }
        if connection_exec_stmt(con, "BEGIN") < 0 {
            return NULL;
        }
    }
    return Py_NewRef(Py_None);
}

def pysqlite_connection_rollback_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    if con.autocommit == AUTOCOMMIT_LEGACY {
        if sqlite3_get_autocommit(con.db) == 0 {
            if connection_exec_stmt(con, "ROLLBACK") < 0 {
                return NULL;
            }
        }
    } elif con.autocommit == AUTOCOMMIT_DISABLED {
        if connection_exec_stmt(con, "ROLLBACK") < 0 {
            return NULL;
        }
        if connection_exec_stmt(con, "BEGIN") < 0 {
            return NULL;
        }
    }
    return Py_NewRef(Py_None);
}

def:priv check_num_params(con: ConnectionState, n: i32, name: str) -> bool {
    limit = sqlite3_limit(con.db, SQLITE_LIMIT_FUNCTION_ARG, i32(-1));
    if n < -1 or n > limit {
        object_error(
            con.state.ProgrammingError,
            f"'{name}' must be between -1 and {limit}, not {n}"
        );
        return False;
    }
    return True;
}

def pysqlite_connection_create_function_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    name: str,
    narg: i32,
    func: ptr[PyObject],
    deterministic: bool
) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None or not check_num_params(con, narg, "narg") {
        return NULL;
    }
    flags = SQLITE_UTF8;
    if deterministic {
        flags = flags | SQLITE_DETERMINISTIC;
    }
    ctx = create_callback_context(cls, func);
    if ctx.is_null() {
        return NULL;
    }
    # The destructor frees `ctx`.
    rc = sqlite3_create_function_v2(
        con.db, name, narg, flags, ctx, func_callback, 0, 0, destructor_callback
    );
    if rc != SQLITE_OK {
        # Workaround for SQLite bug: no error code or string is available.
        object_error(con.state.OperationalError, "Error creating function");
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def create_window_function_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    name: str,
    num_params: i32,
    aggregate_class: ptr[PyObject]
) -> ptr[PyObject] {
    con = connection_of(receiver);
    if con is None {
        return NULL;
    }
    if sqlite3_libversion_number() < 3025000 {
        state = con.state if con.initialized else state_of(receiver);
        if state is not None {
            object_error(
                state.NotSupportedError,
                "create_window_function() requires SQLite 3.25.0 or higher"
            );
        }
        return NULL;
    }
    if not check_thread(con) or not check_connection(receiver, con) {
        return NULL;
    }
    if not check_num_params(con, num_params, "num_params") {
        return NULL;
    }
    rc = SQLITE_OK;
    if aggregate_class == Py_None {
        rc = sqlite3_create_window_function(
            con.db, name, num_params, SQLITE_UTF8, ptr(), 0, 0, 0, 0, 0
        );
    } else {
        ctx = create_callback_context(cls, aggregate_class);
        if ctx.is_null() {
            return NULL;
        }
        rc = sqlite3_create_window_function(
            con.db,
            name,
            num_params,
            SQLITE_UTF8,
            ctx,
            step_callback,
            final_callback,
            value_callback,
            inverse_callback,
            destructor_callback
        );
    }
    if rc != SQLITE_OK {
        # Errors are not set on the database connection; use the result code.
        set_error_from_code(con.state, rc);
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def pysqlite_connection_create_aggregate_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    name: str,
    n_arg: i32,
    aggregate_class: ptr[PyObject]
) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None or not check_num_params(con, n_arg, "n_arg") {
        return NULL;
    }
    ctx = create_callback_context(cls, aggregate_class);
    if ctx.is_null() {
        return NULL;
    }
    rc = sqlite3_create_function_v2(
        con.db,
        name,
        n_arg,
        SQLITE_UTF8,
        ctx,
        0,
        step_callback,
        final_callback,
        destructor_callback
    );
    if rc != SQLITE_OK {
        # Workaround for SQLite bug: no error code or string is available.
        object_error(con.state.OperationalError, "Error creating aggregate");
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def pysqlite_connection_set_authorizer_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], callable: ptr[PyObject]
) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    rc = SQLITE_OK;
    if callable == Py_None {
        rc = sqlite3_set_authorizer(con.db, 0, ptr());
        con.authorizer_ctx = replace_callback_context(
            con.authorizer_ctx, ptr[callback_context]()
        );
    } else {
        ctx = create_callback_context(cls, callable);
        if ctx.is_null() {
            return NULL;
        }
        rc = sqlite3_set_authorizer(con.db, authorizer_callback, ctx);
        con.authorizer_ctx = replace_callback_context(con.authorizer_ctx, ctx);
    }
    if rc != SQLITE_OK {
        object_error(con.state.OperationalError, "Error setting authorizer callback");
        con.authorizer_ctx = replace_callback_context(
            con.authorizer_ctx, ptr[callback_context]()
        );
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def pysqlite_connection_set_progress_handler_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], callable: ptr[PyObject], n: i32
) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    if callable == Py_None {
        # None clears the progress handler previously set.
        sqlite3_progress_handler(con.db, i32(0), 0, ptr());
        con.progress_ctx = replace_callback_context(
            con.progress_ctx, ptr[callback_context]()
        );
    } else {
        ctx = create_callback_context(cls, callable);
        if ctx.is_null() {
            return NULL;
        }
        sqlite3_progress_handler(con.db, n, progress_callback, ctx);
        con.progress_ctx = replace_callback_context(con.progress_ctx, ctx);
    }
    return Py_NewRef(Py_None);
}

def pysqlite_connection_set_trace_callback_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], callable: ptr[PyObject]
) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    if callable == Py_None {
        # None clears the trace callback previously set.
        sqlite3_trace_v2(con.db, SQLITE_TRACE_STMT, 0, ptr());
        con.trace_ctx = replace_callback_context(
            con.trace_ctx, ptr[callback_context]()
        );
    } else {
        ctx = create_callback_context(cls, callable);
        if ctx.is_null() {
            return NULL;
        }
        sqlite3_trace_v2(con.db, SQLITE_TRACE_STMT, trace_callback, ctx);
        con.trace_ctx = replace_callback_context(con.trace_ctx, ctx);
    }
    return Py_NewRef(Py_None);
}

# enable_load_extension() and load_extension() are compiled only with
# PY_SQLITE_ENABLE_LOAD_EXTENSION, which JacPython builds leave undefined;
# the binding does not install them (see ENABLE_LOAD_EXTENSION).
def pysqlite_connection_enable_load_extension_impl(
    receiver: ptr[PyObject], onoff: bool
) -> ptr[PyObject] {
    object_error(PyExc_SystemError, "loadable extensions are not built");
    return NULL;
}

def pysqlite_connection_load_extension_impl(
    receiver: ptr[PyObject], extension_name: str, entrypoint: ptr[u8]
) -> ptr[PyObject] {
    object_error(PyExc_SystemError, "loadable extensions are not built");
    return NULL;
}

def connection_get_isolation_level(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    con = connection_of(instance);
    if con is None or not check_connection(instance, con) {
        return NULL;
    }
    level = con.isolation_level;
    if level is not None {
        return PyUnicode_FromString(level);
    }
    return Py_NewRef(Py_None);
}

def connection_get_total_changes(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    con = connection_of(instance);
    if con is None or not check_connection(instance, con) {
        return NULL;
    }
    return PyLong_FromLong(i64(sqlite3_total_changes(con.db)));
}

def connection_get_in_transaction(
    instance: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    con = connection_of(instance);
    if con is None or not check_connection(instance, con) {
        return NULL;
    }
    return PyBool_FromLong(i64(sqlite3_get_autocommit(con.db) == 0));
}

def connection_set_isolation_level(
    instance: ptr[PyObject], isolation_level: ptr[PyObject], context: u64
) -> i32 {
    if not isolation_level {
        object_error(PyExc_AttributeError, "cannot delete attribute");
        return i32(-1);
    }
    con = connection_of(instance);
    if con is None {
        return i32(-1);
    }
    if isolation_level == Py_None {
        con.isolation_level = None;
        # Execute a COMMIT to re-enable autocommit mode.
        res = pysqlite_connection_commit_impl(instance);
        if not res {
            return i32(-1);
        }
        jacpy_release(res);
        return i32(0);
    }
    try {
        con.isolation_level = convert_isolation_level_converter(
            isolation_level, "", ""
        );
    } except boundary_failure {
        return i32(-1);
    }
    return i32(0);
}

# Connection.__call__(sql): a prepared statement.
def connection_call(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    con = usable_connection(instance);
    if con is None {
        return NULL;
    }
    if kwargs and PyDict_Size(kwargs) != 0 {
        object_error(
            PyExc_TypeError, "sqlite3.Connection() takes no keyword arguments"
        );
        return NULL;
    }
    try {
        values = ArgumentFormat().parse(args, "U");
    } except boundary_failure {
        return NULL;
    }
    return statement_create(instance, con, values[0].object);
}

def pysqlite_connection_execute_impl(
    receiver: ptr[PyObject], sql: ptr[PyObject], parameters: ptr[PyObject]
) -> ptr[PyObject] {
    cursor = pysqlite_connection_cursor_impl(receiver, NULL);
    if not cursor {
        return NULL;
    }
    result = query_execute(cursor, False, sql, parameters);
    if not result {
        jacpy_release(cursor);
        return NULL;
    }
    jacpy_release(result);
    return cursor;
}

def pysqlite_connection_executemany_impl(
    receiver: ptr[PyObject], sql: ptr[PyObject], parameters: ptr[PyObject]
) -> ptr[PyObject] {
    cursor = pysqlite_connection_cursor_impl(receiver, NULL);
    if not cursor {
        return NULL;
    }
    result = query_execute(cursor, True, sql, parameters);
    if not result {
        jacpy_release(cursor);
        return NULL;
    }
    jacpy_release(result);
    return cursor;
}

def pysqlite_connection_executescript_impl(
    receiver: ptr[PyObject], script_obj: ptr[PyObject]
) -> ptr[PyObject] {
    cursor = pysqlite_connection_cursor_impl(receiver, NULL);
    if not cursor {
        return NULL;
    }
    con = connection_of(receiver);
    if con is None {
        jacpy_release(cursor);
        return NULL;
    }
    result = PyObject_CallMethodObjArgs(
        cursor, con.state.str_executescript, script_obj, NULL
    );
    if not result {
        jacpy_release(cursor);
        return NULL;
    }
    jacpy_release(result);
    return cursor;
}

def pysqlite_connection_interrupt_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    con = connection_of(receiver);
    if con is None or not check_connection(receiver, con) {
        return NULL;
    }
    sqlite3_interrupt(con.db);
    return Py_NewRef(Py_None);
}

def pysqlite_connection_iterdump_impl(
    receiver: ptr[PyObject], filter: ptr[PyObject]
) -> ptr[PyObject] {
    con = connection_of(receiver);
    if con is None or not check_connection(receiver, con) {
        return NULL;
    }
    iterdump = PyImport_ImportModuleAttrString("sqlite3.dump", "_iterdump");
    if not iterdump {
        if not PyErr_Occurred() {
            object_error(
                con.state.OperationalError, "Failed to obtain _iterdump() reference"
            );
        }
        return NULL;
    }
    args = PyTuple_Pack(1, receiver);
    kwargs = PyDict_New();
    retval = NULL;
    if args and kwargs and PyDict_SetItemString(kwargs, "filter", filter) == 0 {
        retval = PyObject_Call(iterdump, args, kwargs);
    }
    jacpy_release(args);
    jacpy_release(kwargs);
    jacpy_release(iterdump);
    return retval;
}

def pysqlite_connection_backup_impl(
    receiver: ptr[PyObject],
    target: ptr[PyObject],
    pages: i32,
    progress: ptr[PyObject],
    name: str,
    sleep: f64
) -> ptr[PyObject] {
    sleep_ms = double_to_int(sleep * 1000.0);
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    target_con = connection_of(target);
    if target_con is None or not check_connection(target, target_con) {
        return NULL;
    }
    if target == receiver {
        object_error(PyExc_ValueError, "target cannot be the same connection instance");
        return NULL;
    }
    if progress != Py_None and PyCallable_Check(progress) == 0 {
        object_error(PyExc_TypeError, "progress argument must be a callable");
        return NULL;
    }
    if pages == 0 {
        pages = i32(-1);
    }
    bck_conn = target_con.db;
    thread = PyEval_SaveThread();
    bck_handle = sqlite3_backup_init(bck_conn, "main", con.db, name);
    PyEval_RestoreThread(thread);
    if bck_handle.is_null() {
        set_error_from_db(con.state, bck_conn);
        return NULL;
    }
    rc = SQLITE_OK;
    while True {
        thread = PyEval_SaveThread();
        rc = sqlite3_backup_step(bck_handle, pages);
        PyEval_RestoreThread(thread);
        if progress != Py_None {
            remaining = sqlite3_backup_remaining(bck_handle);
            pagecount = sqlite3_backup_pagecount(bck_handle);
            res = PyObject_CallFunction(progress, "iii", rc, remaining, pagecount);
            if not res {
                # Callback failed: abort the backup and bail.
                thread = PyEval_SaveThread();
                sqlite3_backup_finish(bck_handle);
                PyEval_RestoreThread(thread);
                return NULL;
            }
            jacpy_release(res);
        }
        # Sleep when there are still pages to copy and the engine could not
        # make progress.
        if rc == SQLITE_BUSY or rc == SQLITE_LOCKED {
            thread = PyEval_SaveThread();
            sqlite3_sleep(sleep_ms);
            PyEval_RestoreThread(thread);
        }
        if not (rc == SQLITE_OK or rc == SQLITE_BUSY or rc == SQLITE_LOCKED) {
            break;
        }
    }
    thread = PyEval_SaveThread();
    rc = sqlite3_backup_finish(bck_handle);
    PyEval_RestoreThread(thread);
    if rc != SQLITE_OK {
        set_error_from_db(con.state, bck_conn);
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def pysqlite_connection_create_collation_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], name: str, callable: ptr[PyObject]
) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    ctx = ptr[callback_context]();
    rc = SQLITE_OK;
    if callable == Py_None {
        rc = sqlite3_create_collation_v2(con.db, name, SQLITE_UTF8, ptr(), 0, 0);
    } else {
        if PyCallable_Check(callable) == 0 {
            object_error(PyExc_TypeError, "parameter must be callable");
            return NULL;
        }
        ctx = create_callback_context(cls, callable);
        if ctx.is_null() {
            return NULL;
        }
        rc = sqlite3_create_collation_v2(
            con.db, name, SQLITE_UTF8, ctx, collation_callback, destructor_callback
        );
    }
    if rc != SQLITE_OK {
        # Unlike the other sqlite3_* functions, the destructor is not called
        # when sqlite3_create_collation_v2() fails.
        if callable != Py_None {
            decref_callback_context(ctx);
        }
        set_error_from_db(con.state, con.db);
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def serialize_impl(receiver: ptr[PyObject], name: str) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    # With a contiguous in-memory database SQLite avoids a copy, so try the
    # no-copy flag first.
    size: i64 = 0;
    flags = SQLITE_SERIALIZE_NOCOPY;
    thread = PyEval_SaveThread();
    data = sqlite3_serialize(con.db, name, &mut size, flags);
    if data.is_null() {
        flags = u32(0);
        data = sqlite3_serialize(con.db, name, &mut size, flags);
    }
    PyEval_RestoreThread(thread);
    if data.is_null() {
        object_error(con.state.OperationalError, f"unable to serialize '{name}'");
        return NULL;
    }
    res = bytes_from_memory(data, size);
    if (flags & SQLITE_SERIALIZE_NOCOPY) == u32(0) {
        sqlite3_free(data);
    }
    return res;
}

def deserialize_impl(
    receiver: ptr[PyObject], data: BufferArgument, name: str
) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    # Move the buffer from Python to SQLite, which frees it and may grow the
    # resulting database.
    size = data.size();
    buf = sqlite3_malloc64(u64(size));
    if not buf {
        return PyErr_NoMemory();
    }
    flags = SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE;
    thread = PyEval_SaveThread();
    jacpy_memory_copy(buf, data.address(), size);
    rc = sqlite3_deserialize(con.db, name, buf, size, size, flags);
    PyEval_RestoreThread(thread);
    if rc != SQLITE_OK {
        set_error_from_db(con.state, con.db);
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def pysqlite_connection_enter_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    con = connection_of(receiver);
    if con is None or not check_connection(receiver, con) {
        return NULL;
    }
    return Py_NewRef(receiver);
}

def pysqlite_connection_exit_impl(
    receiver: ptr[PyObject],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_tb: ptr[PyObject]
) -> ptr[PyObject] {
    commit = exc_type == Py_None and exc_value == Py_None and exc_tb == Py_None;
    result = pysqlite_connection_commit_impl(receiver)
        if commit
        else pysqlite_connection_rollback_impl(receiver);
    if not result {
        if commit {
            # Commit failed; roll back to unlock the database, chaining the
            # exceptions when that fails too.
            exc = PyErr_GetRaisedException();
            result = pysqlite_connection_rollback_impl(receiver);
            if not result {
                _PyErr_ChainExceptions1(exc);
            } else {
                jacpy_release(result);
                PyErr_SetRaisedException(exc);
            }
        }
        return NULL;
    }
    jacpy_release(result);
    return Py_NewRef(borrowed_false());
}

def setlimit_impl(receiver: ptr[PyObject], category: i32, limit: i32) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    old_limit = sqlite3_limit(con.db, category, limit);
    if old_limit < 0 {
        object_error(con.state.ProgrammingError, "'category' is out of bounds");
        return NULL;
    }
    return PyLong_FromLong(i64(old_limit));
}

def getlimit_impl(receiver: ptr[PyObject], category: i32) -> ptr[PyObject] {
    return setlimit_impl(receiver, category, i32(-1));
}

def:priv is_int_config(op: i32) -> bool {
    for (name, value) in INTEGER_CONSTANTS {
        if name.startswith("SQLITE_DBCONFIG_") and value == i64(op) {
            return True;
        }
    }
    return False;
}

def setconfig_impl(receiver: ptr[PyObject], op: i32, enable: bool) -> ptr[PyObject] {
    con = usable_connection(receiver);
    if con is None {
        return NULL;
    }
    if not is_int_config(op) {
        object_error(PyExc_ValueError, f"unknown config 'op': {op}");
        return NULL;
    }
    actual: i32 = 0;
    rc = sqlite3_db_config(con.db, op, i32(1 if enable else 0), &mut actual);
    if rc != SQLITE_OK {
        set_error_from_db(con.state, con.db);
        return NULL;
    }
    if (1 if enable else 0) != actual {
        object_error(con.state.OperationalError, "Unable to set config");
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def getconfig_impl(receiver: ptr[PyObject], op: i32) -> i32 {
    con = usable_connection(receiver);
    if con is None {
        return i32(-1);
    }
    if not is_int_config(op) {
        object_error(PyExc_ValueError, f"unknown config 'op': {op}");
        return i32(-1);
    }
    current: i32 = 0;
    rc = sqlite3_db_config(con.db, op, i32(-1), &mut current);
    if rc != SQLITE_OK {
        set_error_from_db(con.state, con.db);
        return i32(-1);
    }
    return current;
}

def connection_get_autocommit(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    con = usable_connection(instance);
    if con is None {
        return NULL;
    }
    if con.autocommit == AUTOCOMMIT_ENABLED {
        return Py_NewRef(borrowed_true());
    }
    if con.autocommit == AUTOCOMMIT_DISABLED {
        return Py_NewRef(borrowed_false());
    }
    return PyLong_FromLong(i64(LEGACY_TRANSACTION_CONTROL));
}

def connection_set_autocommit(
    instance: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    con = usable_connection(instance);
    if con is None {
        return i32(-1);
    }
    mode = autocommit_value(value) if value else None;
    if mode is None {
        if not value {
            object_error(
                PyExc_ValueError,
                "autocommit must be True, False, or sqlite3.LEGACY_TRANSACTION_CONTROL"
            );
        }
        return i32(-1);
    }
    con.autocommit = mode;
    if mode == AUTOCOMMIT_ENABLED {
        if sqlite3_get_autocommit(con.db) == 0 {
            if connection_exec_stmt(con, "COMMIT") < 0 {
                return i32(-1);
            }
        }
    } elif mode == AUTOCOMMIT_DISABLED {
        if sqlite3_get_autocommit(con.db) != 0 {
            if connection_exec_stmt(con, "BEGIN") < 0 {
                return i32(-1);
            }
        }
    }
    return i32(0);
}

def connection_get_sig(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return PyUnicode_FromString("(sql, /)");
}

# ---------------------------------------------------------------- cursor.c

# pysqlite_Cursor, apart from the member fields of its record.
obj CursorState(NativeState) {
    has fields: ptr[cursor_members] = ptr[cursor_members](),
        row_cast_map: ptr[PyObject] = NULL,
        arraysize: u32 = 0,
        # The pysqlite_Statement object being executed, if any.
        statement: ptr[PyObject] = NULL,
        closed: bool = False,
        locked: bool = False,
        initialized: bool = False;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        references = [self.row_cast_map, self.statement];
        if not self.fields.is_null() {
            record = self.fields.view(1);
            references += [
                record[0].connection,
                record[0].description,
                record[0].lastrowid,
                record[0].row_factory
            ];
        }
        for value in references {
            status = visit_reference(value, visitor, context);
            if status != 0 {
                return status;
            }
        }
        return i32(0);
    }

    # cursor_clear().
    def clear {
        references = [self.row_cast_map];
        self.row_cast_map = NULL;
        if not self.fields.is_null() {
            record = self.fields.view(1);
            references += [
                record[0].connection,
                record[0].description,
                record[0].lastrowid,
                record[0].row_factory
            ];
            record[0].connection = NULL;
            record[0].description = NULL;
            record[0].lastrowid = NULL;
            record[0].row_factory = NULL;
        }
        if self.statement {
            # Reset the statement if the user has not closed the cursor.
            statement = self.statement;
            self.statement = NULL;
            reset_statement_object(statement);
            references.append(statement);
        }
        for value in references {
            jacpy_release(value);
        }
    }
}

def:priv cursor_fields(instance: ptr[PyObject]) -> ptr[cursor_members] {
    return ptr[cursor_members](jacpy_binding_record(instance, Cursor_token.handle));
}

# The CursorState of a Cursor instance, created on first use as the zeroed C
# struct would be.
def cursor_of(instance: ptr[PyObject]) -> (CursorState | None) {
    if jacpy_binding_native_present(instance, Cursor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, Cursor_token.handle);
        if isinstance(state, CursorState) {
            return state;
        }
    }
    if PyErr_Occurred() {
        return None;
    }
    fresh = CursorState(fields=cursor_fields(instance));
    if jacpy_binding_native_set(instance, Cursor_token.handle, fresh) < 0 {
        return None;
    }
    return fresh;
}

# The connection state of a cursor's connection.
def:priv cursor_connection(cur: CursorState) -> (ConnectionState | None) {
    connection = cur.fields.view(1)[0].connection;
    return connection_of(connection) if connection else None;
}

def:priv set_field_description(cur: CursorState, value: ptr[PyObject]) {
    record = cur.fields.view(1);
    previous = record[0].description;
    record[0].description = value;
    jacpy_release(previous);
}

def:priv set_field_lastrowid(cur: CursorState, value: ptr[PyObject]) {
    record = cur.fields.view(1);
    previous = record[0].lastrowid;
    record[0].lastrowid = value;
    jacpy_release(previous);
}

def:priv set_statement(cur: CursorState, statement: ptr[PyObject]) {
    previous = cur.statement;
    cur.statement = statement;
    jacpy_release(previous);
}

def:priv check_cursor_locked(cur: CursorState, con: ConnectionState) -> bool {
    if cur.locked {
        object_error(
            con.state.ProgrammingError, "Recursive use of cursors not allowed."
        );
        return False;
    }
    return True;
}

# register_cursor(): a weak reference in the connection's cursor list.
def:priv register_cursor(con: ConnectionState, cursor: ptr[PyObject]) -> bool {
    weakref = PyWeakref_NewRef(cursor, NULL);
    if not weakref {
        return False;
    }
    rc = PyList_Append(con.cursors, weakref);
    jacpy_release(weakref);
    return rc >= 0;
}

def pysqlite_cursor_init_impl(
    receiver: ptr[PyObject], connection: ptr[PyObject]
) -> i32 {
    cur = cursor_of(receiver);
    if cur is None {
        return i32(-1);
    }
    con = connection_of(connection);
    if con is None {
        return i32(-1);
    }
    if cur.locked {
        state = state_of(receiver);
        if state is not None {
            object_error(
                state.ProgrammingError, "Recursive use of cursors not allowed."
            );
        }
        return i32(-1);
    }
    record = cur.fields.view(1);
    previous = record[0].connection;
    record[0].connection = Py_NewRef(connection);
    jacpy_release(previous);
    set_statement(cur, NULL);
    previous = cur.row_cast_map;
    cur.row_cast_map = NULL;
    jacpy_release(previous);
    set_field_description(cur, Py_NewRef(Py_None));
    set_field_lastrowid(cur, Py_NewRef(Py_None));
    cur.arraysize = u32(1);
    cur.closed = False;
    record[0].rowcount = -1;
    previous = record[0].row_factory;
    record[0].row_factory = Py_NewRef(Py_None);
    jacpy_release(previous);
    if not check_thread(con) {
        return i32(-1);
    }
    # An uninitialized connection has no cursor list: PyList_Append() then
    # reports the bad internal call, as in C.
    if not register_cursor(con, receiver) {
        return i32(-1);
    }
    cur.initialized = True;
    return i32(0);
}

# _pysqlite_get_converter(): the converter registered for a type name
# (borrowed), or NULL, with an exception only on failure.
def:priv get_converter(
    state: SqliteState, keystr: ptr[u8], keylen: i64
) -> ptr[PyObject] {
    key = unicode_from_memory(keystr, keylen);
    if not key {
        return NULL;
    }
    upcase_key = PyObject_CallMethodObjArgs(key, state.str_upper, NULL);
    jacpy_release(key);
    if not upcase_key {
        return NULL;
    }
    retval = PyDict_GetItemWithError(state.converters, upcase_key);
    jacpy_release(upcase_key);
    return retval;
}

def:priv clear_row_cast_map(cur: CursorState) {
    previous = cur.row_cast_map;
    cur.row_cast_map = NULL;
    jacpy_release(previous);
}

# pysqlite_build_row_cast_map(): 0, or -1 with the exception set.
def:priv build_row_cast_map(cur: CursorState, con: ConnectionState) -> i32 {
    if con.detect_types == 0 {
        return i32(0);
    }
    previous = cur.row_cast_map;
    cur.row_cast_map = PyList_New(0);
    jacpy_release(previous);
    if not cur.row_cast_map {
        return i32(-1);
    }
    st = current_statement(cur).st;
    state = con.state;
    for i in range(int(sqlite3_column_count(st))) {
        converter = NULL;
        if (con.detect_types & PARSE_COLNAMES) != 0 {
            colname = sqlite3_column_name(st, i32(i));
            if colname.is_null() {
                PyErr_NoMemory();
                clear_row_cast_map(cur);
                return i32(-1);
            }
            type_start = ptr[u8]();
            pos = colname;
            while pos.view(1)[0] != 0 {
                c = pos.view(1)[0];
                if c == 91 {
                    type_start = pos + 1;
                } elif c == 93 and not type_start.is_null() {
                    converter = get_converter(state, type_start, pos - type_start);
                    if not converter and PyErr_Occurred() {
                        clear_row_cast_map(cur);
                        return i32(-1);
                    }
                    break;
                }
                pos += 1;
            }
        }
        if not converter and (con.detect_types & PARSE_DECLTYPES) != 0 {
            decltype = sqlite3_column_decltype(st, i32(i));
            if not decltype.is_null() {
                # Converter names are split at '(' and blanks: 'INTEGER NOT
                # NULL' is 'INTEGER' and 'NUMBER(10)' is 'NUMBER'.
                pos = decltype;
                while True {
                    c = pos.view(1)[0];
                    if c == 32 or c == 40 or c == 0 {
                        converter = get_converter(state, decltype, pos - decltype);
                        if not converter and PyErr_Occurred() {
                            clear_row_cast_map(cur);
                            return i32(-1);
                        }
                        break;
                    }
                    pos += 1;
                }
            }
        }
        if not converter {
            converter = Py_None;
        }
        if PyList_Append(cur.row_cast_map, converter) != 0 {
            clear_row_cast_map(cur);
            return i32(-1);
        }
    }
    return i32(0);
}

def:priv build_column_name(con: ConnectionState, colname: ptr[u8]) -> ptr[PyObject] {
    length = 0;
    if (con.detect_types & PARSE_COLNAMES) != 0 {
        pos = colname;
        while pos.view(1)[0] != 0 {
            if pos.view(1)[0] == 91 {
                if pos != colname and (pos - 1).view(1)[0] == 32 {
                    pos -= 1;
                }
                break;
            }
            pos += 1;
        }
        length = int(pos - colname);
    } else {
        length = c_string_length(colname);
    }
    return unicode_from_memory(colname, i64(length));
}

# _pysqlite_fetch_one_row(): the current row of the active statement
# (sqlite3_step() returned SQLITE_ROW) as a tuple.
def:priv fetch_one_row(cur: CursorState, con: ConnectionState) -> ptr[PyObject] {
    st = current_statement(cur).st;
    thread = PyEval_SaveThread();
    numcols = sqlite3_data_count(st);
    PyEval_RestoreThread(thread);
    row = PyTuple_New(i64(numcols));
    if not row {
        return NULL;
    }
    db = con.db;
    for i in range(int(numcols)) {
        column = i32(i);
        converter = Py_None;
        if con.detect_types != 0
            and cur.row_cast_map
            and i < int(PyList_Size(cur.row_cast_map)) {
            converter = PyList_GetItem(cur.row_cast_map, i64(i));
        }
        converted = NULL;
        # sqlite3_column_bytes() must come after sqlite3_column_blob() or
        # sqlite3_column_text().
        if converter != Py_None {
            blob = sqlite3_column_blob(st, column);
            if not blob {
                if sqlite3_errcode(db) == SQLITE_NOMEM {
                    PyErr_NoMemory();
                    jacpy_release(row);
                    return NULL;
                }
                converted = Py_NewRef(Py_None);
            } else {
                nbytes = i64(sqlite3_column_bytes(st, column));
                item = bytes_from_memory(blob, nbytes);
                if not item {
                    jacpy_release(row);
                    return NULL;
                }
                converted = PyObject_CallOneArg(converter, item);
                jacpy_release(item);
            }
        } else {
            thread = PyEval_SaveThread();
            coltype = sqlite3_column_type(st, column);
            PyEval_RestoreThread(thread);
            if coltype == SQLITE_NULL {
                converted = Py_NewRef(Py_None);
            } elif coltype == SQLITE_INTEGER {
                converted = PyLong_FromLongLong(sqlite3_column_int64(st, column));
            } elif coltype == SQLITE_FLOAT {
                converted = PyFloat_FromDouble(sqlite3_column_double(st, column));
            } elif coltype == SQLITE_TEXT {
                text = sqlite3_column_text(st, column);
                if text.is_null() and sqlite3_errcode(db) == SQLITE_NOMEM {
                    PyErr_NoMemory();
                    jacpy_release(row);
                    return NULL;
                }
                nbytes = i64(sqlite3_column_bytes(st, column));
                text_factory = con.text_factory;
                if text_factory == addressof(PyUnicode_Type) {
                    converted = unicode_from_memory(text, nbytes);
                    if not converted
                        and PyErr_ExceptionMatches(PyExc_UnicodeDecodeError) != 0 {
                        PyErr_Clear();
                        colname = sqlite3_column_name(st, column);
                        if colname.is_null() {
                            PyErr_NoMemory();
                            jacpy_release(row);
                            return NULL;
                        }
                        set_decode_error(con, colname, text);
                    }
                } elif text_factory == addressof(PyBytes_Type) {
                    converted = bytes_from_memory(text, nbytes);
                } elif text_factory == addressof(PyByteArray_Type) {
                    raw = bytes_from_memory(text, nbytes);
                    if raw {
                        converted = PyByteArray_FromObject(raw);
                        jacpy_release(raw);
                    }
                } else {
                    raw = bytes_from_memory(text, nbytes);
                    if raw {
                        converted = PyObject_CallOneArg(text_factory, raw);
                        jacpy_release(raw);
                    }
                }
            } else {
                # SQLITE_BLOB
                blob = sqlite3_column_blob(st, column);
                if not blob and sqlite3_errcode(db) == SQLITE_NOMEM {
                    PyErr_NoMemory();
                    jacpy_release(row);
                    return NULL;
                }
                nbytes = i64(sqlite3_column_bytes(st, column));
                converted = bytes_from_memory(blob, nbytes);
            }
        }
        if not converted {
            jacpy_release(row);
            return NULL;
        }
        PyTuple_SetItem(row, i64(i), converted);
    }
    if PyErr_Occurred() {
        jacpy_release(row);
        return NULL;
    }
    return row;
}

# The OperationalError for undecodable TEXT: PyOS_snprintf() into a
# 200-byte buffer, then an ASCII decode with replacement.
def:priv set_decode_error(con: ConnectionState, colname: ptr[u8], text: ptr[u8]) {
    prefix = "Could not decode to UTF-8 column '";
    parts: list[int] = [ord(c) for c in prefix];
    for index in range(c_string_length(colname)) {
        parts.append(int((colname + index).view(1)[0]));
    }
    for c in "' with text '" {
        parts.append(ord(c));
    }
    for index in range(c_string_length(text)) {
        parts.append(int((text + index).view(1)[0]));
    }
    parts.append(39);
    # sizeof(buf) - 1 bytes are formatted, keeping room for the NUL.
    kept = parts[:198];
    memory = ptr[u8](PyMem_Malloc(u64(len(kept) + 1)));
    if memory.is_null() {
        object_error(con.state.OperationalError, "Could not decode to UTF-8");
        return;
    }
    characters = memory.view(len(kept) + 1);
    for index in range(len(kept)) {
        characters[index] = u8(kept[index]);
    }
    characters[len(kept)] = u8(0);
    error_msg = PyUnicode_DecodeASCII(memory, i64(len(kept)), ptr[u8]("replace"));
    PyMem_Free(memory);
    if not error_msg {
        object_error(con.state.OperationalError, "Could not decode to UTF-8");
    } else {
        PyErr_SetObject(con.state.OperationalError, error_msg);
        jacpy_release(error_msg);
    }
}

# check_cursor(): the cursor is initialized, open, unlocked and its
# connection usable from this thread.
def:priv check_cursor(
    instance: ptr[PyObject], cur: CursorState
) -> (ConnectionState | None) {
    if not cur.initialized {
        state = state_of(instance);
        if state is not None {
            object_error(state.ProgrammingError, "Base Cursor.__init__ not called.");
        }
        return None;
    }
    con = cursor_connection(cur);
    if con is None {
        return None;
    }
    if cur.closed {
        object_error(con.state.ProgrammingError, "Cannot operate on a closed cursor.");
        return None;
    }
    connection = cur.fields.view(1)[0].connection;
    if not check_thread(con)
        or not check_connection(connection, con)
        or not check_cursor_locked(cur, con) {
        return None;
    }
    return con;
}

def:priv begin_transaction(con: ConnectionState) -> i32 {
    level = con.isolation_level;
    return connection_exec_stmt(con, "BEGIN " + (level if level is not None else ""));
}

def:priv get_statement_from_cache(
    con: ConnectionState, operation: ptr[PyObject]
) -> ptr[PyObject] {
    return PyObject_CallOneArg(con.statement_cache, operation);
}

# bind_param(): the SQLite result code of binding one parameter.
def:priv bind_param(
    state: SqliteState, statement: StatementState, pos: i32, parameter: ptr[PyObject]
) -> i32 {
    st = statement.st;
    if parameter == Py_None {
        return sqlite3_bind_null(st, pos);
    }
    if jacpy_is_exact_long(parameter) != 0
        or (
            jacpy_is_exact_float(parameter) == 0
            and jacpy_is_exact_unicode(parameter) == 0
            and jacpy_is_long(parameter) != 0
        ) {
        value = long_as_int64(parameter);
        if value == -1 and PyErr_Occurred() {
            return SQLITE_ERROR;
        }
        return sqlite3_bind_int64(st, pos, value);
    }
    if jacpy_is_exact_float(parameter) != 0
        or (
            jacpy_is_exact_unicode(parameter) == 0 and jacpy_is_float(parameter) != 0
        ) {
        real = PyFloat_AsDouble(parameter);
        if real == -1.0 and PyErr_Occurred() {
            return SQLITE_ERROR;
        }
        return sqlite3_bind_double(st, pos, real);
    }
    if jacpy_is_unicode(parameter) != 0 {
        buflen: i64 = 0;
        string = PyUnicode_AsUTF8AndSize(parameter, &mut buflen);
        if string.is_null() {
            return SQLITE_ERROR;
        }
        if buflen > INT_MAX {
            object_error(PyExc_OverflowError, "string longer than INT_MAX bytes");
            return SQLITE_ERROR;
        }
        return sqlite3_bind_text(st, pos, string, i32(buflen), SQLITE_TRANSIENT);
    }
    if PyObject_CheckBuffer(parameter) != 0 {
        view = BufferArgument();
        if not view.export(parameter, 0) {
            return SQLITE_ERROR;
        }
        if view.size() > INT_MAX {
            object_error(PyExc_OverflowError, "BLOB longer than INT_MAX bytes");
            view.close();
            return SQLITE_ERROR;
        }
        rc = sqlite3_bind_blob(
            st, pos, view.address(), i32(view.size()), SQLITE_TRANSIENT
        );
        view.close();
        return rc;
    }
    PyErr_Format(
        state.ProgrammingError,
        "Error binding parameter %d: type '%s' is not supported",
        pos,
        tp_name(parameter)
    );
    return SQLITE_ERROR;
}

# need_adapt(): False for the builtin types that bind without adaption.
def:priv need_adapt(state: SqliteState, value: ptr[PyObject]) -> bool {
    if state.base_type_adapted {
        return True;
    }
    return not (
        jacpy_is_exact_long(value) != 0
        or jacpy_is_exact_float(value) != 0
        or jacpy_is_exact_unicode(value) != 0
        or Py_TYPE(value) == addressof(PyByteArray_Type)
    );
}

# Adapt one parameter (a new reference, consumed) and bind it; False with
# the exception set.
def:priv bind_one(
    state: SqliteState,
    statement: StatementState,
    pos: i32,
    current_param: ptr[PyObject]
) -> bool {
    adapted = current_param;
    if need_adapt(state, current_param) {
        adapted = microprotocols_adapt(
            state, current_param, state.PrepareProtocolType, current_param
        );
        jacpy_release(current_param);
        if not adapted {
            return False;
        }
    }
    rc = bind_param(state, statement, pos, adapted);
    jacpy_release(adapted);
    if rc != SQLITE_OK {
        exc = PyErr_GetRaisedException();
        set_error_from_db(state, sqlite3_db_handle(statement.st));
        _PyErr_ChainExceptions1(exc);
        return False;
    }
    return True;
}

def:priv bind_parameters(
    state: SqliteState, statement: StatementState, parameters: ptr[PyObject]
) {
    thread = PyEval_SaveThread();
    num_params_needed = sqlite3_bind_parameter_count(statement.st);
    PyEval_RestoreThread(thread);
    exact_tuple = jacpy_is_exact_tuple(parameters) != 0;
    exact_list = jacpy_is_exact_list(parameters) != 0;
    if exact_tuple
        or exact_list
        or (jacpy_is_dict(parameters) == 0 and PySequence_Check(parameters) != 0) {
        # Parameters passed as a sequence.
        num_params: i64 = 0;
        if exact_tuple {
            num_params = PyTuple_Size(parameters);
        } elif exact_list {
            num_params = PyList_Size(parameters);
        } else {
            num_params = PySequence_Size(parameters);
            if num_params == -1 {
                return;
            }
        }
        if num_params != i64(num_params_needed) {
            PyErr_Format(
                state.ProgrammingError,
                "Incorrect number of bindings supplied. The current statement uses %d, and there are %zd supplied.",
                num_params_needed,
                num_params
            );
            return;
        }
        for i in range(int(num_params)) {
            name = sqlite3_bind_parameter_name(statement.st, i32(i + 1));
            if not name.is_null() and name.view(1)[0] != 63 {
                PyErr_Format(
                    state.ProgrammingError,
                    "Binding %d ('%s') is a named parameter, but you supplied a sequence which requires nameless (qmark) placeholders.",
                    i32(i + 1),
                    name
                );
                return;
            }
            current_param = NULL;
            if exact_tuple {
                current_param = Py_NewRef(PyTuple_GetItem(parameters, i64(i)));
            } elif exact_list {
                item = PyList_GetItem(parameters, i64(i));
                current_param = Py_NewRef(item) if item else NULL;
            } else {
                current_param = PySequence_GetItem(parameters, i64(i));
            }
            if not current_param {
                return;
            }
            if not bind_one(state, statement, i32(i + 1), current_param) {
                return;
            }
        }
    } elif jacpy_is_dict(parameters) != 0 {
        # Parameters passed as a dictionary.
        for i in range(1, int(num_params_needed) + 1) {
            thread = PyEval_SaveThread();
            binding_name = sqlite3_bind_parameter_name(statement.st, i32(i));
            PyEval_RestoreThread(thread);
            if binding_name.is_null() {
                PyErr_Format(
                    state.ProgrammingError,
                    "Binding %d has no name, but you supplied a dictionary (which has only names).",
                    i32(i)
                );
                return;
            }
            # Skip the first character (the colon).
            binding_name += 1;
            current_param = NULL;
            key = c_string_text(binding_name);
            if not key {
                return;
            }
            found = PyMapping_GetOptionalItem(parameters, key, &mut current_param);
            jacpy_release(key);
            if found == -1 {
                return;
            } elif found == 0 {
                PyErr_Format(
                    state.ProgrammingError,
                    "You did not supply a value for binding parameter :%s.",
                    binding_name
                );
                return;
            }
            if not bind_one(state, statement, i32(i), current_param) {
                return;
            }
        }
    } else {
        object_error(state.ProgrammingError, "parameters are of unsupported type");
    }
}

# _pysqlite_query_execute(): execute `operation` once or for each parameter
# set; the cursor (a new reference), or NULL with the exception set.
def query_execute(
    instance: ptr[PyObject],
    multiple: bool,
    operation: ptr[PyObject],
    second_argument: ptr[PyObject]
) -> ptr[PyObject] {
    cur = cursor_of(instance);
    if cur is None {
        return NULL;
    }
    con = check_cursor(instance, cur);
    if con is None {
        # C still marks the cursor idle and resets it on this path.
        return finish_execute(instance, cur, NULL, NULL, NULL);
    }
    cur.locked = True;
    parameters_list = NULL;
    parameters_iter = NULL;
    if multiple {
        if PyIter_Check(second_argument) != 0 {
            parameters_iter = Py_NewRef(second_argument);
        } else {
            parameters_iter = PyObject_GetIter(second_argument);
            if not parameters_iter {
                return finish_execute(
                    instance, cur, NULL, parameters_iter, parameters_list
                );
            }
        }
    } else {
        parameters_list = PyList_New(0);
        if not parameters_list {
            return finish_execute(
                instance, cur, NULL, parameters_iter, parameters_list
            );
        }
        argument = Py_NewRef(second_argument) if second_argument else PyTuple_New(0);
        if not argument {
            return finish_execute(
                instance, cur, NULL, parameters_iter, parameters_list
            );
        }
        rc = PyList_Append(parameters_list, argument);
        jacpy_release(argument);
        if rc != 0 {
            return finish_execute(
                instance, cur, NULL, parameters_iter, parameters_list
            );
        }
        parameters_iter = PyObject_GetIter(parameters_list);
        if not parameters_iter {
            return finish_execute(
                instance, cur, NULL, parameters_iter, parameters_list
            );
        }
    }
    # Reset the description.
    set_field_description(cur, Py_NewRef(Py_None));
    if cur.statement {
        # Reset pending statements on this cursor.
        reset_statement_object(cur.statement);
    }
    set_statement(cur, get_statement_from_cache(con, operation));
    if not cur.statement {
        return finish_execute(instance, cur, NULL, parameters_iter, parameters_list);
    }
    state = con.state;
    statement = current_statement(cur);
    if multiple and sqlite3_stmt_readonly(statement.st) != 0 {
        object_error(
            state.ProgrammingError, "executemany() can only execute DML statements."
        );
        return finish_execute(instance, cur, NULL, parameters_iter, parameters_list);
    }
    if sqlite3_stmt_busy(statement.st) != 0 {
        connection = cur.fields.view(1)[0].connection;
        set_statement(cur, statement_create(connection, con, operation));
        if not cur.statement {
            return finish_execute(
                instance, cur, NULL, parameters_iter, parameters_list
            );
        }
        statement = current_statement(cur);
    }
    stmt_reset(statement);
    fields = cur.fields.view(1);
    fields[0].rowcount = 0 if statement.is_dml else -1;
    # A transaction starts implicitly before a DML statement. SELECT is the
    # only exception. See #9924.
    if con.autocommit == AUTOCOMMIT_LEGACY
        and con.isolation_level is not None
        and statement.is_dml
        and sqlite3_get_autocommit(con.db) != 0 {
        if begin_transaction(con) < 0 {
            return finish_execute(
                instance, cur, NULL, parameters_iter, parameters_list
            );
        }
    }
    while True {
        parameters = PyIter_Next(parameters_iter);
        if not parameters {
            break;
        }
        bind_parameters(state, statement, parameters);
        if PyErr_Occurred() {
            return finish_execute(
                instance, cur, parameters, parameters_iter, parameters_list
            );
        }
        rc = step_unlocked(statement.st);
        if rc != SQLITE_DONE and rc != SQLITE_ROW {
            if PyErr_Occurred() {
                # An error in a user-defined callback.
                if state.enable_callback_tracebacks {
                    PyErr_Print();
                } else {
                    PyErr_Clear();
                }
            }
            set_error_from_db(state, con.db);
            return finish_execute(
                instance, cur, parameters, parameters_iter, parameters_list
            );
        }
        if build_row_cast_map(cur, con) != 0 {
            _PyErr_FormatFromCause(
                state.OperationalError, "Error while building row_cast_map"
            );
            return finish_execute(
                instance, cur, parameters, parameters_iter, parameters_list
            );
        }
        thread = PyEval_SaveThread();
        numcols = sqlite3_column_count(statement.st);
        PyEval_RestoreThread(thread);
        if fields[0].description == Py_None and numcols > 0 {
            description = PyTuple_New(i64(numcols));
            set_field_description(cur, description);
            if not description {
                return finish_execute(
                    instance, cur, parameters, parameters_iter, parameters_list
                );
            }
            for i in range(int(numcols)) {
                colname = sqlite3_column_name(statement.st, i32(i));
                if colname.is_null() {
                    PyErr_NoMemory();
                    return finish_execute(
                        instance, cur, parameters, parameters_iter, parameters_list
                    );
                }
                column_name = build_column_name(con, colname);
                if not column_name {
                    return finish_execute(
                        instance, cur, parameters, parameters_iter, parameters_list
                    );
                }
                descriptor = PyTuple_Pack(
                    7, column_name, Py_None, Py_None, Py_None, Py_None, Py_None, Py_None
                );
                jacpy_release(column_name);
                if not descriptor {
                    return finish_execute(
                        instance, cur, parameters, parameters_iter, parameters_list
                    );
                }
                PyTuple_SetItem(description, i64(i), descriptor);
            }
        }
        if rc == SQLITE_DONE {
            if statement.is_dml {
                fields[0].rowcount = fields[0].rowcount + i64(sqlite3_changes(con.db));
            }
            stmt_reset(statement);
        }
        jacpy_release(parameters);
    }
    if not multiple {
        thread = PyEval_SaveThread();
        lastrowid = sqlite3_last_insert_rowid(con.db);
        PyEval_RestoreThread(thread);
        # On failure the exception falls through to finish_execute().
        set_field_lastrowid(cur, PyLong_FromLongLong(lastrowid));
    }
    return finish_execute(instance, cur, NULL, parameters_iter, parameters_list);
}

# The common exit of _pysqlite_query_execute().
def:priv finish_execute(
    instance: ptr[PyObject],
    cur: CursorState,
    parameters: ptr[PyObject],
    parameters_iter: ptr[PyObject],
    parameters_list: ptr[PyObject]
) -> ptr[PyObject] {
    jacpy_release(parameters);
    jacpy_release(parameters_iter);
    jacpy_release(parameters_list);
    cur.locked = False;
    if PyErr_Occurred() {
        if cur.statement {
            reset_statement_object(cur.statement);
            set_statement(cur, NULL);
        }
        if not cur.fields.is_null() {
            cur.fields.view(1)[0].rowcount = -1;
        }
        return NULL;
    }
    if cur.statement {
        statement = current_statement(cur);
        if statement is None or sqlite3_stmt_busy(statement.st) == 0 {
            set_statement(cur, NULL);
        }
    }
    return Py_NewRef(instance);
}

def pysqlite_cursor_execute_impl(
    receiver: ptr[PyObject], sql: ptr[PyObject], parameters: ptr[PyObject]
) -> ptr[PyObject] {
    return query_execute(receiver, False, sql, parameters);
}

def pysqlite_cursor_executemany_impl(
    receiver: ptr[PyObject], sql: ptr[PyObject], seq_of_parameters: ptr[PyObject]
) -> ptr[PyObject] {
    return query_execute(receiver, True, sql, seq_of_parameters);
}

def pysqlite_cursor_executescript_impl(
    receiver: ptr[PyObject], sql_script: str
) -> ptr[PyObject] {
    cur = cursor_of(receiver);
    if cur is None {
        return NULL;
    }
    con = check_cursor(receiver, cur);
    if con is None {
        return NULL;
    }
    script = c_string_copy(sql_script);
    if script.is_null() {
        return PyErr_NoMemory();
    }
    sql_len = c_string_length(script);
    max_length = sqlite3_limit(con.db, SQLITE_LIMIT_SQL_LENGTH, i32(-1));
    if u64(sql_len) > u64(u32.wrap(i64(max_length))) {
        PyMem_RawFree(script);
        object_error(con.state.DataError, "query string is too large");
        return NULL;
    }
    db = con.db;
    failed = False;
    # Commit if needed.
    if con.autocommit == AUTOCOMMIT_LEGACY and sqlite3_get_autocommit(db) == 0 {
        thread = PyEval_SaveThread();
        rc = sqlite3_exec(db, "COMMIT", ptr(), ptr(), ptr());
        PyEval_RestoreThread(thread);
        failed = rc != SQLITE_OK;
    }
    position = script;
    while not failed {
        tail = ptr[u8]();
        stmt = ptr[sqlite3_stmt]();
        thread = PyEval_SaveThread();
        rc = sqlite3_prepare_v2(db, position, i32(sql_len + 1), &mut stmt, &mut tail);
        if rc == SQLITE_OK {
            rc = sqlite3_step(stmt);
            while rc == SQLITE_ROW {
                rc = sqlite3_step(stmt);
            }
            rc = sqlite3_finalize(stmt);
        }
        PyEval_RestoreThread(thread);
        if rc != SQLITE_OK {
            failed = True;
            break;
        }
        if tail.view(1)[0] == 0 {
            break;
        }
        sql_len -= int(tail - position);
        position = tail;
    }
    PyMem_RawFree(script);
    if failed {
        set_error_from_db(con.state, db);
        return NULL;
    }
    return Py_NewRef(receiver);
}

# pysqlite_cursor_iternext(): the next row, or NULL (with no exception when
# the rows are exhausted).
def cursor_iternext(instance: ptr[PyObject]) -> ptr[PyObject] {
    cur = cursor_of(instance);
    if cur is None {
        return NULL;
    }
    con = check_cursor(instance, cur);
    if con is None or not cur.statement {
        return NULL;
    }
    statement = current_statement(cur);
    stmt = statement.st;
    # GH-80254: prevent recursive use of cursors.
    cur.locked = True;
    row = fetch_one_row(cur, con);
    cur.locked = False;
    if not row {
        return NULL;
    }
    rc = step_unlocked(stmt);
    if rc == SQLITE_DONE {
        if statement.is_dml {
            cur.fields.view(1)[0].rowcount = i64(sqlite3_changes(con.db));
        }
        stmt_reset(statement);
        set_statement(cur, NULL);
    } elif rc != SQLITE_ROW {
        set_error_from_db(con.state, con.db);
        stmt_reset(statement);
        set_statement(cur, NULL);
        jacpy_release(row);
        return NULL;
    }
    factory = cur.fields.view(1)[0].row_factory;
    if factory and factory != Py_None {
        new_row = PyObject_CallFunctionObjArgs(factory, instance, row, NULL);
        jacpy_release(row);
        row = new_row;
    }
    return row;
}

def pysqlite_cursor_fetchone_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    row = cursor_iternext(receiver);
    if not row and not PyErr_Occurred() {
        return Py_NewRef(Py_None);
    }
    return row;
}

# The default `size` of fetchmany(): the cursor's arraysize.
def self_arraysize(receiver: ptr[PyObject]) -> u32 {
    cur = cursor_of(receiver);
    if cur is None {
        raise boundary_failure();
    }
    return cur.arraysize;
}

def pysqlite_cursor_fetchmany_impl(
    receiver: ptr[PyObject], maxrows: u32
) -> ptr[PyObject] {
    rows = PyList_New(0);
    if not rows {
        return NULL;
    }
    remaining = maxrows;
    while remaining > u32(0) {
        row = cursor_iternext(receiver);
        if not row {
            break;
        }
        rc = PyList_Append(rows, row);
        jacpy_release(row);
        if rc < 0 {
            break;
        }
        remaining -= u32(1);
    }
    if PyErr_Occurred() {
        jacpy_release(rows);
        return NULL;
    }
    return rows;
}

def pysqlite_cursor_fetchall_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    rows = PyList_New(0);
    if not rows {
        return NULL;
    }
    while True {
        row = cursor_iternext(receiver);
        if not row {
            break;
        }
        rc = PyList_Append(rows, row);
        jacpy_release(row);
        if rc < 0 {
            break;
        }
    }
    if PyErr_Occurred() {
        jacpy_release(rows);
        return NULL;
    }
    return rows;
}

def pysqlite_cursor_setinputsizes_impl(
    receiver: ptr[PyObject], sizes: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_NewRef(Py_None);
}

def pysqlite_cursor_setoutputsize_impl(
    receiver: ptr[PyObject], size: ptr[PyObject], column: ptr[PyObject]
) -> ptr[PyObject] {
    return Py_NewRef(Py_None);
}

def pysqlite_cursor_close_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    cur = cursor_of(receiver);
    if cur is None {
        return NULL;
    }
    connection = cur.fields.view(1)[0].connection;
    if cur.locked {
        con = connection_of(connection);
        if con is not None and con.initialized {
            object_error(
                con.state.ProgrammingError, "Recursive use of cursors not allowed."
            );
        }
        return NULL;
    }
    if not connection {
        state = state_of(receiver);
        if state is not None {
            object_error(state.ProgrammingError, "Base Cursor.__init__ not called.");
        }
        return NULL;
    }
    con = connection_of(connection);
    if con is None or not check_thread(con) or not check_connection(connection, con) {
        return NULL;
    }
    if cur.statement {
        reset_statement_object(cur.statement);
        set_statement(cur, NULL);
    }
    cur.closed = True;
    return Py_NewRef(Py_None);
}

def _sqlite3_Cursor_arraysize_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    cur = cursor_of(receiver);
    if cur is None {
        return NULL;
    }
    return PyLong_FromUInt32(cur.arraysize);
}

def _sqlite3_Cursor_arraysize_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    cur = cursor_of(receiver);
    if cur is None {
        return i32(-1);
    }
    if not value {
        object_error(PyExc_AttributeError, "cannot delete attribute");
        return i32(-1);
    }
    size: u32 = 0;
    if PyLong_AsUInt32(value, &mut size) < 0 {
        return i32(-1);
    }
    cur.arraysize = size;
    return i32(0);
}

def cursor_self_iter(instance: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(instance);
}

# ------------------------------------------------------------------- row.c

obj RowState(NativeState) {
    has data: ptr[PyObject] = NULL,
        description: ptr[PyObject] = NULL;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        status = visit_reference(self.data, visitor, context);
        if status != 0 {
            return status;
        }
        return visit_reference(self.description, visitor, context);
    }

    def clear {
        data = self.data;
        description = self.description;
        self.data = NULL;
        self.description = NULL;
        jacpy_release(data);
        jacpy_release(description);
    }
}

def row_of(instance: ptr[PyObject]) -> (RowState | None) {
    if jacpy_binding_native_present(instance, Row_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, Row_token.handle);
        if isinstance(state, RowState) {
            return state;
        }
    }
    if not PyErr_Occurred() {
        object_error(PyExc_SystemError, "sqlite3.Row state is unavailable");
    }
    return None;
}

def pysqlite_row_new_impl(
    type: ptr[PyObject], cursor: ptr[PyObject], data: ptr[PyObject]
) -> ptr[PyObject] {
    cur = cursor_of(cursor);
    if cur is None {
        return NULL;
    }
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    description = cur.fields.view(1)[0].description;
    row = RowState(
        data=Py_NewRef(data),
        description=Py_NewRef(description if description else Py_None)
    );
    if jacpy_binding_native_set(instance, Row_token.handle, row) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def row_item(instance: ptr[PyObject], index: i64) -> ptr[PyObject] {
    row = row_of(instance);
    if row is None {
        return NULL;
    }
    item = PyTuple_GetItem(row.data, index);
    return Py_NewRef(item) if item else NULL;
}

# equal_ignore_case(): 1 when equal (or equal ignoring ASCII case), 0 when
# not, -1 with the exception set.
def:priv equal_ignore_case(left: ptr[PyObject], right: ptr[PyObject]) -> i32 {
    eq = PyObject_RichCompareBool(left, right, PY_EQ);
    if eq != 0 {
        return eq;
    }
    if jacpy_is_unicode(left) == 0 or jacpy_is_unicode(right) == 0 {
        return i32(0);
    }
    first = text_value(left);
    second = text_value(right);
    if not first.isascii() or not second.isascii() or len(first) != len(second) {
        return i32(0);
    }
    return i32(1) if first.lower() == second.lower() else i32(0);
}

def row_subscript(instance: ptr[PyObject], idx: ptr[PyObject]) -> ptr[PyObject] {
    row = row_of(instance);
    if row is None {
        return NULL;
    }
    if jacpy_is_long(idx) != 0 {
        index = PyNumber_AsSsize_t(idx, PyExc_IndexError);
        if index == -1 and PyErr_Occurred() {
            return NULL;
        }
        if index < 0 {
            index += PyTuple_Size(row.data);
        }
        item = PyTuple_GetItem(row.data, index);
        return Py_NewRef(item) if item else NULL;
    } elif jacpy_is_unicode(idx) != 0 {
        if row.description == Py_None {
            PyErr_Format(PyExc_IndexError, "No item with key %R", idx);
            return NULL;
        }
        nitems = PyTuple_Size(row.description);
        for i in range(int(nitems)) {
            name = PyTuple_GetItem(PyTuple_GetItem(row.description, i64(i)), 0);
            eq = equal_ignore_case(idx, name);
            if eq < 0 {
                return NULL;
            }
            if eq != 0 {
                item = PyTuple_GetItem(row.data, i64(i));
                return Py_NewRef(item) if item else NULL;
            }
        }
        object_error(PyExc_IndexError, "No item with that key");
        return NULL;
    } elif jacpy_is_slice(idx) != 0 {
        return PyObject_GetItem(row.data, idx);
    }
    object_error(PyExc_IndexError, "Index must be int or string");
    return NULL;
}

def row_length(instance: ptr[PyObject]) -> i64 {
    row = row_of(instance);
    if row is None {
        return -1;
    }
    return PyTuple_Size(row.data);
}

def pysqlite_row_keys_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    row = row_of(receiver);
    if row is None {
        return NULL;
    }
    keys = PyList_New(0);
    if not keys {
        return NULL;
    }
    if row.description == Py_None {
        return keys;
    }
    nitems = PyTuple_Size(row.description);
    for i in range(int(nitems)) {
        name = PyTuple_GetItem(PyTuple_GetItem(row.description, i64(i)), 0);
        if PyList_Append(keys, name) < 0 {
            jacpy_release(keys);
            return NULL;
        }
    }
    return keys;
}

def row_iter(instance: ptr[PyObject]) -> ptr[PyObject] {
    row = row_of(instance);
    if row is None {
        return NULL;
    }
    return PyObject_GetIter(row.data);
}

def row_hash(instance: ptr[PyObject]) -> i64 {
    row = row_of(instance);
    if row is None {
        return -1;
    }
    return PyObject_Hash(row.description) ^ PyObject_Hash(row.data);
}

def row_richcompare(
    instance: ptr[PyObject], other: ptr[PyObject], opid: i32
) -> ptr[PyObject] {
    if opid != PY_EQ and opid != PY_NE {
        return Py_NewRef(Py_NotImplemented);
    }
    state = state_of(instance);
    if state is None {
        return NULL;
    }
    if jacpy_type_check(other, state.RowType) != 0 {
        row = row_of(instance);
        other_row = row_of(other);
        if row is None or other_row is None {
            return NULL;
        }
        eq = PyObject_RichCompareBool(row.description, other_row.description, PY_EQ);
        if eq < 0 {
            return NULL;
        }
        if eq != 0 {
            return PyObject_RichCompare(row.data, other_row.data, opid);
        }
        return PyBool_FromLong(i64(opid != PY_EQ));
    }
    return Py_NewRef(Py_NotImplemented);
}

# ------------------------------------------------------------------ blob.c

obj BlobState(NativeState) {
    has connection: ptr[PyObject] = NULL,
        blob: ptr[sqlite3_blob] = ptr[sqlite3_blob](),
        offset: i32 = 0;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return visit_reference(self.connection, visitor, context);
    }

    def clear {
        connection = self.connection;
        self.connection = NULL;
        jacpy_release(connection);
    }
}

def blob_of(instance: ptr[PyObject]) -> (BlobState | None) {
    if jacpy_binding_native_present(instance, Blob_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, Blob_token.handle);
        if isinstance(state, BlobState) {
            return state;
        }
    }
    if not PyErr_Occurred() {
        object_error(PyExc_SystemError, "sqlite3.Blob state is unavailable");
    }
    return None;
}

def close_blob(blob: BlobState) {
    if not blob.blob.is_null() {
        handle = blob.blob;
        blob.blob = ptr[sqlite3_blob]();
        thread = PyEval_SaveThread();
        sqlite3_blob_close(handle);
        PyEval_RestoreThread(thread);
    }
}

# blob_dealloc() closes the blob before the object is freed.
def blob_close_on_dealloc(instance: ptr[PyObject]) {
    if jacpy_binding_native_present(instance, Blob_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, Blob_token.handle);
        if isinstance(state, BlobState) {
            close_blob(state);
        }
    }
}

# pysqlite_close_all_blobs().
def:priv close_all_blobs(con: ConnectionState) {
    if not con.blobs {
        return;
    }
    i = 0;
    while i < int(PyList_Size(con.blobs)) {
        weakref = PyList_GetItem(con.blobs, i64(i));
        i += 1;
        blob = NULL;
        if PyWeakref_GetRef(weakref, &mut blob) <= 0 {
            continue;
        }
        state = blob_of(blob);
        if state is not None {
            close_blob(state);
        }
        jacpy_release(blob);
    }
}

# check_blob(): the blob's connection when the blob is usable.
def:priv check_blob(blob: BlobState) -> (ConnectionState | None) {
    con = connection_of(blob.connection);
    if con is None
        or not check_connection(blob.connection, con)
        or not check_thread(con) {
        return None;
    }
    if blob.blob.is_null() {
        object_error(con.state.ProgrammingError, "Cannot operate on a closed blob.");
        return None;
    }
    return con;
}

def:priv usable_blob(
    instance: ptr[PyObject]
) -> (tuple[BlobState, ConnectionState] | None) {
    blob = blob_of(instance);
    if blob is None {
        return None;
    }
    con = check_blob(blob);
    if con is None {
        return None;
    }
    return (blob, con);
}

def blob_close_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    blob = blob_of(receiver);
    if blob is None {
        return NULL;
    }
    con = connection_of(blob.connection);
    if con is None
        or not check_connection(blob.connection, con)
        or not check_thread(con) {
        return NULL;
    }
    close_blob(blob);
    return Py_NewRef(Py_None);
}

def:priv read_single(
    blob: BlobState, con: ConnectionState, offset: i64
) -> ptr[PyObject] {
    buf = ptr[u8](PyMem_Malloc(1));
    if buf.is_null() {
        return PyErr_NoMemory();
    }
    buf.view(1)[0] = u8(0);
    thread = PyEval_SaveThread();
    rc = sqlite3_blob_read(blob.blob, buf, i32(1), i32(offset));
    PyEval_RestoreThread(thread);
    value = buf.view(1)[0];
    PyMem_Free(buf);
    if rc != SQLITE_OK {
        set_error_from_db(con.state, con.db);
        return NULL;
    }
    return PyLong_FromUnsignedLong(u64(value));
}

def:priv read_multiple(
    blob: BlobState, con: ConnectionState, length: i64, offset: i64
) -> ptr[PyObject] {
    buffer = jacpy_buffer_new(length);
    if not buffer {
        return NULL;
    }
    raw_buffer = PyBytes_AsString(buffer);
    thread = PyEval_SaveThread();
    rc = sqlite3_blob_read(blob.blob, raw_buffer, i32(length), i32(offset));
    PyEval_RestoreThread(thread);
    if rc != SQLITE_OK {
        jacpy_release(buffer);
        set_error_from_db(con.state, con.db);
        return NULL;
    }
    return buffer;
}

def blob_read_impl(receiver: ptr[PyObject], length: i32) -> ptr[PyObject] {
    usable = usable_blob(receiver);
    if usable is None {
        return NULL;
    }
    (blob, con) = usable;
    # Never read past the end; a negative length reads the rest.
    blob_len = sqlite3_blob_bytes(blob.blob);
    max_read_len = blob_len - blob.offset;
    if length < 0 or length > max_read_len {
        length = max_read_len;
    }
    if length == 0 {
        return jacpy_buffer_new(0);
    }
    buffer = read_multiple(blob, con, i64(length), i64(blob.offset));
    if not buffer {
        return NULL;
    }
    blob.offset = blob.offset + length;
    return buffer;
}

def:priv inner_write(
    blob: BlobState, con: ConnectionState, buf: ptr, length: i64, offset: i64
) -> i32 {
    blob_len = i64(sqlite3_blob_bytes(blob.blob));
    remaining_len = blob_len - offset;
    if length > remaining_len {
        object_error(PyExc_ValueError, "data longer than blob length");
        return i32(-1);
    }
    thread = PyEval_SaveThread();
    rc = sqlite3_blob_write(blob.blob, buf, i32(length), i32(offset));
    PyEval_RestoreThread(thread);
    if rc != SQLITE_OK {
        set_error_from_db(con.state, con.db);
        return i32(-1);
    }
    return i32(0);
}

def blob_write_impl(receiver: ptr[PyObject], data: BufferArgument) -> ptr[PyObject] {
    usable = usable_blob(receiver);
    if usable is None {
        return NULL;
    }
    (blob, con) = usable;
    if inner_write(blob, con, data.address(), data.size(), i64(blob.offset)) < 0 {
        return NULL;
    }
    blob.offset = blob.offset + i32.wrap(data.size());
    return Py_NewRef(Py_None);
}

def blob_seek_impl(receiver: ptr[PyObject], offset: i32, origin: i32) -> ptr[PyObject] {
    usable = usable_blob(receiver);
    if usable is None {
        return NULL;
    }
    (blob, con) = usable;
    blob_len = sqlite3_blob_bytes(blob.blob);
    target = i64(offset);
    if origin == BLOB_SEEK_START {
        target = i64(offset);
    } elif origin == BLOB_SEEK_CUR {
        if i64(offset) > INT_MAX - i64(blob.offset) {
            object_error(PyExc_OverflowError, "seek offset results in overflow");
            return NULL;
        }
        target = i64(offset) + i64(blob.offset);
    } elif origin == BLOB_SEEK_END {
        if i64(offset) > INT_MAX - i64(blob_len) {
            object_error(PyExc_OverflowError, "seek offset results in overflow");
            return NULL;
        }
        target = i64(offset) + i64(blob_len);
    } else {
        object_error(
            PyExc_ValueError,
            "'origin' should be os.SEEK_SET, os.SEEK_CUR, or os.SEEK_END"
        );
        return NULL;
    }
    if target < 0 or target > i64(blob_len) {
        object_error(PyExc_ValueError, "offset out of blob range");
        return NULL;
    }
    blob.offset = i32(target);
    return Py_NewRef(Py_None);
}

def blob_tell_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    usable = usable_blob(receiver);
    if usable is None {
        return NULL;
    }
    return PyLong_FromLong(i64(usable[0].offset));
}

def blob_enter_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if usable_blob(receiver) is None {
        return NULL;
    }
    return Py_NewRef(receiver);
}

def blob_exit_impl(
    receiver: ptr[PyObject], type: ptr[PyObject], val: ptr[PyObject], tb: ptr[PyObject]
) -> ptr[PyObject] {
    usable = usable_blob(receiver);
    if usable is None {
        return NULL;
    }
    close_blob(usable[0]);
    return Py_NewRef(borrowed_false());
}

def blob_length(instance: ptr[PyObject]) -> i64 {
    usable = usable_blob(instance);
    if usable is None {
        return -1;
    }
    return i64(sqlite3_blob_bytes(usable[0].blob));
}

def:priv get_subscript_index(blob: BlobState, item: ptr[PyObject]) -> i64 {
    i = PyNumber_AsSsize_t(item, PyExc_IndexError);
    if i == -1 and PyErr_Occurred() {
        return -1;
    }
    blob_len = i64(sqlite3_blob_bytes(blob.blob));
    if i < 0 {
        i += blob_len;
    }
    if i < 0 or i >= blob_len {
        object_error(PyExc_IndexError, "Blob index out of range");
        return -1;
    }
    return i;
}

# The slice's start, stop, step and length over the blob; None on failure.
def:priv get_slice_info(blob: BlobState, item: ptr[PyObject]) -> (list[i64] | None) {
    # start, stop and step, in memory the slice functions write through.
    cells = PyMem_Malloc(u64(24));
    if not cells {
        PyErr_NoMemory();
        return None;
    }
    start = ptr[i64](cells);
    stop = ptr[i64](cells + 8);
    step = ptr[i64](cells + 16);
    try {
        if PySlice_Unpack(item, start, stop, step) < 0 {
            return None;
        }
        length = i64(sqlite3_blob_bytes(blob.blob));
        slicelen = PySlice_AdjustIndices(length, start, stop, step.view(1)[0]);
        return [start.view(1)[0], stop.view(1)[0], step.view(1)[0], slicelen];
    } finally {
        PyMem_Free(cells);
    }
}

def blob_subscript(instance: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    usable = usable_blob(instance);
    if usable is None {
        return NULL;
    }
    (blob, con) = usable;
    if PyIndex_Check(item) != 0 {
        i = get_subscript_index(blob, item);
        if i < 0 {
            return NULL;
        }
        return read_single(blob, con, i);
    }
    if jacpy_is_slice(item) != 0 {
        info = get_slice_info(blob, item);
        if info is None {
            return NULL;
        }
        (start, stop, step, length) = (info[0], info[1], info[2], info[3]);
        if length == 0 {
            return jacpy_buffer_new(0);
        }
        if step == 1 {
            return read_multiple(blob, con, length, start);
        }
        whole = read_multiple(blob, con, stop - start, start);
        if not whole {
            return NULL;
        }
        result = jacpy_buffer_new(length);
        if result {
            blob_buf = ptr[u8](PyBytes_AsString(whole));
            res_buf = ptr[u8](PyBytes_AsString(result));
            j: i64 = 0;
            for i in range(int(length)) {
                (res_buf + i).view(1)[0] = (blob_buf + j).view(1)[0];
                j += step;
            }
        }
        jacpy_release(whole);
        return result;
    }
    object_error(PyExc_TypeError, "Blob indices must be integers");
    return NULL;
}

def:priv ass_subscript_index(
    blob: BlobState, con: ConnectionState, item: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if not value {
        object_error(PyExc_TypeError, "Blob doesn't support item deletion");
        return i32(-1);
    }
    if jacpy_is_long(value) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "'%s' object cannot be interpreted as an integer",
            tp_name(value)
        );
        return i32(-1);
    }
    i = get_subscript_index(blob, item);
    if i < 0 {
        return i32(-1);
    }
    val = PyLong_AsLong(value);
    if val == -1 and PyErr_Occurred() {
        PyErr_Clear();
        val = -1;
    }
    if val < 0 or val > 255 {
        object_error(PyExc_ValueError, "byte must be in range(0, 256)");
        return i32(-1);
    }
    byte = ptr[u8](PyMem_Malloc(1));
    if byte.is_null() {
        PyErr_NoMemory();
        return i32(-1);
    }
    byte.view(1)[0] = u8(val);
    rc = inner_write(blob, con, byte, 1, i);
    PyMem_Free(byte);
    return rc;
}

def:priv ass_subscript_slice(
    blob: BlobState, con: ConnectionState, item: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    if not value {
        object_error(PyExc_TypeError, "Blob doesn't support slice deletion");
        return i32(-1);
    }
    info = get_slice_info(blob, item);
    if info is None {
        return i32(-1);
    }
    (start, stop, step, length) = (info[0], info[1], info[2], info[3]);
    vbuf = BufferArgument();
    if not vbuf.export(value, 0) {
        return i32(-1);
    }
    if vbuf.size() != length {
        object_error(PyExc_IndexError, "Blob slice assignment is wrong size");
        vbuf.close();
        return i32(-1);
    }
    if length == 0 {
        vbuf.close();
        return i32(0);
    }
    rc = i32(-1);
    if step == 1 {
        rc = inner_write(blob, con, vbuf.address(), length, start);
    } else {
        blob_bytes = read_multiple(blob, con, stop - start, start);
        if blob_bytes {
            blob_buf = ptr[u8](PyBytes_AsString(blob_bytes));
            source = ptr[u8](vbuf.address());
            j: i64 = 0;
            for i in range(int(length)) {
                (blob_buf + j).view(1)[0] = (source + i).view(1)[0];
                j += step;
            }
            rc = inner_write(blob, con, blob_buf, stop - start, start);
            jacpy_release(blob_bytes);
        }
    }
    vbuf.close();
    return rc;
}

def blob_ass_subscript(
    instance: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    usable = usable_blob(instance);
    if usable is None {
        return i32(-1);
    }
    (blob, con) = usable;
    if PyIndex_Check(item) != 0 {
        return ass_subscript_index(blob, con, item, value);
    }
    if jacpy_is_slice(item) != 0 {
        return ass_subscript_slice(blob, con, item, value);
    }
    object_error(PyExc_TypeError, "Blob indices must be integers");
    return i32(-1);
}

# ------------------------------------------------------- prepare_protocol.c

def prepare_protocol_init(
    instance: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    return i32(0);
}

# ---------------------------------------------------------------- module.c

def pysqlite_complete_statement_impl(
    module: ptr[PyObject], statement: str
) -> ptr[PyObject] {
    if sqlite3_complete(statement) != 0 {
        return Py_NewRef(borrowed_true());
    }
    return Py_NewRef(borrowed_false());
}

def pysqlite_register_adapter_impl(
    module: ptr[PyObject], type: ptr[PyObject], caster: ptr[PyObject]
) -> ptr[PyObject] {
    state = module_state(module);
    if state is None {
        return NULL;
    }
    # Adapting a basic type disables the fast path that skips adaption.
    if type == addressof(PyLong_Type)
        or type == addressof(PyFloat_Type)
        or type == addressof(PyUnicode_Type)
        or type == addressof(PyByteArray_Type) {
        state.base_type_adapted = True;
    }
    if microprotocols_add(state, type, state.PrepareProtocolType, caster) == -1 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def pysqlite_register_converter_impl(
    module: ptr[PyObject], orig_name: ptr[PyObject], callable: ptr[PyObject]
) -> ptr[PyObject] {
    state = module_state(module);
    if state is None {
        return NULL;
    }
    # Converter names are upper case.
    name = PyObject_CallMethodObjArgs(orig_name, state.str_upper, NULL);
    if not name {
        return NULL;
    }
    rc = PyDict_SetItem(state.converters, name, callable);
    jacpy_release(name);
    if rc != 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def pysqlite_enable_callback_trace_impl(
    module: ptr[PyObject], enable: i32
) -> ptr[PyObject] {
    state = module_state(module);
    if state is None {
        return NULL;
    }
    state.enable_callback_tracebacks = enable != 0;
    return Py_NewRef(Py_None);
}

def pysqlite_adapt_impl(
    module: ptr[PyObject],
    value: ptr[PyObject],
    proto: ptr[PyObject],
    alt: ptr[PyObject]
) -> ptr[PyObject] {
    state = module_state(module);
    if state is None {
        return NULL;
    }
    return microprotocols_adapt(state, value, proto, alt);
}

# get_threadsafety(): the DB-API threadsafety level of SQLite's default
# threading mode; -1 with the error set.
def threadsafety(state: SqliteState) -> i32 {
    mode = sqlite3_threadsafe();
    if mode == 0 {
        # Single-thread mode; threads may not share the module.
        return i32(0);
    }
    if mode == 1 {
        # Serialized mode; threads may share the module, connections and
        # cursors.
        return i32(3);
    }
    if mode == 2 {
        # Multi-thread mode; threads may share the module, but not
        # connections.
        return i32(1);
    }
    PyErr_Format(
        state.InterfaceError,
        "Unable to interpret SQLite threadsafety mode. Got %d, expected 0, 1, or 2",
        mode
    );
    return i32(-1);
}

# The first part of module_exec(): the SQLite version check and
# sqlite3_initialize(); False with ImportError set.
def initialize_library -> bool {
    if sqlite3_libversion_number() < 3015002 {
        object_error(PyExc_ImportError, "sqlite3: SQLite 3.15.2 or higher required");
        return False;
    }
    rc = sqlite3_initialize();
    if rc != SQLITE_OK {
        message = c_string_text(sqlite3_errstr(rc));
        if message {
            PyErr_SetObject(PyExc_ImportError, message);
            jacpy_release(message);
        }
        return False;
    }
    return True;
}

# The SQLite library version string.
def library_version -> ptr[PyObject] {
    return c_string_text(sqlite3_libversion());
}
