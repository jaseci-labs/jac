"""Grammar extraction pass implementation."""

# =========================================================================
# GExpr __eq__ / __repr__
# =========================================================================
impl GExpr.__eq__(
    other: object
) -> bool {
    return type(self) == type(other);
}

impl GExpr.__repr__ -> str {
    return "GExpr()";
}

# -- GSeq -----------------------------------------------------------------
impl GSeq.__eq__(
    other: object
) -> bool {
    return isinstance(other, GSeq) and self.items == other.items;
}

impl GSeq.__repr__ -> str {
    return f"GSeq({self.items!r})";
}

# -- GAlt -----------------------------------------------------------------
impl GAlt.__eq__(
    other: object
) -> bool {
    return isinstance(other, GAlt) and self.choices == other.choices;
}

impl GAlt.__repr__ -> str {
    return f"GAlt({self.choices!r})";
}

# -- GOpt -----------------------------------------------------------------
impl GOpt.__eq__(
    other: object
) -> bool {
    return isinstance(other, GOpt) and self.inner == other.inner;
}

impl GOpt.__repr__ -> str {
    return f"GOpt({self.inner!r})";
}

# -- GStar ----------------------------------------------------------------
impl GStar.__eq__(
    other: object
) -> bool {
    return isinstance(other, GStar) and self.inner == other.inner;
}

impl GStar.__repr__ -> str {
    return f"GStar({self.inner!r})";
}

# -- GTok -----------------------------------------------------------------
impl GTok.__eq__(
    other: object
) -> bool {
    return isinstance(other, GTok) and self.name == other.name;
}

impl GTok.__repr__ -> str {
    return f"GTok({self.name!r})";
}

impl GTok.__hash__ -> int {
    return hash(("GTok", self.name));
}

# -- GRef -----------------------------------------------------------------
impl GRef.__eq__(
    other: object
) -> bool {
    return isinstance(other, GRef) and self.name == other.name;
}

impl GRef.__repr__ -> str {
    return f"GRef({self.name!r})";
}

impl GRef.__hash__ -> int {
    return hash(("GRef", self.name));
}

# =========================================================================
# GrammarRule
# =========================================================================
impl GrammarRule.to_ebnf -> str {
    return f"{self.name} ::= {GrammarExtractPass.format_ebnf(None, self.body)}";
}

impl GrammarRule.to_lark -> str {
    return f"{self.name}: {GrammarExtractPass.format_lark(None, self.body)}";
}

impl GrammarRule.__repr__ -> str {
    return f"GrammarRule({self.name!r}, {self.body!r})";
}

# =========================================================================
# GrammarExtractPass - Init
# =========================================================================
"""Initialize the GrammarExtractPass."""
impl GrammarExtractPass.init(
    ir_in: uni.Module, prog: Any, cancel_token: Any = None
) -> None {
    super.init(ir_in, prog, cancel_token);
}

# =========================================================================
# GrammarExtractPass - Formatting helpers
# =========================================================================
"""Format a grammar expression as EBNF."""
impl GrammarExtractPass.format_ebnf(expr: GExpr) -> str {
    fmt = GrammarExtractPass.format_ebnf;
    if isinstance(expr, GSeq) {
        parts: list = [];
        for item in expr.items {
            s = fmt(self, item);
            # Wrap alt in parens when inside a sequence
            if isinstance(item, GAlt) and len(item.choices) > 1 {
                s = f"({s})";
            }
            parts.append(s);
        }
        return " ".join(parts);
    }
    if isinstance(expr, GAlt) {
        parts2: list = [];
        for choice in expr.choices {
            parts2.append(fmt(self, choice));
        }
        return " | ".join(parts2);
    }
    if isinstance(expr, GOpt) {
        inner = fmt(self, expr.inner);
        if isinstance(expr.inner, (GAlt, GSeq)) {
            return f"({inner})?";
        }
        return f"{inner}?";
    }
    if isinstance(expr, GStar) {
        inner = fmt(self, expr.inner);
        if isinstance(expr.inner, (GAlt, GSeq)) {
            return f"({inner})*";
        }
        return f"{inner}*";
    }
    if isinstance(expr, GTok) {
        return expr.name;
    }
    if isinstance(expr, GRef) {
        return expr.name;
    }
    return "???";
}

"""Format a grammar expression as Lark."""
impl GrammarExtractPass.format_lark(expr: GExpr) -> str {
    return GrammarExtractPass.format_ebnf(self, expr);
}

"""Simplify grammar expression by flattening nested structures."""
impl GrammarExtractPass.simplify_expr(expr: GExpr) -> GExpr {
    simp = GrammarExtractPass.simplify_expr;
    if isinstance(expr, GSeq) {
        flat: list = [];
        for item in expr.items {
            simplified = simp(self, item);
            if isinstance(simplified, GSeq) {
                flat.extend(simplified.items);
            } else {
                flat.append(simplified);
            }
        }
        if len(flat) == 0 {
            return GSeq(items=[]);
        }
        if len(flat) == 1 {
            return flat[0];
        }
        return GSeq(items=flat);
    }
    if isinstance(expr, GAlt) {
        flat2: list = [];
        seen: set = set();
        for choice in expr.choices {
            simplified = simp(self, choice);
            if isinstance(simplified, GAlt) {
                for inner_c in simplified.choices {
                    key = repr(inner_c);
                    if key not in seen {
                        flat2.append(inner_c);
                        seen.add(key);
                    }
                }
            } else {
                key2 = repr(simplified);
                if key2 not in seen {
                    flat2.append(simplified);
                    seen.add(key2);
                }
            }
        }
        if len(flat2) == 1 {
            return flat2[0];
        }
        return GAlt(choices=flat2);
    }
    if isinstance(expr, GOpt) {
        return GOpt(inner=simp(self, expr.inner));
    }
    if isinstance(expr, GStar) {
        simplified_inner = simp(self, expr.inner);
        # Simplify (A (B A)*)* → (A B)* — common pattern in binary operator loops
        if isinstance(simplified_inner, GSeq) and len(simplified_inner.items) == 2 {
            first = simplified_inner.items[0];
            second = simplified_inner.items[1];
            if isinstance(second, GStar)
            and isinstance(second.inner, GSeq)
            and len(second.inner.items) == 2
            and repr(second.inner.items[1]) == repr(first) {
                return GStar(inner=GSeq(items=[first, second.inner.items[0]]));
            }
        }
        return GStar(inner=simplified_inner);
    }
    return expr;
}

