"""C integer data-model rules, independent of Jac syntax emission."""
obj CEmitConfig {
    has abi: str = "lp64",
        char_signed: bool = True;
}


obj CScalar {
    has width: int = 32,
        signed: bool = True,
        rank: int = 3,
        category: str = "integer";
    has jac: str {
        getter {
            if self.category == "void" { return "None"; }
            if self.category == "bool" { return "bool"; }
            return ("i" if self.signed else "u") + str(self.width);
        }
    }
}


def compatible(a: CScalar, b: CScalar) -> bool {
    return a.width == b.width and a.signed == b.signed and a.rank == b.rank and a.category == b.category;
}


def promote(typ: CScalar) -> CScalar {
    return CScalar() if typ.rank < 3 else typ;
}


def common(a: CScalar, b: CScalar) -> CScalar {
    left = promote(a); right = promote(b);
    if left.signed == right.signed { return left if left.rank >= right.rank else right; }
    unsigned = right if left.signed else left; signed = left if left.signed else right;
    if unsigned.rank >= signed.rank { return unsigned; }
    if signed.width > unsigned.width { return signed; }
    return CScalar(signed.width, False, signed.rank);
}

