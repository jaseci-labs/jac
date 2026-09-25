"""Bundled native `sqlite3` cross-backend equivalence fixture.

The SAME `import sqlite3` binds CPython's `sqlite3` on the sv (Python)
backend and the bundled `na_stdlib/sqlite3.jac` module -- a pure-Jac surface
over the system `libsqlite3` via the `_sqlite3_native` FFI floor -- on the na
(native LLVM) backend. Rows and description entries marshal as JacVal lists,
so everything is probed through scalar cell reads and `len(...)`. Covers:
module metadata and `complete_statement`, `:memory:` connect, fresh-cursor
defaults, DDL vs DML transaction semantics, commit/rollback, qmark / numeric
/ named / `@` / `$` parameters, `executemany`, `fetchone`/`fetchmany`/
`fetchall`, cursor iteration, `NULL`/`bool`/`int`/`float`/`str` binding,
blob round-trip through `hex()`, `executescript` (implicit commit plus
multi-statement execution), error-class parity, and close idempotence.
ES/JS opts out (no SQLite client runtime). The na lane is split across
small pinned helpers per the one-function-JITs-poorly convention; helpers
crossing lanes would hit E5093 on `any`/`dict` params, so each lane keeps
its own copies.
"""

import sqlite3;


def _cell(row: (list[any] | None), i: int) -> any {
    if row is None {
        return None;
    }
    return row[i];
}


def _rcell(rows: list[any], j: int, i: int) -> any {
    return rows[j][i];
}


def _cell_na(row: (list[any] | None), i: int) -> any {
    if row is None {
        return None;
    }
    return row[i];
}


def _rcell_na(rows: list[any], j: int, i: int) -> any {
    return rows[j][i];
}


