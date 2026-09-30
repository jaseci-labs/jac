def version_key(v: str) -> tuple[int, int, int] {
    parts = (v.strip().split(".") + ["0", "0", "0"])[:3];
    out: list[int] = [];
    for p in parts {
        digits = "".join(
            [
                c
                for c in p
                if c.isdigit()
            ]
        );
        out.append(int(digits) if digits else 0);
    }
    return (out[0], out[1], out[2]);
}

def is_plain_version(s: str) -> bool {
    return all([p.isdigit() for p in s.strip().split(".")]);
}

def split_clause(clause: str) -> tuple[str, str] {
    for op in ["==", "!=", ">=", "<=", "~=", ">", "<"] {
        if clause.startswith(op) {
            return (op, clause[len(op):].strip());
        }
    }
    return ("==", clause.strip());
}

def satisfies(version: str, spec: str) -> bool {
    v = version_key(version);
    for raw in spec.split(",") {
        clause = raw.strip();
        if not clause {
            continue;
        }
        (op, target) = split_clause(clause);
        t = version_key(target);
        if op == "==" and v != t {
            return False;
        } elif op == "!=" and v == t {
            return False;
        } elif op == ">=" and v < t {
            return False;
        } elif op == "<=" and v > t {
            return False;
        } elif op == ">" and v <= t {
            return False;
        } elif op == "<" and v >= t {
            return False;
        } elif op == "~=" {
            ncomp = len(
                [
                    x
                    for x in target.split(".")
                    if x != ""
                ]
            );
            cap = (t[0], t[1] + 1, 0) if ncomp >= 3 else (t[0] + 1, 0, 0);
            if v < t or v >= cap {
                return False;
            }
        }
    }
    return True;
}

def exact_pin(spec: str) -> str {
    clauses = [
        c.strip()
        for c in spec.split(",")
        if c.strip()
    ];
    if len(clauses) != 1 {
        return "";
    }
    (op, target) = split_clause(clauses[0]);
    if op == "==" and is_plain_version(target) {
        return target;
    }
    return "";
}
