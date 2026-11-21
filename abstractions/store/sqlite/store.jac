"""The standard store: a space's rows in a SQLite file, which several
programs may open at once.

- **Each row has a version,** which a write raises: a write that finds a row
  at another version than it read is refused whole (StoreConflict).
- **Each write has a mark,** one more than the last: each row keeps the mark
  it was last written at, and each row taken out leaves its id and its
  mark, so that a program asks what was written since it last looked. What
  was taken out is kept that long for KEPT_GONE writes."""

import os;
import sqlite3;
import from common.contract { Host }
import from sqlfile { Upgrade, open_db }
import from store.contract { Changed, Row, Store, StoreConflict, Writing }

"""The layout of the file, as its `user_version`: 3, each row with its
version and the mark it was written at, how many rows there are of each
type and the shape each was written in, and what was taken out."""
glob STORE_FORMAT: int = 3;

"""How many writes back the ids of the rows taken out are kept: a program
that last looked longer ago reads again all it holds."""
glob KEPT_GONE: int = 4096;

glob STORE_TABLES: list[str] = [
    "create table rows (id text primary key, kind text, type text, data text, src text, dst text, ord integer, version integer not null, mark integer not null)",
    "create index rows_src on rows (src) where kind = 'e'",
    "create index rows_dst on rows (dst) where kind = 'e'",
    "create index rows_type on rows (type)",
    "create index rows_mark on rows (mark)",
    "create table gone (id text not null, mark integer not null)",
    "create index gone_mark on gone (mark)",
    "create table counts (name text primary key, n integer not null)",
    "create table kinds (type text primary key, n integer not null)",
    "create table shapes (type text primary key, shape text not null)",
    "create table roots (user text primary key, id text not null)",
    "create table shared (id text not null)",
];

"""Layout 2, rows with no versions and no marks, to layout 3: each row is at
its first version, written before every mark."""
def from_layout_2(db: any) {
    db.execute("alter table rows add column version integer not null default 1");
    db.execute("alter table rows add column mark integer not null default 0");
    for made in STORE_TABLES[1:10] {
        db.execute(made);
    }
    db.execute("insert into kinds select type, count(*) from rows group by type");
    top = 0;
    for r in db.execute("select coalesce(max(ord), -1) + 1 from rows") {
        top = int(r[0]);
    }
    db.execute("insert into counts values ('mark', 0)");
    db.execute("insert into counts values ('ord', ?)", (top,));
}

"""The steps from each layout of the file a release wrote to the next."""
glob STORE_UPGRADES: list[Upgrade] = [Upgrade(since=2, apply=from_layout_2)];

"""The row a result's line holds."""
def row_of(r: any) -> Row {
    return Row(
        id=str(r[0]),
        kind=str(r[1]),
        type_name=str(r[2]),
        data=str(r[3]),
        src=str(r[4]),
        dst=str(r[5]),
        ord=int(r[6]),
        version=int(r[7]),
    );
}

glob COLUMNS: str = "id, kind, type, data, src, dst, ord, version";

