impl _ver_info -> tuple[(int, int, int)] {
    s = sq3_libversion();
    nums: list[int] = [];
    cur = 0;
    got = False;
    for i in range(len(s)) {
        c = s[i:i + 1];
        if c == "." {
            nums.append(cur);
            cur = 0;
        } else {
            cur = cur * 10 + int(c);
            got = True;
        }
    }
    if got {
        nums.append(cur);
    }
    a = 0;
    b = 0;
    c2 = 0;
    if len(nums) > 0 {
        a = nums[0];
    }
    if len(nums) > 1 {
        b = nums[1];
    }
    if len(nums) > 2 {
        c2 = nums[2];
    }
    return (a, b, c2);
}

impl _type_name(v: any) -> str {
    if isinstance(v, bool) {
        return "bool";
    }
    if isinstance(v, int) {
        return "int";
    }
    if isinstance(v, float) {
        return "float";
    }
    if isinstance(v, str) {
        return "str";
    }
    if isinstance(v, bytes) {
        return "bytes";
    }
    if isinstance(v, bytearray) {
        return "bytearray";
    }
    if isinstance(v, list) {
        return "list";
    }
    if isinstance(v, tuple) {
        return "tuple";
    }
    if isinstance(v, dict) {
        return "dict";
    }
    if isinstance(v, set) {
        return "set";
    }
    if v is None {
        return "NoneType";
    }
    return "object";
}

impl _raise_db_error(db: int, rc: int) {
    msg = sq3_errmsg(db);
    base = rc % 256;
    if base == 19 {
        raise IntegrityError(msg);
    }
    if base == 2 {
        raise InternalError(msg);
    }
    if base == 7 {
        raise MemoryError(msg);
    }
    if base == 25 {
        raise ProgrammingError(msg);
    }
    if base == 20 {
        raise InterfaceError(msg);
    }
    raise OperationalError(msg);
}

impl _raise_msg(rc: int, msg: str) {
    base = rc % 256;
    if base == 19 {
        raise IntegrityError(msg);
    }
    if base == 2 {
        raise InternalError(msg);
    }
    if base == 7 {
        raise MemoryError(msg);
    }
    if base == 25 {
        raise ProgrammingError(msg);
    }
    if base == 20 {
        raise InterfaceError(msg);
    }
    raise OperationalError(msg);
}

impl _is_dml(sql: str) -> bool {
    i = 0;
    n = len(sql);
    while i < n {
        c = sql[i:i + 1];
        if c == " "
            or c == "\t"
            or c == "\n"
            or c == "\r"
            or c == "\x0b"
            or c == "\x0c" {
            i += 1;
            continue;
        }
        if c == "-" and i + 1 < n and sql[i + 1:i + 2] == "-" {
            while i < n and sql[i:i + 1] != "\n" {
                i += 1;
            }
            continue;
        }
        if c == "/" and i + 1 < n and sql[i + 1:i + 2] == "*" {
            i += 2;
            while i + 1 < n and not (sql[i:i + 1] == "*" and sql[i + 1:i + 2] == "/") {
                i += 1;
            }
            i += 2;
            if i > n {
                i = n;
            }
            continue;
        }
        break;
    }
    w = "";
    while i < n {
        c = sql[i:i + 1];
        if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") {
            w += c;
            i += 1;
        } else {
            break;
        }
    }
    lw = w.lower();
    return lw == "insert" or lw == "update" or lw == "delete" or lw == "replace";
}

impl _desc_of(stmt: int, ncols: int) -> list[any] {
    desc: list[any] = [];
    for i in range(ncols) {
        d: list[any] = [];
        d.append(sq3_column_name(stmt, i));
        d.append(None);
        d.append(None);
        d.append(None);
        d.append(None);
        d.append(None);
        d.append(None);
        desc.append(d);
    }
    return desc;
}

impl _cache_entry(stmt: int, sql: str) -> list[any] {
    ncols = sq3_column_count(stmt);
    desc: any = None;
    if ncols > 0 {
        desc = _desc_of(stmt, ncols);
    }
    np = sq3_bind_parameter_count(stmt);
    named = 0;
    for i in range(1, np + 1) {
        pn = sq3_bind_parameter_name(stmt, i);
        if len(pn) > 0 and pn[0:1] != "?" {
            named = 1;
            break;
        }
    }
    dml = 0;
    if _is_dml(sql) {
        dml = 1;
    }
    stmts: list[any] = [];
    return [stmts, ncols, desc, dml, np, named];
}

