"""Tests for jac's minimal Postgres wire client (epic #7945).

Offline: SCRAM-SHA-256 math pinned to the RFC 7677 test vector, named
parameter conversion, array literal encoding, and error-field parsing.

Live, against the embedded server: how many socket reads a result costs
and that NOTIFY traffic survives the read buffer. The socket is wrapped
in a pass-through that counts reads (and, to stand in for a starved
thread, can delay them); every byte still comes from a real Postgres
backend. SCRAM-over-TCP is covered by the k8s path.
"""

import select;
import threading;
import time;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.data.pgembed { PgRuntime }
import from jaclang.data.pgload { connect as pg_connect }
import from jaclang.server.session { shared_pg_data_dir, project_db_name }
import from jaclang.data.pgwire {
    PgWireError,
    STATEMENT_CACHE_SIZE,
    _array_literal,
    _named_to_positional,
    _parse_error_fields,
    _rewrite_named,
    _scram_proofs
}


test "scram-sha-256 matches the RFC 7677 test vector" {
    client_first_bare = "n=user,r=rOprNGfwEbeRWgbNEkqO";
    server_first = (
        "r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,"
        "s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096"
    );
    (client_final_wo, proof, server_sig) = _scram_proofs(
        "pencil", server_first, client_first_bare
    );
    assert client_final_wo
        == ("c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0");
    assert proof == "dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ=";
    assert server_sig == "6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=";
}


test "named params convert to positional, sharing repeated slots" {
    (sql, args) = _named_to_positional(
        "UPDATE t SET a = :v, b = :v WHERE id = :i AND k = 'lit:x' "
        "AND j = CAST(:v AS jsonb)::text",
        {'v': 'val', 'i': 7}
    );
    assert sql
        == (
            "UPDATE t SET a = $1, b = $1 WHERE id = $2 AND k = 'lit:x' "
            "AND j = CAST($1 AS jsonb)::text"
        );
    assert args == ['val', 7];
}


test "placeholders inside quotes and unknown names are untouched" {
    (sql, args) = _named_to_positional(
        "SELECT ':notaparam', \":alsonot\", :real FROM x WHERE t = ':real'", {'real': 1}
    );
    assert sql == ("SELECT ':notaparam', \":alsonot\", $1 FROM x WHERE t = ':real'");
    assert args == [1];
}


test "named params preserve dollar quoted literals" {
    for literal in [
        '$$:x$$',
        '$tag$:x$tag$',
        '$_tag1$:x$_tag1$',
        '$é$:x$é$',
        "$tag$it's $$:x$$ and $other$:unused$other$$tag$",
        '$Tag$:x $tag$ :unused$Tag$'
    ] {
        (sql, args) = _named_to_positional(
            f'SELECT {literal}, :x::int, :x', {'x': 7, 'unused': 9}
        );
        assert sql == f'SELECT {literal}, $1::int, $1';
        assert args == [7];
    }
    (sql, args) = _named_to_positional('SELECT identifier$tag$, :x', {'x': 7});
    assert sql == 'SELECT identifier$tag$, $1';
    assert args == [7];
}


test "named params preserve SQL comments" {
    for comment in [
        "-- user's :unused note\n",
        '-- :unused\r\n',
        '-- :unused\r',
        "/* user's :unused note */",
        '/* outer /* :unused */ still :unused */'
    ] {
        (sql, args) = _named_to_positional(
            f'{comment}SELECT :x::int', {'x': 7, 'unused': 9}
        );
        assert sql == f'{comment}SELECT $1::int';
        assert args == [7];
    }
    for comment in ['-- :unused', '/* :unused */'] {
        (sql, args) = _named_to_positional(
            f'SELECT :x::int {comment}', {'x': 7, 'unused': 9}
        );
        assert sql == f'SELECT $1::int {comment}';
        assert args == [7];
    }
}


test "named params preserve escape string literals" {
    for literal in [
        r"E'it\'s :x'",
        r"e'it\'s :x'",
        r"E'back\\slash :x'",
        "E':x''quoted'",
        "E'first'\n'it\\'s :x'"
    ] {
        (sql, args) = _named_to_positional(f'SELECT {literal}, :x::int', {'x': 7});
        assert sql == f'SELECT {literal}, $1::int';
        assert args == [7];
    }
    (sql, args) = _named_to_positional(r"SELECT 'back\', :x::int", {'x': 7});
    assert sql == r"SELECT 'back\', $1::int";
    assert args == [7];
}