# =========================================================================
# GrammarExtractPass - Pass hooks
# =========================================================================
impl GrammarExtractPass.before_pass -> None {
    self.rules = [];
}

impl GrammarExtractPass.after_pass -> None {
    # Also traverse impl_mod sub-modules to find ImplDef nodes
    if self.ir_in?.impl_mod {
        for impl_mod in self.ir_in.impl_mod {
            self.traverse(impl_mod);
        }
    }
    # Simplify all extracted rules
    simplified: list = [];
    for rule in self.rules {
        simplified.append(
            GrammarRule(name=rule.name, body=self.simplify_expr(rule.body))
        );
    }
    self.rules = simplified;
}

# -------------------------------------------------------------------------
# Visitor: enter_impl_def
# -------------------------------------------------------------------------
"""Check if this impl targets a parse method and extract its rule."""
impl GrammarExtractPass.enter_impl_def(nd: uni.ImplDef) -> None {
    names = self.get_impl_target_names(nd);
    if len(names) < 2 {
        return;
    }
    class_name = names[0];
    method_name = names[1];
    if class_name != self.target_class {
        return;
    }
    if not method_name.startswith("parse_") {
        return;
    }
    rule_name = method_name[6:];  # strip "parse_"
    body = nd.body;
    if not isinstance(body, list) and not isinstance(body, tuple) {
        return;
    }
    grammar_expr = self.extract_from_stmts(list(body));
    if grammar_expr is not None {
        self.rules.append(GrammarRule(name=rule_name, body=grammar_expr));
    }
    self.prune();
}

# -------------------------------------------------------------------------
# get_impl_target_names
# -------------------------------------------------------------------------
"""Extract class and method names from an ImplDef target."""
impl GrammarExtractPass.get_impl_target_names(nd: uni.ImplDef) -> list {
    names: list = [];
    for name_atom in nd.target {
        if isinstance(name_atom, uni.Name) {
            names.append(name_atom.value);
        } elif name_atom?.sym_name {
            names.append(name_atom.sym_name);
        }
    }
    return names;
}

# -------------------------------------------------------------------------
# Body extraction
# -------------------------------------------------------------------------
"""Extract grammar from a list of statements."""
impl GrammarExtractPass.extract_from_stmts(stmts: list) -> GExpr | None {
    parts: list = [];
    alt_branches: list = [];
    i = 0;
    while i < len(stmts) {
        stmt = stmts[i];

        # Detect dispatch pattern: if self.check(...) { ... return ... }
        if isinstance(stmt, uni.IfStmt) or isinstance(stmt, uni.ElseIf) {
            cond_info = self.analyze_condition(stmt.condition);
            if cond_info is not None and self.has_early_return(list(stmt.body)) {
                branches = self.collect_elif_chain(stmt);
                for branch in branches {
                    alt_branches.append(branch);
                }
                i += 1;
                continue;
            }
            # Local-variable dispatch: condition not recognizable but branch
            # returns early (e.g., if is_ability { return parse_ability(); })
            if cond_info is None
            and self.has_early_return(list(stmt.body))
            and stmt.else_body is None {
                body_expr = self.extract_from_stmts(list(stmt.body));
                if body_expr is not None {
                    alt_branches.append(body_expr);
                }
                i += 1;
                continue;
            }
        }

        # If we hit a return after dispatch branches, it's the fallback
        if isinstance(stmt, uni.ReturnStmt) and len(alt_branches) > 0 {
            has_fallback = False;
            if stmt.expr is not None {
                call = self.get_call_from_expr(stmt.expr);
                if call is not None {
                    fallback = self.analyze_func_call(call);
                    if fallback is not None {
                        alt_branches.append(fallback);
                        has_fallback = True;
                    }
                }
            }
            branch_expr: GExpr;
            if len(alt_branches) == 1 {
                branch_expr = alt_branches[0];
            } else {
                branch_expr = GAlt(choices=alt_branches);
            }
            # If the return doesn't produce a grammar element (e.g. return local var
            # or return None), the dispatch branches are optional
            if has_fallback {
                parts.append(branch_expr);
            } else {
                parts.append(GOpt(inner=branch_expr));
            }
            alt_branches = [];
            i += 1;
            continue;
        }

        # Flush any pending dispatch alternatives
        # Since dispatch branches return early, remaining code only runs
        # when no dispatch matched → remaining is an alternative
        if len(alt_branches) > 0 {
            remaining = stmts[i:];
            remaining_expr = self.extract_from_stmts(remaining);
            if remaining_expr is not None {
                alt_branches.append(remaining_expr);
                if len(alt_branches) == 1 {
                    parts.append(alt_branches[0]);
                } else {
                    parts.append(GAlt(choices=alt_branches));
                }
            } else {
                if len(alt_branches) == 1 {
                    parts.append(GOpt(inner=alt_branches[0]));
                } else {
                    parts.append(GOpt(inner=GAlt(choices=alt_branches)));
                }
            }
            alt_branches = [];
            break;
        }

        # Normal statement
        expr = self.extract_from_stmt(stmt);
        if expr is not None {
            parts.append(expr);
        }
        i += 1;
    }
    # Flush remaining alternatives
    if len(alt_branches) > 0 {
        if len(alt_branches) == 1 {
            parts.append(GOpt(inner=alt_branches[0]));
        } else {
            parts.append(GOpt(inner=GAlt(choices=alt_branches)));
        }
    }
    if len(parts) == 0 {
        return None;
    }
    if len(parts) == 1 {
        return parts[0];
    }
    return GSeq(items=parts);
}

