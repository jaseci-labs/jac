import from jaclang.jac0core.constant { EdgeDir, OwnershipKind }

glob NIL: int = 0;

glob TAG_NONE: int = 0,
     TAG_NODE: int = 1,
     TAG_LIST: int = 2,
     TAG_STR: int = 3,
     TAG_INT: int = 4,
     TAG_BOOL: int = 5,
     TAG_ENUM: int = 6;

obj SyntaxArena {
    has kinds: list[int] = [],
        kid_los: list[int] = [],
        kid_ns: list[int] = [],
        arg_los: list[int] = [],
        arg_ns: list[int] = [],
        kids: list[int] = [],
        args: list[int] = [],
        seqs: list[int] = [],
        strtab: list[str] = [],
        posts: list[int] = [],
        _intern: dict[str, int] = {},
        root_id: int = 0;

    def postinit {
        self.kinds.append(0);
        self.kid_los.append(0);
        self.kid_ns.append(0);
        self.arg_los.append(0);
        self.arg_ns.append(0);
    }

    def node_count -> int {
        return len(self.kinds);
    }

    def intern(s: str) -> int {
        got = self._intern.get(s, -1);
        if got >= 0 {
            return got;
        }
        idx = len(self.strtab);
        self.strtab.append(s);
        self._intern[s] = idx;
        return idx;
    }

    def _start(kind: int, kid: list[int], arg_n: int) -> int {
        idx = len(self.kinds);
        self.kinds.append(kind);
        self.kid_los.append(len(self.kids));
        self.kid_ns.append(len(kid));
        for k in kid {
            self.kids.append(k);
        }
        self.arg_los.append(len(self.args));
        self.arg_ns.append(arg_n);
        return idx;
    }

    def _arg_node(v: int) {
        if v == NIL {
            self.args.append(TAG_NONE);
            self.args.append(0);
        } else {
            self.args.append(TAG_NODE);
            self.args.append(v);
        }
    }

    def _arg_list(ids: (list[int] | None)) {
        if ids is None {
            self.args.append(TAG_NONE);
            self.args.append(0);
            return;
        }
        ids2: list[int] = ids;
        off = len(self.seqs);
        self.seqs.append(len(ids2));
        for i in ids2 {
            self.seqs.append(i);
        }
        self.args.append(TAG_LIST);
        self.args.append(off);
    }

    def _arg_str(s: (str | None)) {
        if s is None {
            self.args.append(TAG_NONE);
            self.args.append(0);
        } else {
            s2: str = s;
            self.args.append(TAG_STR);
            self.args.append(self.intern(s2));
        }
    }

    def _arg_int(v: int) {
        self.args.append(TAG_INT);
        self.args.append(v);
    }

    def _arg_bool(v: bool) {
        self.args.append(TAG_BOOL);
        self.args.append(1 if v else 0);
    }

    def _arg_enum(v: int) {
        self.args.append(TAG_ENUM);
        self.args.append(v);
    }

    def _arg_poly(v: (int | list[int] | None)) {
        if v is None {
            self.args.append(TAG_NONE);
            self.args.append(0);
        } elif isinstance(v, int) {
            vi: int = v;
            self._arg_node(vi);
        } else {
            vl: list[int] = v;
            self._arg_list(vl);
        }
    }

    def kind_of(i: int) -> int {
        return self.kinds[i];
    }

    def kid_ids(i: int) -> list[int] {
        lo = self.kid_los[i];
        return self.kids[lo:lo + self.kid_ns[i]];
    }

    def arg_at(i: int, slot: int) -> tuple[(int, int)] {
        if slot >= self.arg_ns[i] {
            raise ValueError(
                f"arg slot {slot} out of range for node {i} "
                f"(kind {self.kinds[i]}, {self.arg_ns[i]} args)"
            );
        }
        p = self.arg_los[i] + (slot * 2);
        return (self.args[p], self.args[p + 1]);
    }

    def arg_node(i: int, slot: int) -> int {
        if slot >= self.arg_ns[i] {
            return NIL;
        }
        (tag, v) = self.arg_at(i, slot);
        return v if tag == TAG_NODE else NIL;
    }

    def arg_str(i: int, slot: int) -> (str | None) {
        if slot >= self.arg_ns[i] {
            return None;
        }
        (tag, v) = self.arg_at(i, slot);
        return self.strtab[v] if tag == TAG_STR else None;
    }

    def arg_int(i: int, slot: int) -> int {
        if slot >= self.arg_ns[i] {
            return 0;
        }
        (tag, v) = self.arg_at(i, slot);
        return v;
    }

    def arg_bool(i: int, slot: int) -> bool {
        if slot >= self.arg_ns[i] {
            return False;
        }
        (tag, v) = self.arg_at(i, slot);
        return tag == TAG_BOOL and v != 0;
    }

    def arg_list(i: int, slot: int) -> (list[int] | None) {
        if slot >= self.arg_ns[i] {
            return None;
        }
        (tag, v) = self.arg_at(i, slot);
        if tag != TAG_LIST {
            return None;
        }
        return self.seq_ids(v);
    }

    def seq_ids(off: int) -> list[int] {
        n = self.seqs[off];
        return self.seqs[off + 1:off + 1 + n];
    }

    def set_arg_node(i: int, slot: int, v: int) {
        p = self.arg_los[i] + (slot * 2);
        if v == NIL {
            self.args[p] = TAG_NONE;
            self.args[p + 1] = 0;
        } else {
            self.args[p] = TAG_NODE;
            self.args[p + 1] = v;
        }
    }

    def set_arg_str(i: int, slot: int, s: str) {
        p = self.arg_los[i] + (slot * 2);
        self.args[p] = TAG_STR;
        self.args[p + 1] = self.intern(s);
    }

    def set_arg_bool(i: int, slot: int, v: bool) {
        p = self.arg_los[i] + (slot * 2);
        self.args[p] = TAG_BOOL;
        self.args[p + 1] = 1 if v else 0;
    }

    def set_arg_enum(i: int, slot: int, v: int) {
        p = self.arg_los[i] + (slot * 2);
        self.args[p] = TAG_ENUM;
        self.args[p + 1] = v;
    }

    def prepend_kids(i: int, ids: list[int]) {
        old = self.kid_ids(i);
        lo = len(self.kids);
        for k in ids {
            self.kids.append(k);
        }
        for k in old {
            self.kids.append(k);
        }
        self.kid_los[i] = lo;
        self.kid_ns[i] = len(ids) + len(old);
    }

    def append_kids(i: int, ids: list[int]) {
        old = self.kid_ids(i);
        lo = len(self.kids);
        for k in old {
            self.kids.append(k);
        }
        for k in ids {
            self.kids.append(k);
        }
        self.kid_los[i] = lo;
        self.kid_ns[i] = len(old) + len(ids);
    }

    def post_set(i: int, key: str, v: int) {
        self.posts.append(i);
        self.posts.append(self.intern(key));
        self.posts.append(v);
    }

    # >>> generated builder surface (jac gen-unitree) >>>
    def mk_ability(
        body: (int | list[int] | None) = None,
        is_async: bool = False,
        doc: int = NIL,
        access: int = NIL,
        codespace_dual: bool = False,
        name_ref: int = NIL,
        is_override: bool = False,
        is_static: bool = False,
        is_classmethod: bool = False,
        is_abstract: bool = False,
        signature: int = NIL,
        decorators: (list[int] | None) = None,
        type_params: (list[int] | None) = None,
        accessor_kind: str = '',
        event_triggers: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_arch_block_stmt(kid: list[int] = []) -> int;
    def mk_arch_has(
        doc: int = NIL,
        access: int = NIL,
        is_static: bool = False,
        vars: (list[int] | None) = None,
        is_frozen: bool = False,
        kid: list[int] = []
    ) -> int;

    def mk_arch_spec(
        doc: int = NIL,
        is_async: bool = False,
        decorators: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_archetype(
        doc: int = NIL,
        is_async: bool = False,
        body: (int | list[int] | None) = None,
        access: int = NIL,
        decorators: (list[int] | None) = None,
        codespace_dual: bool = False,
        name: int = NIL,
        arch_type: int = NIL,
        base_classes: (list[int] | None) = None,
        type_params: (list[int] | None) = None,
        src_endpoint: int = NIL,
        tgt_endpoint: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_assert_stmt(
        condition: int = NIL, error_msg: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_assign_compr(
        assigns: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_assignment(
        is_enum_stmt: bool = False,
        type_tag: int = NIL,
        target: (list[int] | None) = None,
        value: int = NIL,
        mutable: bool = True,
        aug_op: int = NIL,
        na_move_lowerable: bool = False,
        na_overwrite_consumed: bool = False,
        na_flow_reduce: str = '',
        kid: list[int] = []
    ) -> int;

    def mk_ast_access_node(access: int = NIL, kid: list[int] = []) -> int;
    def mk_ast_async_node(is_async: bool = False, kid: list[int] = []) -> int;
    def mk_ast_doc_node(doc: int = NIL, kid: list[int] = []) -> int;
    def mk_ast_else_body_node(else_body: int = NIL, kid: list[int] = []) -> int;
    def mk_ast_impl_needing_node(
        body: (int | list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_ast_symbol_node(kid: list[int] = []) -> int;
    def mk_ast_symbol_stub_node(kid: list[int] = []) -> int;
    def mk_ast_typed_var_node(type_tag: int = NIL, kid: list[int] = []) -> int;
    def mk_atom_expr(kid: list[int] = []) -> int;
    def mk_atom_trailer(
        target: int = NIL,
        right: int = NIL,
        is_attr: bool = False,
        is_null_ok: bool = False,
        is_genai: bool = False,
        kid: list[int] = []
    ) -> int;

    def mk_atom_unit(value: int = NIL, kid: list[int] = []) -> int;
    def mk_await_expr(target: int = NIL, kid: list[int] = []) -> int;
    def mk_awaiting_clause(
        body: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_binary_expr(
        left: int = NIL, right: int = NIL, op: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_bool(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        kid: list[int] = []
    ) -> int;

    def mk_bool_expr(
        op: int = NIL, values: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_builtin_type(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        is_enum_stmt: bool = False,
        is_kwesc: bool = False,
        kid: list[int] = []
    ) -> int;

    def mk_cast_expr(
        value: int = NIL, cast_type: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_cfg_expr(
        sc_true_target: int = NIL,
        sc_false_target: int = NIL,
        expr: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_code_block_stmt(kid: list[int] = []) -> int;
    def mk_compare_expr(
        left: int = NIL,
        rights: (list[int] | None) = None,
        ops: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_concurrent_expr(
        tok: int = NIL, target: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_conditional_node(
        sc_true_target: int = NIL, sc_false_target: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_connect_op(
        conn_type: int = NIL,
        conn_assign: int = NIL,
        edge_dir: EdgeDir = EdgeDir.IN,
        kid: list[int] = []
    ) -> int;

    def mk_context_aware_node(
        codespace_dual: bool = False, kid: list[int] = []
    ) -> int;

    def mk_ctrl_stmt(ctrl: int = NIL, kid: list[int] = []) -> int;
    def mk_delete_stmt(target: int = NIL, kid: list[int] = []) -> int;
    def mk_dict_compr(
        kv_pair: int = NIL, compr: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_dict_val(kv_pairs: (list[int] | None) = None, kid: list[int] = []) -> int;
    def mk_disconnect_op(edge_spec: int = NIL, kid: list[int] = []) -> int;
    def mk_disengage_stmt(kid: list[int] = []) -> int;
    def mk_edge_op_ref(
        filter_cond: int = NIL, edge_dir: EdgeDir = EdgeDir.IN, kid: list[int] = []
    ) -> int;

    def mk_edge_ref_trailer(
        chain: (list[int] | None) = None,
        edges_only: bool = False,
        is_async: bool = False,
        kid: list[int] = []
    ) -> int;

    def mk_element_stmt(doc: int = NIL, kid: list[int] = []) -> int;
    def mk_ellipsis(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        kid: list[int] = []
    ) -> int;

    def mk_else_if(
        else_body: int = NIL,
        condition: int = NIL,
        body: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_else_stmt(body: (list[int] | None) = None, kid: list[int] = []) -> int;
    def mk_empty_token(kid: list[int] = []) -> int;
    def mk_enum(
        doc: int = NIL,
        is_async: bool = False,
        body: (int | list[int] | None) = None,
        access: int = NIL,
        decorators: (list[int] | None) = None,
        codespace_dual: bool = False,
        name: int = NIL,
        value_type: int = NIL,
        base_classes: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_enum_block_stmt(is_enum_stmt: bool = False, kid: list[int] = []) -> int;
    def mk_event_signature(
        event: int = NIL, arch_tag_info: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_except(
        ex_type: int = NIL,
        name: int = NIL,
        body: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_expr(kid: list[int] = []) -> int;
    def mk_expr_as_item(expr: int = NIL, alias: int = NIL, kid: list[int] = []) -> int;
    def mk_expr_stmt(
        expr: int = NIL,
        in_fstring: bool = False,
        has_semi: bool = True,
        kid: list[int] = []
    ) -> int;

    def mk_f_string(
        start: int = NIL,
        parts: (list[int] | None) = None,
        end: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_filter_compr(
        f_type: int = NIL, compares: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_finally_stmt(body: (list[int] | None) = None, kid: list[int] = []) -> int;
    def mk_float(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        kid: list[int] = []
    ) -> int;

    def mk_forever_stmt(body: (list[int] | None) = None, kid: list[int] = []) -> int;
    def mk_formatted_value(
        format_part: int = NIL,
        conversion: int = 0,
        format_spec: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_func_call(
        target: int = NIL,
        params: (list[int] | None) = None,
        genai_call: int = NIL,
        call_kind: (str | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_func_signature(
        posonly_params: (list[int] | None) = None,
        params: (list[int] | None) = None,
        varargs: int = NIL,
        kwonlyargs: (list[int] | None) = None,
        kwargs: int = NIL,
        return_type: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_gen_compr(
        out_expr: int = NIL, compr: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_global_vars(
        access: int = NIL,
        doc: int = NIL,
        codespace_dual: bool = False,
        assignments: (list[int] | None) = None,
        is_frozen: bool = False,
        kid: list[int] = []
    ) -> int;

    def mk_has_var(
        type_tag: int = NIL,
        name: int = NIL,
        value: int = NIL,
        defer: bool = False,
        accessors: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_if_else_expr(
        condition: int = NIL,
        value: int = NIL,
        else_value: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_if_stmt(
        else_body: int = NIL,
        condition: int = NIL,
        body: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_impl_def(
        doc: int = NIL,
        codespace_dual: bool = False,
        decorators: (list[int] | None) = None,
        target: (list[int] | None) = None,
        spec: (int | list[int] | None) = None,
        body: (int | list[int] | None) = None,
        decl_link: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_import(
        doc: int = NIL,
        codespace_dual: bool = False,
        from_loc: int = NIL,
        items: (list[int] | None) = None,
        is_absorb: bool = False,
        is_typed: bool = False,
        clib_decls: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_in_for_stmt(
        else_body: int = NIL,
        is_async: bool = False,
        target: int = NIL,
        collection: int = NIL,
        body: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_index_slice(
        slices: (list[int] | None) = None, is_range: bool = False, kid: list[int] = []
    ) -> int;

    def mk_inner_compr(
        is_async: bool = False,
        target: int = NIL,
        collection: int = NIL,
        conditional: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_int(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        kid: list[int] = []
    ) -> int;

    def mk_iter_for_stmt(
        else_body: int = NIL,
        is_async: bool = False,
        iter: int = NIL,
        condition: int = NIL,
        count_by: int = NIL,
        body: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_jsx_attribute(kid: list[int] = []) -> int;
    def mk_jsx_child(kid: list[int] = []) -> int;
    def mk_jsx_comment(value: int = NIL, kid: list[int] = []) -> int;
    def mk_jsx_element(
        name: int = NIL,
        attributes: (list[int] | None) = None,
        children: (list[int] | None) = None,
        is_self_closing: bool = False,
        is_fragment: bool = False,
        dynamic_tag: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_jsx_element_name(
        parts: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_jsx_expression(expr: int = NIL, kid: list[int] = []) -> int;
    def mk_jsx_normal_attribute(
        name: int = NIL,
        value: int = NIL,
        is_shorthand: bool = False,
        kid: list[int] = []
    ) -> int;

    def mk_jsx_slot(body: (list[int] | None) = None, kid: list[int] = []) -> int;
    def mk_jsx_spread_attribute(expr: int = NIL, kid: list[int] = []) -> int;
    def mk_jsx_text(value: int = NIL, kid: list[int] = []) -> int;
    def mk_k_v_pair(key: int = NIL, value: int = NIL, kid: list[int] = []) -> int;
    def mk_k_w_pair(key: int = NIL, value: int = NIL, kid: list[int] = []) -> int;
    def mk_lambda_expr(
        body: (int | list[int] | None) = None, signature: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_list_compr(
        out_expr: int = NIL, compr: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_list_val(values: (list[int] | None) = None, kid: list[int] = []) -> int;
    def mk_literal(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        kid: list[int] = []
    ) -> int;

    def mk_match_arch(
        name: int = NIL,
        arg_patterns: (list[int] | None) = None,
        kw_patterns: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_match_as(name: int = NIL, pattern: int = NIL, kid: list[int] = []) -> int;
    def mk_match_case(
        pattern: int = NIL,
        guard: int = NIL,
        body: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_match_k_v_pair(
        key: int = NIL, value: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_match_mapping(
        values: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_match_or(patterns: (list[int] | None) = None, kid: list[int] = []) -> int;
    def mk_match_pattern(kid: list[int] = []) -> int;
    def mk_match_sequence(
        values: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_match_singleton(value: int = NIL, kid: list[int] = []) -> int;
    def mk_match_star(
        name: int = NIL, is_list: bool = False, kid: list[int] = []
    ) -> int;

    def mk_match_stmt(
        target: int = NIL, cases: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_match_value(value: int = NIL, kid: list[int] = []) -> int;
    def mk_match_wild(kid: list[int] = []) -> int;
    def mk_module(
        doc: int = NIL,
        name: str = "",
        body: (list[int] | None) = None,
        terminals: (list[int] | None) = None,
        stub_only: bool = False,
        src_terminals: (list[int] | None) = None,
        is_raised_from_py: bool = False,
        decided_codespace: str = '',
        kid: list[int] = []
    ) -> int;

    def mk_module_code(
        is_enum_stmt: bool = False,
        doc: int = NIL,
        codespace_dual: bool = False,
        name: int = NIL,
        body: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_module_item(name: int = NIL, alias: int = NIL, kid: list[int] = []) -> int;
    def mk_module_path(
        path: (list[int] | None) = None,
        level: int = 0,
        alias: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_multi_string(
        strings: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_name(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        is_enum_stmt: bool = False,
        is_kwesc: bool = False,
        kid: list[int] = []
    ) -> int;

    def mk_name_atom(
        is_enum_stmt: bool = False,
        is_getattr_resolved: bool = False,
        kid: list[int] = []
    ) -> int;

    def mk_null(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        kid: list[int] = []
    ) -> int;

    def mk_open_stmt(
        target: int = NIL, body: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_param_var(
        type_tag: int = NIL,
        name: int = NIL,
        unpack: int = NIL,
        value: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_py_inline_code(
        is_enum_stmt: bool = False, doc: int = NIL, code: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_raise_stmt(
        cause: int = NIL, from_target: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_report_stmt(expr: int = NIL, kid: list[int] = []) -> int;
    def mk_return_stmt(
        expr: int = NIL, is_implicit: bool = False, kid: list[int] = []
    ) -> int;

    def mk_sem_def(
        doc: int = NIL,
        target: (list[int] | None) = None,
        value: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_semi(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        kid: list[int] = []
    ) -> int;

    def mk_set_compr(
        out_expr: int = NIL, compr: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_set_val(values: (list[int] | None) = None, kid: list[int] = []) -> int;
    def mk_slice(
        start: int = NIL, stop: int = NIL, step: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_special_var_ref(
        var: int = NIL, is_enum_stmt: bool = False, kid: list[int] = []
    ) -> int;

    def mk_string(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        kid: list[int] = []
    ) -> int;

    def mk_sub_tag(
        tag: (int | list[int] | None) = None,
        ownership: OwnershipKind = OwnershipKind.NONE,
        kid: list[int] = []
    ) -> int;

    def mk_switch_case(
        pattern: int = NIL, body: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_switch_stmt(
        target: int = NIL, cases: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_test(
        doc: int = NIL,
        codespace_dual: bool = False,
        name: int = NIL,
        body: (list[int] | None) = None,
        description: int = NIL,
        decorators: (list[int] | None) = None,
        TEST_COUNT: int = 0,
        kid: list[int] = []
    ) -> int;

    def mk_token(
        name: str = "",
        value: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        kid: list[int] = []
    ) -> int;

    def mk_try_stmt(
        else_body: int = NIL,
        body: (list[int] | None) = None,
        excepts: (list[int] | None) = None,
        awaiting_body: int = NIL,
        finally_body: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_tuple_val(values: (list[int] | None) = None, kid: list[int] = []) -> int;
    def mk_type_alias(
        doc: int = NIL,
        access: int = NIL,
        codespace_dual: bool = False,
        name: int = NIL,
        type_params: (list[int] | None) = None,
        value: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_type_param(
        name: int = NIL, bound: int = NIL, default_val: int = NIL, kid: list[int] = []
    ) -> int;

    def mk_typed_ctx_block(
        type_ctx: int = NIL, body: (list[int] | None) = None, kid: list[int] = []
    ) -> int;

    def mk_unary_expr(
        operand: int = NIL,
        op: int = NIL,
        ownership: OwnershipKind = OwnershipKind.NONE,
        kid: list[int] = []
    ) -> int;

    def mk_uni_c_f_g_node(kid: list[int] = []) -> int;
    def mk_uni_scope_node(kid: list[int] = []) -> int;
    def mk_visit_stmt(
        else_body: int = NIL,
        insert_loc: int = NIL,
        target: int = NIL,
        kid: list[int] = []
    ) -> int;

    def mk_walker_stmt_only_node(kid: list[int] = []) -> int;
    def mk_while_stmt(
        else_body: int = NIL,
        condition: int = NIL,
        body: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_with_stmt(
        is_async: bool = False,
        exprs: (list[int] | None) = None,
        body: (list[int] | None) = None,
        kid: list[int] = []
    ) -> int;

    def mk_yield_expr(
        expr: int = NIL, with_from: bool = False, kid: list[int] = []
    ) -> int;
    # <<< generated builder surface <<<
}
