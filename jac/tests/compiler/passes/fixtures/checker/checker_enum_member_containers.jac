enum Op { LT, GT, LTE }

def take_str(sym: str) -> str {
    return sym;
}

def take_int(n: int) -> int {
    return n;
}

def take_op(o: Op) -> Op {
    return o;
}

def by_member(op: Op) -> str {
    sym = {Op.LT: "<", Op.GT: ">"}[op];
    return take_str(sym);
}

def member_values(k: str) -> Op {
    table = {"a": Op.LT, "b": Op.GT};
    table["c"] = Op.LTE;
    return take_op(table[k]);
}

def member_list(op: Op) -> Op {
    items = [Op.LT, Op.GT];
    items.append(op);
    return take_op(items[0]);
}

def member_set(op: Op) -> bool {
    seen = {Op.LT, Op.GT};
    seen.add(op);
    return op in seen;
}

def still_typed(op: Op) -> int {
    sym = {Op.LT: "<", Op.GT: ">"}[op];
    return take_int(sym);
}