test "array literal escapes quotes and backslashes" {
    lit = _array_literal(['plain', 'has"quote', 'back\\slash']);
    assert lit == '{"plain","has\\"quote","back\\\\slash"}';
}


test "array null elements stay distinct from strings" {
    assert _array_literal([None, 'None', 'NULL', 'null', ''])
        == '{NULL,"None","NULL","null",""}';
    assert _array_literal((1, None, 3)) == '{"1",NULL,"3"}';
    assert _array_literal({None}) == '{NULL}';
    assert _array_literal([]) == '{}';
}


test "error fields parse into the sqlstate dict shape" {
    payload = b'SERROR\x00C40001\x00Mdeadlock\x00\x00';
    fields = _parse_error_fields(payload);
    assert fields == {'S': 'ERROR', 'C': '40001', 'M': 'deadlock'};
}


test "one named-param rewrite per text and bound-name set" {
    sql = "SELECT :a, :b FROM t WHERE c = ':a'";
    rewrite: any = _rewrite_named;
    rewrite.cache_clear();
    (first, args1) = _named_to_positional(sql, {'a': 1, 'b': 2});
    (again, args2) = _named_to_positional(sql, {'b': 'y', 'a': 'x'});
    reused = rewrite.cache_info();
    assert (reused.misses, reused.hits) == (1, 1) , (
        f"the same text and names must be rewritten once: {reused}"
    );
    (partial, args3) = _named_to_positional(sql, {'b': 3});
    assert rewrite.cache_info().misses == 2 , (
        'a different bound-name set must not reuse the rewrite'
    );
    assert first == again == "SELECT $1, $2 FROM t WHERE c = ':a'";
    assert args1 == [1, 2] and args2 == ['x', 'y'];
    assert partial == "SELECT :a, $1 FROM t WHERE c = ':a'";
    assert args3 == [3];
}


obj _ReadProbe {
    has sock: any,
        delay: float = 0.0,
        sent: any = None,
        hold: any = None,
        reads: int = 0;

    def recv(n: int) -> bytes {
        self.reads += 1;
        if self.hold is not None {
            assert self.hold.wait(10.0) , 'the probe was never released';
        }
        if self.delay {
            time.sleep(self.delay);
        }
        return self.sock.recv(n);
    }

    def sendall(data: bytes) {
        self.sock.sendall(data);
        if self.sent is not None {
            self.sent.set();
        }
    }

    def close {
        self.sock.close();
    }
}


def _live_conn(td: str, app_name: str = 'jac_pgwire_test') -> any {
    rt = PgRuntime(
        data_dir=shared_pg_data_dir(),
        database=project_db_name(td, str(Path(td) / 'app.jac')),
        owner_path=td
    );
    info = rt.ensure();
    return pg_connect(
        info.user,
        host=(info.host or None),
        port=info.port,
        unix_socket_dir=info.unix_socket_dir,
        database=info.database,
        password=(info.password or None),
        startup_params={'application_name': app_name}
    );
}


test "named params preserve SQL literals and bind counts against Postgres" {
    cases = [
        ("SELECT ':x', :x::int", {'x': 7}, [(':x', 7)]),
        ('SELECT $$:x$$, :x::int', {'x': 7}, [(':x', 7)]),
        ('SELECT $tag$:x$tag$, :x::int', {'x': 7}, [(':x', 7)]),
        ('SELECT :x::int -- :unused\n', {'x': 7, 'unused': 9}, [(7, )]),
        ('SELECT :x::int /* :unused */', {'x': 7, 'unused': 9}, [(7, )]),
        ("-- user's note\nSELECT :x::int", {'x': 7}, [(7, )]),
        ("/* user's note */ SELECT :x::int", {'x': 7}, [(7, )]),
        (
            '/* outer /* :unused */ still :unused */ SELECT :x::int',
            {'x': 7, 'unused': 9},
            [(7, )]
        ),
        (r"SELECT E'it\'s :x', :x::int", {'x': 7}, [("it's :x", 7)])
    ];
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            for (sql, params, expected) in cases {
                assert conn.run(sql, **params) == expected;
            }
            assert conn.run('SELECT 42::int') == [(42, )];
        } finally {
            conn.close();
        }
    }
}


