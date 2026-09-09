import from jaclang.compiler.frontend.constant { OwnershipKind }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Assignment,
    FuncSignature,
    Module,
    Name
}

obj InferredHint {
    has line: int,
        col: int,
        label: str,
        kind: str;
}

def ownership_label(kind: OwnershipKind, linear: bool = False) -> (str | None) {
    if linear {
        return "lin";
    }
    if kind == OwnershipKind.OWN {
        return "own";
    }
    if kind == OwnershipKind.BORROW {
        return "&";
    }
    if kind == OwnershipKind.MUT_BORROW {
        return "&mut";
    }
    if kind == OwnershipKind.IMM {
        return "imm";
    }
    return None;
}

def receiver_label(kind: OwnershipKind) -> (str | None) {
    if kind == OwnershipKind.OWN {
        return "own self";
    }
    if kind == OwnershipKind.MUT_BORROW {
        return "&mut self";
    }
    if kind == OwnershipKind.BORROW {
        return "&self";
    }
    return None;
}

def _explicit_self(ab: Ability) -> bool {
    sig = ab.signature;
    if not isinstance(sig, FuncSignature) {
        return False;
    }
    params = sig.get_parameters();
    return bool(params)
        and params[0].name is not None
        and params[0].name.sym_name == "self";
}

def _end_of(nd: Name) -> tuple {
    loc = nd.loc;
    return (loc.last_line or loc.first_line, loc.col_end or loc.col_start);
}

def inferred_hints(mod: Module) -> list[InferredHint] {
    hints: list[InferredHint] = [];
    for asg in mod.get_all_sub_nodes(Assignment) {
        if len(asg.target) != 1 or not isinstance(asg.target[0], Name) {
            continue;
        }
        tgt = asg.target[0];
        sym = tgt.sym;
        if sym is None {
            continue;
        }
        explicit = asg.type_tag is not None
            and asg.type_tag.ownership != OwnershipKind.NONE;
        label = None if explicit else ownership_label(sym.ownership, sym.linear);
        (line, col) = _end_of(tgt);
        if label is not None {
            hints.append(
                InferredHint(line=line, col=col, label=f": {label}", kind="type")
            );
        }
        if sym.is_view {
            hints.append(InferredHint(line=line, col=col, label=" view", kind="type"));
        }
    }
    for ab in mod.get_all_sub_nodes(Ability) {
        if ab.name_ref is None or not isinstance(ab.name_ref, Name) {
            continue;
        }
        (line, col) = _end_of(ab.name_ref);
        rlabel = receiver_label(ab.receiver_mode);
        if rlabel is not None and ab.is_method and not _explicit_self(ab) {
            hints.append(
                InferredHint(line=line, col=col, label=f"({rlabel})", kind="parameter")
            );
        }
        if ab.raises {
            hints.append(
                InferredHint(
                    line=line,
                    col=col,
                    label=" raises " + ", ".join(ab.raises),
                    kind="type"
                )
            );
        }
    }
    return hints;
}
