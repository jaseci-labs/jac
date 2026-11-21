"""The contract of the `store` abstraction: `Store`, the interface of the
plugin that holds a space's rows, and what crosses it.

A store is rows by their ids, with no query language: a graph database is
used as rows too. The runtime above it owns which node is which object, what
of the graph is in memory, and when a call's writes commit.

- **Each row has a version,** which a write expects to be the one it read: a
  write that finds another raises StoreConflict, and the call is run again
  on what the other wrote.
- **A write is the only thing that changes a store,** and it is whole: a
  store never holds half of what a call made."""

import from common.contract { Host }

"""One node or edge as a store keeps it, by its id (its `jid`, which the runtime
gives it as it is made and the store gives back to what it loads): `src`,
`dst` and `ord` only for an edge, `ord` the order edges were made in, which
loading makes them in again, so each node's edges keep their order.
`version` counts the times it was written: 0 for a row no store has yet."""
obj Row {
    has id: str,
        kind: str,
        type_name: str,
        data: str,
        src: str = "",
        dst: str = "",
        ord: int = 0,
        version: int = 0;
}

"""What a store has had written since a mark (Store.since): the rows written,
as they are now, and the ids of the rows taken out."""
obj Changed {
    has rows: list[Row] = [],
        gone: list[str] = [];
}

"""What one commit writes, all of it or none (Store.write): the rows to keep,
each at the version it was read at; the rows to take out, likewise; the
roots first given to users, by user; the shared root, when it is first set;
and the shape each type's rows are now written in."""
obj Writing {
    has rows: list[Row] = [],
        gone: list[Row] = [],
        roots: dict[str, str] = {},
        shared: str = "",
        shapes: dict[str, str] = {};
}

"""A write a store refuses because what it would change is no longer what was
read: another user of the store wrote or took out the rows `ids` first, or
gave a user their root first."""
obj StoreConflict(Exception) {
    has ids: list[str] = [];

    def __str__ -> str {
        return f"the store's rows changed under this call: {', '.join(self.ids[:3])}"
            + (f" and {len(self.ids) - 3} more" if len(self.ids) > 3 else "");
    }
}

"""What holds a space's rows: the interface of the `store` abstraction's
plugins. One is made with its settings and does nothing until it is
opened."""
obj Store {
    """Make ready to hold rows, in the program `host`: open the file, reach
    the service. The first thing asked of it. DataError
    (`common.contract`) for data it holds that it can't be opened with."""
    def open(host: dyn Host) abst;

    """What its data is called, where an app says what is wrong with what
    it kept: a file's path, a table's address."""
    def kept_as -> str abst;

    """How many rows it holds of each type, by the type's name: what a
    program is held against as it starts."""
    def types -> dict[str, int] abst;

    """The shape each type's rows were last written in (Writing.shapes)."""
    def shapes -> dict[str, str] abst;

    """Every row of the type `type_name`: asked only for a type whose shape
    the program has changed, to see that what is kept still fits."""
    def of_type(type_name: str) -> list[Row] abst;

    """The rows of `ids`, those it holds, in any order."""
    def rows(ids: list[str]) -> list[Row] abst;

    """Every edge at the node `id`, out of it and into it, in the order they
    were made."""
    def edges(id: str) -> list[Row] abst;

    """Where its writes are counted to: a number each write raises."""
    def mark -> int abst;

    """What was written after `mark`, by any user of the store; None when it
    no longer knows that far back, and what a program holds of it is to be
    read again."""
    def since(mark: int) -> Changed | None abst;

    """Keep what `w` writes, all of it or none, and give the mark it made.
    StoreConflict when a row is not at the version `w` has it at, or a user
    already has a root."""
    def write(w: Writing) -> int abst;

    """Every row it holds, each without its data: its id, its kind, an
    edge's two ends, and its version. What a sweep reads, a row at a
    time."""
    def every -> Iterator[Row] abst;

    """The id of the root of the user `user`, or "" before they have one."""
    def root_of(user: str) -> str abst;

    """Every user's root: never the shared one."""
    def roots -> list[str] abst;

    """The id of the space's one shared root, or "" before it has one. It is
    no user's: no user ID names it."""
    def shared_root -> str abst;
}
