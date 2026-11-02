graph import {
    edge Constraints: constraints.* --> ui.*;

    constraints.algebra ++> [
        ui.layout_compile_emit {
            Constraint,
            Expression,
            Relation,
            StrengthTier,
            Term,
            Variable,
            is_finite,
            normalize_expression
        },
        ui.layout_compile_flow | ui.layout_compile_overlays { Relation, StrengthTier },
        ui.layout_compile_model { Variable },
        ui.layout_compile_relations { Relation, Term },
        ui.layout_types { is_finite },
        ui.layout_types_core { StrengthTier },
    ]
    constraints.results ++> ui.layout_compile_emit { SolveError }
    constraints.solver ++> ui.layout_compile | ui.layout_compile_model { Solver }
}

graph import constraints {
    algebra ++> [
        layout_relations {
            Constraint,
            Expression,
            Relation,
            StrengthTier,
            Term,
            Variable,
            normalize_expression
        },
        solver {
            Constraint,
            Expression,
            LexWeight,
            Relation,
            StrengthTier,
            Term,
            Variable,
            constraint_key,
            is_finite,
            lex_compare,
            normalize_expression,
            strength_weight,
            term
        },
        solver_dual {
            LexWeight,
            StrengthTier,
            lex_compare,
            lex_is_zero,
            lex_neg,
            lex_scale,
            lex_zero,
            near_zero,
            strength_weight
        },
        solver_journal { Expression, Variable, is_finite },
        solver_simplex {
            Constraint,
            Expression,
            LexWeight,
            Relation,
            StrengthTier,
            Term,
            Variable,
            constraint_key,
            lex_is_negative,
            lex_is_zero,
            near_zero,
            strength_weight
        },
        solver_types {
            Expression,
            LexWeight,
            Relation,
            StrengthTier,
            lex_add,
            lex_is_zero,
            lex_scale,
            lex_zero,
            near_zero
        },
    ]
    results ++> [
        solver { ConstraintHandle, SolveError, SolveResult, SolverSnapshot },
        solver_dual | solver_simplex { SolveError, SolveResult },
        solver_types { ConstraintHandle },
    ]
    type solver ++> solver_dual | solver_journal | solver_simplex { Solver }
    solver_dual ++> solver {
        _solver_apply_suggestion,
        _solver_dual_optimize,
        _solver_remove_core
    }
    solver_journal ++> [
        solver {
            _journal_begin,
            _journal_expression_is_finite,
            _journal_rollback,
            _journal_witness_extra,
            _journal_witness_for_key
        },
        solver_dual {
            _journal_kind_of,
            _journal_pop_row,
            _journal_touch_objective,
            _journal_touch_row
        },
        solver_simplex {
            _journal_begin,
            _journal_get_var_symbol,
            _journal_insert_row,
            _journal_kind_of,
            _journal_new_symbol_journaled,
            _journal_pop_row,
            _journal_touch_objective,
            _journal_touch_row
        },
    ]
    solver_simplex ++> [
        solver {
            _solver_add_core,
            _solver_adopt,
            _solver_rebuild_admitting,
            _solver_replay_all
        },
        solver_dual { _solver_optimize_cost, _solver_pivot },
    ]
    solver_types ++> [
        solver { CostRow, EditInfo, Row, StoredConstraint, SymbolKind, Tag },
        solver_dual { EditInfo, MutationJournal, Row, SymbolKind, Tag },
        solver_journal { MutationJournal, Row, SymbolKind },
        solver_simplex { MutationJournal, Row, StoredConstraint, SymbolKind, Tag },
    ]
}