"""Check if a statement list contains a return statement (searches nested ifs)."""
impl GrammarExtractPass.has_early_return(stmts: list) -> bool {
    for stmt in stmts {
        if isinstance(stmt, uni.ReturnStmt) {
            return True;
        }
        # Check nested if/elif/else bodies for returns
        if isinstance(stmt, (uni.IfStmt, uni.ElseIf)) {
            if self.has_early_return(list(stmt.body)) {
                return True;
            }
            if stmt.else_body is not None {
                if isinstance(stmt.else_body, uni.ElseStmt) {
                    if self.has_early_return(list(stmt.else_body.body)) {
                        return True;
                    }
                } elif isinstance(stmt.else_body, (uni.ElseIf, uni.IfStmt)) {
                    if self.has_early_return([stmt.else_body]) {
                        return True;
                    }
                }
            }
        }
    }
    return False;
}

"""Check if condition is a negated check pattern (e.g. not check(X), not check(X) and not at_end())."""
impl GrammarExtractPass.is_negated_check_condition(cond: uni.Expr) -> bool {
    # Single negation: not self.check(X) or not self.at_end()
    if isinstance(cond, uni.UnaryExpr) {
        if cond.op is not None and cond.op?.value and cond.op.value == "not" {
            if isinstance(cond.operand, uni.FuncCall) {
                method = self.get_self_method(cond.operand.target);
                if method in (
                    "check",
                    "check_any",
                    "check_peek",
                    "check_peek_any",
                    "at_end"
                ) {
                    return True;
                }
            }
        }
        return False;
    }
    # BoolExpr AND of negations: not check(X) and not check(Y)
    if isinstance(cond, uni.BoolExpr) {
        if not (cond.op and cond.op?.value and cond.op.value == "and") {
            return False;
        }
        if not cond.values or len(cond.values) == 0 {
            return False;
        }
        for val in cond.values {
            if not self.is_negated_check_condition(val) {
                return False;
            }
        }
        return True;
    }
    # BinaryExpr AND of negations
    if isinstance(cond, uni.BinaryExpr) {
        if cond.op and cond.op?.value and cond.op.value in ("and", "&&") {
            return (
                self.is_negated_check_condition(cond.left)
                and self.is_negated_check_condition(cond.right)
            );
        }
    }
    return False;
}

"""Check if a grammar expression contains a specific token name."""
impl GrammarExtractPass.expr_contains_tok(expr: GExpr, tok_name: str) -> bool {
    if isinstance(expr, GTok) {
        return expr.name == tok_name;
    }
    if isinstance(expr, GSeq) {
        for item in expr.items {
            if self.expr_contains_tok(item, tok_name) {
                return True;
            }
        }
    }
    if isinstance(expr, GAlt) {
        for c in expr.choices {
            if self.expr_contains_tok(c, tok_name) {
                return True;
            }
        }
    }
    if isinstance(expr, GOpt) {
        return self.expr_contains_tok(expr.inner, tok_name);
    }
    if isinstance(expr, GStar) {
        return self.expr_contains_tok(expr.inner, tok_name);
    }
    return False;
}

# -------------------------------------------------------------------------
# Single statement extraction
# -------------------------------------------------------------------------
"""Extract grammar from a single statement."""
impl GrammarExtractPass.extract_from_stmt(stmt: uni.UniNode) -> GExpr | None {
    if isinstance(stmt, uni.ExprStmt) {
        call = self.get_call_from_expr(stmt.expr);
        if call is not None {
            return self.analyze_func_call(call);
        }
        return None;
    }
    if isinstance(stmt, uni.Assignment) {
        if stmt.value is not None {
            call = self.get_call_from_expr(stmt.value);
            if call is not None {
                return self.analyze_func_call(call);
            }
            # Handle list initialization: x = [self.parse_X()]
            if isinstance(stmt.value, uni.ListVal) and hasattr(stmt.value, 'values') {
                for elem in stmt.value.values {
                    inner_call = self.get_call_from_expr(elem);
                    if inner_call is not None {
                        result = self.analyze_func_call(inner_call);
                        if result is not None {
                            return result;
                        }
                    }
                }
            }
        }
        return None;
    }
    if isinstance(stmt, uni.IfStmt) or isinstance(stmt, uni.ElseIf) {
        return self.analyze_if_stmt(stmt);
    }
    if isinstance(stmt, uni.WhileStmt) {
        return self.analyze_while_stmt(stmt);
    }
    if isinstance(stmt, uni.ReturnStmt) {
        if stmt.expr is not None {
            call = self.get_call_from_expr(stmt.expr);
            if call is not None {
                return self.analyze_func_call(call);
            }
        }
        return None;
    }
    return None;
}

