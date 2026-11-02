import from jaclang.osprey.constraints.algebra { add_expressions, eq }

import from time { perf_counter, }


def _vt(v: Variable, c: float = 1.0) -> Expression;


def _sum(parts: list[Expression]) -> Expression;


def _build_chain(s: Solver) -> dict[int, float];


def _tableau_state(s: Solver) -> str;


test "chained equalities solve deterministically with handles" {
    s = Solver();
    vals = _build_chain(s);
    assert len(vals) == 3;
    ids = sorted(vals.keys());
    assert vals[ids[0]] == 0.0;
    assert vals[ids[1]] == 10.0;
    assert vals[ids[2]] == 30.0;

    s2 = Solver();
    v2 = _build_chain(s2);
    assert v2 == vals;

    assert s.generation == 3;
}


test "successful adds return unique usable handles" {
    s = Solver();
    a = s.new_variable();

    r1 = s.add_constraint(eq(_vt(a)), provenance="spec:a==0");
    assert r1.ok;
    h1 = r1.handle;
    assert h1 is not None;
    assert s.has_constraint(h1);
    assert s.provenance_of(h1) == "spec:a==0";

    b = s.new_variable();
    r2 = s.add_constraint(eq(_vt(b)), provenance="spec:b==0");
    assert r2.ok;
    h2 = r2.handle;
    assert h2 is not None;
    assert h2.id != h1.id;
    assert not s.has_constraint(ConstraintHandle(id=h2.id + 100));
}


test "duplicate constraints are rejected by content hash" {
    s = Solver();
    x = s.new_variable();
    y = s.new_variable();

    e = _sum([_vt(x), _vt(y), Expression(constant=-10.0)]);
    r1 = s.add_constraint(eq(e), provenance="first");
    assert r1.ok;

    dup = s.add_constraint(eq(normalize_expression(e)), provenance="second",);
    assert not dup.ok;
    assert dup.error == SolveError.DUPLICATE_CONSTRAINT;
    assert dup.handle is None;
    assert dup.witness_provenance == ["first"];

    reordered = _sum([_vt(y), Expression(constant=-10.0), _vt(x)]);
    dup2 = s.add_constraint(eq(reordered));
    assert not dup2.ok;
    assert dup2.error == SolveError.DUPLICATE_CONSTRAINT;

    other_strength = Constraint(
        expression=e, relation=Relation.EQ, strength=StrengthTier.WEAK,
    );
    r3 = s.add_constraint(other_strength);
    assert r3.ok;

    assert s.generation == 2;
}


test "failed add rolls back tableau state exactly" {
    s = Solver();
    a = s.new_variable();
    b = s.new_variable();
    fresh = s.new_variable();

    assert s.add_constraint(eq(_vt(a))).ok;
    assert s.add_constraint(eq(add_expressions(_vt(b), Expression(constant=-5.0),))).ok;

    before = _tableau_state(s);

    bad = s.add_constraint(eq(add_expressions(_vt(a), Expression(constant=-7.0),)));
    assert not bad.ok;
    assert bad.error == SolveError.UNSATISFIABLE;

    after = _tableau_state(s);
    assert before == after;

    c = s.new_variable();
    ok_r = s.add_constraint(eq(add_expressions(_vt(c), Expression(constant=-2.0),)));
    assert ok_r.ok;
    assert s.snapshot().values[c.id] == 2.0;
}