impl Connection.cursor -> Cursor {
    if not self._open {
        raise ProgrammingError("Cannot operate on a closed database.");
    }
    cur = Cursor();
    cur.connection = self;
    self._cursors.append(cur);
    return cur;
}

impl Connection.execute(
    sql: any, parameters: (list[any] | dict[str, any] | tuple[any, ...] | None) = None
) -> Cursor {
    cur = self.cursor();
    return cur.execute(sql, parameters);
}

impl Connection.executemany(sql: any, seq_of_parameters: list[any]) -> Cursor {
    cur = self.cursor();
    return cur.executemany(sql, seq_of_parameters);
}

impl Connection.executescript(sql_script: str) -> Cursor {
    return self.cursor().executescript(sql_script);
}

impl Connection._sync_state {
    if self._open and self._db != 0 {
        self.in_transaction = sq3_get_autocommit(self._db) == 0;
        self.total_changes = sq3_total_changes(self._db);
    }
}

impl Connection._check_isolation_level {
    ilvl = self.isolation_level;
    if not isinstance(ilvl, str) {
        if ilvl is not None {
            raise TypeError("isolation_level must be str or None");
        }
        return;
    }
    u = ilvl.upper();
    if u != "" and u != "DEFERRED" and u != "IMMEDIATE" and u != "EXCLUSIVE" {
        raise ValueError(
            "isolation_level string must be '', 'DEFERRED', 'IMMEDIATE', or 'EXCLUSIVE'"
        );
    }
}

impl Connection._maybe_begin(dml: int) {
    if self.autocommit == True {
        return;
    }
    if sq3_get_autocommit(self._db) == 0 {
        return;
    }
    if self.autocommit == False {
        rc = sq3_exec(self._db, "BEGIN");
        if rc != 0 {
            _raise_db_error(self._db, rc);
        }
        self.in_transaction = True;
        return;
    }

    self._check_isolation_level();
    if dml == 0 {
        return;
    }
    if not isinstance(self.isolation_level, str) {
        return;
    }
    kw = self.isolation_level;
    cmd = "BEGIN";
    if kw != "" {
        cmd = "BEGIN " + kw;
    }
    rc = sq3_exec(self._db, cmd);
    if rc != 0 {
        _raise_db_error(self._db, rc);
    }
    self.in_transaction = True;
}

impl Connection.commit {
    if not self._open {
        raise ProgrammingError("Cannot operate on a closed database.");
    }
    if sq3_get_autocommit(self._db) == 0 {
        rc = sq3_exec(self._db, "COMMIT");
        if rc != 0 {
            _raise_db_error(self._db, rc);
        }
        self._sync_state();
    }
}

impl Connection.rollback {
    if not self._open {
        raise ProgrammingError("Cannot operate on a closed database.");
    }
    if sq3_get_autocommit(self._db) == 0 {
        rc = sq3_exec(self._db, "ROLLBACK");
        if rc != 0 {
            _raise_db_error(self._db, rc);
        }
        self._sync_state();
    }
}

impl Connection.close {
    if self._open {
        self._open = False;
        for cur in self._cursors {
            cur._mark_closed();
        }
        for sql in self._pool {
            ent: list[any] = self._pool[sql];
            stmts: list[any] = ent[0];
            for h in stmts {
                sq3_finalize(h);
            }
        }
        self._pool = {};
        self._pool_n = 0;
        sq3_close(self._db);
        self._db = 0;
        self.in_transaction = False;
    }
}

impl Connection.__enter__ -> Connection {
    return self;
}

impl Connection.__exit__(exc_type: any, exc: any, tb: any) -> bool {
    if exc is None {
        self.commit();
    } else {
        self.rollback();
    }
    return False;
}

impl Cursor._check_open {
    if not self.connection._open {
        raise ProgrammingError("Cannot operate on a closed database.");
    }
    if self._closed {
        raise ProgrammingError("Cannot operate on a closed cursor.");
    }
}