# -------------------------------------------------------------------------
# Analyze function calls
# -------------------------------------------------------------------------
"""Determine if a call is grammar-relevant."""
impl GrammarExtractPass.analyze_func_call(call: uni.FuncCall) -> GExpr | None {
    method = self.get_self_method(call.target);
    if method is not None {
        if method == "expect" or method == "consume_uni" {
            tokens = self.get_token_args(call);
            if len(tokens) > 0 {
                return GTok(name=tokens[0]);
            }
            return None;
        }
        if method.startswith("parse_") {
            return GRef(name=method[6:]);
        }
        if method == "expect_name" {
            return GTok(name="NAME");
        }
        if method == "match_tok" {
            tokens = self.get_token_args(call);
            if len(tokens) > 0 {
                return GOpt(inner=GTok(name=tokens[0]));
            }
        }
        return None;
    }
    # Not a self.method call — scan arguments for grammar-relevant calls.
    # Handles patterns like: values.append(self.parse_X())
    for param in call.params {
        inner_call = self.get_call_from_expr(param);
        if inner_call is not None {
            result = self.analyze_func_call(inner_call);
            if result is not None {
                return result;
            }
        }
    }
    return None;
}

# -------------------------------------------------------------------------
# Analyze if statements
# -------------------------------------------------------------------------
"""Extract grammar from an if statement."""
impl GrammarExtractPass.analyze_if_stmt(stmt: uni.IfStmt) -> GExpr | None {
    cond_info = self.analyze_condition(stmt.condition);
    if cond_info is None {
        # Negated guard: if not check(SEMI) and not check(RBRACE) { body } → GOpt(body)
        if self.is_negated_check_condition(stmt.condition) and stmt.else_body is None {
            opt_body = self.extract_from_stmts(list(stmt.body));
            if opt_body is not None {
                return GOpt(inner=opt_body);
            }
            return None;
        }
        body_expr = self.extract_from_stmts(list(stmt.body));
        # If the if-body returns early and there are elif/else branches,
        # branches are alternatives (local-variable dispatch pattern)
        if self.has_early_return(list(stmt.body)) and stmt.else_body is not None {
            alt_list: list = [];
            if body_expr is not None {
                alt_list.append(body_expr);
            }
            cur_alt = stmt.else_body;
            while cur_alt is not None {
                if isinstance(cur_alt, (uni.ElseIf, uni.IfStmt)) {
                    eb = self.extract_from_stmts(list(cur_alt.body));
                    if eb is not None {
                        alt_list.append(eb);
                    }
                    cur_alt = cur_alt?.else_body;
                } elif isinstance(cur_alt, uni.ElseStmt) {
                    eb = self.extract_from_stmts(list(cur_alt.body));
                    if eb is not None {
                        alt_list.append(eb);
                    }
                    cur_alt = None;
                } else {
                    cur_alt = None;
                }
            }
            # Deduplicate alternatives
            unique_alts: list = [];
            seen_reprs: set = set();
            for a in alt_list {
                r = repr(a);
                if r not in seen_reprs {
                    unique_alts.append(a);
                    seen_reprs.add(r);
                }
            }
            if len(unique_alts) > 1 {
                return GAlt(choices=unique_alts);
            } elif len(unique_alts) == 1 {
                return unique_alts[0];
            }
            return body_expr;
        }
        else_expr: GExpr | None = None;
        if stmt.else_body is not None {
            if isinstance(stmt.else_body, (uni.ElseIf, uni.IfStmt)) {
                else_expr = self.analyze_if_stmt(stmt.else_body);
            } elif isinstance(stmt.else_body, uni.ElseStmt) {
                else_expr = self.extract_from_stmts(list(stmt.else_body.body));
            }
        }
        found: list = [];
        if body_expr is not None {
            found.append(body_expr);
        }
        if else_expr is not None {
            found.append(else_expr);
        }
        if len(found) == 0 {
            return None;
        }
        if len(found) == 1 {
            return found[0];
        }
        return GSeq(items=found);
    }
    method = cond_info[0];
    tokens: list = cond_info[1];
    # if self.match_tok(X) { body } -> optional (X body)?
    if method == "match_tok" and len(tokens) > 0 {
        body_expr = self.extract_from_stmts(list(stmt.body));
        inner_parts: list = [GTok(name=tokens[0])];
        if body_expr is not None {
            inner_parts.append(body_expr);
        }
        inner: GExpr = GSeq(items=inner_parts)
        if len(inner_parts) > 1
        else inner_parts[0];
        if stmt.else_body is not None {
            else_expr2: GExpr | None = None;
            if isinstance(stmt.else_body, (uni.ElseIf, uni.IfStmt)) {
                else_expr2 = self.analyze_if_stmt(stmt.else_body);
            } elif isinstance(stmt.else_body, uni.ElseStmt) {
                else_expr2 = self.extract_from_stmts(list(stmt.else_body.body));
            }
            if else_expr2 is not None {
                return GAlt(choices=[inner, else_expr2]);
            }
        }
        return GOpt(inner=inner);
    }
    # if self.check(X) / check_any(X,Y) { body } [elif ...] -> optional/alt
    if method in ("check", "check_any", "check_peek", "check_peek_any") {
        branches = self.collect_elif_chain(stmt);
        if len(branches) == 0 {
            return None;
        }
        if len(branches) == 1 {
            return GOpt(inner=branches[0]);
        }
        has_else = False;
        cur: uni.IfStmt = stmt;
        while True {
            if cur.else_body is None {
                break;
            }
            if isinstance(cur.else_body, uni.ElseStmt) {
                has_else = True;
                break;
            }
            if isinstance(cur.else_body, (uni.ElseIf, uni.IfStmt)) {
                cur = cur.else_body;
            } else {
                break;
            }
        }
        alt = GAlt(choices=branches);
        if has_else {
            return alt;
        }
        return GOpt(inner=alt);
    }
    return None;
}