test "unsatisfiable system via artificial variable rolls back" {
    s = Solver();
    w = s.new_variable();
    x = s.new_variable();
    y = s.new_variable();

    assert s.add_constraint(eq(_sum([_vt(w), _vt(x), Expression(constant=-4.0), ]))).ok;
    assert s.add_constraint(eq(_sum([_vt(w), _vt(x, -1.0), ]))).ok;

    before = _tableau_state(s);

    r1 = s.add_constraint(
        eq(_sum([_vt(y), _vt(w, -1.0), Expression(constant=-1.0), ]))
    );
    assert r1.ok;
    r2 = s.add_constraint(
        eq(_sum([_vt(y), _vt(w, -1.0), Expression(constant=-3.0), ]))
    );
    assert not r2.ok;
    assert r2.error == SolveError.UNSATISFIABLE;

    mid = _tableau_state(s);
    assert len(mid) > 0;

    s2 = Solver();
    w2 = s2.new_variable();
    x2 = s2.new_variable();
    y2 = s2.new_variable();
    assert s2.add_constraint(
        eq(_sum([_vt(w2), _vt(x2), Expression(constant=-4.0), ]))
    ).ok;
    assert s2.add_constraint(eq(_sum([_vt(w2), _vt(x2, -1.0), ]))).ok;
    assert s2.add_constraint(
        eq(_sum([_vt(y2), _vt(w2, -1.0), Expression(constant=-1.0), ]))
    ).ok;
    assert _tableau_state(s2) == _tableau_state(s);
    assert before != _tableau_state(s);
}


test "required inequality leaves variable at default bound" {
    s = Solver();
    x = s.new_variable();

    r = s.add_constraint(
        Constraint(
            expression=normalize_expression(_vt(x)),
            relation=Relation.LEQ,
            strength=StrengthTier.REQUIRED,
        )
    );
    assert r.ok;
    assert s.snapshot().values[x.id] == 0.0;
}


test "non-finite coefficients are rejected at the interface" {
    s = Solver();
    x = s.new_variable();

    huge = 1e308 * 10.0;
    bad = s.add_constraint(
        Constraint(
            expression=Expression(
                terms=[Term(variable=x, coefficient=huge)], constant=0.0,
            ),
            relation=Relation.EQ,
            strength=StrengthTier.REQUIRED,
        )
    );
    assert not bad.ok;
    assert bad.error == SolveError.NON_FINITE_VALUE;
    assert s.generation == 0;
}


test "reset returns solver to empty state" {
    s = Solver();
    a = s.new_variable();
    assert s.add_constraint(eq(_vt(a))).ok;
    s.reset();
    assert len(s.rows) == 0;
    assert len(s.cns) == 0;
    assert len(s.var_symbols) == 0;
    assert s.generation == 0;

    b = s.new_variable();
    assert s.add_constraint(eq(add_expressions(_vt(b), Expression(constant=-3.0),))).ok;
    assert s.snapshot().values[b.id] == 3.0;
}


obj LCG {
    has state: int = 12345;

    def next_int(bound: int) -> int;
    def next_float -> float;
}


def _absf(x: float) -> float;


def _contains_str(xs: list[str], x: str) -> bool;


def _residual_ok(s: Solver, cs: list[Constraint], vs: list[Variable]) -> bool;


test "property: constructed solvable systems satisfy all constraints" {
    for seed in range(1, 21) {
        rng = LCG(state=seed * 7919);
        s = Solver();
        vs: list[Variable] = [];
        n = 1 + rng.next_int(15);
        for i in range(n) {
            vs.append(s.new_variable());
        }

        targets: dict[int, float] = {};
        for v in vs {
            targets[v.id] = float(rng.next_int(21) - 10);
        }

        count = 1 + rng.next_int(30);
        cs: list[Constraint] = [];
        seen_keys: list[str] = [];
        for i in range(count) {
            k = 1 + rng.next_int(3);
            terms: list[Expression] = [];
            const: float = 0.0;
            picked: list[Variable] = [];
            for j in range(k) {
                v = vs[rng.next_int(len(vs))];
                if v in picked {
                    continue;
                }
                picked.append(v);
                sign = 1.0 if rng.next_int(2) == 0 else -1.0;
                coef = sign * float(1 + rng.next_int(5));
                terms.append(_vt(v, coef));
                const += coef * targets[v.id];
            }
            if len(terms) == 0 {
                continue;
            }
            roll = rng.next_int(3);
            rel = Relation.EQ;
            if roll == 1 {
                rel = Relation.LEQ;
                const += float(1 + rng.next_int(10));
            } elif roll == 2 {
                rel = Relation.GEQ;
                const -= float(1 + rng.next_int(10));
            }
            c = Constraint(
                expression=_sum(terms + [Expression(constant=-const)]),
                relation=rel,
                strength=StrengthTier.REQUIRED,
            );

            key = constraint_key(c);
            if _contains_str(seen_keys, key) {
                continue;
            }
            seen_keys.append(key);
            r = s.add_constraint(c);
            assert r.ok;
            cs.append(c);
        }

        snap = s.snapshot();
        assert _residual_ok(s, cs, vs);
        assert snap.generation == len(cs);
    }
}