impl Cursor._mark_closed {
    self._closed = True;
    self._finish_stmt();
}

impl Cursor._finish_stmt {
    if self._stmt != 0 {
        conn = self.connection;
        if conn._open
            and self._sql != ""
            and conn._pool_n < conn._cache_max
            and self._sql in conn._pool {
            meta: list[any] = conn._pool[self._sql];
            sq3_reset(self._stmt);
            sq3_clear_bindings(self._stmt);
            stmts: list[any] = meta[0];
            stmts.append(self._stmt);
            conn._pool_n += 1;
        } else {
            sq3_finalize(self._stmt);
        }
        self._stmt = 0;
    }
    self._sql = "";
    self._done = False;
}

impl Cursor._bind_value(i: int, v: any) {
    if v is None {
        sq3_bind_null(self._stmt, i);
    } elif isinstance(v, bool) {
        sq3_bind_int(self._stmt, i, 1 if v else 0);
    } elif isinstance(v, int) {
        sq3_bind_int(self._stmt, i, v);
    } elif isinstance(v, float) {
        sq3_bind_double(self._stmt, i, v);
    } elif isinstance(v, str) {
        sq3_bind_text(self._stmt, i, v);
    } elif isinstance(v, bytes) {
        sq3_bind_blob(self._stmt, i, v);
    } elif isinstance(v, bytearray) {
        sq3_bind_blob(self._stmt, i, bytes(v));
    } else {
        raise ProgrammingError(
            "Error binding parameter "
                + str(i)
                + ": type '"
                + _type_name(v)
                + "' is not supported"
        );
    }
}

impl Cursor._bind_params(
    parameters: (list[any] | dict[str, any] | tuple[any, ...] | None),
    n: int,
    named: int
) {
    if parameters is None {
        if n != 0 {
            raise ProgrammingError(
                "Incorrect number of bindings supplied. The current statement uses "
                    + str(n)
                    + ", and there are 0 supplied."
            );
        }
        return;
    }
    if isinstance(parameters, dict) {
        d: dict[str, any] = parameters;
        for i in range(1, n + 1) {
            pname = sq3_bind_parameter_name(self._stmt, i);
            if len(pname) == 0 {
                raise ProgrammingError(
                    "Binding "
                        + str(i)
                        + " has no name, but you supplied a dictionary (which has only names)."
                );
            }
            key = pname[1:];
            found = True;
            v: any = None;
            try {
                v = d[key];
            } except KeyError as e {
                found = False;
            }
            if not found {
                raise ProgrammingError(
                    "You did not supply a value for binding parameter " + pname + "."
                );
            }
            self._bind_value(i, v);
        }
        return;
    }
    params: list[any] = [];
    if isinstance(parameters, tuple) or isinstance(parameters, list) {
        for el in parameters {
            params.append(el);
        }
    }
    m = len(params);
    if m != n {
        raise ProgrammingError(
            "Incorrect number of bindings supplied. The current statement uses "
                + str(n)
                + ", and there are "
                + str(m)
                + " supplied."
        );
    }
    if named == 0 {
        brc = sq3_bind_seq(self._stmt, params, m);
        if brc != 0 {
            raise ProgrammingError(
                "Error binding parameter "
                    + str(-brc)
                    + ": type '"
                    + _type_name(params[-brc - 1])
                    + "' is not supported"
            );
        }
        return;
    }
    for i in range(1, n + 1) {
        pname = sq3_bind_parameter_name(self._stmt, i);
        if len(pname) > 0 and pname[0:1] != "?" {
            raise ProgrammingError(
                "Binding "
                    + str(i)
                    + " ('"
                    + pname
                    + "') is a named parameter, but you supplied a sequence which requires nameless (qmark) placeholders."
            );
        }
        self._bind_value(i, params[i - 1]);
    }
}

impl Cursor._check_tail(stmt: int, sqlp: int) {
    nonws = sq3_tail_nonws();
    sq3_free(sqlp);
    if nonws == 1 {
        sq3_finalize(stmt);
        raise ProgrammingError("You can only execute one statement at a time.");
    }
}

