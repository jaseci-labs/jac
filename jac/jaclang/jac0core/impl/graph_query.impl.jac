impl QPred.postinit -> None {
    if self.op not in QUERY_OPS {
        raise ValueError(f"QPred op '{self.op}' outside the closed query sublanguage");
    }
    if self.op == 'in' {
        if not isinstance(self.value, (list, tuple, set, frozenset)) {
            raise TypeError(
                f"QPred 'in' requires a collection of scalars, got "
                f"{type(self.value).__name__}"
            );
        }
        for item in self.value {
            if item is not None and not isinstance(item, SCALARS) {
                raise TypeError(
                    f"QPred 'in' collection holds non-scalar " f"{type(item).__name__}"
                );
            }
        }
    } elif self.value is not None and not isinstance(self.value, SCALARS) {
        raise TypeError(
            f"QPred value for '{self.field}' must be a scalar, got "
            f"{type(self.value).__name__}"
        );
    }
    if self.op in ORDERED_OPS and not isinstance(self.value, (str, int, float)) {
        raise TypeError(
            f"QPred ordering op '{self.op}' requires a str/int/float value, "
            f"got {type(self.value).__name__}"
        );
    }
}


impl QPred.matches(subject: any) -> bool {
    val = self.value;
    if self.op == '==' {
        return subject == val;
    }
    if self.op == '!=' {
        return subject != val;
    }
    if self.op == 'in' {
        if isinstance(val, (list, tuple, set, frozenset)) {
            return subject in val;
        }
        return False;
    }

    if isinstance(subject, (int, float)) and isinstance(val, (int, float)) {
        if self.op == '<' {
            return subject < val;
        }
        if self.op == '<=' {
            return subject <= val;
        }
        if self.op == '>' {
            return subject > val;
        }
        return subject >= val;
    }
    if isinstance(subject, str) and isinstance(val, str) {
        if self.op == '<' {
            return subject < val;
        }
        if self.op == '<=' {
            return subject <= val;
        }
        if self.op == '>' {
            return subject > val;
        }
        return subject >= val;
    }
    return False;
}


impl QPred.repr -> str {
    return f"{self.field} {self.op} {self.value!r}";
}


impl QHop.add_node_constraint(node_type: (type | None)) -> None {
    if node_type is None {
        return;
    }
    if self.nd is None {
        self.nd = node_type;
    } elif isinstance(self.nd, tuple) {
        self.nd = self.nd + (node_type, );
    } else {
        self.nd = (self.nd, node_type);
    }
}


impl QHop.only_ids -> (set | None) {
    if self.only is None {
        return None;
    }
    sel = self.only if isinstance(self.only, (list, tuple, set)) else [self.only];
    out: set = set();
    for item in sel {
        anch = item?.__jac__;
        if isinstance(anch, Anchor) {
            out.add(anch.id);
        }
    }
    return out;
}


impl QHop.repr -> str {
    dir_mark = {1: '<--', 2: '-->', 3: '<->'}.get(self.dir, '?');
    et: str = self.`edge.__name__ if self.`edge is not None else '*';
    nt: str;
    if isinstance(self.nd, tuple) {
        nt = '&'.join(t.__name__ for t in self.nd);
    } else {
        nt = self.nd.__name__ if self.nd is not None else '*';
    }
    parts: list[str] = [f"{dir_mark}:{et}:{nt}"];
    if self.epreds {
        parts.append('e[' + ', '.join(p.repr() for p in self.epreds) + ']');
    }
    if self.preds {
        parts.append('n[' + ', '.join(p.repr() for p in self.preds) + ']');
    }
    return ' '.join(parts);
}


impl GraphQuery.init(
    origin: any,
    hops: (list[QHop] | None) = None,
    edges_only: bool = False,
    slc: (slice | None) = None,
    level: str = 'default'
) -> None {
    self.origin = origin if isinstance(origin, list) else [origin];
    self.hops = hops if hops is not None else [];
    self.edges_only = edges_only;
    self.from_visit = False;
    self.slc = slc;
    self.level = level;
}


impl GraphQuery.`visit -> GraphQuery {
    self.from_visit = True;
    return self;
}


impl GraphQuery.narrow(
    nd: (type | None) = None, preds: (list[QPred] | None) = None, only: any = None
) -> GraphQuery {
    if not self.hops {
        self.hops.append(QHop(dir=2));
    }
    last = self.hops[-1];
    last.add_node_constraint(nd);
    if preds {
        last.preds.extend(preds);
    }
    if only is not None {
        last.only = only;
    }
    return self;
}


impl GraphQuery.repr -> str {
    hops = ' '.join(h.repr() for h in self.hops);
    tail = '';
    if self.slc is not None {
        tail += f" [{self.slc.start}:{self.slc.stop}]";
    }
    if self.edges_only {
        tail += ' edges';
    }
    if self.level != 'default' {
        tail += f" level={self.level}";
    }
    return f"GraphQuery(|origin|={len(self.origin)} {hops}{tail})";
}
