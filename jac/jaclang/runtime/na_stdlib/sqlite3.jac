glob apilevel: str = "2.0",
     paramstyle: str = "qmark",
     threadsafety: int = 3,
     sqlite_version: str = sq3_libversion();

glob PARSE_DECLTYPES: int = 1,
     PARSE_COLNAMES: int = 2,
     LEGACY_TRANSACTION_CONTROL: int = -1;

glob SQLITE_ABORT: int = 4,
     SQLITE_ABORT_ROLLBACK: int = 516,
     SQLITE_ALTER_TABLE: int = 26,
     SQLITE_ANALYZE: int = 28,
     SQLITE_ATTACH: int = 24;
glob SQLITE_AUTH: int = 23,
     SQLITE_AUTH_USER: int = 279,
     SQLITE_BUSY: int = 5,
     SQLITE_BUSY_RECOVERY: int = 261,
     SQLITE_BUSY_SNAPSHOT: int = 517;
glob SQLITE_BUSY_TIMEOUT: int = 773,
     SQLITE_CANTOPEN: int = 14,
     SQLITE_CANTOPEN_CONVPATH: int = 1038,
     SQLITE_CANTOPEN_DIRTYWAL: int = 1294,
     SQLITE_CANTOPEN_FULLPATH: int = 782;
glob SQLITE_CANTOPEN_ISDIR: int = 526,
     SQLITE_CANTOPEN_NOTEMPDIR: int = 270,
     SQLITE_CANTOPEN_SYMLINK: int = 1550,
     SQLITE_CONSTRAINT: int = 19,
     SQLITE_CONSTRAINT_CHECK: int = 275;
glob SQLITE_CONSTRAINT_COMMITHOOK: int = 531,
     SQLITE_CONSTRAINT_FOREIGNKEY: int = 787,
     SQLITE_CONSTRAINT_FUNCTION: int = 1043,
     SQLITE_CONSTRAINT_NOTNULL: int = 1299,
     SQLITE_CONSTRAINT_PINNED: int = 2835;
glob SQLITE_CONSTRAINT_PRIMARYKEY: int = 1555,
     SQLITE_CONSTRAINT_ROWID: int = 2579,
     SQLITE_CONSTRAINT_TRIGGER: int = 1811,
     SQLITE_CONSTRAINT_UNIQUE: int = 2067,
     SQLITE_CONSTRAINT_VTAB: int = 2323;
glob SQLITE_CORRUPT: int = 11,
     SQLITE_CORRUPT_INDEX: int = 779,
     SQLITE_CORRUPT_SEQUENCE: int = 523,
     SQLITE_CORRUPT_VTAB: int = 267,
     SQLITE_CREATE_INDEX: int = 1;
glob SQLITE_CREATE_TABLE: int = 2,
     SQLITE_CREATE_TEMP_INDEX: int = 3,
     SQLITE_CREATE_TEMP_TABLE: int = 4,
     SQLITE_CREATE_TEMP_TRIGGER: int = 5,
     SQLITE_CREATE_TEMP_VIEW: int = 6;
glob SQLITE_CREATE_TRIGGER: int = 7,
     SQLITE_CREATE_VIEW: int = 8,
     SQLITE_CREATE_VTABLE: int = 29,
     SQLITE_DBCONFIG_DEFENSIVE: int = 1010,
     SQLITE_DBCONFIG_DQS_DDL: int = 1014;
glob SQLITE_DBCONFIG_DQS_DML: int = 1013,
     SQLITE_DBCONFIG_ENABLE_FKEY: int = 1002,
     SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER: int = 1004,
     SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION: int = 1005,
     SQLITE_DBCONFIG_ENABLE_QPSG: int = 1007;
glob SQLITE_DBCONFIG_ENABLE_TRIGGER: int = 1003,
     SQLITE_DBCONFIG_ENABLE_VIEW: int = 1015,
     SQLITE_DBCONFIG_LEGACY_ALTER_TABLE: int = 1012,
     SQLITE_DBCONFIG_LEGACY_FILE_FORMAT: int = 1016,
     SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE: int = 1006;
glob SQLITE_DBCONFIG_RESET_DATABASE: int = 1009,
     SQLITE_DBCONFIG_TRIGGER_EQP: int = 1008,
     SQLITE_DBCONFIG_TRUSTED_SCHEMA: int = 1017,
     SQLITE_DBCONFIG_WRITABLE_SCHEMA: int = 1011,
     SQLITE_DELETE: int = 9;
glob SQLITE_DENY: int = 1,
     SQLITE_DETACH: int = 25,
     SQLITE_DONE: int = 101,
     SQLITE_DROP_INDEX: int = 10,
     SQLITE_DROP_TABLE: int = 11;
glob SQLITE_DROP_TEMP_INDEX: int = 12,
     SQLITE_DROP_TEMP_TABLE: int = 13,
     SQLITE_DROP_TEMP_TRIGGER: int = 14,
     SQLITE_DROP_TEMP_VIEW: int = 15,
     SQLITE_DROP_TRIGGER: int = 16;