# -------------------------------------------------------------------------
# Collect elif chain
# -------------------------------------------------------------------------
"""Collect grammar expressions from all branches of an if-elif chain."""
impl GrammarExtractPass.collect_elif_chain(stmt: uni.IfStmt) -> list {
    branches: list = [];
    cur: uni.IfStmt | None = stmt;
    while cur is not None {
        cond_info = self.analyze_condition(cur.condition);
        branch_body = self.extract_from_stmts(list(cur.body));

        if cond_info is not None {
            method = cond_info[0];
            tokens: list = cond_info[1];
            if method in ("check", "check_any", "check_peek", "check_peek_any") {
                tok_expr: GExpr | None = None;
                if len(tokens) > 1 {
                    tok_expr = GAlt(choices=[GTok(name=t) for t in tokens]);
                } elif len(tokens) == 1 {
                    tok_expr = GTok(name=tokens[0]);
                }
                if tok_expr is not None and branch_body is not None {
                    # check/check_any are lookahead-only (they don't consume
                    # tokens). When the body is a *pure* delegation — a single
                    # `return self.parse_X()` — the guard tokens are redundant
                    # because the sub-rule defines them internally.  Emitting
                    # both produces duplicated token lists in the grammar (e.g.
                    # "(TYP_STRING|…) builtin_type" instead of "builtin_type").
                    #
                    # We only suppress when len(body) == 1 to avoid stripping
                    # guard tokens from branches that also call advance() or
                    # build AST nodes inline (e.g. parse_factor's unary-op
                    # branch has advance + parse_factor + return, so the guard
                    # tokens are the only grammar representation of the
                    # consumed operator).
                    if isinstance(branch_body, GRef) and len(list(cur.body)) == 1 {
                        branches.append(branch_body);
                    } else {
                        branches.append(GSeq(items=[tok_expr, branch_body]));
                    }
                } elif tok_expr is not None {
                    # check/check_any doesn't consume token - only include
                    # the bare token if the body does something non-trivial
                    # (skip guard clauses like: if check(RBRACE) { return None; })
                    is_guard = True;
                    for s in list(cur.body) {
                        if not isinstance(s, uni.ReturnStmt)
                        and not (
                            isinstance(s, uni.CtrlStmt)
                            and s.ctrl is not None
                            and s.ctrl.value == "break"
                        ) {
                            is_guard = False;
                        }
                    }
                    if not is_guard {
                        branches.append(tok_expr);
                    }
                } elif branch_body is not None {
                    branches.append(branch_body);
                }
            } elif method == "match_tok" and len(tokens) > 0 {
                inner_parts: list = [GTok(name=tokens[0])];
                if branch_body is not None {
                    inner_parts.append(branch_body);
                }
                if len(inner_parts) > 1 {
                    branches.append(GSeq(items=inner_parts));
                } else {
                    branches.append(inner_parts[0]);
                }
            } else {
                if branch_body is not None {
                    branches.append(branch_body);
                }
            }
        } else {
            if branch_body is not None {
                branches.append(branch_body);
            }
        }

        # Move to next branch
        if cur.else_body is not None {
            if isinstance(cur.else_body, (uni.ElseIf, uni.IfStmt)) {
                cur = cur.else_body;
            } elif isinstance(cur.else_body, uni.ElseStmt) {
                else_expr = self.extract_from_stmts(list(cur.else_body.body));
                if else_expr is not None {
                    branches.append(else_expr);
                }
                cur = None;
            } else {
                cur = None;
            }
        } else {
            cur = None;
        }
    }
    return branches;
}

