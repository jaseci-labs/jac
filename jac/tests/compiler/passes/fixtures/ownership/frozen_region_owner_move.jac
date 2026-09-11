"""A live immutable alias prevents moving its region owner."""

obj Snapshot {
    has region: imm Region;
}

def invalid -> int {
    region: own Region = Region();
    frozen = imm region;
    alias: imm Region = frozen;
    nested = alias;
    snapshot = Snapshot(region=frozen);
    return id(nested);
}