glob SQLITE_DROP_VIEW: int = 17,
     SQLITE_DROP_VTABLE: int = 30,
     SQLITE_EMPTY: int = 16,
     SQLITE_ERROR: int = 1,
     SQLITE_ERROR_MISSING_COLLSEQ: int = 257;
glob SQLITE_ERROR_RETRY: int = 513,
     SQLITE_ERROR_SNAPSHOT: int = 769,
     SQLITE_FORMAT: int = 24,
     SQLITE_FULL: int = 13,
     SQLITE_FUNCTION: int = 31;
glob SQLITE_IGNORE: int = 2,
     SQLITE_INSERT: int = 18,
     SQLITE_INTERNAL: int = 2,
     SQLITE_INTERRUPT: int = 9,
     SQLITE_IOERR: int = 10;
glob SQLITE_IOERR_ACCESS: int = 3338,
     SQLITE_IOERR_AUTH: int = 7178,
     SQLITE_IOERR_BEGIN_ATOMIC: int = 7434,
     SQLITE_IOERR_BLOCKED: int = 2826,
     SQLITE_IOERR_CHECKRESERVEDLOCK: int = 3594;
glob SQLITE_IOERR_CLOSE: int = 4106,
     SQLITE_IOERR_COMMIT_ATOMIC: int = 7690,
     SQLITE_IOERR_CONVPATH: int = 6666,
     SQLITE_IOERR_CORRUPTFS: int = 8458,
     SQLITE_IOERR_DATA: int = 8202;
glob SQLITE_IOERR_DELETE: int = 2570,
     SQLITE_IOERR_DELETE_NOENT: int = 5898,
     SQLITE_IOERR_DIR_CLOSE: int = 4362,
     SQLITE_IOERR_DIR_FSYNC: int = 1290,
     SQLITE_IOERR_FSTAT: int = 1802;
glob SQLITE_IOERR_FSYNC: int = 1034,
     SQLITE_IOERR_GETTEMPPATH: int = 6410,
     SQLITE_IOERR_LOCK: int = 3850,
     SQLITE_IOERR_MMAP: int = 6154,
     SQLITE_IOERR_NOMEM: int = 3082;
glob SQLITE_IOERR_RDLOCK: int = 2314,
     SQLITE_IOERR_READ: int = 266,
     SQLITE_IOERR_ROLLBACK_ATOMIC: int = 7946,
     SQLITE_IOERR_SEEK: int = 5642,
     SQLITE_IOERR_SHMLOCK: int = 5130;
glob SQLITE_IOERR_SHMMAP: int = 5386,
     SQLITE_IOERR_SHMOPEN: int = 4618,
     SQLITE_IOERR_SHMSIZE: int = 4874,
     SQLITE_IOERR_SHORT_READ: int = 522,
     SQLITE_IOERR_TRUNCATE: int = 1546;
glob SQLITE_IOERR_UNLOCK: int = 2058,
     SQLITE_IOERR_VNODE: int = 6922,
     SQLITE_IOERR_WRITE: int = 778,
     SQLITE_LIMIT_ATTACHED: int = 7,
     SQLITE_LIMIT_COLUMN: int = 2;
glob SQLITE_LIMIT_COMPOUND_SELECT: int = 4,
     SQLITE_LIMIT_EXPR_DEPTH: int = 3,
     SQLITE_LIMIT_FUNCTION_ARG: int = 6,
     SQLITE_LIMIT_LENGTH: int = 0,
     SQLITE_LIMIT_LIKE_PATTERN_LENGTH: int = 8;
glob SQLITE_LIMIT_SQL_LENGTH: int = 1,
     SQLITE_LIMIT_TRIGGER_DEPTH: int = 10,
     SQLITE_LIMIT_VARIABLE_NUMBER: int = 9,
     SQLITE_LIMIT_VDBE_OP: int = 5,
     SQLITE_LIMIT_WORKER_THREADS: int = 11;
glob SQLITE_LOCKED: int = 6,
     SQLITE_LOCKED_SHAREDCACHE: int = 262,
     SQLITE_LOCKED_VTAB: int = 518,
     SQLITE_MISMATCH: int = 20,
     SQLITE_MISUSE: int = 21;
glob SQLITE_NOLFS: int = 22,
     SQLITE_NOMEM: int = 7,
     SQLITE_NOTADB: int = 26,
     SQLITE_NOTFOUND: int = 12,
     SQLITE_NOTICE: int = 27;
glob SQLITE_NOTICE_RECOVER_ROLLBACK: int = 539,
     SQLITE_NOTICE_RECOVER_WAL: int = 283,
     SQLITE_OK: int = 0,
     SQLITE_OK_LOAD_PERMANENTLY: int = 256,
     SQLITE_OK_SYMLINK: int = 512;
glob SQLITE_PERM: int = 3,
     SQLITE_PRAGMA: int = 19,
     SQLITE_PROTOCOL: int = 15,
     SQLITE_RANGE: int = 25,
     SQLITE_READ: int = 20;