# -------------------------------------------------------------------------
# Analyze while statements
# -------------------------------------------------------------------------
"""Extract grammar from a while loop."""
impl GrammarExtractPass.analyze_while_stmt(stmt: uni.WhileStmt) -> GExpr | None {
    cond_info = self.analyze_condition(stmt.condition);
    if cond_info is None {
        # Handle `while True { body; if not self.match_tok(X) { break; } }`
        # This pattern is used in parse_logical_or/and to collect operands.
        # Extract grammar from body stmts (excluding the break condition)
        # and include the break condition's token as part of the repetition.
        if isinstance(stmt.condition, uni.Bool) and stmt.condition.value == "True" {
            break_info = self.find_break_match_tok(list(stmt.body));
            if break_info is not None {
                break_tokens: list = break_info[0];
                body_stmts: list = break_info[1];
                body_expr = self.extract_from_stmts(body_stmts);
                inner_parts: list = [];
                if body_expr is not None {
                    inner_parts.append(body_expr);
                }
                if len(break_tokens) > 0 {
                    inner_parts.append(GTok(name=break_tokens[0]));
                }
                if len(inner_parts) == 0 {
                    return None;
                }
                inner: GExpr = GSeq(items=inner_parts)
                if len(inner_parts) > 1
                else inner_parts[0];
                return GStar(inner=inner);
            }
            # Handle: while True { x = parse_X(); if x is None { break; } body }
            none_check_info = self.find_break_none_check(list(stmt.body));
            if none_check_info is not None {
                ref_name: str = none_check_info[0];
                remaining_stmts: list = none_check_info[1];
                remaining_expr = self.extract_from_stmts(remaining_stmts);
                inner_parts2: list = [GRef(name=ref_name)];
                if remaining_expr is not None {
                    inner_parts2.append(remaining_expr);
                }
                inner2: GExpr = GSeq(items=inner_parts2)
                if len(inner_parts2) > 1
                else inner_parts2[0];
                return GStar(inner=inner2);
            }
        }
        # Handle: while not self.check(X) { body } → body*
        if self.is_negated_check_condition(stmt.condition) {
            body_expr = self.extract_from_stmts(list(stmt.body));
            if body_expr is not None {
                return GStar(inner=body_expr);
            }
            return None;
        }
        return self.extract_from_stmts(list(stmt.body));
    }
    method = cond_info[0];
    tokens: list = cond_info[1];
    if method == "match_tok" and len(tokens) > 0 {
        body_expr = self.extract_from_stmts(list(stmt.body));
        inner_parts: list = [GTok(name=tokens[0])];
        if body_expr is not None {
            inner_parts.append(body_expr);
        }
        inner: GExpr = GSeq(items=inner_parts)
        if len(inner_parts) > 1
        else inner_parts[0];
        return GStar(inner=inner);
    }
    if method in ("check", "check_any", "check_peek", "check_peek_any")
    and len(tokens) > 0 {
        body_expr = self.extract_from_stmts(list(stmt.body));
        # If body already contains condition tokens (via consume_uni/expect),
        # skip adding them to avoid duplication. Otherwise include them
        # (body uses advance() which isn't grammar-recognized).
        body_has_cond_tok = False;
        if body_expr is not None {
            for t in tokens {
                if self.expr_contains_tok(body_expr, t) {
                    body_has_cond_tok = True;
                    break;
                }
            }
        }
        if body_has_cond_tok {
            if body_expr is not None {
                return GStar(inner=body_expr);
            }
            return None;
        }
        tok_expr: GExpr | None = None;
        if len(tokens) > 1 {
            tok_expr = GAlt(choices=[GTok(name=t) for t in tokens]);
        } else {
            tok_expr = GTok(name=tokens[0]);
        }
        inner_parts2: list = [tok_expr];
        if body_expr is not None {
            inner_parts2.append(body_expr);
        }
        inner2: GExpr = GSeq(items=inner_parts2)
        if len(inner_parts2) > 1
        else inner_parts2[0];
        return GStar(inner=inner2);
    }
    return None;
}

# -------------------------------------------------------------------------
# Find break-match_tok in while True bodies
# -------------------------------------------------------------------------
"""Find `if not self.match_tok(X) { break; }` at end of while True body.

Returns (token_names, remaining_body_stmts) or None."""
impl GrammarExtractPass.find_break_match_tok(stmts: list) -> tuple | None {
    if len(stmts) == 0 {
        return None;
    }
    last = stmts[-1];
    if not isinstance(last, uni.IfStmt) {
        return None;
    }
    # Check condition is `not self.match_tok(X)`
    cond = last.condition;
    if not isinstance(cond, uni.UnaryExpr) {
        return None;
    }
    if not (cond.op is not None and cond.op.value == "not") {
        return None;
    }
    inner_call = cond.operand;
    if not isinstance(inner_call, uni.FuncCall) {
        return None;
    }
    method = self.get_self_method(inner_call.target);
    if method != "match_tok" {
        return None;
    }
    # Check body contains a break
    has_break = False;
    for s in last.body {
        if isinstance(s, uni.CtrlStmt) {
            if s.ctrl is not None and s.ctrl.value == "break" {
                has_break = True;
            }
        }
    }
    if not has_break {
        return None;
    }
    tokens = self.get_token_args(inner_call);
    body_stmts = stmts[:-1];
    return (tokens, body_stmts);
}

# -------------------------------------------------------------------------
# Find break-none-check in while True bodies
# -------------------------------------------------------------------------
"""Find `x = self.parse_X(); if x is None { break; }` at start of while True body.

Returns (rule_name, remaining_body_stmts) or None."""
impl GrammarExtractPass.find_break_none_check(stmts: list) -> tuple | None {
    if len(stmts) < 2 {
        return None;
    }
    # First stmt: x = self.parse_X()
    first = stmts[0];
    if not isinstance(first, uni.Assignment) {
        return None;
    }
    if first.value is None {
        return None;
    }
    call = self.get_call_from_expr(first.value);
    if call is None {
        return None;
    }
    method = self.get_self_method(call.target);
    if method is None or not method.startswith("parse_") {
        return None;
    }
    rule_name = method[6:];
    # Second stmt: if x is None { break; }
    second = stmts[1];
    if not isinstance(second, uni.IfStmt) {
        return None;
    }
    # Check condition is `x is None` (CompareExpr with 'is' and Null)
    cond = second.condition;
    if not isinstance(cond, uni.CompareExpr) {
        return None;
    }
    is_none_check = False;
    if cond.ops is not None and len(cond.ops) > 0 {
        for op in cond.ops {
            if op.value == "is" {
                is_none_check = True;
            }
        }
    }
    if not is_none_check {
        return None;
    }
    # Check body contains break
    has_break = False;
    for s in second.body {
        if isinstance(s, uni.CtrlStmt) {
            if s.ctrl is not None and s.ctrl.value == "break" {
                has_break = True;
            }
        }
    }
    if not has_break {
        return None;
    }
    remaining = stmts[2:];
    return (rule_name, remaining);
}