test "property: same seed produces identical values" {
    for seed in range(1, 6) {
        vals_a = _seeded_system(seed);
        vals_b = _seeded_system(seed);
        assert vals_a == vals_b;
    }
}


def _seeded_system(seed: int) -> dict[int, float];


test "baseline timings print for progress log" {
    rows: list[Row] = [];
    for i in range(2000) {
        r = Row();
        r.insert_symbol(i + 1, 1.0);
        r.insert_symbol(i + 2, -0.5);
        rows.append(r);
    }
    t0 = perf_counter();
    acc = Row();
    for r in rows {
        acc.insert_row(r, 0.5);
    }
    t1 = perf_counter();

    s = Solver();
    vs: list[Variable] = [];
    for i in range(100) {
        vs.append(s.new_variable());
    }
    t2 = perf_counter();
    assert s.add_constraint(eq(_vt(vs[0]))).ok;
    for i in range(1, 100) {
        c = _sum([_vt(vs[i]), _vt(vs[i - 1], -1.0), Expression(constant=-1.0), ]);
        assert s.add_constraint(eq(c)).ok;
    }
    vals = s.snapshot().values;
    t3 = perf_counter();
    assert vals[vs[99].id] == 99.0;
}


def _fixture_expr(vs: list[Variable], pairs: list[any], const: float) -> Expression;


test "LexWeight compares tiers lexicographically" {
    strong = strength_weight(StrengthTier.STRONG);
    medium = strength_weight(StrengthTier.MEDIUM);
    weak = strength_weight(StrengthTier.WEAK);
    assert lex_compare(strong, medium) > 0;
    assert lex_compare(medium, weak) > 0;

    many_weak = LexWeight(tiers=[0.0, 0.0, 1000000.0]);
    assert lex_compare(strong, many_weak) > 0;
    assert lex_compare(many_weak, strong) < 0;
}


test "strong soft equality dominates weak equality" {
    s = Solver();
    x = s.new_variable();
    strong = Constraint(
        expression=_sum([_vt(x), Expression(constant=-10.0)]),
        relation=Relation.EQ,
        strength=StrengthTier.STRONG,
    );
    weak = Constraint(
        expression=_vt(x), relation=Relation.EQ, strength=StrengthTier.WEAK,
    );
    assert s.add_constraint(strong).ok;
    assert s.add_constraint(weak).ok;
    assert s.snapshot().values[x.id] == 10.0;
}


test "medium soft equality dominates weak equality" {
    s = Solver();
    x = s.new_variable();
    medium = Constraint(
        expression=_sum([_vt(x), Expression(constant=-7.0)]),
        relation=Relation.EQ,
        strength=StrengthTier.MEDIUM,
    );
    weak = Constraint(
        expression=_sum([_vt(x), Expression(constant=-2.0)]),
        relation=Relation.EQ,
        strength=StrengthTier.WEAK,
    );
    assert s.add_constraint(medium).ok;
    assert s.add_constraint(weak).ok;
    assert s.snapshot().values[x.id] == 7.0;
}


test "one strong error dominates many weak errors" {
    s = Solver();
    x = s.new_variable();
    strong = Constraint(
        expression=_sum([_vt(x), Expression(constant=-1000.0)]),
        relation=Relation.EQ,
        strength=StrengthTier.STRONG,
    );
    assert s.add_constraint(strong).ok;

    for i in range(1, 21) {
        weak = Constraint(
            expression=_sum([_vt(x), Expression(constant=-float(i))]),
            relation=Relation.EQ,
            strength=StrengthTier.WEAK,
        );
        assert s.add_constraint(weak).ok;
    }
    assert s.snapshot().values[x.id] == 1000.0;
}