impl Cursor.execute(
    sql: any, parameters: (list[any] | dict[str, any] | tuple[any, ...] | None) = None
) -> Cursor {
    conn = self.connection;
    if not conn._open {
        raise ProgrammingError("Cannot operate on a closed database.");
    }
    if self._closed {
        raise ProgrammingError("Cannot operate on a closed cursor.");
    }
    if not isinstance(sql, str) {
        raise TypeError("execute() argument 1 must be str, not " + _type_name(sql));
    }
    self.description = None;
    self.rowcount = -1;
    stmt = 0;
    meta: list[any] = [];
    if self._stmt != 0 and self._sql == sql {
        stmt = self._stmt;
        meta = self._ent;
        sq3_reset(stmt);
        self._done = False;
    } else {
        if self._stmt != 0 {
            self._finish_stmt();
        }
        self._sql = "";
        self._done = False;
        if sql in conn._pool {
            meta = conn._pool[sql];
            stmts: list[any] = meta[0];
            if len(stmts) > 0 {
                stmt = stmts.pop();
                conn._pool_n -= 1;
                sq3_reset(stmt);
            }
        }
        if stmt == 0 {
            rc = sq3_prepare(conn._db, sql);
            if rc != 0 {
                _raise_db_error(conn._db, -rc);
            }
            stmt = sq3_prep_stmt();
            sqlp = sq3_prep_sqlp();
            if stmt == 0 {
                sq3_free(sqlp);
                return self;
            }
            self._check_tail(stmt, sqlp);
            if len(meta) == 0 {
                meta = _cache_entry(stmt, sql);
                conn._pool[sql] = meta;
            }
        }
        self._stmt = stmt;
        self._sql = sql;
        self._ent = meta;
    }
    ncols = sq3_column_count(stmt);
    self._ncols = ncols;
    if ncols != meta[1] {
        meta[1] = ncols;
        meta[2] = _desc_of(stmt, ncols);
    }
    if ncols > 0 {
        self.description = meta[2];
    }
    if parameters is None {
        if meta[4] != 0 {
            raise ProgrammingError(
                "Incorrect number of bindings supplied. The current statement uses "
                    + str(meta[4])
                    + ", and there are 0 supplied."
            );
        }
    } elif isinstance(parameters, list) and meta[5] == 0 {
        plist: list[any] = [];
        for e in parameters {
            plist.append(e);
        }
        m = len(plist);
        if m != meta[4] {
            raise ProgrammingError(
                "Incorrect number of bindings supplied. The current statement uses "
                    + str(meta[4])
                    + ", and there are "
                    + str(m)
                    + " supplied."
            );
        }
        brc = sq3_bind_seq(stmt, plist, m);
        if brc != 0 {
            raise ProgrammingError(
                "Error binding parameter "
                    + str(-brc)
                    + ": type '"
                    + _type_name(plist[-brc - 1])
                    + "' is not supported"
            );
        }
    } else {
        self._bind_params(parameters, meta[4], meta[5]);
    }
    conn._maybe_begin(meta[3]);
    if ncols == 0 {
        rc3 = sq3_step(stmt);
        self._finish_stmt();
        if rc3 != 100 and rc3 != 101 {
            _raise_db_error(conn._db, rc3);
        }
        if meta[3] == 1 {
            self.rowcount = sq3_changes(conn._db);
        }
        self.lastrowid = sq3_last_insert_rowid(conn._db);
        conn._sync_state();
        self._done = True;
    }
    return self;
}

