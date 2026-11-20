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


def:pub sq3_libversion -> str;


def:pub sq3_open(path: str) -> int;


def:pub sq3_open_v2(path: str, uri: bool) -> int;


def:pub sq3_open_err -> str;


def:pub sq3_close(db: int) -> int;


def:pub sq3_busy_timeout(db: int, ms: int) -> int;


def:pub sq3_prepare(db: int, sql: str) -> int;


def:pub sq3_prep_stmt -> int;


def:pub sq3_prep_tail -> int;


def:pub sq3_prep_sqlp -> int;


def:pub sq3_tail_nonws -> int;


def:pub sq3_free(p: int);


def:pub sq3_step(stmt: int) -> int;


def:pub sq3_reset(stmt: int) -> int;


def:pub sq3_finalize(stmt: int) -> int;


def:pub sq3_clear_bindings(stmt: int) -> int;


def:pub sq3_column_count(stmt: int) -> int;


def:pub sq3_column_type(stmt: int, i: int) -> int;


def:pub sq3_column_int(stmt: int, i: int) -> int;


def:pub sq3_column_float(stmt: int, i: int) -> float;


def:pub sq3_column_raw(stmt: int, i: int) -> bytes;


def:pub sq3_row(stmt: int, ncols: int) -> list[any];


def:pub sq3_bind_seq(stmt: int, params: list[any], n: int) -> int;


def:pub sq3_column_name(stmt: int, i: int) -> str;


def:pub sq3_errmsg(db: int) -> str;


def:pub sq3_errcode(db: int) -> int;


def:pub sq3_extended_errcode(db: int) -> int;


def:pub sq3_exec(db: int, sql: str) -> int;


def:pub sq3_exec_err -> str;


def:pub sq3_changes(db: int) -> int;


def:pub sq3_total_changes(db: int) -> int;


def:pub sq3_last_insert_rowid(db: int) -> int;


def:pub sq3_get_autocommit(db: int) -> int;


def:pub sq3_complete(sql: str) -> int;


def:pub sq3_bind_parameter_count(stmt: int) -> int;


def:pub sq3_bind_parameter_name(stmt: int, i: int) -> str;


def:pub sq3_bind_null(stmt: int, i: int) -> int;


def:pub sq3_bind_int(stmt: int, i: int, v: int) -> int;


def:pub sq3_bind_double(stmt: int, i: int, v: float) -> int;


def:pub sq3_bind_text(stmt: int, i: int, v: str) -> int;


def:pub sq3_bind_blob(stmt: int, i: int, v: bytes) -> int;


def:pub sq3_stmt_readonly(stmt: int) -> int;