test "soft inequality minimizes only its violating side" {
    s = Solver();
    x = s.new_variable();

    assert s.add_constraint(eq(_sum([_vt(x), Expression(constant=-3.0), ]))).ok;
    soft = Constraint(
        expression=_sum([_vt(x), Expression(constant=-1.0)]),
        relation=Relation.LEQ,
        strength=StrengthTier.STRONG,
    );
    assert s.add_constraint(soft).ok;
    assert s.snapshot().values[x.id] == 3.0;
}


def _must_handle(r: SolveResult) -> ConstraintHandle;


test "removal frees a variable for re-constraining" {
    s = Solver();
    a = s.new_variable();
    b = s.new_variable();

    r1 = s.add_constraint(eq(_vt(a)));
    r2 = s.add_constraint(
        eq(_sum([_vt(b), _vt(a, -1.0), Expression(constant=-10.0), ]))
    );
    assert r1.ok and r2.ok;
    snap = s.snapshot();
    assert snap.values[a.id] == 0.0 and snap.values[b.id] == 10.0;

    assert s.remove_constraint(_must_handle(r1)).ok;
    assert s.add_constraint(eq(_sum([_vt(a), Expression(constant=-5.0)]))).ok;
    snap = s.snapshot();
    assert snap.values[a.id] == 5.0 and snap.values[b.id] == 15.0;

    ghost = ConstraintHandle(id=99999);
    res = s.remove_constraint(ghost);
    assert not res.ok;
    assert res.error == SolveError.UNKNOWN_CONSTRAINT;
}


test "removing a soft constraint releases its objective weight" {
    s = Solver();
    x = s.new_variable();
    strong = s.add_constraint(
        Constraint(
            expression=_sum([_vt(x), Expression(constant=-10.0)]),
            relation=Relation.EQ,
            strength=StrengthTier.STRONG,
        )
    );
    weak = s.add_constraint(
        Constraint(
            expression=_sum([_vt(x), Expression(constant=-2.0)]),
            relation=Relation.EQ,
            strength=StrengthTier.WEAK,
        )
    );
    assert strong.ok and weak.ok;
    assert s.snapshot().values[x.id] == 10.0;

    assert s.remove_constraint(_must_handle(strong)).ok;
    assert s.snapshot().values[x.id] == 2.0;

    assert s.remove_constraint(_must_handle(weak)).ok;
    assert s.snapshot().values[x.id] == 0.0;
}


test "removal of required inequality drops only its slack row" {
    s = Solver();
    x = s.new_variable();
    y = s.new_variable();
    r_le = s.add_constraint(
        Constraint(
            expression=_sum([_vt(x), Expression(constant=-5.0)]),
            relation=Relation.LEQ,
            strength=StrengthTier.REQUIRED,
        )
    );
    r_ge = s.add_constraint(
        Constraint(
            expression=_sum([_vt(y), _vt(x, -1.0)]),
            relation=Relation.GEQ,
            strength=StrengthTier.REQUIRED,
        )
    );
    assert r_le.ok and r_ge.ok;
    rows_before = len(s.rows);
    assert s.remove_constraint(_must_handle(r_le)).ok;
    assert len(s.rows) == rows_before - 1;

    assert s.add_constraint(eq(_sum([_vt(y), Expression(constant=-9.0)]))).ok;
    assert s.add_constraint(eq(_vt(x))).ok;
    snap = s.snapshot();
    assert snap.values[x.id] == 0.0 and snap.values[y.id] == 9.0;

    assert snap.values[y.id] >= snap.values[x.id];
}