impl Cursor.executemany(sql: any, seq_of_parameters: list[any]) -> Cursor {
    self._check_open();
    if not isinstance(sql, str) {
        raise TypeError("executemany() argument 1 must be str, not " + _type_name(sql));
    }
    if self._stmt != 0 {
        self._finish_stmt();
    } else {
        self._sql = "";
        self._done = False;
    }
    self.description = None;
    self.rowcount = -1;
    conn = self.connection;
    stmt = 0;
    meta: list[any] = [];
    if sql in conn._pool {
        meta = conn._pool[sql];
        stmts: list[any] = meta[0];
        if len(stmts) > 0 {
            stmt = stmts.pop();
            conn._pool_n -= 1;
        }
    }
    if stmt == 0 {
        rc = sq3_prepare(conn._db, sql);
        if rc != 0 {
            _raise_db_error(conn._db, -rc);
        }
        stmt = sq3_prep_stmt();
        sqlp = sq3_prep_sqlp();
        if stmt == 0 {
            sq3_free(sqlp);
            return self;
        }
        self._check_tail(stmt, sqlp);
    }
    if sq3_column_count(stmt) > 0 {
        sq3_finalize(stmt);
        raise ProgrammingError("executemany() can only execute DML statements.");
    }
    if len(meta) == 0 {
        meta = _cache_entry(stmt, sql);
        conn._pool[sql] = meta;
    }
    sq3_reset(stmt);
    sq3_clear_bindings(stmt);
    self._stmt = stmt;
    self._sql = sql;
    self._ent = meta;
    self._ncols = 0;
    conn._maybe_begin(meta[3]);
    self._many_total = 0;
    np = meta[4];
    named = meta[5];
    for parameters in seq_of_parameters {
        if isinstance(parameters, list) and named == 0 {
            plist: list[any] = [];
            for e in parameters {
                plist.append(e);
            }
            m = len(plist);
            if m != np {
                raise ProgrammingError(
                    "Incorrect number of bindings supplied. The current statement uses "
                        + str(np)
                        + ", and there are "
                        + str(m)
                        + " supplied."
                );
            }
            brc = sq3_bind_seq(stmt, plist, m);
            if brc != 0 {
                raise ProgrammingError(
                    "Error binding parameter "
                        + str(-brc)
                        + ": type '"
                        + _type_name(plist[-brc - 1])
                        + "' is not supported"
                );
            }
        } else {
            self._bind_params(parameters, np, named);
        }
        rc3 = sq3_step(stmt);
        if rc3 != 100 and rc3 != 101 {
            sq3_finalize(stmt);
            self._stmt = 0;
            _raise_db_error(conn._db, rc3);
        }
        self._many_total += sq3_changes(conn._db);
        sq3_reset(stmt);
    }
    total = self._many_total;
    self._finish_stmt();
    self.rowcount = total;
    conn._sync_state();
    return self;
}

impl Cursor.executescript(sql_script: str) -> Cursor {
    return self._exec_script_impl(sql_script);
}

impl Cursor._exec_script_impl(sql_script: str) -> Cursor {
    self._check_open();
    self._finish_stmt();
    self.description = None;
    self.rowcount = -1;
    conn = self.connection;
    if conn.in_transaction {
        conn.commit();
    }
    rc = sq3_exec(conn._db, sql_script);
    if rc != 0 {
        msg = sq3_exec_err();
        if len(msg) > 0 {
            _raise_msg(rc, msg);
        }
        _raise_db_error(conn._db, rc);
    }
    conn._sync_state();
    return self;
}

impl Cursor.fetchone -> (list[any] | None) {
    if not self.connection._open {
        raise ProgrammingError("Cannot operate on a closed database.");
    }
    if self._closed {
        raise ProgrammingError("Cannot operate on a closed cursor.");
    }
    stmt = self._stmt;
    if stmt == 0 or self._done {
        return None;
    }
    rc = sq3_step(stmt);
    if rc == 100 {
        return sq3_row(stmt, self._ncols);
    }
    conn = self.connection;
    if rc != 101 {
        self._finish_stmt();
        _raise_db_error(conn._db, rc);
    }
    self._finish_stmt();
    self._done = True;
    conn._sync_state();
    return None;
}

impl Cursor.fetchmany(size: any = None) -> list[any] {
    self._check_open();
    n = self.arraysize;
    if isinstance(size, int) {
        if size < 0 {
            raise ValueError("Cannot convert negative int");
        }
        n = size;
    } elif size is not None {
        raise TypeError(
            "'" + _type_name(size) + "' object cannot be interpreted as an integer"
        );
    }
    out: list[any] = [];
    for _ in range(n) {
        r = self.fetchone();
        if r is None {
            break;
        }
        out.append(r);
    }
    return out;
}