def sqlite3_py -> dict[any, any] {
    out: dict[any, any] = {};
    out["apilevel"] = sqlite3.apilevel;
    out["paramstyle"] = sqlite3.paramstyle;
    out["threadsafety"] = sqlite3.threadsafety;
    out["sqlite_version"] = sqlite3.sqlite_version;
    out["complete_t"] = sqlite3.complete_statement("select 1;");
    out["complete_f"] = sqlite3.complete_statement("select 1");
    vi = sqlite3.sqlite_version_info;
    out["ver_major"] = vi[0];
    out["ver_minor"] = vi[1];
    out["ver_patch"] = vi[2];
    con = sqlite3.connect(":memory:");
    cur = con.cursor();
    conn_tn = type(con).__name__;
    cur_tn = type(cur).__name__;
    out["conn_tn"] = conn_tn;
    out["cur_tn"] = cur_tn;
    out["fresh_rc"] = cur.rowcount;
    out["fresh_arraysize"] = cur.arraysize;
    out["fresh_desc_none"] = cur.description is None;
    out["fresh_lrid_none"] = cur.lastrowid is None;
    out["in_trans0"] = con.in_transaction;
    cur.execute("create table t(a,b,c)");
    out["in_trans_ddl"] = con.in_transaction;
    out["rc_ddl"] = cur.rowcount;
    out["lrid_ddl"] = cur.lastrowid;
    cur.execute("insert into t values(?,?,?)", [1, "x", 2.5]);
    out["in_trans_ins"] = con.in_transaction;
    out["rc_ins"] = cur.rowcount;
    out["lrid_ins"] = cur.lastrowid;
    cur.execute("insert into t values(?,?,?)", [2, "y", 3.5]);
    con.rollback();
    out["in_trans_rb"] = con.in_transaction;
    out["after_rb"] = _cell(cur.execute("select count(*) from t").fetchone(), 0);
    cur.executemany(
        "insert into t values(?,?,?)", [[1, "x", 2.5], [2, "y", 3.5], [3, "z", None]]
    );
    out["many_rc"] = cur.rowcount;
    con.commit();
    out["in_trans_cm"] = con.in_transaction;
    out["total_changes"] = con.total_changes;
    sel = cur.execute("select * from t order by a");
    ds = sel.description;
    if ds is not None {
        out["desc_len"] = len(ds);
        out["desc_name0"] = ds[0][0];
        out["desc_name2"] = ds[2][0];
        out["desc_pad"] = ds[0][1];
        out["desc_col_len"] = len(ds[0]);
    }
    fst = sel.fetchone();
    if fst is not None {
        out["fst_len"] = len(fst);
        out["f0"] = fst[0];
    }
    one = sel.fetchall();
    out["n_after_one"] = len(one);
    out["c20"] = _rcell(one, 0, 0);
    out["c21"] = _rcell(one, 0, 1);
    out["c22"] = _rcell(one, 0, 2);
    rows = cur.execute("select * from t order by a").fetchall();
    out["rows_len"] = len(rows);
    out["r00"] = _rcell(rows, 0, 0);
    out["r01"] = _rcell(rows, 0, 1);
    out["r02"] = _rcell(rows, 0, 2);
    out["r10"] = _rcell(rows, 1, 0);
    out["r20"] = _rcell(rows, 2, 0);
    out["r22_null"] = _rcell(rows, 2, 2);
    out["past_end"] = cur.execute("select * from t where a>99").fetchone() is None;
    itn = 0;
    for row in cur.execute("select a from t order by a") {
        itn += 1;
    }
    out["iter_rows"] = itn;
    types = cur.execute("select ?,?,?,?,?", [None, True, 4, 1.25, "s"]).fetchone();
    out["ty0"] = _cell(types, 0);
    out["ty1"] = _cell(types, 1);
    out["ty2"] = _cell(types, 2);
    out["ty3"] = _cell(types, 3);
    out["ty4"] = _cell(types, 4);
    cur.execute("insert into t values(9,'t',x'0102ff')");
    out["blob_len"] = _cell(
        cur.execute("select length(c) from t where a=9").fetchone(), 0
    );
    out["blob_hex"] = _cell(
        cur.execute("select hex(c) from t where a=9").fetchone(), 0
    );
    p_named: dict[any, any] = {"a": 1, "b": 2};
    p_at: dict[any, any] = {"a": 7};
    p_dollar: dict[any, any] = {"a": 8};
    out["named0"] = _cell(cur.execute("select :a,:b", p_named).fetchone(), 0);
    out["named1"] = _cell(cur.execute("select :a,:b", p_named).fetchone(), 1);
    out["at_p"] = _cell(cur.execute("select @a", p_at).fetchone(), 0);
    out["dollar_p"] = _cell(cur.execute("select $a", p_dollar).fetchone(), 0);
    out["qnum1"] = _cell(cur.execute("select ?2,?1", [10, 20]).fetchone(), 0);
    out["qnum2"] = _cell(cur.execute("select ?2,?1", [10, 20]).fetchone(), 1);
    cur.execute("delete from t where a=999");
    out["del0_rc"] = cur.rowcount;
    try {
        cur.execute("select 1; select 2");
        out["tail_two"] = "none";
    } except sqlite3.ProgrammingError as e4 {
        out["tail_two"] = "ProgrammingError: " + str(e4);
    } except Exception as e4x {
        out["tail_two"] = "WRONG-TYPE: " + str(e4x);
    }
    try {
        cur.execute("select 1; selct 2");
        out["tail_synt"] = "none";
    } except sqlite3.ProgrammingError as e5 {
        out["tail_synt"] = "ProgrammingError: " + str(e5);
    } except Exception as e5x {
        out["tail_synt"] = "WRONG-TYPE: " + str(e5x);
    }
    out["tail_ws"] = _rcell(cur.execute("select 7;   ").fetchall(), 0, 0);
    try {
        cur.execute("select :a", [9]);
        out["seq_named"] = "none";
    } except sqlite3.ProgrammingError as e6 {
        out["seq_named"] = "ProgrammingError: " + str(e6);
    } except Exception as e6x {
        out["seq_named"] = "WRONG-TYPE: " + str(e6x);
    }
    try {
        sqlite3.connect(":memory:", isolation_level="BOGUS");
        out["iso_bad"] = "none";
    } except ValueError as e7 {
        out["iso_bad"] = "ValueError: " + str(e7);
    } except Exception as e7x {
        out["iso_bad"] = "WRONG-TYPE: " + str(e7x);
    }
    c_low = sqlite3.connect(":memory:", isolation_level="deferred");
    c_low.execute("create table lt(a)");
    c_low.execute("insert into lt values(1)");
    out["iso_low"] = c_low.in_transaction;
    c_low.close();
    try {
        sqlite3.complete_statement(1);
        out["complete_bad"] = "none";
    } except TypeError as e8 {
        out["complete_bad"] = "TypeError: " + str(e8);
    } except Exception as e8x {
        out["complete_bad"] = "WRONG-TYPE: " + str(e8x);
    }
    try {
        cur.execute("select 1").fetchmany("x");
        out["fm_str"] = "none";
    } except TypeError as e9 {
        out["fm_str"] = "TypeError: " + str(e9);
    } except Exception as e9x {
        out["fm_str"] = "WRONG-TYPE: " + str(e9x);
    }
    try {
        cur.execute("select ?", [{}]);
        out["bind_dict"] = "none";
    } except sqlite3.ProgrammingError as e10 {
        out["bind_dict"] = "ProgrammingError: " + str(e10);
    } except Exception as e10x {
        out["bind_dict"] = "WRONG-TYPE: " + str(e10x);
    }
    cur.execute("create table u(x unique)");
    cur.execute("insert into u values(1)");
    con.commit();
    try {
        cur.execute("insert into u values(1)");
        out["integrity"] = "none";
    } except sqlite3.IntegrityError as e11 {
        out["integrity"] = "IntegrityError: " + str(e11);
    } except Exception as e11x {
        out["integrity"] = "WRONG-TYPE: " + str(e11x);
    }
    out["ac_default"] = con.autocommit;
    c_ac = sqlite3.connect(":memory:", autocommit=False);
    c_ac.execute("select 1");
    out["ac_f_sel"] = c_ac.in_transaction;
    c_ac.close();
    c_at = sqlite3.connect(":memory:", autocommit=True);
    c_at.execute("create table z(a)");
    c_at.execute("insert into z values(1)");
    out["ac_t_ins"] = c_at.in_transaction;
    out["ac_t_attr"] = c_at.autocommit;
    c_at.close();
    cur2 = con.cursor();
    cur2.close();
    cur2.close();
    out["close_twice"] = "ok";
    con.executescript("create table e(x); insert into e values(5);");
    out["in_trans_es"] = con.in_transaction;
    out["es_val"] = _cell(con.execute("select x from e").fetchone(), 0);
    out["empty_rows"] = len(cur.execute("").fetchall());
    ws = cur.execute("   ").description;
    out["ws_desc_none"] = ws is None;
    try {
        cur.execute("select * from nosuch_tbl");
        out["err_tbl"] = "none";
    } except sqlite3.OperationalError as e1 {
        out["err_tbl"] = "OperationalError: " + str(e1);
    } except Exception as e1x {
        out["err_tbl"] = "WRONG-TYPE: " + str(e1x);
    }
    try {
        cur.execute("insert into t values(?,?,?)", [1, 2]);
        out["err_bind"] = "none";
    } except sqlite3.ProgrammingError as e2 {
        out["err_bind"] = "ProgrammingError: " + str(e2);
    } except Exception as e2x {
        out["err_bind"] = "WRONG-TYPE: " + str(e2x);
    }
    cur.close();
    con.close();
    con.close();
    out["double_close"] = 1;
    try {
        con.execute("select 1");
        out["closed_exec"] = "none";
    } except sqlite3.ProgrammingError as e3 {
        out["closed_exec"] = "ProgrammingError: " + str(e3);
    } except Exception as e3x {
        out["closed_exec"] = "WRONG-TYPE: " + str(e3x);
    }
    return out;
}


