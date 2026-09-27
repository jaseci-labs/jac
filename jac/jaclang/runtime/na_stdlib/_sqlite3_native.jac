import from c { def malloc(size: i64) -> int;  }
import from c { def free(p: int) -> None;  }
import from c { def memcpy(dst: bytes, src: int, n: i64) -> int;  }
import from c { def strdup(s: int) -> str;  }
import from c { def strcpy(dst: int, src: str) -> int;  }
import from c { def strlen(s: str) -> i64;  }

import from sqlite3 { def sqlite3_open(filename: str, ppdb: int) -> i32;  }
import from sqlite3 {
    def sqlite3_open_v2(filename: str, ppdb: int, flags: i32, vfs: int) -> i32;
}
import from sqlite3 { def sqlite3_close(db: int) -> i32;  }
import from sqlite3 {
    def sqlite3_prepare_v2(
        db: int, sql: int, nbyte: i32, ppstmt: int, tail: int
    ) -> i32;
}
import from sqlite3 { def sqlite3_step(stmt: int) -> i32;  }
import from sqlite3 { def sqlite3_reset(stmt: int) -> i32;  }
import from sqlite3 { def sqlite3_finalize(stmt: int) -> i32;  }
import from sqlite3 { def sqlite3_clear_bindings(stmt: int) -> i32;  }
import from sqlite3 { def sqlite3_column_count(stmt: int) -> i32;  }
import from sqlite3 { def sqlite3_column_type(stmt: int, i: i32) -> i32;  }
import from sqlite3 { def sqlite3_column_int64(stmt: int, i: i32) -> i64;  }
import from sqlite3 { def sqlite3_column_double(stmt: int, i: i32) -> f64;  }
import from sqlite3 { def sqlite3_column_blob(stmt: int, i: i32) -> int;  }
import from sqlite3 { def sqlite3_column_text(stmt: int, i: i32) -> int;  }
import from sqlite3 { def sqlite3_column_bytes(stmt: int, i: i32) -> i32;  }
import from sqlite3 { def sqlite3_column_name(stmt: int, i: i32) -> int;  }
import from sqlite3 { def sqlite3_errmsg(db: int) -> int;  }
import from sqlite3 { def sqlite3_errcode(db: int) -> i32;  }
import from sqlite3 { def sqlite3_extended_errcode(db: int) -> i32;  }
import from sqlite3 {
    def sqlite3_exec(db: int, sql: str, cb: int, arg: int, errmsg: int) -> i32;
}
import from sqlite3 { def sqlite3_free(p: int) -> None;  }
import from sqlite3 { def sqlite3_changes64(db: int) -> i64;  }
import from sqlite3 { def sqlite3_total_changes64(db: int) -> i64;  }
import from sqlite3 { def sqlite3_last_insert_rowid(db: int) -> i64;  }
import from sqlite3 { def sqlite3_get_autocommit(db: int) -> i32;  }
import from sqlite3 { def sqlite3_busy_timeout(db: int, ms: i32) -> i32;  }
import from sqlite3 { def sqlite3_libversion -> int;  }
import from sqlite3 { def sqlite3_complete(sql: str) -> i32;  }
import from sqlite3 { def sqlite3_bind_parameter_count(stmt: int) -> i32;  }
import from sqlite3 { def sqlite3_bind_parameter_name(stmt: int, i: i32) -> int;  }
import from sqlite3 { def sqlite3_bind_null(stmt: int, i: i32) -> i32;  }
import from sqlite3 { def sqlite3_bind_int64(stmt: int, i: i32, v: i64) -> i32;  }
import from sqlite3 { def sqlite3_bind_double(stmt: int, i: i32, v: f64) -> i32;  }
import from sqlite3 {
    def sqlite3_bind_text(stmt: int, i: i32, v: str, n: i32, dtor: i64) -> i32;
}
import from sqlite3 {
    def sqlite3_bind_blob(stmt: int, i: i32, v: bytes, n: i32, dtor: i64) -> i32;
}
import from sqlite3 { def sqlite3_stmt_readonly(stmt: int) -> i32;  }

glob _OUT: int = malloc(32),
     _ERRP: int = malloc(8),
     _OPEN_ERR: str = "",
     _SQLITE_TRANSIENT: int = -1;


def:pub sq3_libversion -> str {
    return strdup(sqlite3_libversion());
}


