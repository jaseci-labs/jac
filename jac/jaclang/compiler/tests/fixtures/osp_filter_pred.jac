"""Cross-backend OSP equivalence fixture: field-predicate filters (#7626 B2).

Predicates over filter comprehensions whose element layout the checker
already knows from a type filter: the chained form `[...][?:Item][?done ==
False]`, the combined form `[?:Item, val > 1]`, and multi-predicate AND
`[?:Item, val > 1, done == False]`. Backend status: py is the oracle; na
lowers each predicate as a per-element field load + compare loop over the
layout registry. The body is duplicated per backend fn (fixture idiom) so
each leg runs fully in its own codespace.
"""

node Item {
    has val: int,
        done: bool;
}

def filter_pred_py -> dict[str, any] {
    hub = Item(val=0, done=True);
    a = Item(val=1, done=False);
    b = Item(val=2, done=True);
    c = Item(val=3, done=False);
    hub ++> a;
    hub ++> b;
    hub ++> c;
    pending = [hub-->[?:Item]][?done==False];
    combined = [hub-->[?:Item, val>1]];
    multi = [hub-->[?:Item, val>1, done==False]];
    inchain = [hub-->[?:Item, done==False]];
    pending_vals: list[int] = [];
    for i in pending {
        pending_vals.append(i.val);
    }
    combined_vals: list[int] = [];
    for i in combined {
        combined_vals.append(i.val);
    }
    multi_vals: list[int] = [];
    for i in multi {
        multi_vals.append(i.val);
    }
    inchain_vals: list[int] = [];
    for i in inchain {
        inchain_vals.append(i.val);
    }
    return {
        "pending": pending_vals,
        "combined": combined_vals,
        "multi": multi_vals,
        "inchain": inchain_vals
    };
}

na {
    def filter_pred_na -> dict[str, any] {
        hub = Item(val=0, done=True);
        a = Item(val=1, done=False);
        b = Item(val=2, done=True);
        c = Item(val=3, done=False);
        hub ++> a;
        hub ++> b;
        hub ++> c;
        pending = [hub-->[?:Item]][?done==False];
        combined = [hub-->[?:Item, val>1]];
        multi = [hub-->[?:Item, val>1, done==False]];
        inchain = [hub-->[?:Item, done==False]];
        pending_vals: list[int] = [];
        for i in pending {
            pending_vals.append(i.val);
        }
        combined_vals: list[int] = [];
        for i in combined {
            combined_vals.append(i.val);
        }
        multi_vals: list[int] = [];
        for i in multi {
            multi_vals.append(i.val);
        }
        inchain_vals: list[int] = [];
        for i in inchain {
            inchain_vals.append(i.val);
        }
        return {
            "pending": pending_vals,
            "combined": combined_vals,
            "multi": multi_vals,
            "inchain": inchain_vals
        };
    }
}

cl {
    def filter_pred_cl -> dict[str, any] {
        hub = Item(val=0, done=True);
        a = Item(val=1, done=False);
        b = Item(val=2, done=True);
        c = Item(val=3, done=False);
        hub ++> a;
        hub ++> b;
        hub ++> c;
        pending = [hub-->[?:Item]][?done==False];
        combined = [hub-->[?:Item, val>1]];
        multi = [hub-->[?:Item, val>1, done==False]];
        inchain = [hub-->[?:Item, done==False]];
        pending_vals: list[int] = [];
        for i in pending {
            pending_vals.append(i.val);
        }
        combined_vals: list[int] = [];
        for i in combined {
            combined_vals.append(i.val);
        }
        multi_vals: list[int] = [];
        for i in multi {
            multi_vals.append(i.val);
        }
        inchain_vals: list[int] = [];
        for i in inchain {
            inchain_vals.append(i.val);
        }
        return {
            "pending": pending_vals,
            "combined": combined_vals,
            "multi": multi_vals,
            "inchain": inchain_vals
        };
    }
}
