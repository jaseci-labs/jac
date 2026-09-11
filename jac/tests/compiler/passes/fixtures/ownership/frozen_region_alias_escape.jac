"""A borrowed frozen alias cannot outlive its local owner."""

def escape -> imm Region {
    region: own Region = Region();
    frozen = imm region;
    alias = frozen;
    return alias;
}