# -------------------------------------------------------------------------
# Condition analysis
# -------------------------------------------------------------------------
"""Analyze condition. Returns (method_name, [token_names]) or None."""
impl GrammarExtractPass.analyze_condition(cond: uni.Expr) -> tuple | None {
    if isinstance(cond, uni.FuncCall) {
        method = self.get_self_method(cond.target);
        if method in (
            "check",
            "check_any",
            "check_peek",
            "check_peek_any",
            "match_tok"
        ) {
            tokens = self.get_token_args(cond);
            return (method, tokens);
        }
    }
    # Handle peek().kind == TokenKind.X or peek().kind in [...] comparisons
    if isinstance(cond, uni.CompareExpr) {
        if cond.ops is not None
        and len(cond.ops) > 0
        and cond.rights is not None
        and len(cond.rights) > 0 {
            op_val = "";
            if hasattr(cond.ops[0], 'value') {
                op_val = cond.ops[0].value;
            }
            if op_val == "==" {
                right = cond.rights[0];
                tok_name = self.extract_token_kind(right);
                if tok_name is not None {
                    return ("check", [tok_name]);
                }
            } elif op_val == "in" {
                right = cond.rights[0];
                if isinstance(right, uni.ListVal) {
                    tok_names: list = [];
                    for item in right.values {
                        tn = self.extract_token_kind(item);
                        if tn is not None {
                            tok_names.append(tn);
                        }
                    }
                    if len(tok_names) > 0 {
                        return ("check", tok_names);
                    }
                }
            }
        }
    }
    # Boolean expressions: BoolExpr for and/or
    if isinstance(cond, uni.BoolExpr) {
        is_or = cond?.op and cond.op?.value and cond.op.value == "or";
        if is_or {
            # For OR: collect all check/match_tok tokens from all values
            all_toks: list = [];
            found_method: str | None = None;
            if cond?.values {
                for val in cond.values {
                    if isinstance(val, uni.FuncCall) {
                        m = self.get_self_method(val.target);
                        if m in (
                            "check",
                            "check_any",
                            "check_peek",
                            "check_peek_any",
                            "match_tok"
                        ) {
                            tks = self.get_token_args(val);
                            all_toks.extend(tks);
                            if found_method is None {
                                found_method = m;
                            }
                        }
                    }
                }
            }
            if found_method is not None and len(all_toks) > 0 {
                return (found_method, all_toks);
            }
            return None;
        }
        # For AND: find the first check/match_tok call in any position
        if cond?.values and len(cond.values) > 0 {
            for val in cond.values {
                if isinstance(val, uni.FuncCall) {
                    method = self.get_self_method(val.target);
                    if method in (
                        "check",
                        "check_any",
                        "check_peek",
                        "check_peek_any",
                        "match_tok"
                    ) {
                        tokens = self.get_token_args(val);
                        return (method, tokens);
                    }
                }
            }
        }
    }
    if isinstance(cond, uni.BinaryExpr) {
        if cond?.op and cond.op?.value {
            if cond.op.value in ("and", "&&") {
                left = cond.left;
                if isinstance(left, uni.FuncCall) {
                    method = self.get_self_method(left.target);
                    if method in (
                        "check",
                        "check_any",
                        "check_peek",
                        "check_peek_any",
                        "match_tok"
                    ) {
                        tokens = self.get_token_args(left);
                        return (method, tokens);
                    }
                }
            }
        }
    }
    return None;
}

# -------------------------------------------------------------------------
# AST helpers
# -------------------------------------------------------------------------
"""Extract token name from a TokenKind.X expression, or None."""
impl GrammarExtractPass.extract_token_kind(expr: uni.Expr) -> str | None {
    if isinstance(expr, uni.AtomTrailer) and expr.is_attr {
        if isinstance(expr.target, uni.Name) and expr.target.value == "TokenKind" {
            if isinstance(expr.right, uni.Name) {
                return expr.right.value;
            }
        }
    }
    return None;
}

"""Extract method name from self.method access."""
impl GrammarExtractPass.get_self_method(nd: uni.Expr) -> str | None {
    if isinstance(nd, uni.AtomTrailer) and nd.is_attr {
        target = nd.target;
        right = nd.right;
        is_self = False;
        if isinstance(target, uni.SpecialVarRef) {
            is_self = target.value == "self";
        } elif isinstance(target, uni.Name) {
            is_self = target.value == "self";
        }
        if is_self and isinstance(right, uni.Name) {
            return right.value;
        }
    }
    return None;
}

"""Extract TokenKind.X names from function call parameters."""
impl GrammarExtractPass.get_token_args(call: uni.FuncCall) -> list {
    result: list = [];
    for param in call.params {
        if isinstance(param, uni.AtomTrailer) and param.is_attr {
            if isinstance(param.target, uni.Name) {
                if param.target.value == "TokenKind" {
                    if isinstance(param.right, uni.Name) {
                        result.append(param.right.value);
                    }
                }
            }
        }
    }
    return result;
}

"""Extract a FuncCall from an expression, if present."""
impl GrammarExtractPass.get_call_from_expr(expr: uni.Expr) -> uni.FuncCall | None {
    if isinstance(expr, uni.FuncCall) {
        return expr;
    }
    if isinstance(expr, uni.AtomTrailer) {
        if isinstance(expr.target, uni.FuncCall) {
            return expr.target;
        }
    }
    return None;
}

# -------------------------------------------------------------------------
# Output
# -------------------------------------------------------------------------
"""Format a rule with Black-style line-breaking.

Short rules stay on one line. Long rules break after ::= with
4-space indented body. Uses recursive tree-based formatting.
"""
impl GrammarExtractPass.format_rule_pretty(
    rule: GrammarRule, sep: str = "::=", max_line: int = 88
) -> str {
    body = GrammarExtractPass.format_ebnf(self, rule.body);
    prefix = f"{rule.name} {sep} ";
    if len(prefix + body) <= max_line {
        return prefix + body;
    }
    return f"{rule.name} {sep}\n" + self.format_expr_pretty(rule.body, 4, max_line);
}