test "array parameters preserve SQL null elements" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            assert conn.run(
                "SELECT array_to_json(:v::text[])::text",
                v=[None, 'None', 'NULL', 'null', '']
            )
                == [('[null,"None","NULL","null",""]', )];
            assert conn.run("SELECT array_to_json(:v::int[])::text", v=(1, None, 3))
                == [('[1,null,3]', )];
            assert conn.run(
                "SELECT array_to_json(:v::bool[])::text", v=[True, None, False]
            )
                == [('[true,null,false]', )];
        } finally {
            conn.close();
        }
    }
}


test "a multi-row result costs a few socket reads, not two per row" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        counter = _ReadProbe(sock=conn._sock);
        conn._sock = counter;
        try {
            rows = conn.run(
                "SELECT g, repeat('x', 40) FROM generate_series(1, :n) AS g", n=2000
            );
            assert len(rows) == 2000;
            assert rows[0] == (1, 'x' * 40) and rows[-1][0] == 2000;
            assert counter.reads <= 100 , (
                f"{counter.reads} socket reads for one 2000-row statement:"
                ' the client reads protocol messages one recv at a time'
            );
            reads_before = counter.reads;
            for _ in range(50) {
                assert conn.run('SELECT 1') == [(1, )];
            }
            per_stmt = (counter.reads - reads_before) / 50;
            assert per_stmt <= 1.5 , (
                f"{per_stmt} socket reads per single-row statement (expected about 1)"
            );
        } finally {
            conn.close();
        }
    }
}


test "a notification that shares a read with ReadyForQuery reaches the listener" {
    with TemporaryDirectory() as td {
        listener = _live_conn(td, 'jac_pgwire_listen');
        sender = _live_conn(td, 'jac_pgwire_notify');
        try {
            listener.run('LISTEN jac_pgwire_buf');
            raw = listener._sock;
            sent = threading.Event();
            fired = threading.Event();
            listener._sock = _ReadProbe(sock=raw, delay=0.2, sent=sent, hold=fired);
            def _fire {
                assert sent.wait(10.0);
                time.sleep(0.2);
                sender.run("NOTIFY jac_pgwire_buf, 'hello'");
                fired.set();
            }
            t = threading.Thread(target=_fire, daemon=True);
            t.start();
            listener.run('SELECT 1');
            t.join(timeout=10.0);
            listener._sock = raw;
            queued = [n[2] for n in listener.notifications];
            wakes = bool(select.select([raw], [], [], 1.0)[0]);
            assert queued == ['hello'] or wakes , (
                'the NOTIFY sent right after ReadyForQuery is neither queued nor'
                ' readable on the socket: a select()-driven listener never sees it'
            );
        } finally {
            listener.close();
            sender.close();
        }
    }
}


def _prepared(conn: any, marker: str) -> int {
    return conn.run(
        "SELECT count(*)::int FROM pg_prepared_statements WHERE statement LIKE :m",
        m=f"%{marker}%"
    )[0][0];
}


test "a repeated statement is parsed once per connection and reused by name" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            for i in range(5) {
                assert conn.run("SELECT :x::int + 41 AS reuse_marker", x=i)
                    == [(i + 41, )];
            }
            assert _prepared(conn, "reuse_marker") == 1 , (
                "five runs of one statement did not share one prepared statement"
            );
        } finally {
            conn.close();
        }
    }
}


test "a statement whose first execution fails stays prepared and reusable" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            conn.run("CREATE TEMP TABLE uniq_marker (k int PRIMARY KEY)");
            conn.run("INSERT INTO uniq_marker SELECT 1");
            failed = False;
            try {
                conn.run("INSERT INTO uniq_marker VALUES (:k)", k=1);
            } except PgWireError {
                failed = True;
            }
            assert failed , "a duplicate key was accepted";
            conn.run("INSERT INTO uniq_marker VALUES (:k)", k=2);
            assert conn.run("SELECT count(*)::int FROM uniq_marker") == [(2, )];
            assert _prepared(conn, "VALUES ($1)") == 1 , (
                "the statement whose first execution failed was prepared again"
            );
        } finally {
            conn.close();
        }
    }
}


