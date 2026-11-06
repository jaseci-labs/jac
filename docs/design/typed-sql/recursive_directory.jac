"""Traverse a fixed directory tree with a recursive SQL query.

Run from the repository root:
    jac run docs/design/typed-sql/recursive_directory.jac

SQLite runs the generated query in memory; no database server is required.
"""
import sqlite3;
import jaclang.sql as q;

def main {
    entry_id = q.field('id', q.int64_type());
    parent_id = q.field('parent_id', q.int64_type());
    name = q.field('name', q.text_type());
    kind = q.field('kind', q.text_type());
    depth = q.field('depth', q.int64_type());
    path = q.field('path', q.text_type());
    entries = q.table('entries', [entry_id, parent_id, name, kind]);

    # The anchor starts at the directory selected by a bound parameter.
    descendants = q.cte_ref([entry_id, kind, depth, path]);
    anchor = q.select(
        [
            q.named('id', entries.col(entry_id)),
            q.named('kind', entries.col(kind)),
            q.named('depth', q.int64(0)),
            q.named('path', entries.col(name))
        ],
        source=entries,
        where=q.eq(entries.col(entry_id), q.slot('root_id', q.int64_type()))
    );

    # Each recursive row joins a directory to its immediate children.
    step = q.select(
        [
            q.named('id', entries.col(entry_id)),
            q.named('kind', entries.col(kind)),
            q.named('depth', q.add(descendants.col(depth), q.int64(1))),
            q.named(
                'path',
                q.text_concat(
                    q.text_concat(descendants.col(path), q.text('/')), entries.col(name)
                )
            )
        ],
        source=descendants,
        joins=[
            q.inner_join(
                entries, q.eq(entries.col(parent_id), descendants.col(entry_id))
            )
        ],
        where=q.eq(descendants.col(kind), q.text('dir'))
    );
    q.define_cte(descendants, q.union_all(anchor, step), recursive=True);
    query = q.select(
        [
            q.named('path', descendants.col(path)),
            q.named('kind', descendants.col(kind)),
            q.named('depth', descendants.col(depth))
        ],
        source=descendants,
        order_by=[q.asc(descendants.col(path))]
    );
    compiled = q.compile_sql(query).bind({'root_id': 1});
    # parent_id=0 denotes a root. The unrelated root stays outside the result.
    nodes = [
        (1, 0, 'project', 'dir'),
        (2, 1, 'src', 'dir'),
        (3, 2, 'main.jac', 'file'),
        (4, 2, 'lib', 'dir'),
        (5, 4, 'helper.jac', 'file'),
        (6, 1, 'README.md', 'file'),
        (7, 0, 'unrelated.txt', 'file')
    ];
    expected = [
        ('project', 'dir', 0),
        ('project/README.md', 'file', 1),
        ('project/src', 'dir', 1),
        ('project/src/lib', 'dir', 2),
        ('project/src/lib/helper.jac', 'file', 3),
        ('project/src/main.jac', 'file', 2)
    ];

    db = sqlite3.connect(':memory:');
    try {
        db.execute(
            'CREATE TABLE entries(id INTEGER PRIMARY KEY, parent_id INTEGER, name TEXT, kind TEXT)'
        );
        db.executemany('INSERT INTO entries VALUES (?, ?, ?, ?)', nodes);
        actual = db.execute(compiled.sql, compiled.params).fetchall();
        print('SQL:');
        print(compiled.sql);
        print('\nParameters:');
        print(compiled.params);
        print('\nExpected rows (path, kind, depth):');
        for row in expected {
            print(row);
        }
        print('\nActual rows:');
        for row in actual {
            print(row);
        }
        assert actual == expected;
        print('\nPASS: actual rows match expected rows.');
    } finally {
        db.close();
    }
}

with entry {
    main();
}