impl Cursor.fetchall -> list[any] {
    if not self.connection._open {
        raise ProgrammingError("Cannot operate on a closed database.");
    }
    if self._closed {
        raise ProgrammingError("Cannot operate on a closed cursor.");
    }
    out: list[any] = [];
    stmt = self._stmt;
    if stmt == 0 or self._done {
        return out;
    }
    ncols = self._ncols;
    while True {
        rc = sq3_step(stmt);
        if rc == 100 {
            out.append(sq3_row(stmt, ncols));
            continue;
        }
        conn = self.connection;
        if rc != 101 {
            self._finish_stmt();
            _raise_db_error(conn._db, rc);
        }
        self._finish_stmt();
        self._done = True;
        conn._sync_state();
        return out;
    }
    return out;
}

impl Cursor.__iter__ -> Cursor {
    return self;
}

impl Cursor.__next__ -> list[any] {
    if not self.connection._open {
        raise ProgrammingError("Cannot operate on a closed database.");
    }
    if self._closed {
        raise ProgrammingError("Cannot operate on a closed cursor.");
    }
    stmt = self._stmt;
    if stmt == 0 or self._done {
        raise StopIteration();
    }
    rc = sq3_step(stmt);
    if rc == 100 {
        return sq3_row(stmt, self._ncols);
    }
    conn = self.connection;
    if rc != 101 {
        self._finish_stmt();
        _raise_db_error(conn._db, rc);
    }
    self._finish_stmt();
    self._done = True;
    conn._sync_state();
    raise StopIteration();
}

impl Cursor.close {
    if not self.connection._open {
        raise ProgrammingError("Cannot operate on a closed database.");
    }
    if self._closed {
        return;
    }
    self._closed = True;
    self._finish_stmt();
}

impl Cursor.setinputsizes(sizes: any) {}

impl Cursor.setoutputsize(size: int, column: any = None) {}

impl connect(
    database: any,
    timeout: float = 5.0,
    detect_types: int = 0,
    isolation_level: (str | None) = "",
    check_same_thread: bool = True,
    factory: any = None,
    cached_statements: int = 128,
    uri: bool = False,
    autocommit: any = -1
) -> Connection {
    if isinstance(database, bytes) {
        database = database.decode();
    }
    if not isinstance(database, str) {
        raise TypeError(
            "expected str, bytes or os.PathLike object, not " + _type_name(database)
        );
    }
    if not isinstance(timeout, int)
        and not isinstance(timeout, float)
        and not isinstance(timeout, bool) {
        raise TypeError("must be real number, not " + _type_name(timeout));
    }
    if isolation_level is not None {
        if not isinstance(isolation_level, str) {
            raise TypeError("isolation_level must be str or None");
        }
        il = isolation_level.upper();
        if il != "" and il != "DEFERRED" and il != "IMMEDIATE" and il != "EXCLUSIVE" {
            raise ValueError(
                "isolation_level string must be '', 'DEFERRED', 'IMMEDIATE', or 'EXCLUSIVE'"
            );
        }
    }
    if not isinstance(autocommit, bool)
        and not (
            isinstance(autocommit, int) and autocommit == LEGACY_TRANSACTION_CONTROL
        ) {
        raise ValueError(
            "autocommit must be True, False, or sqlite3.LEGACY_TRANSACTION_CONTROL"
        );
    }
    h = sq3_open_v2(database, uri);
    if h <= 0 {
        msg = sq3_open_err();
        if len(msg) == 0 {
            msg = "unable to open database file";
        }
        raise OperationalError(msg);
    }
    conn = Connection(_db=h, _open=True);
    conn.isolation_level = isolation_level;
    conn._cache_max = cached_statements;
    if isinstance(autocommit, bool) {
        conn.autocommit = autocommit;
        if autocommit {
            conn.isolation_level = None;
        }
    }
    sq3_busy_timeout(h, int(timeout * 1000.0));
    return conn;
}

impl complete_statement(statement: any) -> bool {
    if not isinstance(statement, str) {
        raise TypeError(
            "complete_statement() argument 'statement' must be str, not "
                + _type_name(statement)
        );
    }
    return sq3_complete(statement) != 0;
}

impl Binary(`obj: any) -> bytes {
    if isinstance(`obj, bytes) {
        return `obj;
    }
    if isinstance(`obj, bytearray) {
        return bytes(`obj);
    }
    raise TypeError(
        "memoryview: a bytes-like object is required, not '" + _type_name(`obj) + "'"
    );
}

impl Warning.__str__ -> str {
    return self.message;
}

impl Error.__str__ -> str {
    return self.message;
}