glob SQLITE_READONLY: int = 8,
     SQLITE_READONLY_CANTINIT: int = 1288,
     SQLITE_READONLY_CANTLOCK: int = 520,
     SQLITE_READONLY_DBMOVED: int = 1032,
     SQLITE_READONLY_DIRECTORY: int = 1544;
glob SQLITE_READONLY_RECOVERY: int = 264,
     SQLITE_READONLY_ROLLBACK: int = 776,
     SQLITE_RECURSIVE: int = 33,
     SQLITE_REINDEX: int = 27,
     SQLITE_ROW: int = 100;
glob SQLITE_SAVEPOINT: int = 32,
     SQLITE_SCHEMA: int = 17,
     SQLITE_SELECT: int = 21,
     SQLITE_TOOBIG: int = 18,
     SQLITE_TRANSACTION: int = 22;
glob SQLITE_UPDATE: int = 23,
     SQLITE_WARNING: int = 28,
     SQLITE_WARNING_AUTOINDEX: int = 284;

glob SQLITE_INTEGER: int = 1,
     SQLITE_FLOAT: int = 2,
     SQLITE_TEXT: int = 3,
     SQLITE_BLOB: int = 4,
     SQLITE_NULL: int = 5;


obj:pub Warning(Exception) {
    has message: str = "";

    def __str__ -> str;
}

obj:pub Error(Exception) {
    has message: str = "";

    def __str__ -> str;
}

obj:pub InterfaceError(Error) {}

obj:pub DatabaseError(Error) {}

obj:pub InternalError(DatabaseError) {}

obj:pub OperationalError(DatabaseError) {}

obj:pub ProgrammingError(DatabaseError) {}

obj:pub IntegrityError(DatabaseError) {}

obj:pub DataError(DatabaseError) {}

obj:pub NotSupportedError(DatabaseError) {}


def _ver_info -> tuple[(int, int, int)];

glob sqlite_version_info: tuple[(int, int, int)] = _ver_info();


def _type_name(v: any) -> str;


def _raise_db_error(db: int, rc: int);


def _raise_msg(rc: int, msg: str);


def _is_dml(sql: str) -> bool;


def _desc_of(stmt: int, ncols: int) -> list[any];


def _cache_entry(stmt: int, sql: str) -> list[any];


obj:pub Connection {
    has _db: int = 0,
        _open: bool = False,
        isolation_level: (str | None) = "",
        autocommit: any = -1,
        in_transaction: bool = False,
        total_changes: int = 0,
        _cursors: list[Cursor] = [],
        _pool: dict[str, list[any]] = {},
        _pool_n: int = 0,
        _cache_max: int = 128;

    def cursor -> Cursor;
    def execute(
        sql: any,
        parameters: (list[any] | dict[str, any] | tuple[any, ...] | None) = None
    ) -> Cursor;

    def executemany(sql: any, seq_of_parameters: list[any]) -> Cursor;
    def executescript(sql_script: str) -> Cursor;
    def _sync_state;
    def _check_isolation_level;
    def _maybe_begin(dml: int);
    def commit;
    def rollback;
    def close;
    def __enter__ -> Connection;
    def __exit__(exc_type: any, exc: any, tb: any) -> bool;
}


obj:pub Cursor {
    has connection: Connection = Connection(),
        _stmt: int = 0,
        _closed: bool = False,
        _done: bool = False,
        arraysize: int = 1,
        rowcount: int = -1,
        lastrowid: (int | None) = None,
        description: (list[any] | None) = None,
        _many_total: int = 0,
        _sql: str = "",
        _ncols: int = 0,
        _ent: any = None;

    def _check_open;
    def _mark_closed;
    def _finish_stmt;
    def _bind_value(i: int, v: any);
    def _bind_params(
        parameters: (list[any] | dict[str, any] | tuple[any, ...] | None),
        n: int,
        named: int
    );

    def _check_tail(stmt: int, sqlp: int);
    def execute(
        sql: any,
        parameters: (list[any] | dict[str, any] | tuple[any, ...] | None) = None
    ) -> Cursor;

    def executemany(sql: any, seq_of_parameters: list[any]) -> Cursor;
    def executescript(sql_script: str) -> Cursor;
    def _exec_script_impl(sql_script: str) -> Cursor;
    def fetchone -> (list[any] | None);
    def fetchmany(size: any = None) -> list[any];
    def fetchall -> list[any];
    def __iter__ -> Cursor;
    def __next__ -> list[any];
    def close;
    def setinputsizes(sizes: any);
    def setoutputsize(size: int, column: any = None);
}


def:pub connect(
    database: any,
    timeout: float = 5.0,
    detect_types: int = 0,
    isolation_level: (str | None) = "",
    check_same_thread: bool = True,
    factory: any = None,
    cached_statements: int = 128,
    uri: bool = False,
    autocommit: any = -1
) -> Connection;


def:pub complete_statement(statement: any) -> bool;


def:pub Binary(`obj: any) -> bytes;