"""Format a grammar expression with Black-style indentation.

Tries flat rendering first. If it doesn't fit, expands based on
expression type with fixed 4-space indent increments.
"""
impl GrammarExtractPass.format_expr_pretty(
    expr: GExpr, indent: int, max_line: int
) -> str {
    pad = " " * indent;
    flat = GrammarExtractPass.format_ebnf(self, expr);
    if len(pad) + len(flat) <= max_line {
        return pad + flat;
    }
    if isinstance(expr, GAlt) {
        return self.format_alt_pretty(expr.choices, indent, max_line);
    }
    if isinstance(expr, GSeq) {
        return self.format_seq_pretty(expr.items, indent, max_line);
    }
    if isinstance(expr, GOpt) {
        return self.format_group_pretty(expr.inner, indent, max_line, "?");
    }
    if isinstance(expr, GStar) {
        return self.format_group_pretty(expr.inner, indent, max_line, "*");
    }
    return pad + flat;
}

"""Format alternatives, one per line with | prefix for 2nd+."""
impl GrammarExtractPass.format_alt_pretty(
    choices: list, indent: int, max_line: int
) -> str {
    lines: list = [];
    for (i, choice) in enumerate(choices) {
        if i == 0 {
            prefix = " " * indent;
        } else {
            prefix = " " * indent + "| ";
        }
        choice_flat = GrammarExtractPass.format_ebnf(self, choice);
        if len(prefix) + len(choice_flat) <= max_line {
            lines.append(prefix + choice_flat);
        } else {
            expanded = self.format_expr_pretty(choice, len(prefix), max_line);
            exp_lines = expanded.split("\n");
            lines.append(prefix + exp_lines[0].lstrip());
            for el in exp_lines[1:] {
                lines.append(el);
            }
        }
    }
    return "\n".join(lines);
}

"""Format a sequence by greedily packing items onto lines.

When an item (GOpt/GStar with complex inner, or GAlt) needs multi-line
expansion, opens ( on the current line, formats inner at indent+4,
and closes ) at indent.
"""
impl GrammarExtractPass.format_seq_pretty(
    items: list, indent: int, max_line: int
) -> str {
    pad = " " * indent;
    lines: list = [];
    cur = pad;
    for item in items {
        item_flat = GrammarExtractPass.format_ebnf(self, item);
        if isinstance(item, GAlt) and len(item.choices) > 1 {
            item_flat = f"({item_flat})";
        }
        # Try to append to current line
        if cur == pad {
            candidate = cur + item_flat;
        } else {
            candidate = cur + " " + item_flat;
        }
        if len(candidate) <= max_line {
            cur = candidate;
            continue;
        }
        # Doesn't fit. Try starting on a new line.
        if len(pad + item_flat) <= max_line {
            if cur != pad {
                lines.append(cur);
            }
            cur = pad + item_flat;
            continue;
        }
        # Item needs multi-line expansion
        group_inner: GExpr | None = None;
        suffix = "";
        if isinstance(item, GOpt) and isinstance(item.inner, (GAlt, GSeq)) {
            group_inner = item.inner;
            suffix = "?";
        } elif isinstance(item, GStar) and isinstance(item.inner, (GAlt, GSeq)) {
            group_inner = item.inner;
            suffix = "*";
        } elif isinstance(item, GAlt) and len(item.choices) > 1 {
            group_inner = item;
            suffix = "";
        }
        if group_inner is not None {
            # Put ( on current line
            if cur != pad {
                lines.append(cur + " (");
            } else {
                lines.append(pad + "(");
            }
            # Format inner at indent + 4
            inner_str = self.format_expr_pretty(group_inner, indent + 4, max_line);
            lines.append(inner_str);
            cur = pad + ")" + suffix;
        } else {
            if cur != pad {
                lines.append(cur);
            }
            expanded = self.format_expr_pretty(item, indent, max_line);
            lines.append(expanded);
            cur = pad;
        }
    }
    if cur != pad {
        lines.append(cur);
    }
    return "\n".join(lines);
}

"""Format GOpt/GStar: try inline (inner)suffix, else expand."""
impl GrammarExtractPass.format_group_pretty(
    inner: GExpr, indent: int, max_line: int, suffix: str
) -> str {
    pad = " " * indent;
    inner_flat = GrammarExtractPass.format_ebnf(self, inner);
    needs_parens = isinstance(inner, (GAlt, GSeq));
    if not needs_parens {
        return pad + inner_flat + suffix;
    }
    inline = f"({inner_flat}){suffix}";
    if len(pad) + len(inline) <= max_line {
        return pad + inline;
    }
    inner_str = self.format_expr_pretty(inner, indent + 4, max_line);
    return f"{pad}(\n{inner_str}\n{pad}){suffix}";
}

"""Emit all extracted rules in EBNF format."""
impl GrammarExtractPass.emit_ebnf -> str {
    lines: list = [];
    for rule in self.rules {
        lines.append(self.format_rule_pretty(rule, "::=", 88));
    }
    return "\n\n".join(lines);
}

"""Emit all extracted rules in Lark format."""
impl GrammarExtractPass.emit_lark -> str {
    lines: list = [];
    for rule in self.rules {
        lines.append(self.format_rule_pretty(rule, ":", 88));
    }
    return "\n\n".join(lines);
}