def sqlite3_cl -> dict[any, any] {
    return {};
}


def _meta_na(out: dict[str, any]) {
    out["apilevel"] = sqlite3.apilevel;
    out["paramstyle"] = sqlite3.paramstyle;
    out["threadsafety"] = sqlite3.threadsafety;
    out["sqlite_version"] = sqlite3.sqlite_version;
    out["complete_t"] = sqlite3.complete_statement("select 1;");
    out["complete_f"] = sqlite3.complete_statement("select 1");
    vi = sqlite3.sqlite_version_info;
    out["ver_major"] = vi[0];
    out["ver_minor"] = vi[1];
    out["ver_patch"] = vi[2];
    con = sqlite3.connect(":memory:");
    cur = con.cursor();
    conn_tn = type(con).__name__;
    cur_tn = type(cur).__name__;
    out["conn_tn"] = conn_tn;
    out["cur_tn"] = cur_tn;
    out["fresh_rc"] = cur.rowcount;
    out["fresh_arraysize"] = cur.arraysize;
    out["fresh_desc_none"] = cur.description is None;
    out["fresh_lrid_none"] = cur.lastrowid is None;
    out["in_trans0"] = con.in_transaction;
    con.close();
}


def _txn_na(out: dict[str, any]) {
    con = sqlite3.connect(":memory:");
    cur = con.cursor();
    cur.execute("create table t(a,b,c)");
    out["in_trans_ddl"] = con.in_transaction;
    out["rc_ddl"] = cur.rowcount;
    out["lrid_ddl"] = cur.lastrowid;
    cur.execute("insert into t values(?,?,?)", [1, "x", 2.5]);
    out["in_trans_ins"] = con.in_transaction;
    out["rc_ins"] = cur.rowcount;
    out["lrid_ins"] = cur.lastrowid;
    cur.execute("insert into t values(?,?,?)", [2, "y", 3.5]);
    con.rollback();
    out["in_trans_rb"] = con.in_transaction;
    out["after_rb"] = _cell_na(cur.execute("select count(*) from t").fetchone(), 0);
    cur.executemany(
        "insert into t values(?,?,?)", [[1, "x", 2.5], [2, "y", 3.5], [3, "z", None]]
    );
    out["many_rc"] = cur.rowcount;
    con.commit();
    out["in_trans_cm"] = con.in_transaction;
    out["total_changes"] = con.total_changes;
    con.close();
}


