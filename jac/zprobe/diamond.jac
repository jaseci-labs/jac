obj DA { has x: int = 1; }
obj DB(DA) { has x: int = 2; }
obj DC(DB) {}

obj MA { def m() -> int { return 1; } }
obj MB(MA) {}
obj MC(MA) { def m() -> int { return 3; } }
obj MD(MB, MC) {}

with entry {
    assert MD().m() == 3;
    assert DC().x == 2;
}
