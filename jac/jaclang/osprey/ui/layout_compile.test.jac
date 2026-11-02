import from jaclang.osprey.ui.layout_types_core {
    Axis,
    AxisSize,
    LayoutRelation,
    LayoutRelationKind,
    LayoutSpec
}
import from jaclang.osprey.ui.layout_types {
    add_relation,
    create_layout_state,
    set_spec
}
import from jaclang.osprey.ui.model {
    Child,
    Header,
    MainScreen,
    Prompt,
    Status,
    TranscriptView
}


def _solver_of(r: CompileResult) -> Solver;


def _fill -> AxisSize;


def _fixed(n: float) -> AxisSize;


def _grow(weight: float) -> AxisSize;


def _intrinsic -> AxisSize;


obj _ShellFixture {
    has state: LayoutState,
        screen: MainScreen,
        header: Header,
        transcript: TranscriptView,
        status: Status,
        prompt: Prompt;
}


def _shell_state(columns: int = 80, rows: int = 24) -> _ShellFixture;


test "root pins to viewport and grow child absorbs the remainder" {
    m = _shell_state();
    r = compile_layout(m.state, m.screen, Viewport(columns=80, rows=24));
    assert r.ok;
    for d in r.diagnostics {
        assert d.severity == LayoutSeverity.WARNING;
    }

    snap = _solver_of(r).snapshot();
    edges = r.nodes[node_id(m.transcript)];
    top = snap.values[edges.top.id];
    bottom = snap.values[edges.bottom.id];

    assert top == 1.0;
    assert bottom == 21.0;
    assert bottom - top == 20.0;

    root_edges = r.nodes[node_id(m.screen)];
    assert snap.values[root_edges.left.id] == 0.0;
    assert snap.values[root_edges.top.id] == 0.0;
    assert snap.values[root_edges.right.id] == 80.0;
    assert snap.values[root_edges.bottom.id] == 24.0;

    assert snap.values[edges.left.id] == 0.0;
    assert snap.values[edges.right.id] == 80.0;
}


test "every generated constraint carries provenance with template and node" {
    m = _shell_state();
    r = compile_layout(m.state, m.screen, Viewport(columns=80, rows=24));
    assert r.ok;
    found_templates: list[str] = [];
    for pv in _solver_of(r).provenance.values() {
        if "template=grow" in pv {
            found_templates.append(pv);
        }
    }
    assert len(found_templates) >= 1;
    for pv in found_templates {
        assert "node=" in pv;
        assert "parent=" in pv;
        assert "src=spec" in pv;
        assert "weight=" in pv;
        assert "target=" in pv;
    }
}


test "scoped node without a spec is rejected as INVALID_SPEC" {
    m = _shell_state();
    stranger = Prompt(key="stranger");
    m.screen +>:Child(rank=9999):+> stranger;
    r = compile_layout(m.state, m.screen, Viewport(columns=80, rows=24));
    assert not r.ok;
    assert r.diagnostics[0].code == LayoutError.INVALID_SPEC;
}


test "relation endpoint outside scope is rejected as OUT_OF_SCOPE" {
    m = _shell_state();
    outsider = Prompt(key="outsider");
    set_spec(m.state, outsider, LayoutSpec(width=_fill(), height=_fixed(1.0)));
    rel = LayoutRelation(
        owner_id=node_id(m.screen),
        source_id=node_id(m.prompt),
        target_id=node_id(outsider),
        kind=LayoutRelationKind.BELOW,
        axis=Axis.VERTICAL,
        provenance="test",
    );
    from_state = m.state;
    handle_res = add_relation(from_state, rel);
    assert handle_res.ok;
    r = compile_layout(from_state, m.screen, Viewport(columns=80, rows=24));
    assert not r.ok;
    codes: list[str] = [];
    for d in r.diagnostics {
        codes.append(d.code.value);
    }
    assert "out_of_scope" in codes;
}


test "relation owner that is not the direct parent is INVALID_TOPOLOGY" {
    m = _shell_state();

    rel = LayoutRelation(
        owner_id=node_id(m.status),
        source_id=node_id(m.header),
        target_id=node_id(m.prompt),
        kind=LayoutRelationKind.SAME_SIZE,
        axis=Axis.HORIZONTAL,
        provenance="test",
    );
    st = m.state;
    hr = add_relation(st, rel);
    assert hr.ok;
    r = compile_layout(st, m.screen, Viewport(columns=80, rows=24));
    assert not r.ok;
    for d in r.diagnostics {
        if d.code == LayoutError.INVALID_TOPOLOGY {
            return;
        }
    }
    assert False;
}