def _fetch_na(out: dict[str, any]) {
    con = sqlite3.connect(":memory:");
    cur = con.cursor();
    cur.execute("create table t(a,b,c)");
    cur.executemany(
        "insert into t values(?,?,?)", [[1, "x", 2.5], [2, "y", 3.5], [3, "z", None]]
    );
    con.commit();
    sel = cur.execute("select * from t order by a");
    ds = sel.description;
    if ds is not None {
        out["desc_len"] = len(ds);
        out["desc_name0"] = ds[0][0];
        out["desc_name2"] = ds[2][0];
        out["desc_pad"] = ds[0][1];
        out["desc_col_len"] = len(ds[0]);
    }
    fst = sel.fetchone();
    if fst is not None {
        out["fst_len"] = len(fst);
        out["f0"] = fst[0];
    }
    one = sel.fetchall();
    out["n_after_one"] = len(one);
    out["c20"] = _rcell_na(one, 0, 0);
    out["c21"] = _rcell_na(one, 0, 1);
    out["c22"] = _rcell_na(one, 0, 2);
    rows = cur.execute("select * from t order by a").fetchall();
    out["rows_len"] = len(rows);
    out["r00"] = _rcell_na(rows, 0, 0);
    out["r01"] = _rcell_na(rows, 0, 1);
    out["r02"] = _rcell_na(rows, 0, 2);
    out["r10"] = _rcell_na(rows, 1, 0);
    out["r20"] = _rcell_na(rows, 2, 0);
    out["r22_null"] = _rcell_na(rows, 2, 2);
    out["past_end"] = cur.execute("select * from t where a>99").fetchone() is None;
    itn = 0;
    for row in cur.execute("select a from t order by a") {
        itn += 1;
    }
    out["iter_rows"] = itn;
    con.close();
}


