obj InferredHint {
    has line: int,
        col: int,
        label: str,
        kind: str;
}

def ownership_label(kind: OwnershipKind, linear: bool = False) -> (str | None);

def receiver_label(kind: OwnershipKind) -> (str | None);

def _explicit_self(ab: Ability) -> bool;

def _end_of(nd: Name) -> tuple[int, int];

def inferred_hints(mod: Module) -> list[InferredHint];