test "add/remove cycles return state to baseline" {
    s = Solver();
    a = s.new_variable();
    b = s.new_variable();
    c = s.new_variable();
    base_rows = len(s.rows);
    base_kinds = len(s.kinds);
    base_cns = len(s.cns);
    base_objective_cells = len(s.objective.cells);
    base_values = s.snapshot();

    handles: list[ConstraintHandle] = [];
    for i in range(1, 11) {
        vi = s.new_variable();
        r = s.add_constraint(eq(_sum([_vt(vi), Expression(constant=-float(i)), ])));
        assert r.ok;
        handles.append(_must_handle(r));
    }
    for h in handles {
        r = s.remove_constraint(h);
        assert r.ok;
    }

    assert len(s.rows) == base_rows;
    assert len(s.cns) == base_cns;
    assert len(s.handle_keys) == 0;
    assert len(s.provenance) == 0;
    assert len(s.objective.cells) == base_objective_cells;
    after = s.snapshot();

    for vid in sorted(after.values.keys()) {
        assert after.values[vid] == 0.0;
    }
    assert after.generation > base_values.generation;

    assert len(s.kinds) >= base_kinds;

    assert s.add_constraint(eq(_vt(a))).ok;
    assert s.add_constraint(
        eq(_sum([_vt(b), _vt(a, -1.0), Expression(constant=-7.0), ]))
    ).ok;
    snap = s.snapshot();
    assert snap.values[a.id] == 0.0 and snap.values[b.id] == 7.0;
}


test "edit variables track suggestions under hard constraints" {
    s = Solver();
    width = s.new_variable();
    child = s.new_variable();

    assert s.add_constraint(
        Constraint(
            expression=_vt(width),
            relation=Relation.GEQ,
            strength=StrengthTier.REQUIRED,
        )
    ).ok;
    assert s.add_constraint(
        Constraint(
            expression=_vt(child),
            relation=Relation.GEQ,
            strength=StrengthTier.REQUIRED,
        )
    ).ok;
    assert s.add_constraint(
        Constraint(
            expression=_sum([_vt(child), _vt(width, -0.5)]),
            relation=Relation.EQ,
            strength=StrengthTier.REQUIRED,
        )
    ).ok;

    assert s.add_edit_variable(width, StrengthTier.STRONG).ok;
    import from sys { stderr }
    stderr.write("rows=" + str(len(s.rows)) + "\n");
    for suggested in [40.0, 80.0, 20.0, 0.0] {
        r = s.suggest_value(width, suggested);
        if not r.ok {
            stderr.write("SUGGEST FAILED " + r.error.value + " " + r.message + "\n");
        }
        assert r.ok;
        snap = s.snapshot();
        stderr.write(
            "suggested="
                + str(suggested)
                + " width="
                + str(snap.values[width.id])
                + " child="
                + str(snap.values[child.id])
                + "\n"
        );
        assert snap.values[width.id] == suggested;
        assert abs(snap.values[child.id] - suggested / 2.0) < 1e-9;
    }
}


test "edit variable API rejects misuse with typed errors" {
    s = Solver();
    x = s.new_variable();
    y = s.new_variable();

    res = s.suggest_value(x, 1.0);
    assert not res.ok;
    assert res.error == SolveError.UNKNOWN_EDIT_VARIABLE;

    res = s.add_edit_variable(x, StrengthTier.REQUIRED);
    assert not res.ok;
    assert res.error == SolveError.REQUIRED_EDIT_VARIABLE;

    assert s.add_edit_variable(x, StrengthTier.WEAK).ok;
    res = s.add_edit_variable(x, StrengthTier.WEAK);
    assert not res.ok;
    assert res.error == SolveError.DUPLICATE_EDIT_VARIABLE;

    assert s.add_edit_variable(y, StrengthTier.MEDIUM).ok;
    assert s.has_edit_variable(x) and s.has_edit_variable(y);

    assert s.remove_edit_variable(x).ok;
    assert not s.has_edit_variable(x);
    res = s.remove_edit_variable(x);
    assert not res.ok;
    assert res.error == SolveError.UNKNOWN_EDIT_VARIABLE;
    assert s.has_edit_variable(y);
}


test "suggestion yields to stronger constraints via dual optimize" {
    s = Solver();
    x = s.new_variable();

    assert s.add_constraint(
        Constraint(
            expression=_sum([_vt(x), Expression(constant=-5.0)]),
            relation=Relation.LEQ,
            strength=StrengthTier.REQUIRED,
        )
    ).ok;

    assert s.add_edit_variable(x, StrengthTier.WEAK).ok;
    assert s.suggest_value(x, 3.0).ok;
    assert s.snapshot().values[x.id] == 3.0;

    assert s.suggest_value(x, 100.0).ok;
    assert s.snapshot().values[x.id] == 5.0;

    assert s.suggest_value(x, 1.0).ok;
    assert s.snapshot().values[x.id] == 1.0;
}