test "a partial reset keeps the session's statements" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            assert conn.run("SELECT :x::int AS partial_marker", x=1) == [(1, )];
            conn.run("DISCARD TEMP");
            assert conn.run("SELECT :x::int AS partial_marker", x=2) == [(2, )];
            assert _prepared(conn, "partial_marker") == 1 , (
                "a reset that keeps prepared statements made the client prepare it again"
            );
        } finally {
            conn.close();
        }
    }
}


test "deallocating one statement forgets only that one" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            conn.run("SELECT :x::int AS keep_marker", x=1);
            conn.run("SELECT :x::int AS drop_marker", x=1);
            dropped = conn.run(
                "SELECT name FROM pg_prepared_statements WHERE statement LIKE :m",
                m="%drop_marker%"
            )[0][0];
            conn.run(
                f'DEALLOCATE "{dropped}"; -- one statement, quoted, with a comment'
            );
            assert conn.run("SELECT :x::int AS drop_marker", x=2) == [(2, )];
            assert conn.run("SELECT :x::int AS keep_marker", x=2) == [(2, )];
            assert _prepared(conn, "keep_marker") == 1;
            assert _prepared(conn, "drop_marker") == 1;
        } finally {
            conn.close();
        }
    }
}


test "a cached statement whose result columns change recovers by the next call" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            conn.run("CREATE TEMP TABLE shape_marker (a int)");
            conn.run("INSERT INTO shape_marker VALUES (1)");
            assert conn.run("SELECT * FROM shape_marker") == [(1, )];
            conn.run("ALTER TABLE shape_marker ADD COLUMN b int DEFAULT 7");
            try {
                conn.run("SELECT * FROM shape_marker");
            } except PgWireError as e {
                assert "0A000" in str(e) , str(e);
            }
            assert conn.run("SELECT * FROM shape_marker") == [(1, 7)];
        } finally {
            conn.close();
        }
    }
}


test "statements past the cache size are closed on the server" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            for i in range(STATEMENT_CACHE_SIZE + 20) {
                conn.run(f"SELECT {i} AS evict_marker_{i}");
            }
            held = _prepared(conn, "evict_marker_");
            assert held <= STATEMENT_CACHE_SIZE , (
                f"{held} statements held for a cache of {STATEMENT_CACHE_SIZE}"
            );
        } finally {
            conn.close();
        }
    }
}


test "statements keep working after the session is reset for the pool" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            assert conn.run("SELECT :x::int AS discard_marker", x=1) == [(1, )];
            conn.run("DISCARD ALL");
            assert conn.run("SELECT :x::int AS discard_marker", x=2) == [(2, )];
            assert _prepared(conn, "discard_marker") == 1;
        } finally {
            conn.close();
        }
    }
}


test "a statement dropped behind the client's back is prepared again outside a transaction" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            assert conn.run("SELECT :x::int AS dropped_marker", x=1) == [(1, )];
            conn.run("DO $$ BEGIN EXECUTE 'DEALLOCATE ALL'; END $$");
            assert conn.run("SELECT :x::int AS dropped_marker", x=3) == [(3, )];
        } finally {
            conn.close();
        }
    }
}


test "an unquoted deallocation with a trailing semicolon forgets that statement" {
    with TemporaryDirectory() as td {
        conn = _live_conn(td);
        try {
            conn.run("SELECT :x::int AS bare_marker", x=1);
            name = conn.run(
                "SELECT name FROM pg_prepared_statements WHERE statement LIKE :m",
                m="%bare_marker%"
            )[0][0];
            conn.run(f"DEALLOCATE PREPARE {name.upper()};");
            conn.run("BEGIN");
            try {
                assert conn.run("SELECT :x::int AS bare_marker", x=2) == [(2, )];
            } finally {
                conn.run("ROLLBACK");
            }
        } finally {
            conn.close();
        }
    }
}
