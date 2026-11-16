"""The module the importer takes TABLE from, plus globals whose storage type
the importer must declare exactly as this module defines it."""

glob SECOND: i64 = 2,
     TABLE: list[i64] = [20, 21, 22];

glob ESC = "\x1b";
glob NONE_GLOB = None;
glob NONE_DECL: None = None;

obj Box {
    static has EMPTY: None = None;
}