test "incremental suggestion matches a from-scratch solve" {
    inc = Solver();
    width_i = inc.new_variable();
    top_i = inc.new_variable();
    height_i = inc.new_variable();
    assert inc.add_constraint(
        Constraint(
            expression=_sum([_vt(height_i), _vt(top_i, -1.0), _vt(width_i, -1.0)]),
            relation=Relation.EQ,
            strength=StrengthTier.REQUIRED,
        )
    ).ok;
    assert inc.add_edit_variable(width_i, StrengthTier.STRONG).ok;
    assert inc.add_edit_variable(top_i, StrengthTier.STRONG).ok;
    assert inc.suggest_value(width_i, 40.0).ok;
    assert inc.suggest_value(top_i, 10.0).ok;
    assert inc.suggest_value(width_i, 60.0).ok;
    assert inc.suggest_value(top_i, 2.0).ok;

    fresh = Solver();
    width_f = fresh.new_variable();
    top_f = fresh.new_variable();
    height_f = fresh.new_variable();
    assert fresh.add_constraint(
        Constraint(
            expression=_sum([_vt(height_f), _vt(top_f, -1.0), _vt(width_f, -1.0)]),
            relation=Relation.EQ,
            strength=StrengthTier.REQUIRED,
        )
    ).ok;
    assert fresh.add_constraint(
        eq(_sum([_vt(width_f), Expression(constant=-60.0), ]))
    ).ok;
    assert fresh.add_constraint(eq(_sum([_vt(top_f), Expression(constant=-2.0), ]))).ok;

    si = inc.snapshot().values;
    sf = fresh.snapshot().values;
    assert si[width_i.id] == sf[width_f.id];
    assert si[top_i.id] == sf[top_f.id];
    assert si[height_i.id] == sf[height_f.id];

    assert si[height_i.id] == 62.0;
}


test "edit removal releases its constraint from the system" {
    s = Solver();
    x = s.new_variable();
    assert s.add_edit_variable(x, StrengthTier.STRONG).ok;
    assert s.suggest_value(x, 12.0).ok;
    assert s.snapshot().values[x.id] == 12.0;

    handles_before = len(s.handle_keys);
    assert s.remove_edit_variable(x).ok;
    assert len(s.handle_keys) == handles_before - 1;

    assert s.snapshot().values[x.id] == 0.0;
    assert s.add_edit_variable(x, StrengthTier.MEDIUM).ok;
    assert s.suggest_value(x, 4.0).ok;
    assert s.snapshot().values[x.id] == 4.0;
}


test "rebuild adoption swaps the full mutable state including worklist" {
    s = Solver();
    x = s.new_variable();
    y = s.new_variable();

    assert s.add_constraint(eq(_vt(x, 1.0))).ok;
    assert s.add_constraint(
        Constraint(
            expression=_vt(y, 1.0), relation=Relation.EQ, strength=StrengthTier.WEAK
        )
    ).ok;

    bundle = s._replay_all(s.history);
    assert bundle is not None;

    stale = bundle.id_tick + 999;
    s.infeasible_rows.append(stale);

    s._adopt(bundle);

    assert s.infeasible_rows == bundle.infeasible_rows;
    assert stale not in s.infeasible_rows;

    assert sorted(s.rows.keys()) == sorted(bundle.rows.keys());
    assert sorted(s.var_symbols.keys()) == sorted(bundle.var_symbols.keys());
    assert s.id_tick == bundle.id_tick;
    assert len(s.cns) == len(bundle.cns);
    assert len(s.handle_keys) == 2;
}

impl _vt(v: Variable, c: float = 1.0) -> Expression {
    return Expression(terms=[Term(variable=v, coefficient=c)]);
}


impl _sum(parts: list[Expression]) -> Expression {
    acc = Expression();
    for p in parts {
        acc = add_expressions(acc, p);
    }
    return acc;
}


