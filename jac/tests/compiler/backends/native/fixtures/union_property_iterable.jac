glob receiver_calls: int = 0,
     receiver_drops: int = 0;
obj Value {
    has amount: int;
}
obj Pair {}
obj Expr {
    def drop {
        receiver_drops += 1;
    }
}

obj TupleExpr(Expr) {
    has stored: list[Value | Pair];
    has values: list[Value | Pair] {
        getter {
            return self.stored;
        }
    }
}

obj ListExpr(Expr) {
    has stored: list[Value];
    has values: list[Value] {
        getter {
            return self.stored;
        }
    }
}

obj Compr {
    has target: Expr;
}
def total(c: Compr) -> int {
    answer = 0;
    if isinstance(c.target, (TupleExpr, ListExpr)) {
        for value in c.target.values {
            if isinstance(value, Value) {
                answer += value.amount;
            }
        }
    }
    return answer;
}

def probe -> int {
    return total(Compr(ListExpr([Value(3)])))
        + total(Compr(TupleExpr([Value(5), Pair()])));
}

def choose(flag: bool) -> TupleExpr | ListExpr {
    receiver_calls += 1;
    if flag {
        return TupleExpr([Value(5), Pair()]);
    }
    return ListExpr([Value(3)]);
}

def called(flag: bool) -> int {
    answer = 0;
    for value in choose(flag).values {
        if isinstance(value, Value) {
            answer += value.amount;
        }
    }
    return answer;
}

def named(flag: bool) -> int {
    selected = choose(flag);
    answer = 0;
    for value in selected.values {
        if isinstance(value, Value) {
            answer += value.amount;
        }
    }
    return answer;
}

def calls -> int {
    return receiver_calls;
}
def drops -> int {
    return receiver_drops;
}

with entry {
    print(probe());
    print(called(True));
    print(called(False));
    print(named(True));
    print(named(False));
}