def _types_na(out: dict[str, any]) {
    con = sqlite3.connect(":memory:");
    cur = con.cursor();
    types = cur.execute("select ?,?,?,?,?", [None, True, 4, 1.25, "s"]).fetchone();
    out["ty0"] = _cell_na(types, 0);
    out["ty1"] = _cell_na(types, 1);
    out["ty2"] = _cell_na(types, 2);
    out["ty3"] = _cell_na(types, 3);
    out["ty4"] = _cell_na(types, 4);
    cur.execute("create table t(a,b)");
    cur.execute("insert into t values(9,x'0102ff')");
    out["blob_len"] = _cell_na(
        cur.execute("select length(b) from t where a=9").fetchone(), 0
    );
    out["blob_hex"] = _cell_na(
        cur.execute("select hex(b) from t where a=9").fetchone(), 0
    );
    con.close();
}


def _params_na(out: dict[str, any]) {
    con = sqlite3.connect(":memory:");
    cur = con.cursor();
    p_named: dict[str, any] = {"a": 1, "b": 2};
    p_at: dict[str, any] = {"a": 7};
    p_dollar: dict[str, any] = {"a": 8};
    out["named0"] = _cell_na(cur.execute("select :a,:b", p_named).fetchone(), 0);
    out["named1"] = _cell_na(cur.execute("select :a,:b", p_named).fetchone(), 1);
    out["at_p"] = _cell_na(cur.execute("select @a", p_at).fetchone(), 0);
    out["dollar_p"] = _cell_na(cur.execute("select $a", p_dollar).fetchone(), 0);
    out["qnum1"] = _cell_na(cur.execute("select ?2,?1", [10, 20]).fetchone(), 0);
    out["qnum2"] = _cell_na(cur.execute("select ?2,?1", [10, 20]).fetchone(), 1);
    cur.execute("create table t(a)");
    cur.execute("delete from t where a=999");
    out["del0_rc"] = cur.rowcount;
    try {
        cur.execute("select 1; select 2");
        out["tail_two"] = "none";
    } except sqlite3.ProgrammingError as e4 {
        out["tail_two"] = "ProgrammingError: " + str(e4);
    } except Exception as e4x {
        out["tail_two"] = "WRONG-TYPE: " + str(e4x);
    }
    try {
        cur.execute("select 1; selct 2");
        out["tail_synt"] = "none";
    } except sqlite3.ProgrammingError as e5 {
        out["tail_synt"] = "ProgrammingError: " + str(e5);
    } except Exception as e5x {
        out["tail_synt"] = "WRONG-TYPE: " + str(e5x);
    }
    out["tail_ws"] = _rcell_na(cur.execute("select 7;   ").fetchall(), 0, 0);
    try {
        cur.execute("select :a", [9]);
        out["seq_named"] = "none";
    } except sqlite3.ProgrammingError as e6 {
        out["seq_named"] = "ProgrammingError: " + str(e6);
    } except Exception as e6x {
        out["seq_named"] = "WRONG-TYPE: " + str(e6x);
    }
    con.close();
}