obj SqliteStore(Store) {
    """The file: `graph.db` in the app's data directory when it is not said."""
    has path: str = "";

    has db: any postinit;
    # The app's data directory, as the program it was opened in says.
    has data_dir: str postinit;

    def postinit {
        self.db = None;
        self.data_dir = "";
    }

    def kept_as -> str {
        return self.path if self.path != "" else os.path.join(self.data_dir, "graph.db");
    }

    def open(host: dyn Host) {
        self.data_dir = host.data_dir();
        self.db = open_db(self.kept_as(), STORE_FORMAT, STORE_TABLES, STORE_UPGRADES, host);
        # (Its writers wait their turn at the file, and a reader reads beside
        # a writer.)
        self.db.execute("pragma busy_timeout = 30000");
        self.db.execute("pragma journal_mode = wal");
        self.db.execute("insert or ignore into counts values ('mark', 0)");
        self.db.execute("insert or ignore into counts values ('ord', 0)");
        self.db.commit();
    }

    def count(name: str) -> int {
        for r in self.db.execute("select n from counts where name = ?", (name,)) {
            return int(r[0]);
        }
        return 0;
    }

    def types -> dict[str, int] {
        out: dict[str, int] = {};
        for r in self.db.execute("select type, n from kinds where n > 0") {
            out[str(r[0])] = int(r[1]);
        }
        return out;
    }

    def shapes -> dict[str, str] {
        out: dict[str, str] = {};
        for r in self.db.execute("select type, shape from shapes") {
            out[str(r[0])] = str(r[1]);
        }
        return out;
    }

    def of_type(type_name: str) -> list[Row] {
        out = [
            row_of(r)
            for r in self.db.execute(f"select {COLUMNS} from rows where type = ?", (type_name,))
        ];
        return out;
    }

    def rows(ids: list[str]) -> list[Row] {
        out: list[Row] = [];
        k = 0;
        while k < len(ids) {
            some = ids[k:k + 500];
            k += 500;
            marks = ", ".join(["?" for _ in some]);
            for r in self.db.execute(
                f"select {COLUMNS} from rows where id in ({marks})", tuple(some)
            ) {
                out.append(row_of(r));
            }
        }
        return out;
    }

    def edges(id: str) -> list[Row] {
        # (Each end by its own index; an edge from a node to itself once.)
        out = [
            row_of(r)
            for r in self.db.execute(
                f"select {COLUMNS} from rows where kind = 'e' and src = ? union all select {COLUMNS} from rows where kind = 'e' and dst = ? and src != dst order by ord",
                (id, id),
            )
        ];
        return out;
    }

    def mark -> int {
        at = self.count("mark");
        return at;
    }

    def since(mark: int) -> Changed | None {
        if mark < self.count("mark") - KEPT_GONE {
            return None;
        }
        out = Changed();
        out.rows = [
            row_of(r)
            for r in self.db.execute(
                f"select {COLUMNS} from rows where mark > ? order by mark, ord", (mark,)
            )
        ];
        out.gone = [
            str(r[0])
            for r in self.db.execute("select id from gone where mark > ?", (mark,))
        ];
        return out;
    }

    def write(w: Writing) -> int {
        db = self.db;
        lost: list[str] = [];
        mark = 0;
        try {
            # (Its turn at the file from here, whoever else has it open.)
            db.execute("begin immediate");
            mark = self.count("mark") + 1;
            ord = self.count("ord");
            more: dict[str, int] = {};
            for r in w.rows {
                if r.version == 0 {
                    place = r.ord;
                    if r.kind == "e" and place < 0 {
                        place = ord;
                        ord += 1;
                    }
                    try {
                        db.execute(
                            "insert into rows values (?, ?, ?, ?, ?, ?, ?, 1, ?)",
                            (r.id, r.kind, r.type_name, r.data, r.src, r.dst, place, mark),
                        );
                        more[r.type_name] = more.get(r.type_name, 0) + 1;
                    } except sqlite3.IntegrityError {
                        lost.append(r.id);
                    }
                    continue;
                }
                done = db.execute(
                    "update rows set data = ?, version = version + 1, mark = ? where id = ? and version = ?",
                    (r.data, mark, r.id, r.version),
                );
                if done.rowcount != 1 {
                    lost.append(r.id);
                }
            }
            for r in w.gone {
                was = "";
                at = -1;
                for still in db.execute("select type, version from rows where id = ?", (r.id,)) {
                    was = str(still[0]);
                    at = int(still[1]);
                }
                if at < 0 {
                    # (Another took it out: gone, as this write wants it.)
                    continue;
                }
                if at != r.version {
                    lost.append(r.id);
                    continue;
                }
                db.execute("delete from rows where id = ?", (r.id,));
                db.execute("insert into gone values (?, ?)", (r.id, mark));
                more[was] = more.get(was, 0) - 1;
            }
            for (user, id) in w.roots.items() {
                try {
                    db.execute("insert into roots values (?, ?)", (user, id));
                } except sqlite3.IntegrityError {
                    lost.append("the root of " + user);
                }
            }
            if w.shared != "" {
                for had in db.execute("select id from shared") {
                    lost.append("the shared root");
                }
                db.execute("insert into shared values (?)", (w.shared,));
            }
            if len(lost) > 0 {
                db.rollback();
                raise StoreConflict(ids=lost);
            }
            for (name, shape) in w.shapes.items() {
                db.execute("insert or replace into shapes values (?, ?)", (name, shape));
            }
            for (name, change) in more.items() {
                db.execute("insert or ignore into kinds values (?, 0)", (name,));
                db.execute("update kinds set n = n + ? where type = ?", (change, name));
            }
            db.execute("update counts set n = ? where name = 'mark'", (mark,));
            db.execute("update counts set n = ? where name = 'ord'", (ord,));
            db.execute("delete from gone where mark <= ?", (mark - KEPT_GONE,));
            db.commit();
        } except sqlite3.Error {
            db.rollback();
            raise;
        }
        return mark;
    }

    def every -> Iterator[Row] {
        for r in self.db.execute("select id, kind, src, dst, version from rows") {
            yield Row(
                id=str(r[0]),
                kind=str(r[1]),
                type_name="",
                data="",
                src=str(r[2]),
                dst=str(r[3]),
                version=int(r[4]),
            );
        }
    }

    def root_of(user: str) -> str {
        found = "";
        for r in self.db.execute("select id from roots where user = ?", (user,)) {
            found = str(r[0]);
        }
        return found;
    }

    def roots -> list[str] {
        out = [str(r[0]) for r in self.db.execute("select id from roots")];
        return out;
    }

    def shared_root -> str {
        found = "";
        for r in self.db.execute("select id from shared") {
            found = str(r[0]);
        }
        return found;
    }
}
