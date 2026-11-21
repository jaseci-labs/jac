"""N1: a negated tuple-form `isinstance` inside an `or`-chain guard.

`UniScopeNode.get_enclosing_captures` writes its skip test as

    if ((tab is None) or (tab is self) or not isinstance(tab, (A, B, C, D)))

over a `Tab | None` local. Three things happen in one condition: an identity
test against `None`, an identity test against another object, and a negated
tuple-form `isinstance`. The plain (non-negated) tuple form lowers today, so
this fixture keeps both spellings side by side plus the four-`or` expansion
the workaround used, and every one of them reads a field back off the
narrowed value so a guard that lets the wrong member through is visible in
the answer rather than only in whether it compiled.
"""

obj Tab {
    has n: int = 0;
}


obj Ability(Tab) {}


obj ImplDef(Tab) {}


obj LambdaEx(Tab) {}


obj Tst(Tab) {}


obj Plain(Tab) {}


"""1..4 are capture-worthy tabs, 5 is not, anything else is unset."""
def mk_tab(flag: int) -> Tab | None {
    if flag == 1 {
        return Ability(n=11);
    }
    if flag == 2 {
        return ImplDef(n=22);
    }
    if flag == 3 {
        return LambdaEx(n=33);
    }
    if flag == 4 {
        return Tst(n=44);
    }
    if flag == 5 {
        return Plain(n=55);
    }
    return None;
}


"""The guard as `get_enclosing_captures` wants to write it."""
def negated_tuple_guard(flag: int) -> int {
    tab = mk_tab(flag);
    me = Plain(n=99);
    if (tab is None)
        or (tab is me)
        or not isinstance(tab, (Ability, ImplDef, LambdaEx, Tst)) {
        return -1;
    }
    return tab.n;
}


"""The same guard expanded into four `or`ed single-class tests (the workaround)."""
def negated_or_chain_guard(flag: int) -> int {
    tab = mk_tab(flag);
    me = Plain(n=99);
    tab_captures = isinstance(tab, Ability)
        or isinstance(tab, ImplDef)
        or isinstance(tab, LambdaEx)
        or isinstance(tab, Tst);
    if ((tab is None) or (tab is me) or not tab_captures) {
        return -1;
    }
    return tab.n;
}


"""A bare negated tuple-form test with no `or`-chain around it."""
def bare_negated_tuple(flag: int) -> int {
    tab = mk_tab(flag);
    if not isinstance(tab, (Ability, ImplDef, LambdaEx, Tst)) {
        return -1;
    }
    return tab.n;
}


"""The positive tuple form, which `update_expr_ctx_for_def` already uses."""
def plain_tuple_guard(flag: int) -> int {
    tab = mk_tab(flag);
    if isinstance(tab, (Ability, ImplDef, LambdaEx, Tst)) {
        return tab.n;
    }
    return -1;
}


"""A negated tuple test in an `elif` position, the other spelling in the tree."""
def negated_tuple_elif(flag: int) -> int {
    tab = mk_tab(flag);
    if tab is None {
        return -1;
    } elif not isinstance(tab, (Ability, ImplDef)) {
        return -2;
    }
    return tab.n;
}