def _script_err_na(out: dict[str, any]) {
    con = sqlite3.connect(":memory:");
    cur = con.cursor();
    cur.execute("create table t(a,b,c)");
    con.executescript("create table e(x); insert into e values(5);");
    out["in_trans_es"] = con.in_transaction;
    out["es_val"] = _cell_na(con.execute("select x from e").fetchone(), 0);
    out["empty_rows"] = len(cur.execute("").fetchall());
    ws = cur.execute("   ").description;
    out["ws_desc_none"] = ws is None;
    try {
        cur.execute("select * from nosuch_tbl");
        out["err_tbl"] = "none";
    } except sqlite3.OperationalError as e1 {
        out["err_tbl"] = "OperationalError: " + str(e1);
    } except Exception as e1x {
        out["err_tbl"] = "WRONG-TYPE: " + str(e1x);
    }
    try {
        cur.execute("insert into t values(?,?,?)", [1, 2]);
        out["err_bind"] = "none";
    } except sqlite3.ProgrammingError as e2 {
        out["err_bind"] = "ProgrammingError: " + str(e2);
    } except Exception as e2x {
        out["err_bind"] = "WRONG-TYPE: " + str(e2x);
    }
    try {
        sqlite3.connect(":memory:", isolation_level="BOGUS");
        out["iso_bad"] = "none";
    } except ValueError as e7 {
        out["iso_bad"] = "ValueError: " + str(e7);
    } except Exception as e7x {
        out["iso_bad"] = "WRONG-TYPE: " + str(e7x);
    }
    c_low = sqlite3.connect(":memory:", isolation_level="deferred");
    c_low.execute("create table lt(a)");
    c_low.execute("insert into lt values(1)");
    out["iso_low"] = c_low.in_transaction;
    c_low.close();
    try {
        sqlite3.complete_statement(1);
        out["complete_bad"] = "none";
    } except TypeError as e8 {
        out["complete_bad"] = "TypeError: " + str(e8);
    } except Exception as e8x {
        out["complete_bad"] = "WRONG-TYPE: " + str(e8x);
    }
    try {
        cur.execute("select 1").fetchmany("x");
        out["fm_str"] = "none";
    } except TypeError as e9 {
        out["fm_str"] = "TypeError: " + str(e9);
    } except Exception as e9x {
        out["fm_str"] = "WRONG-TYPE: " + str(e9x);
    }
    try {
        cur.execute("select ?", [{}]);
        out["bind_dict"] = "none";
    } except sqlite3.ProgrammingError as e10 {
        out["bind_dict"] = "ProgrammingError: " + str(e10);
    } except Exception as e10x {
        out["bind_dict"] = "WRONG-TYPE: " + str(e10x);
    }
    cur.execute("create table u(x unique)");
    cur.execute("insert into u values(1)");
    con.commit();
    try {
        cur.execute("insert into u values(1)");
        out["integrity"] = "none";
    } except sqlite3.IntegrityError as e11 {
        out["integrity"] = "IntegrityError: " + str(e11);
    } except Exception as e11x {
        out["integrity"] = "WRONG-TYPE: " + str(e11x);
    }
    out["ac_default"] = con.autocommit;
    c_ac = sqlite3.connect(":memory:", autocommit=False);
    c_ac.execute("select 1");
    out["ac_f_sel"] = c_ac.in_transaction;
    c_ac.close();
    c_at = sqlite3.connect(":memory:", autocommit=True);
    c_at.execute("create table z(a)");
    c_at.execute("insert into z values(1)");
    out["ac_t_ins"] = c_at.in_transaction;
    out["ac_t_attr"] = c_at.autocommit;
    c_at.close();
    cur2 = con.cursor();
    cur2.close();
    cur2.close();
    out["close_twice"] = "ok";
    cur.close();
    con.close();
    con.close();
    out["double_close"] = 1;
    try {
        con.execute("select 1");
        out["closed_exec"] = "none";
    } except sqlite3.ProgrammingError as e3 {
        out["closed_exec"] = "ProgrammingError: " + str(e3);
    } except Exception as e3x {
        out["closed_exec"] = "WRONG-TYPE: " + str(e3x);
    }
}


def sqlite3_na -> dict[str, any] {
    out: dict[str, any] = {};
    _meta_na(out);
    _txn_na(out);
    _fetch_na(out);
    _types_na(out);
    _params_na(out);
    _script_err_na(out);
    return out;
}