def:pub sq3_open(path: str) -> int {
    __mem_store_i64(_OUT, 0);
    _OPEN_ERR = "";
    rc = sqlite3_open(path, _OUT);
    h = __mem_load_i64(_OUT);
    if h != 0 {
        if rc != 0 {
            _OPEN_ERR = sq3_errmsg(h);
            sqlite3_close(h);
        } else {
            return h;
        }
    }
    return -int(rc);
}


def:pub sq3_open_v2(path: str, uri: bool) -> int {
    flags = 6;
    if uri {
        flags = 6 + 64;
    }
    __mem_store_i64(_OUT, 0);
    _OPEN_ERR = "";
    rc = sqlite3_open_v2(path, _OUT, i32(flags), 0);
    h = __mem_load_i64(_OUT);
    if h != 0 {
        if rc != 0 {
            _OPEN_ERR = sq3_errmsg(h);
            sqlite3_close(h);
        } else {
            return h;
        }
    }
    return -int(rc);
}


def:pub sq3_open_err -> str {
    s = _OPEN_ERR;
    _OPEN_ERR = "";
    return s;
}


def:pub sq3_close(db: int) -> int {
    return int(sqlite3_close(db));
}


def:pub sq3_busy_timeout(db: int, ms: int) -> int {
    return int(sqlite3_busy_timeout(db, i32(ms)));
}


def:pub sq3_prepare(db: int, sql: str) -> int {
    p = malloc(strlen(sql) + 1);
    strcpy(p, sql);
    __mem_store_i64(_OUT, 0);
    __mem_store_i64(_OUT + 8, 0);
    __mem_store_i64(_OUT + 16, p);
    rc = sqlite3_prepare_v2(db, p, -1, _OUT, _OUT + 8);
    if rc != 0 {
        free(p);
        __mem_store_i64(_OUT + 16, 0);
        return -int(rc);
    }
    return 0;
}


def:pub sq3_prep_stmt -> int {
    return __mem_load_i64(_OUT);
}


def:pub sq3_prep_tail -> int {
    return __mem_load_i64(_OUT + 8);
}


def:pub sq3_prep_sqlp -> int {
    return __mem_load_i64(_OUT + 16);
}


def:pub sq3_tail_nonws -> int {
    p = sq3_prep_tail();
    if p == 0 {
        return 0;
    }
    i = 0;
    while True {
        a = (p + i) & -8;
        sh = ((p + i) & 7) * 8;
        b = (__mem_load_i64(a) >> sh) & 255;
        if b == 0 {
            return 0;
        }

        if b > 32 {
            return 1;
        }
        i += 1;
    }
    return 0;
}


def:pub sq3_free(p: int) {
    if p != 0 {
        free(p);
    }
}


def:pub sq3_step(stmt: int) -> int {
    return int(sqlite3_step(stmt));
}


def:pub sq3_reset(stmt: int) -> int {
    return int(sqlite3_reset(stmt));
}


def:pub sq3_finalize(stmt: int) -> int {
    return int(sqlite3_finalize(stmt));
}


def:pub sq3_clear_bindings(stmt: int) -> int {
    return int(sqlite3_clear_bindings(stmt));
}


def:pub sq3_column_count(stmt: int) -> int {
    return int(sqlite3_column_count(stmt));
}


def:pub sq3_column_type(stmt: int, i: int) -> int {
    return int(sqlite3_column_type(stmt, i32(i)));
}


def:pub sq3_column_int(stmt: int, i: int) -> int {
    return int(sqlite3_column_int64(stmt, i32(i)));
}


def:pub sq3_column_float(stmt: int, i: int) -> float {
    return float(sqlite3_column_double(stmt, i32(i)));
}


def:pub sq3_column_raw(stmt: int, i: int) -> bytes {
    n = int(sqlite3_column_bytes(stmt, i32(i)));
    buf = b"\x00" * n;
    if n > 0 {
        memcpy(buf, sqlite3_column_blob(stmt, i32(i)), i64(n));
    }
    return buf;
}


def:pub sq3_row(stmt: int, ncols: int) -> list[any] {
    row: list[any] = [];
    for i in range(ncols) {
        ii = i32(i);
        t = int(sqlite3_column_type(stmt, ii));
        v: any = None;
        if t == 1 {
            v = int(sqlite3_column_int64(stmt, ii));
        } elif t == 2 {
            v = float(sqlite3_column_double(stmt, ii));
        } elif t == 3 {
            p = sqlite3_column_text(stmt, ii);
            if p == 0 {
                v = "";
            } else {
                v = strdup(p);
            }
        } elif t == 4 {
            n = int(sqlite3_column_bytes(stmt, ii));
            buf = b"\x00" * n;
            if n > 0 {
                memcpy(buf, sqlite3_column_blob(stmt, ii), i64(n));
            }
            v = buf;
        }
        row.append(v);
    }
    return row;
}


