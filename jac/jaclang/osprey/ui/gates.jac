import from time { perf_counter }


obj Gate4Report {
    has nodes_queried: int = 0,
        cells_written: int = 0,
        latency_ms: float = 0.0,
        full_frame_cells: int = 0,
        retained_cells: int = 0;
}


def run_gate1_detached_lifecycle -> bool;


def run_gate3_layout_damage -> bool;


def run_gate4_invalidation_bench -> Gate4Report;


def run_gate5_external_widget -> bool;


def run_gate6_authoring_scale -> bool;

impl run_gate1_detached_lifecycle -> bool {
    handle = create_session();
    session = handle.session;
    shell = build_main_shell(session);
    install_shell_contracts(session, shell, "session.events");

    event = InsertText(text="gate1");
    dispatch_event(session, event, shell.prompt);

    ui_ids = set(session.tracked_node_ids);
    leaked = ui_jids_reachable_from_persistent_root(ui_ids);
    if leaked {
        return False;
    }

    dispose_session(session);
    if not session.disposed {
        return False;
    }
    if not is_empty(session.bindings) {
        return False;
    }
    if session.renderer.layout or session.renderer.damage {
        return False;
    }
    if session.capabilities.by_node {
        return False;
    }
    if session.tracked_node_ids {
        return False;
    }
    if session.ui_root is not None {
        return False;
    }
    return True;
}


impl run_gate3_layout_damage -> bool {
    handle = create_session();
    session = handle.session;
    shell = build_main_shell(session);
    shell_insert_text(session, shell, "hello");
    shell_resize(session, shell, 80, 24);
    open_res = shell_open_approval(session, shell);
    if not open_res.overlay_id {
        dispose_session(session);
        return False;
    }
    term = VirtualTerminal(columns=80, rows=24);
    renderer = create_renderer(80, 24);
    failures = configure_main_shell_layout(renderer.layout, shell);
    if failures {
        dispose_session(session);
        return False;
    }
    frame = render_frame(renderer, shell.screen, term);
    close_res = shell_close_approval(session, shell);
    _ = (frame, close_res);
    findings = validate_invariants(session);
    dispose_session(session);
    return findings == [];
}


impl run_gate4_invalidation_bench -> Gate4Report {
    handle = create_session();
    session = handle.session;
    shell = build_main_shell(session);
    term = VirtualTerminal(columns=80, rows=24);
    renderer = create_renderer(80, 24);
    if configure_main_shell_layout(renderer.layout, shell) {
        dispose_session(session);
        return Gate4Report();
    }
    set_node_content(renderer, shell.header, ["Osprey"]);
    set_node_content(renderer, shell.transcript, ["hello retained stream"]);
    set_node_content(renderer, shell.status, ["ready"]);
    set_node_content(renderer, shell.prompt, ["> "]);

    t0 = perf_counter();
    frame1 = render_frame(renderer, shell.screen, term);
    set_node_content(renderer, shell.transcript, ["hello retained stream!"]);
    frame2 = render_frame(renderer, shell.screen, term);
    t1 = perf_counter();

    full_cells = 80 * 24;
    retained = frame2.cells_written;
    if retained > full_cells {
        retained = full_cells;
    }
    nodes_q = len(session.tracked_node_ids);
    metrics = Gate4Report(
        nodes_queried=nodes_q,
        cells_written=frame1.cells_written + frame2.cells_written,
        latency_ms=(t1 - t0) * 1000.0,
        full_frame_cells=full_cells,
        retained_cells=retained,
    );
    dispose_session(session);
    return metrics;
}


impl run_gate5_external_widget -> bool {
    bar = ProgressBar(key="p", value=0.0);
    event = SetProgress(value=0.4);
    bar spawn event;
    if not event.handled {
        return False;
    }
    if bar.value != 0.4 {
        return False;
    }
    painted = render_progress(bar.value, 12);
    if len(painted) != 12 {
        return False;
    }
    tags: dict[str, object] = {};
    register_progress_markup(tags);
    if "ProgressBar" not in tags {
        return False;
    }

    reg = create_tag_registry();
    register_tag(reg, "ProgressBar", ProgressBar);
    result = lower_markup('<ProgressBar key="pb" value="0.5" />', reg);
    if result.errors {
        return False;
    }
    if result.graph_root is None {
        return False;
    }
    return isinstance(result.graph_root, ProgressBar);
}


impl run_gate6_authoring_scale -> bool {
    parts: list[str] = ['<MainScreen key="main">'];
    parts.append('  <Header key="header" title="Osprey" />');
    parts.append('  <TranscriptView key="transcript" />');
    for i in range(40) {
        parts.append('  <Status key="region_' + str(i) + '" phase="ready" />');
    }
    parts.append('  <Prompt key="prompt" />');
    parts.append('  <ApprovalOverlay key="approval" />');
    parts.append("</MainScreen>");
    source = "\n".join(parts);
    result = lower_markup(source, default_shell_registry());
    if result.errors {
        return False;
    }
    if result.graph_root is None {
        return False;
    }
    if not isinstance(result.graph_root, MainScreen) {
        return False;
    }
    keys = ordered_child_keys(result.graph_root);
    if len(keys) < 40 {
        return False;
    }
    if "header" not in keys or "prompt" not in keys {
        return False;
    }

    gen = result.generated_jac;
    if "append_child" not in gen {
        return False;
    }
    if "rank=" in gen {
        return False;
    }
    return True;
}
