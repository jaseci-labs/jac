---
description: The native sqlite3 module, CPython's DB-API interface to SQLite over the SQLite library - connections, cursors, rows, functions and callbacks written in Jac, adapters and converters, transactions, blobs, backups and dumps - and where it differs.
keywords: sqlite3, sqlite3.connect, sqlite3.Connection, sqlite3.Cursor, sqlite3.Row, sqlite3.Blob, sqlite3.Error, sqlite3.DatabaseError, sqlite3.IntegrityError, sqlite3.OperationalError, sqlite3.ProgrammingError, sqlite3.register_adapter, sqlite3.register_converter, sqlite3.complete_statement, sqlite3.dbapi2, create_function, create_aggregate, row_factory, SQLite, database
---
# sqlite3

`sqlite3` is CPython's DB-API 2.0 interface to SQLite, the whole of it, with CPython's behavior
and messages. It is native, and calls the SQLite library (see [The library](index.md),
`jac docs library`). Rows are tuples, or what the row factory makes of them.

```jac
import sqlite3;

def score_band(score: float) -> str {
    return "high" if score >= 8 else "low";
}

with entry {
    db = sqlite3.connect(":memory:");
    db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, score REAL)");
    db.executemany("INSERT INTO users (name, score) VALUES (?, ?)", [("Ada", 9.5), ("Bo", 7.0)]);
    db.commit();
    cur = db.execute("SELECT id, name, score FROM users WHERE score > ? ORDER BY id", (5,));
    print(cur.fetchall());
    print(db.execute("SELECT name FROM users WHERE id = :id", {"id": 2}).fetchone());
    try {
        db.execute("INSERT INTO users (id, name) VALUES (1, 'dup')");
    } except sqlite3.IntegrityError as e {
        print("IntegrityError:", e, e.sqlite_errorname);
    }
    with db {
        db.execute("INSERT INTO users (name) VALUES ('Cy')");
    }
    db.row_factory = sqlite3.Row;
    db.create_function("band", 1, score_band, deterministic=True);
    row: sqlite3.Row = db.execute(
        "SELECT name, band(score) AS band FROM users WHERE id = 1"
    ).fetchone();
    print(row["name"], row["BAND"], row.keys());
    db.close();
}
```

```output
[(1, 'Ada', 9.5), (2, 'Bo', 7.0)]
('Bo',)
IntegrityError: UNIQUE constraint failed: users.id SQLITE_CONSTRAINT_PRIMARYKEY
Ada high ['name', 'band']
```

## What is there

| Name | What it is |
|---|---|
| `connect(database, *, timeout, detect_types, isolation_level, check_same_thread, factory, cached_statements, uri, autocommit)` | A `Connection` to a file, a URI or `":memory:"`; `factory` a `Connection` subclass |
| `Connection` | `cursor`, `execute`, `executemany`, `executescript`, `commit`, `rollback`, `close`, `with`, `in_transaction`, `isolation_level`, `autocommit`, `total_changes`, `row_factory`, `text_factory`; `create_function`, `create_aggregate`, `create_window_function`, `create_collation`; `set_authorizer`, `set_progress_handler`, `set_trace_callback`; `backup`, `iterdump`, `serialize`, `deserialize`, `blobopen`, `interrupt`, `getlimit`, `setlimit`, `getconfig`, `setconfig`, `enable_load_extension`, `load_extension` |
| `Cursor` | `execute`, `executemany`, `executescript`, `fetchone`, `fetchmany`, `fetchall`, iteration, `description`, `rowcount`, `lastrowid`, `arraysize`, `row_factory`, `connection`, `close` |
| `Row` | A row by index, slice or column name (any case), with `keys`, equality and a hash |
| `Blob` | A BLOB read and written in place: `read`, `write`, `seek`, `tell`, indexing and slicing, `with` |
| `adapt`, `adapters`, `register_adapter`, `PrepareProtocol`, `__conform__` | Python values made SQLite's |
| `converters`, `register_converter`, `PARSE_DECLTYPES`, `PARSE_COLNAMES` | SQLite's values made Python's, by declared type or by column name |
| `Warning`, `Error` (`sqlite_errorcode`, `sqlite_errorname`), `InterfaceError`, `DatabaseError`, `DataError`, `OperationalError`, `IntegrityError`, `InternalError`, `ProgrammingError`, `NotSupportedError` | The DB-API exceptions, in CPython's hierarchy |
| `complete_statement`, `enable_callback_tracebacks`, `Date`, `Time`, `Timestamp` and `Binary` (`datetime.date`, `datetime.time`, `datetime.datetime` and `memoryview` under the DB-API's names), `DateFromTicks`, `TimeFromTicks`, `TimestampFromTicks`, `apilevel`, `paramstyle`, `threadsafety`, `sqlite_version`, `sqlite_version_info`, `SQLITE_KEYWORDS`, `LEGACY_TRANSACTION_CONTROL`, every `SQLITE_*` code | As CPython's |
| `sqlite3.dbapi2` | The same names, under the DB-API module's name |

Parameters are `?` placeholders bound from a sequence, or `:name` placeholders bound from a dict.
Values map as in CPython: `INTEGER` to `int`, `REAL` to `float`, `TEXT` to `str`, `BLOB` to
`bytes`, `NULL` to `None`; a `bool`, a `bytearray` and a `memoryview` are bound too, and anything
else through an adapter or its `__conform__`. Transactions are CPython's: while `autocommit` is
`LEGACY_TRANSACTION_CONTROL`, a statement that changes data opens one, as `isolation_level` says;
with `autocommit` False one is always open, and with True SQLite commits each statement.

A connection belongs to the thread that made it, as in CPython: used from another
([threading](threading.md)), it, its cursors and its blobs raise `ProgrammingError`
(`SQLite objects created in a thread can only be used in that same thread. ...`).
`connect(..., check_same_thread=False)` makes one that any thread may use, and `interrupt()`
may be called from another thread either way.

A function, aggregate, collation, authorizer, progress handler or trace callback is any Jac
callable; an aggregate or window function is a class, whose objects SQLite gives each row's
values. An exception one raises is reported as CPython reports it: the statement fails with
`OperationalError` (`user-defined function raised exception`), or a collation's own exception is
raised.

## Differences from CPython

- **Every parameter of `connect` after `database` is keyword-only**, as CPython 3.15 has them
  (its stub still lists them positionally).
- **An `int` is 64 bits**, as SQLite's `INTEGER` is.
- **A connection nothing refers to any longer is closed**, at once, where CPython closes it when
  it collects it.

## What is not there yet

Each refused when a program names it, or noted:

- `Connection.Error` and its nine siblings (`except conn.Error`): they wait on `type[T]`.
- `text_factory = bytearray`, and `register_adapter(bytearray, ...)`: `bytearray` is not a value
  yet.

## Platforms

The program calls the SQLite library the system provides: `/usr/lib/libsqlite3.dylib` on macOS,
`libsqlite3.so.0` on Linux (install the distribution's SQLite package where it is missing), and
`winsqlite3.dll` on Windows. The SQLite version is the system's (`sqlite3.sqlite_version`), and
so are its keywords, its limits and whether it loads extensions. macOS's SQLite is built without
extension loading: there `enable_load_extension` and `load_extension` raise the `AttributeError`
CPython raises where its SQLite has none (`'sqlite3.Connection' object has no attribute
'enable_load_extension'`).