impl _build_chain(s: Solver) -> dict[int, float] {
    a = s.new_variable();
    b = s.new_variable();
    c = s.new_variable();

    r1 = s.add_constraint(eq(_vt(a)));
    assert r1.ok;
    r2 = s.add_constraint(
        eq(_sum([_vt(b), _vt(a, -1.0), Expression(constant=-10.0), ]))
    );
    assert r2.ok;
    r3 = s.add_constraint(
        eq(_sum([_vt(c), _vt(b, -1.0), Expression(constant=-20.0), ]))
    );
    assert r3.ok;
    return s.snapshot().values;
}


impl _tableau_state(s: Solver) -> str {
    parts: list[str] = [];
    parts.append("tick=" + str(s.id_tick));
    parts.append("gen=" + str(s.generation));
    for vid in sorted(s.var_symbols.keys()) {
        parts.append("var" + str(vid) + "->sym" + str(s.var_symbols[vid]));
    }
    for sym in sorted(s.kinds.keys()) {
        parts.append("kind" + str(sym) + "=" + s.kinds[sym].value);
    }
    for sym in sorted(s.rows.keys()) {
        row = s.rows[sym];
        cells: list[str] = [];
        for cid in sorted(row.cells.keys()) {
            cells.append(str(cid) + ":" + repr(row.cells[cid]));
        }
        parts.append(
            "row" + str(sym) + "[" + repr(row.constant) + ";" + ",".join(cells) + "]"
        );
    }
    return "|".join(parts);
}


impl LCG.next_int(bound: int) -> int {
    self.state = (self.state * 1103515245 + 12345) % 2147483648;
    return self.state % bound;
}

impl LCG.next_float -> float {
    return float(self.next_int(20001) - 10000) / 1000.0;
}


impl _absf(x: float) -> float {
    return x if x >= 0.0 else -x;
}


impl _contains_str(xs: list[str], x: str) -> bool {
    for e in xs {
        if e == x {
            return True;
        }
    }
    return False;
}


impl _residual_ok(s: Solver, cs: list[Constraint], vs: list[Variable]) -> bool {
    snap = s.snapshot().values;
    for c in cs {
        total: float = c.expression.constant;
        for t in c.expression.terms {
            total += t.coefficient * snap[t.variable.id];
        }
        if c.relation == Relation.EQ {
            if _absf(total) > 1e-6 * (1.0 + _absf(c.expression.constant)) {
                return False;
            }
        } elif c.relation == Relation.LEQ {
            if total > 1e-6 * (1.0 + _absf(c.expression.constant)) {
                return False;
            }
        } else {
            if total < -1e-6 * (1.0 + _absf(c.expression.constant)) {
                return False;
            }
        }
    }
    return True;
}


impl _seeded_system(seed: int) -> dict[int, float] {
    rng = LCG(state=seed * 104729 + 17);
    s = Solver();
    vs: list[Variable] = [];
    n = 5 + rng.next_int(10);
    for i in range(n) {
        vs.append(s.new_variable());
    }

    s.add_constraint(eq(_vt(vs[0])));
    for i in range(1, n) {
        anchor = vs[rng.next_int(i)];
        coef = float(1 + rng.next_int(5));
        offset = float(rng.next_int(50));
        s.add_constraint(
            eq(_sum([_vt(vs[i]), _vt(anchor, -coef), Expression(constant=-offset), ]))
        );
    }
    return s.snapshot().values;
}


impl _fixture_expr(vs: list[Variable], pairs: list[any], const: float) -> Expression {
    acc: Expression = Expression(constant=const);
    for pair in pairs {
        plist: list[any] = pair as list[any];
        vid: int = int(plist[0] as int);
        coef: float = plist[1] as float;
        acc = add_expressions(
            acc, Expression(terms=[Term(variable=vs[vid], coefficient=coef)]),
        );
    }
    return acc;
}


impl _must_handle(r: SolveResult) -> ConstraintHandle {
    assert r.ok;
    h = r.handle;
    if h is None {
        raise ValueError("successful add returned no handle");
    }
    return h;
}