def:pub sq3_bind_seq(stmt: int, params: list[any], n: int) -> int {
    for i in range(n) {
        v = params[i];
        j = i + 1;
        if v is None {
            sqlite3_bind_null(stmt, i32(j));
        } elif isinstance(v, bool) {
            sqlite3_bind_int64(stmt, i32(j), i64(1 if v else 0));
        } elif isinstance(v, int) {
            sqlite3_bind_int64(stmt, i32(j), i64(v));
        } elif isinstance(v, float) {
            sqlite3_bind_double(stmt, i32(j), v);
        } elif isinstance(v, str) {
            sqlite3_bind_text(stmt, i32(j), v, -1, i64(_SQLITE_TRANSIENT));
        } elif isinstance(v, bytes) {
            sqlite3_bind_blob(stmt, i32(j), v, i32(len(v)), i64(_SQLITE_TRANSIENT));
        } elif isinstance(v, bytearray) {
            bv = bytes(v);
            sqlite3_bind_blob(stmt, i32(j), bv, i32(len(bv)), i64(_SQLITE_TRANSIENT));
        } else {
            return -j;
        }
    }
    return 0;
}


def:pub sq3_column_name(stmt: int, i: int) -> str {
    p = sqlite3_column_name(stmt, i32(i));
    if p == 0 {
        return "";
    }
    return strdup(p);
}


def:pub sq3_errmsg(db: int) -> str {
    p = sqlite3_errmsg(db);
    if p == 0 {
        return "";
    }
    return strdup(p);
}


def:pub sq3_errcode(db: int) -> int {
    return int(sqlite3_errcode(db));
}


def:pub sq3_extended_errcode(db: int) -> int {
    return int(sqlite3_extended_errcode(db));
}


def:pub sq3_exec(db: int, sql: str) -> int {
    __mem_store_i64(_ERRP, 0);
    return int(sqlite3_exec(db, sql, 0, 0, _ERRP));
}


def:pub sq3_exec_err -> str {
    ep = __mem_load_i64(_ERRP);
    if ep == 0 {
        return "";
    }
    s = strdup(ep);
    sqlite3_free(ep);
    __mem_store_i64(_ERRP, 0);
    return s;
}


def:pub sq3_changes(db: int) -> int {
    return int(sqlite3_changes64(db));
}


def:pub sq3_total_changes(db: int) -> int {
    return int(sqlite3_total_changes64(db));
}


def:pub sq3_last_insert_rowid(db: int) -> int {
    return int(sqlite3_last_insert_rowid(db));
}


def:pub sq3_get_autocommit(db: int) -> int {
    return int(sqlite3_get_autocommit(db));
}


def:pub sq3_complete(sql: str) -> int {
    return int(sqlite3_complete(sql));
}


def:pub sq3_bind_parameter_count(stmt: int) -> int {
    return int(sqlite3_bind_parameter_count(stmt));
}


def:pub sq3_bind_parameter_name(stmt: int, i: int) -> str {
    p = sqlite3_bind_parameter_name(stmt, i32(i));
    if p == 0 {
        return "";
    }
    return strdup(p);
}


def:pub sq3_bind_null(stmt: int, i: int) -> int {
    return int(sqlite3_bind_null(stmt, i32(i)));
}


def:pub sq3_bind_int(stmt: int, i: int, v: int) -> int {
    return int(sqlite3_bind_int64(stmt, i32(i), i64(v)));
}


def:pub sq3_bind_double(stmt: int, i: int, v: float) -> int {
    return int(sqlite3_bind_double(stmt, i32(i), v));
}


def:pub sq3_bind_text(stmt: int, i: int, v: str) -> int {
    return int(sqlite3_bind_text(stmt, i32(i), v, -1, i64(_SQLITE_TRANSIENT)));
}


def:pub sq3_bind_blob(stmt: int, i: int, v: bytes) -> int {
    return int(sqlite3_bind_blob(stmt, i32(i), v, i32(len(v)), i64(_SQLITE_TRANSIENT)));
}


def:pub sq3_stmt_readonly(stmt: int) -> int {
    return int(sqlite3_stmt_readonly(stmt));
}