graph import ui {
    bindings ++> [
        gates | runtime { is_empty },
        inspect { Binding },
        runtime_core { BindingRegistry, clear_bindings, find_orphan_bindings },
        screen { subscribe },
    ]
    cells ++> [
        markdown_proj { StyleAttrs },
        renderer { StyleAttrs, TextSpan, buffer_to_plain_rows },
        renderer_damage { CellBuffer, diff_buffers_ansi },
        renderer_paint {
            CellBuffer,
            StyleAttrs,
            TextSpan,
            buffer_blit_spans,
            buffer_blit_text,
            buffer_clear_rect,
            create_buffer
        },
        renderer_types { CellBuffer, StyleAttrs, TextSpan },
    ]
    demo_live_shell ++> demo_entry { run_live_shell_demo }
    demo_live_shell_messages ++> demo_live_shell { _push_turn, _rewrite_turn }
    demo_live_shell_model ++> demo_live_shell
        | demo_live_shell_messages
        | demo_live_shell_render { LiveShell }
    demo_live_shell_render ++> demo_live_shell { _install_layout, _render }
    editor ++> [
        demo_live_shell { editor_backspace, editor_history_next, editor_history_prev },
        screen { AblePrompt, editor_insert, editor_submit },
    ]
    events ++> [
        editor { Cancel, InsertText, SendPrompt, Submit },
        gates { InsertText, dispatch_event },
        inspect { UiEvent, containment_path, resolve_target },
        screen { Cancel, InsertText, SendPrompt, Submit, dispatch_event },
    ]
    input ++> [
        demo_live_shell | host { InputNormalizer, coalesce_events },
        demo_live_shell_model { InputNormalizer },
    ]
    input_events ++> [
        demo_live_shell { HostEvent, KeyEvent, PasteEvent, TextEvent },
        host { EofEvent, HostEvent, InterruptEvent, KeyEvent },
        input {
            BRACKETED_PASTE_END,
            BRACKETED_PASTE_START,
            ESC,
            HostEvent,
            KeyEvent,
            MouseEvent,
            PasteEvent,
            ResizeEvent,
            StreamChunkEvent,
            TextEvent
        },
        input_sequences { ESC, HostEvent, KeyEvent, MouseEvent, TextEvent },
    ]
    input_sequences ++> input { decode_sequence, extract_sequences }
    inspect ++> gates { validate_invariants }
    layout ++> renderer_damage { compute_layout }
    layout_compile ++> layout { compile_layout }
    layout_compile_emit ++> [
        layout_compile { _emit_invariants, _emit_root, _req },
        layout_compile_flow {
            _axis_end,
            _axis_start,
            _emit,
            _emit_cross_axis,
            _emit_sized_axis,
            _expr,
            _prov,
            _req,
            _t
        },
        layout_compile_overlays { _emit, _emit_sized_axis, _expr, _prov, _t },
        layout_compile_relations { _emit, _expr, _t },
    ]
    layout_compile_flow ++> layout_compile { _emit_partition }
    layout_compile_model ++> [
        layout { CompileResult, PartitionInfo },
        layout_compile { CompileResult, NodeEdges, _Entry, _Scope },
        layout_compile_emit | layout_compile_overlays {
            CompileResult,
            NodeEdges,
            _Entry,
            _wants
        },
        layout_compile_flow {
            CompileResult,
            PartitionInfo,
            _Allocation,
            _Entry,
            _FlowChild,
            _wants
        },
        layout_compile_relations { CompileResult, NodeEdges, _wants },
        layout_compile_scope { _Scope, _ScopedNode },
    ]
    layout_compile_overlays ++> layout_compile { _emit_overlay }
    layout_compile_relations ++> layout_compile { _emit_relation }
    layout_compile_scope ++> layout_compile { _collect_scope }
    layout_measure ++> [
        layout { natural_width, wrapped_lines_at },
        layout_types { invalidate_measurement_cache },
    ]
    layout_quantize ++> layout { PartitionRequest, quantize_partition, snap_edge }
    layout_scope ++> layout { _ScopedNode, _collect_scope }
    layout_types ++> [
        demo_live_shell_render { fill_axis, fixed_axis, grow_axis },
        layout {
            _copy_rect,
            add_relation,
            clear_node,
            create_layout_state,
            frame_entry_of,
            rect_of,
            remove_relation,
            set_content,
            set_scroll_offset,
            set_spec,
            validate_spec
        },
        renderer {
            clear_node,
            create_layout_state,
            frame_entry_of,
            set_content,
            set_spec
        },
        screen { fixed_axis, set_spec },
    ]
    layout_types_core ++> [
        cells { Rect },
        demo_live_shell_render { LayoutSpec },
        layout {
            Axis,
            AxisSize,
            FrameEntry,
            LayoutDiagnostic,
            LayoutError,
            LayoutFrame,
            LayoutRelation,
            LayoutRelationKind,
            LayoutResult,
            LayoutSeverity,
            LayoutSpec,
            LayoutState,
            MutationResult,
            Rect,
            RelationHandle,
            Size,
            SizeMode,
            Viewport
        },
        layout_compile {
            LayoutDiagnostic,
            LayoutError,
            LayoutSeverity,
            LayoutState,
            Size,
            SizeMode,
            Viewport
        },
        layout_compile_emit {
            Align,
            AxisSize,
            LayoutDiagnostic,
            LayoutError,
            LayoutSeverity,
            LayoutSpec,
            Size,
            SizeMode,
            Viewport
        },
        layout_compile_flow {
            AxisSize,
            LayoutDiagnostic,
            LayoutError,
            LayoutSeverity,
            Size,
            SizeMode
        },
        layout_compile_model { AxisSize, LayoutDiagnostic, LayoutSpec },
        layout_compile_overlays { OverlayAnchor, Size, SizeMode },
        layout_compile_relations { LayoutRelation, LayoutRelationKind },
        layout_compile_scope | layout_scope {
            LayoutDiagnostic,
            LayoutError,
            LayoutSeverity
        },
        layout_types {
            Axis,
            AxisSize,
            ContentEntry,
            FrameEntry,
            LayoutDiagnostic,
            LayoutError,
            LayoutRelation,
            LayoutRelationKind,
            LayoutSeverity,
            LayoutSpec,
            LayoutState,
            MutationResult,
            Rect,
            RelationHandle,
            Size,
            SizeMode,
            Viewport
        },
        renderer { LayoutResult, LayoutSpec, LayoutState, Rect },
        renderer_damage { LayoutResult, Rect, Viewport, rect_union },
        renderer_paint { FrameEntry, LayoutState },
        renderer_types { LayoutState, Rect },
        screen { AxisSize, LayoutDiagnostic, LayoutSpec, LayoutState, SizeMode },
    ]
    markdown_proj ++> transcript {
        looks_like_markdown,
        proj_lines_to_span_dicts,
        project_markdown
    }
    markup ++> gates {
        create_tag_registry,
        default_shell_registry,
        lower_markup,
        register_tag
    }
    model ++> [
        editor { Prompt },
        events {
            Child,
            Layer,
            Overlay,
            Screen,
            UiContainer,
            UiNode,
            find_node_by_jid,
            node_id,
            ordered_children
        },
        gates { MainScreen, ordered_child_keys },
        inspect {
            Child,
            Feeds,
            FocusNext,
            Layer,
            Owns,
            Screen,
            UiContainer,
            UiNode,
            child_rank,
            duplicate_sibling_keys,
            node_id,
            ordered_child_keys,
            ordered_children
        },
        layout | layout_types | renderer { UiNode, node_id },
        layout_compile { UiContainer, UiNode, node_id },
        layout_compile_flow { UiContainer, node_id, ordered_children },
        layout_compile_model | renderer_types { UiNode },
        layout_compile_scope | layout_scope {
            Child,
            Layer,
            Overlay,
            Screen,
            UiContainer,
            UiNode,
            node_id,
            ordered_children
        },
        markup {
            ApprovalOverlay,
            Header,
            MainScreen,
            Prompt,
            Status,
            TranscriptView,
            UiContainer,
            UiNode
        },
        mutation {
            Child,
            Feeds,
            FocusNext,
            Header,
            Layer,
            MainScreen,
            Owns,
            Prompt,
            Status,
            TranscriptView,
            UiContainer,
            UiNode,
            UiSessionRoot,
            child_parent,
            child_rank,
            is_child_ancestor,
            node_id,
            ordered_child_keys,
            ordered_children
        },
        renderer_damage { Screen, UiContainer, UiNode, node_id, ordered_children },
        renderer_paint {
            Layer,
            Overlay,
            Screen,
            UiContainer,
            UiNode,
            node_id,
            ordered_children
        },
        runtime {
            Feeds,
            FocusNext,
            Layer,
            Overlay,
            Screen,
            UiContainer,
            UiNode,
            node_id,
            ordered_children
        },
        runtime_core {
            Child,
            Feeds,
            FocusNext,
            Layer,
            Owns,
            Screen,
            UiContainer,
            UiNode,
            UiSessionRoot,
            find_node_by_jid,
            node_id,
            ordered_children
        },
        screen {
            ApprovalOverlay,
            Header,
            MainScreen,
            Prompt,
            Status,
            TranscriptView,
            UiNode,
            node_id
        },
        transcript { TranscriptView },
    ]
    mutation ++> [
        markup { append_child },
        runtime { dispose_subtree },
        runtime_core { MutationResult, append_child, dispose_subtree },
    ]
    persistence_probe ++> gates { ui_jids_reachable_from_persistent_root }
    progress_bar ++> [
        demo_live_shell { ProgressBar, SetProgress },
        demo_live_shell_model { ProgressBar },
        gates { ProgressBar, SetProgress, register_progress_markup, render_progress },
    ]
    renderer ++> [
        demo_live_shell { create_renderer },
        demo_live_shell_render {
            mark_layout_dirty,
            mark_semantic_dirty,
            render_frame,
            request_cursor,
            set_node_content,
            set_node_contract
        },
        gates { create_renderer, render_frame, set_node_content },
    ]
    renderer_damage ++> renderer {
        _diff_ansi,
        _merge_damage,
        _resolve_cursor,
        _run_layout,
        _snapshot_rects,
        compute_damage
    }
    renderer_paint ++> [
        renderer { _paint_frame_buffer },
        renderer_damage { _layered_overlays },
    ]
    renderer_types ++> [
        demo_live_shell_model { Renderer },
        renderer { DamageRect, FrameResult, Renderer },
        renderer_damage { AnsiDiff, CursorPos, DamageRect, Renderer },
        renderer_paint { Renderer, _OverlayHit },
    ]
    runtime ++> [
        focus {
            OverlayBounds,
            OverlayCloseResult,
            OverlayOpenResult,
            advance_focus,
            close_overlay,
            focus_order,
            layers_input_order,
            layers_paint_order,
            open_modal_overlay
        },
        screen {
            OverlayBounds,
            OverlayCloseResult,
            OverlayOpenResult,
            close_overlay,
            open_modal_overlay
        },
    ]
    runtime_core ++> [
        demo_live_shell | gates { create_session, dispose_session },
        demo_live_shell_model | events { UiSession },
        inspect { UiSession, validate_session },
        runtime {
            UiSession,
            append_child_session,
            create_session,
            dispose_session,
            get_focus_node,
            register_capability,
            release_capabilities,
            set_focus,
            track_node,
            validate_session
        },
        screen {
            SessionEventRecord,
            UiSession,
            append_child_session,
            register_capability,
            set_current_screen,
            set_focus,
            track_node
        },
    ]
    screen ++> [
        demo_live_shell {
            build_main_shell,
            install_shell_contracts,
            shell_cancel,
            shell_close_approval,
            shell_insert_text,
            shell_open_approval,
            shell_resize,
            shell_submit
        },
        demo_live_shell_model { ShellScreen },
        gates {
            build_main_shell,
            configure_main_shell_layout,
            install_shell_contracts,
            shell_close_approval,
            shell_insert_text,
            shell_open_approval,
            shell_resize
        },
    ]
    terminal ++> [
        demo_live_shell { ProcessTerminal, read_terminal_size },
        demo_live_shell_model { ProcessTerminal },
        host { Terminal },
        renderer { Terminal, synchronized_write },
        virtual_terminal {
            CLEAR_SCREEN,
            DISABLE_BRACKETED_PASTE,
            ENABLE_BRACKETED_PASTE,
            ENTER_ALT_SCREEN,
            HIDE_CURSOR,
            LEAVE_ALT_SCREEN,
            SHOW_CURSOR,
            SYNC_BEGIN,
            SYNC_END,
            Terminal
        },
    ]
    transcript ++> [
        demo_live_shell { bind_transcript, set_follow_tail },
        demo_live_shell_messages { TranscriptMessage, apply_transcript_revision },
        demo_live_shell_model { TranscriptMessage, TranscriptProjection },
        demo_live_shell_render { materialize_visible },
    ]
    virtual_terminal ++> gates { VirtualTerminal }
    width ++> [
        cells { display_width, grapheme_width, segment_graphemes },
        demo_live_shell_render { display_width, truncate_text },
        editor { display_width },
        layout { wrap_text_joined },
        layout_measure { display_width, wrap_text_joined },
        markdown_proj { display_width, wrap_text },
        transcript { wrap_words },
    ]
}