test "conflicting REQUIRED relation makes compilation unsatisfiable" {
    m = _shell_state();

    set_spec(m.state, m.header, LayoutSpec(width=_fixed(30.0), height=_fixed(1.0)),);
    set_spec(m.state, m.status, LayoutSpec(width=_fixed(45.0), height=_fixed(1.0)),);
    rel = LayoutRelation(
        owner_id=node_id(m.screen),
        source_id=node_id(m.header),
        target_id=node_id(m.status),
        kind=LayoutRelationKind.SAME_SIZE,
        axis=Axis.HORIZONTAL,
        provenance="test-conflict",
    );
    st = m.state;
    hr = add_relation(st, rel);
    assert hr.ok;
    r = compile_layout(st, m.screen, Viewport(columns=80, rows=24));
    assert not r.ok;
    unsat = [
        d
        for d in r.diagnostics
        if d.code == LayoutError.UNSATISFIABLE
    ];
    assert len(unsat) == 1;
    assert len(unsat[0].provenance) >= 1;
}


test "overflow keeps the frame satisfiable and attaches a WARNING" {
    m = _shell_state(rows=3);
    r = compile_layout(m.state, m.screen, Viewport(columns=80, rows=3));
    overflow = [
        d
        for d in r.diagnostics
        if d.code == LayoutError.OVERFLOW
    ];
    assert len(overflow) == 1;
    assert overflow[0].severity == LayoutSeverity.WARNING;
    assert r.ok;
}


test "intrinsic natural drift never turns the frame unsatisfiable (D23)" {
    screen = MainScreen(key="main");
    text = Header(key="text");
    filler = TranscriptView(key="filler");
    screen +>:Child(rank=1):+> text;
    screen +>:Child(rank=2):+> filler;

    state = create_layout_state(40, 10);
    set_spec(state, screen, LayoutSpec(width=_fill(), height=_fill()));
    set_spec(state, text, LayoutSpec(width=_fill(), height=_intrinsic()),);
    set_spec(state, filler, LayoutSpec(width=_fill(), height=_grow(1.0)));

    naturals: dict[str, Size] = {};
    naturals[node_id(text)] = Size(width=40, height=500);
    r = compile_layout(
        state, screen, Viewport(columns=40, rows=10), natural_sizes=naturals,
    );
    assert r.ok;
    for d in r.diagnostics {
        assert d.code != LayoutError.UNSATISFIABLE;
    }
    snap = _solver_of(r).snapshot();
    tedges = r.nodes[node_id(text)];
    fedges = r.nodes[node_id(filler)];

    assert (snap.values[tedges.bottom.id] - snap.values[tedges.top.id]) < 1e-6;
    assert (snap.values[fedges.bottom.id] - snap.values[fedges.top.id]) == 10.0;
}


test "compilation is deterministic across runs" {
    a = _shell_state();
    b = _shell_state();
    ra = compile_layout(a.state, a.screen, Viewport(columns=60, rows=20));
    rb = compile_layout(b.state, b.screen, Viewport(columns=60, rows=20));
    assert ra.ok;
    assert rb.ok;
    sa = _solver_of(ra).snapshot();
    sb = _solver_of(rb).snapshot();
    assert sa.generation == sb.generation;
    ka = sorted(sa.values.keys());
    kb = sorted(sb.values.keys());
    assert ka == kb;
    for vid in ka {
        assert abs(sa.values[vid] - sb.values[vid]) < 1e-9;
    }
}

impl _solver_of(r: CompileResult) -> Solver {
    s = r.solver;
    if s is None {
        raise ValueError("expected a successful compile with a solver");
    }
    return s;
}


impl _fill -> AxisSize {
    return AxisSize(mode=SizeMode.FILL);
}


impl _fixed(n: float) -> AxisSize {
    return AxisSize(mode=SizeMode.FIXED, preferred=n);
}


impl _grow(weight: float) -> AxisSize {
    return AxisSize(mode=SizeMode.GROW, grow_weight=weight);
}


impl _intrinsic -> AxisSize {
    return AxisSize(mode=SizeMode.INTRINSIC);
}


impl _shell_state(columns: int = 80, rows: int = 24) -> _ShellFixture {
    screen = MainScreen(key="main");
    header = Header(key="header");
    transcript = TranscriptView(key="transcript");
    status = Status(key="status");
    prompt = Prompt(key="prompt");
    screen +>:Child(rank=1024):+> header;
    screen +>:Child(rank=2048):+> transcript;
    screen +>:Child(rank=3072):+> status;
    screen +>:Child(rank=4096):+> prompt;

    state = create_layout_state(columns, rows);
    set_spec(state, screen, LayoutSpec(width=_fill(), height=_fill()));
    set_spec(state, header, LayoutSpec(width=_fill(), height=_fixed(1.0)));
    set_spec(
        state,
        transcript,
        LayoutSpec(width=_fill(), height=_grow(1.0), scroll_vertical=True),
    );
    set_spec(state, status, LayoutSpec(width=_fill(), height=_fixed(1.0)));
    set_spec(state, prompt, LayoutSpec(width=_fill(), height=_fixed(2.0)));
    return _ShellFixture(
        state=state,
        screen=screen,
        header=header,
        transcript=transcript,
        status=status,
        prompt=prompt,
    );
}
