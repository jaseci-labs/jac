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

# -- GPlus ----------------------------------------------------------------
impl GPlus.__eq__(
    other: object
) -> bool {
    return isinstance(other, GPlus) and self.inner == other.inner;
}

impl GPlus.__repr__ -> str {
    return f"GPlus({self.inner!r})";
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
    if isinstance(expr, GPlus) {
        inner = fmt(self, expr.inner);
        if isinstance(expr.inner, (GAlt, GSeq)) {
            return f"({inner})+";
        }
        return f"{inner}+";
    }
    if isinstance(expr, GTok) {
        # Show human-readable token text: LBRACE → "{", KW_IF → "if"
        # Category tokens (NAME, INT, STRING, etc.) stay as-is
        kind = getattr(TokenKind, expr.name, None);
        if kind is not None and kind.value != expr.name {
            val = kind.value;
            # If value contains double quotes (e.g. fstring tokens f"),
            # use single quotes to avoid broken EBNF like "f""
            if '"' in val {
                return f"'{val}'";
            }
            return f'"{val}"';
        }
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
        simplified_opt = simp(self, expr.inner);
        # GOpt(GStar(x)) → GStar(x) since * already allows zero matches
        if isinstance(simplified_opt, GStar) {
            return simplified_opt;
        }
        return GOpt(inner=simplified_opt);
    }
    if isinstance(expr, GStar) {
        simplified_inner = simp(self, expr.inner);
        # GStar(GOpt(x)) → GStar(x) since * already allows zero matches
        if isinstance(simplified_inner, GOpt) {
            simplified_inner = simplified_inner.inner;
        }
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
    if isinstance(expr, GPlus) {
        return GPlus(inner=simp(self, expr.inner));
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
    # Post-processing pipeline
    self.rules = self._stage_simplify(self.rules);
    self.rules = self._stage_unwrap_top_opt(self.rules);
    self.rules = self._stage_dedup_tokens(self.rules);
    self.rules = self._stage_remove_errors(self.rules);
    self.rules = self._stage_remove_unreachable(self.rules);
}

# -------------------------------------------------------------------------
# Post-processing pipeline stages
# -------------------------------------------------------------------------
"""Simplify all extracted rules."""
impl GrammarExtractPass._stage_simplify(rules: list) -> list {
    result: list = [];
    for rule in rules {
        result.append(GrammarRule(name=rule.name, body=self.simplify_expr(rule.body)));
    }
    return result;
}

"""Strip top-level GOpt from rules with multi-alternative bodies.

Parser methods return None as fallback, making the extraction wrap
the entire dispatch in GOpt. But in a grammar spec, rules are
invoked when expected to match; optionality belongs at the call
site. Only strip when the inner is GAlt (real dispatch with
multiple alternatives)."""
impl GrammarExtractPass._stage_unwrap_top_opt(rules: list) -> list {
    result: list = [];
    for rule in rules {
        body = rule.body;
        if isinstance(body, GOpt) and isinstance(body.inner, GAlt) {
            result.append(GrammarRule(name=rule.name, body=body.inner));
        } else {
            result.append(rule);
        }
    }
    return result;
}

"""Deduplicate parent-child keyword tokens across all rules."""
impl GrammarExtractPass._stage_dedup_tokens(rules: list) -> list {
    rule_map: dict = {};
    for rule in rules {
        rule_map[rule.name] = rule;
    }
    result: list = [];
    for rule in rules {
        result.append(
            GrammarRule(
                name=rule.name,
                body=self._dedup_parent_child_tokens(rule.body, rule_map)
            )
        );
    }
    return result;
}

"""Remove error-recovery alternatives from the 'statement' rule."""
impl GrammarExtractPass._stage_remove_errors(rules: list) -> list {
    error_recovery_tokens: set = set(
        ["KW_ELIF", "KW_ELSE", "KW_EXCEPT", "KW_FINALLY", "KW_CASE"]
    );
    result: list = [];
    for rule in rules {
        if rule.name == "statement" and isinstance(rule.body, GAlt) {
            filtered: list = [];
            for choice in rule.body.choices {
                if isinstance(choice, GTok) and choice.name in error_recovery_tokens {
                    continue;
                }
                filtered.append(choice);
            }
            result.append(GrammarRule(name=rule.name, body=GAlt(choices=filtered)));
        } else {
            result.append(rule);
        }
    }
    return result;
}

"""Remove unreachable rules (defined but never referenced from module)."""
impl GrammarExtractPass._stage_remove_unreachable(rules: list) -> list {
    reachable: set = set();
    reachable_map: dict = {};
    for rule in rules {
        reachable_map[rule.name] = rule;
    }
    worklist: list = ["module"];
    while len(worklist) > 0 {
        name = worklist.pop();
        if name in reachable {
            continue;
        }
        reachable.add(name);
        if name in reachable_map {
            refs = self._collect_refs(reachable_map[name].body);
            for ref_name in refs {
                if ref_name not in reachable {
                    worklist.append(ref_name);
                }
            }
        }
    }
    result: list = [];
    for rule in rules {
        if rule.name in reachable {
            result.append(rule);
        }
    }
    return result;
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
    grammar_expr = self.interpret_stmts(list(body));
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

# =========================================================================
# FIRST Set Computation
# =========================================================================
"""Compute the FIRST set of terminal tokens for a grammar expression.

Returns (token_set, nullable) where:
- token_set: set of token names that can appear first
- nullable: True if the expression can match empty string"""
impl GrammarExtractPass.compute_first_set(expr: GExpr) -> tuple {
    if isinstance(expr, GTok) {
        return (set([expr.name]), False);
    }
    if isinstance(expr, GRef) {
        return (set(), False);
    }
    if isinstance(expr, GSeq) {
        result: set = set();
        for item in expr.items {
            item_result = self.compute_first_set(item);
            item_first: set = item_result[0];
            item_nullable: bool = item_result[1];
            result.update(item_first);
            if not item_nullable {
                return (result, False);
            }
        }
        return (result, True);
    }
    if isinstance(expr, GAlt) {
        result2: set = set();
        nullable = False;
        for choice in expr.choices {
            c_result = self.compute_first_set(choice);
            c_first: set = c_result[0];
            c_nullable: bool = c_result[1];
            result2.update(c_first);
            if c_nullable {
                nullable = True;
            }
        }
        return (result2, nullable);
    }
    if isinstance(expr, GOpt) {
        inner_result = self.compute_first_set(expr.inner);
        return (inner_result[0], True);
    }
    if isinstance(expr, GStar) {
        inner_result = self.compute_first_set(expr.inner);
        return (inner_result[0], True);
    }
    if isinstance(expr, GPlus) {
        return self.compute_first_set(expr.inner);
    }
    return (set(), False);
}

"""Check if every possible parse path through expr starts with a token in tok_set."""
impl GrammarExtractPass.all_paths_start_with(expr: GExpr, tok_set: set) -> bool {
    if isinstance(expr, GTok) {
        return expr.name in tok_set;
    }
    if isinstance(expr, GSeq) and len(expr.items) > 0 {
        first = expr.items[0];
        # If first item is optional, check both paths:
        # 1. Optional present: inner starts with tok_set
        # 2. Optional absent: next item starts with tok_set
        if isinstance(first, GOpt) and len(expr.items) > 1 {
            opt_starts = self.all_paths_start_with(first.inner, tok_set);
            rest_starts = self.all_paths_start_with(expr.items[1], tok_set);
            if opt_starts and rest_starts {
                return True;
            }
        }
        return self.all_paths_start_with(first, tok_set);
    }
    # GAlt: every alternative must start with a token from the set
    if isinstance(expr, GAlt) {
        if len(expr.choices) == 0 {
            return False;
        }
        for choice in expr.choices {
            if not self.all_paths_start_with(choice, tok_set) {
                return False;
            }
        }
        return True;
    }
    return False;
}

"""Determine if lookahead guard tokens are redundant with body."""
impl GrammarExtractPass.should_suppress_guard(
    guard_tokens: set, body: GExpr, body_stmt_count: int
) -> bool {
    # Pure delegation: body is GRef and the if-body has exactly one statement
    if isinstance(body, GRef) and body_stmt_count == 1 {
        return True;
    }
    # Body already starts with all guard tokens (using FIRST set)
    first_result = self.compute_first_set(body);
    body_first: set = first_result[0];
    if len(guard_tokens) > 0 and guard_tokens.issubset(body_first) {
        return True;
    }
    # GStar/GPlus where inner starts with guard tokens
    if isinstance(body, (GStar, GPlus)) {
        inner_result = self.compute_first_set(body.inner);
        inner_first: set = inner_result[0];
        if len(guard_tokens) > 0 and guard_tokens.issubset(inner_first) {
            return True;
        }
    }
    return False;
}

# =========================================================================
# Savepoint detection helpers
# =========================================================================
"""Check if expression is self.pos attribute access."""
impl GrammarExtractPass._is_self_pos_access(expr: uni.Expr) -> bool {
    if isinstance(expr, uni.AtomTrailer) and expr.is_attr {
        method = self.get_self_method(expr);
        if method == "pos" {
            return True;
        }
    }
    return False;
}

"""Detect savepoint pattern and return the delegated parse call.

Scans stmts for: save = self.pos; ...; self.pos = save; return self.parse_X();
Returns GRef for the parse_X call, or None if no savepoint pattern found."""
impl GrammarExtractPass._extract_savepoint_delegation(stmts: list) -> GExpr | None {
    if len(stmts) == 0 {
        return None;
    }
    first = stmts[0];
    if not isinstance(first, uni.Assignment) {
        return None;
    }
    if first.value is None or not self._is_self_pos_access(first.value) {
        return None;
    }
    # Found savepoint save. Recursively search remaining stmts
    # for return self.parse_X() (the real delegation after restore)
    return self._find_post_restore_delegation(stmts[1:]);
}

"""Recursively search statements for parse delegation after pos restore."""
impl GrammarExtractPass._find_post_restore_delegation(stmts: list) -> GExpr | None {
    for stmt in stmts {
        if isinstance(stmt, uni.ReturnStmt) and stmt.expr is not None {
            call = self.get_call_from_expr(stmt.expr);
            if call is not None {
                method = self.get_self_method(call.target);
                if method is not None and method.startswith("parse_") {
                    return GRef(name=method[6:]);
                }
            }
        }
        # Recurse into if-body and else-body
        if isinstance(stmt, (uni.IfStmt, uni.ElseIf)) {
            result = self._find_post_restore_delegation(list(stmt.body));
            if result is not None {
                return result;
            }
            if stmt.else_body is not None {
                if isinstance(stmt.else_body, uni.ElseStmt) {
                    result = self._find_post_restore_delegation(
                        list(stmt.else_body.body)
                    );
                    if result is not None {
                        return result;
                    }
                } elif isinstance(stmt.else_body, (uni.ElseIf, uni.IfStmt)) {
                    result = self._find_post_restore_delegation([stmt.else_body]);
                    if result is not None {
                        return result;
                    }
                }
            }
        }
    }
    return None;
}

# =========================================================================
# Phase 1: Interpretation
# =========================================================================
"""Extract grammar from a list of statements."""
impl GrammarExtractPass.interpret_stmts(stmts: list) -> GExpr | None {
    # Detect savepoint scanning
    savepoint_result = self._extract_savepoint_delegation(stmts);
    if savepoint_result is not None {
        return savepoint_result;
    }
    parts: list = [];
    alt_branches: list = [];
    i = 0;
    while i < len(stmts) {
        stmt = stmts[i];

        # Detect dispatch pattern: if self.check(...) { ... return ... }
        if isinstance(stmt, uni.IfStmt) or isinstance(stmt, uni.ElseIf) {
            cond_info = self.interpret_condition(stmt.condition);
            if cond_info is not None and self.has_early_return(list(stmt.body)) {
                branches = self.collect_dispatch_chain(stmt);
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
                body_expr = self.interpret_stmts(list(stmt.body));
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
                    fallback = self.interpret_call(call);
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
        if len(alt_branches) > 0 {
            remaining = stmts[i:];
            remaining_expr = self.interpret_stmts(remaining);
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
        expr = self.interpret_stmt(stmt);
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

"""Check if condition is a negated check pattern."""
impl GrammarExtractPass.is_negated_check(cond: uni.Expr) -> bool {
    if isinstance(cond, uni.UnaryExpr) {
        if cond.op is not None and cond.op?.value and cond.op.value == "not" {
            if isinstance(cond.operand, uni.FuncCall) {
                method = self.get_self_method(cond.operand.target);
                if method is not None {
                    sem = METHOD_TABLE.get(method);
                    if sem is not None
                    and (sem.kind.startswith("lookahead") or sem.kind == "consume_opt") {
                        return True;
                    }
                }
            }
        }
        return False;
    }
    if isinstance(cond, uni.BoolExpr) {
        if not (cond.op and cond.op?.value and cond.op.value == "and") {
            return False;
        }
        if not cond.values or len(cond.values) == 0 {
            return False;
        }
        for val in cond.values {
            if not self.is_negated_check(val) {
                return False;
            }
        }
        return True;
    }
    if isinstance(cond, uni.BinaryExpr) {
        if cond.op and cond.op?.value and cond.op.value in ("and", "&&") {
            return (
                self.is_negated_check(cond.left) and self.is_negated_check(cond.right)
            );
        }
    }
    return False;
}

# -------------------------------------------------------------------------
# Single statement interpretation
# -------------------------------------------------------------------------
"""Extract grammar from a single statement."""
impl GrammarExtractPass.interpret_stmt(stmt: uni.UniNode) -> GExpr | None {
    if isinstance(stmt, uni.ExprStmt) {
        call = self.get_call_from_expr(stmt.expr);
        if call is not None {
            return self.interpret_call(call);
        }
        return None;
    }
    if isinstance(stmt, uni.Assignment) {
        if stmt.value is not None {
            call = self.get_call_from_expr(stmt.value);
            if call is not None {
                return self.interpret_call(call);
            }
            # Handle ternary: x = parse_X() if check(Y) else parse_Z()
            if isinstance(stmt.value, uni.IfElseExpr) {
                ternary = stmt.value;
                ternary_parts: list = [];
                true_call = self.get_call_from_expr(ternary.value);
                if true_call is not None {
                    true_result = self.interpret_call(true_call);
                    if true_result is not None {
                        ternary_parts.append(true_result);
                    }
                }
                false_call = self.get_call_from_expr(ternary.else_value);
                if false_call is not None {
                    false_result = self.interpret_call(false_call);
                    if false_result is not None {
                        ternary_parts.append(false_result);
                    }
                }
                if len(ternary_parts) == 1 {
                    return ternary_parts[0];
                }
                if len(ternary_parts) > 1 {
                    if repr(ternary_parts[0]) == repr(ternary_parts[1]) {
                        return ternary_parts[0];
                    }
                    return GAlt(choices=ternary_parts);
                }
            }
            # Handle list initialization: x = [self.parse_X()]
            if isinstance(stmt.value, uni.ListVal) and hasattr(stmt.value, 'values') {
                for elem in stmt.value.values {
                    inner_call = self.get_call_from_expr(elem);
                    if inner_call is not None {
                        result = self.interpret_call(inner_call);
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
        return self.interpret_if(stmt);
    }
    if isinstance(stmt, uni.WhileStmt) {
        return self.interpret_while(stmt);
    }
    if isinstance(stmt, uni.ReturnStmt) {
        if stmt.expr is not None {
            call = self.get_call_from_expr(stmt.expr);
            if call is not None {
                return self.interpret_call(call);
            }
        }
        return None;
    }
    return None;
}

# -------------------------------------------------------------------------
# Interpret function calls
# -------------------------------------------------------------------------
"""Determine if a call is grammar-relevant using METHOD_TABLE."""
impl GrammarExtractPass.interpret_call(call: uni.FuncCall) -> GExpr | None {
    method = self.get_self_method(call.target);
    if method is not None {
        # Check method table first
        sem = METHOD_TABLE.get(method);
        if sem is not None {
            if sem.kind == "consume" {
                if sem.token_args {
                    tokens = self.get_token_args(call);
                    if len(tokens) > 0 {
                        return GTok(name=tokens[0]);
                    }
                    return None;
                }
                return None;
            }
            if sem.kind == "consume_name" {
                return GTok(name="NAME");
            }
            if sem.kind == "consume_opt" {
                tokens = self.get_token_args(call);
                if len(tokens) > 0 {
                    return GOpt(inner=GTok(name=tokens[0]));
                }
                return None;
            }
            # consume_raw, lookahead*, ignore → no grammar
            return None;
        }
        # Not in table: check for parse_* delegation
        if method.startswith("parse_") {
            return GRef(name=method[6:]);
        }
        return None;
    }
    # Not a self.method call — scan arguments for grammar-relevant calls.
    # Handles patterns like: values.append(self.parse_X())
    for param in call.params {
        inner_call = self.get_call_from_expr(param);
        if inner_call is not None {
            result = self.interpret_call(inner_call);
            if result is not None {
                return result;
            }
        }
    }
    return None;
}

# -------------------------------------------------------------------------
# Interpret if statements
# -------------------------------------------------------------------------
"""Extract grammar from an if statement."""
impl GrammarExtractPass.interpret_if(stmt: uni.IfStmt) -> GExpr | None {
    cond_info = self.interpret_condition(stmt.condition);
    if cond_info is None {
        # Negated guard: if not check(SEMI) and not check(RBRACE) { body } → GOpt(body)
        if self.is_negated_check(stmt.condition) and stmt.else_body is None {
            opt_body = self.interpret_stmts(list(stmt.body));
            if opt_body is not None {
                return GOpt(inner=opt_body);
            }
            return None;
        }
        body_expr = self.interpret_stmts(list(stmt.body));
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
                    eb = self.interpret_stmts(list(cur_alt.body));
                    if eb is not None {
                        alt_list.append(eb);
                    }
                    cur_alt = cur_alt?.else_body;
                } elif isinstance(cur_alt, uni.ElseStmt) {
                    eb = self.interpret_stmts(list(cur_alt.body));
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
                else_expr = self.interpret_if(stmt.else_body);
            } elif isinstance(stmt.else_body, uni.ElseStmt) {
                else_expr = self.interpret_stmts(list(stmt.else_body.body));
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
    # if self.match_tok(X) { body } -> optional (X body)?
    if cond_info.kind == "consume_opt" and len(cond_info.tokens) > 0 {
        body_expr = self.interpret_stmts(list(stmt.body));
        inner_parts: list = [GTok(name=cond_info.tokens[0])];
        if body_expr is not None {
            inner_parts.append(body_expr);
        }
        inner: GExpr = GSeq(items=inner_parts)
        if len(inner_parts) > 1
        else inner_parts[0];
        if stmt.else_body is not None {
            else_expr2: GExpr | None = None;
            if isinstance(stmt.else_body, (uni.ElseIf, uni.IfStmt)) {
                else_expr2 = self.interpret_if(stmt.else_body);
            } elif isinstance(stmt.else_body, uni.ElseStmt) {
                else_expr2 = self.interpret_stmts(list(stmt.else_body.body));
            }
            if else_expr2 is not None {
                return GAlt(choices=[inner, else_expr2]);
            }
        }
        return GOpt(inner=inner);
    }
    # if self.check(X) / check_any(X,Y) { body } [elif ...] -> optional/alt
    if cond_info.kind.startswith("lookahead") {
        branches = self.collect_dispatch_chain(stmt);
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
# Collect dispatch chain
# -------------------------------------------------------------------------
"""Collect grammar expressions from all branches of an if-elif chain."""
impl GrammarExtractPass.collect_dispatch_chain(stmt: uni.IfStmt) -> list {
    branches: list = [];
    cur: uni.IfStmt | None = stmt;
    while cur is not None {
        cond_info = self.interpret_condition(cur.condition);
        branch_body = self.interpret_stmts(list(cur.body));

        if cond_info is not None {
            if cond_info.kind.startswith("lookahead") {
                tokens: list = cond_info.tokens;
                tok_expr: GExpr | None = None;
                if len(tokens) > 1 {
                    tok_expr = GAlt(choices=[GTok(name=t) for t in tokens]);
                } elif len(tokens) == 1 {
                    tok_expr = GTok(name=tokens[0]);
                }
                if tok_expr is not None and branch_body is not None {
                    # Build guard token set for suppression check
                    guard_tok_set: set = set(tokens);
                    body_stmt_count = len(list(cur.body));
                    if self.should_suppress_guard(
                        guard_tok_set, branch_body, body_stmt_count
                    ) {
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
            } elif cond_info.kind == "consume_opt" and len(cond_info.tokens) > 0 {
                inner_parts: list = [GTok(name=cond_info.tokens[0])];
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
                else_expr = self.interpret_stmts(list(cur.else_body.body));
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
# Interpret while statements
# -------------------------------------------------------------------------
"""Extract grammar from a while loop."""
impl GrammarExtractPass.interpret_while(stmt: uni.WhileStmt) -> GExpr | None {
    cond_info = self.interpret_condition(stmt.condition);
    if cond_info is None {
        # Handle `while True { body; if not self.match_tok(X) { break; } }`
        if isinstance(stmt.condition, uni.Bool) and stmt.condition.value == "True" {
            # Pattern 1: if not match_tok(X) { break; } at end
            break_info = self.find_break_match_tok(list(stmt.body));
            if break_info is not None {
                break_tokens: list = break_info[0];
                body_stmts: list = break_info[1];
                body_expr = self.interpret_stmts(body_stmts);
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
            # Pattern 2: x = parse_X(); if x is None { break; }
            none_check_info = self.find_break_none_check(list(stmt.body));
            if none_check_info is not None {
                ref_name: str = none_check_info[0];
                remaining_stmts: list = none_check_info[1];
                remaining_expr = self.interpret_stmts(remaining_stmts);
                inner_parts2: list = [GRef(name=ref_name)];
                if remaining_expr is not None {
                    inner_parts2.append(remaining_expr);
                }
                inner2: GExpr = GSeq(items=inner_parts2)
                if len(inner_parts2) > 1
                else inner_parts2[0];
                return GStar(inner=inner2);
            }
            # Pattern 3: while True { ...; if ... elif ... else { break; }; ... }
            # Find an if/elif chain ending in else{break} anywhere in the body.
            body_stmts3 = list(stmt.body);
            break_chain_idx: int = -1;
            for idx3 in range(len(body_stmts3)) {
                s3 = body_stmts3[idx3];
                if not isinstance(s3, (uni.IfStmt, uni.ElseIf)) {
                    continue;
                }
                cur3: uni.UniNode | None = s3;
                found_break3 = False;
                while cur3 is not None {
                    if not hasattr(cur3, 'else_body') or cur3.else_body is None {
                        break;
                    }
                    if isinstance(cur3.else_body, uni.ElseStmt) {
                        else_stmts3 = list(cur3.else_body.body);
                        if len(else_stmts3) == 1
                        and isinstance(else_stmts3[0], uni.CtrlStmt)
                        and else_stmts3[0].ctrl is not None
                        and else_stmts3[0].ctrl.value == "break" {
                            found_break3 = True;
                        }
                        break;
                    }
                    if isinstance(cur3.else_body, (uni.ElseIf, uni.IfStmt)) {
                        cur3 = cur3.else_body;
                    } else {
                        break;
                    }
                }
                if found_break3 {
                    break_chain_idx = idx3;
                    break;
                }
            }
            if break_chain_idx >= 0 {
                if_chain3 = body_stmts3[break_chain_idx];
                branches3 = self.collect_dispatch_chain(if_chain3);
                if len(branches3) > 0 {
                    # Build dispatch expression from break-chain branches
                    dispatch3: GExpr;
                    if len(branches3) == 1 {
                        dispatch3 = branches3[0];
                    } else {
                        dispatch3 = GAlt(choices=branches3);
                    }
                    # Interpret any remaining stmts after the break-chain
                    after_stmts3 = body_stmts3[break_chain_idx + 1:];
                    after_expr3 = self.interpret_stmts(after_stmts3)
                    if len(after_stmts3) > 0
                    else None;
                    if after_expr3 is not None {
                        return GStar(inner=GSeq(items=[dispatch3, after_expr3]));
                    }
                    return GStar(inner=dispatch3);
                }
            }
        }
        # Handle: while not self.check(X) { body } → body*
        if self.is_negated_check(stmt.condition) {
            body_expr = self.interpret_stmts(list(stmt.body));
            if body_expr is not None {
                return GStar(inner=body_expr);
            }
            return None;
        }
        return self.interpret_stmts(list(stmt.body));
    }
    tokens: list = cond_info.tokens;
    # while match_tok(X) { body } → (X body)*
    if cond_info.kind == "consume_opt" and len(tokens) > 0 {
        body_expr = self.interpret_stmts(list(stmt.body));
        inner_parts: list = [GTok(name=tokens[0])];
        if body_expr is not None {
            inner_parts.append(body_expr);
        }
        inner: GExpr = GSeq(items=inner_parts)
        if len(inner_parts) > 1
        else inner_parts[0];
        return GStar(inner=inner);
    }
    # while check(X) / check_any(X,Y) { body } → (body)*
    if cond_info.kind.startswith("lookahead") and len(tokens) > 0 {
        body_expr = self.interpret_stmts(list(stmt.body));
        # If body already contains condition tokens (via consume_uni/expect),
        # skip adding them to avoid duplication.
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
# Find break patterns in while True bodies
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

"""Find `x = self.parse_X(); if x is None { break; }` at start of while True body.

Returns (rule_name, remaining_body_stmts) or None."""
impl GrammarExtractPass.find_break_none_check(stmts: list) -> tuple | None {
    if len(stmts) < 2 {
        return None;
    }
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
    second = stmts[1];
    if not isinstance(second, uni.IfStmt) {
        return None;
    }
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

# =========================================================================
# Condition Analysis (table-driven)
# =========================================================================
"""Resolve tokens for a parser method call using the method table."""
impl GrammarExtractPass._resolve_tokens(method: str, call: uni.FuncCall | None) -> list {
    # Check special parameterless methods first
    if method in SPECIAL_LOOKAHEAD_TOKENS {
        return list(SPECIAL_LOOKAHEAD_TOKENS[method]);
    }
    # For methods that take token args, extract them
    if call is not None {
        sem = METHOD_TABLE.get(method);
        if sem is not None and sem.token_args {
            return self.get_token_args(call);
        }
    }
    return [];
}

"""Merge OR conditions from a list of expressions into a single ConditionResult."""
impl GrammarExtractPass._merge_or_conditions(exprs: list) -> ConditionResult | None {
    all_toks: list = [];
    found_method: str | None = None;
    found_kind: str | None = None;
    for val in exprs {
        if isinstance(val, uni.FuncCall) {
            m = self.get_self_method(val.target);
            if m is not None {
                sem = METHOD_TABLE.get(m);
                if sem is not None
                and (sem.kind.startswith("lookahead") or sem.kind == "consume_opt") {
                    tks = self._resolve_tokens(m, val);
                    all_toks.extend(tks);
                    if found_method is None {
                        found_method = m;
                        found_kind = sem.kind;
                    }
                    continue;
                }
            }
        }
        # Recurse into nested expressions
        if isinstance(val, (uni.BoolExpr, uni.BinaryExpr, uni.AtomUnit)) {
            nested = self.interpret_condition(val);
            if nested is not None {
                all_toks.extend(nested.tokens);
                if found_method is None {
                    found_method = nested.method;
                    found_kind = nested.kind;
                }
            }
        }
    }
    if found_method is not None and len(all_toks) > 0 {
        return ConditionResult(method=found_method, kind=found_kind, tokens=all_toks);
    }
    return None;
}

"""Analyze condition. Returns ConditionResult or None."""
impl GrammarExtractPass.interpret_condition(cond: uni.Expr) -> ConditionResult | None {
    # Unwrap parenthesized expressions (AtomUnit wraps inner expr in parens)
    if isinstance(cond, uni.AtomUnit) and cond.value is not None {
        return self.interpret_condition(cond.value);
    }
    # Direct function call: self.check(X), self.match_tok(X), etc.
    if isinstance(cond, uni.FuncCall) {
        method = self.get_self_method(cond.target);
        if method is not None {
            sem = METHOD_TABLE.get(method);
            if sem is not None
            and (sem.kind.startswith("lookahead") or sem.kind == "consume_opt") {
                tokens = self._resolve_tokens(method, cond);
                return ConditionResult(method=method, kind=sem.kind, tokens=tokens);
            }
        }
        return None;
    }
    # CompareExpr: self.peek().kind == TokenKind.X or self.current().kind in [...]
    # Guard: only treat as lookahead if left side references self.* (parser state),
    # not a local variable like edge_tok.kind (already-consumed token).
    if isinstance(cond, uni.CompareExpr) {
        if cond.ops is not None
        and len(cond.ops) > 0
        and cond.rights is not None
        and len(cond.rights) > 0 {
            # Check that left side involves a self.method() call
            left_involves_self = False;
            left = cond.left;
            # Walk AtomTrailer chain to find self reference
            check_node: uni.UniNode | None = left;
            while check_node is not None {
                if isinstance(check_node, uni.SpecialVarRef)
                and check_node.value == "self" {
                    left_involves_self = True;
                    break;
                }
                if isinstance(check_node, uni.Name) and check_node.value == "self" {
                    left_involves_self = True;
                    break;
                }
                if isinstance(check_node, uni.AtomTrailer) {
                    check_node = check_node.target;
                } elif isinstance(check_node, uni.FuncCall) {
                    check_node = check_node.target;
                } else {
                    break;
                }
            }
            if left_involves_self {
                op_val = "";
                if hasattr(cond.ops[0], 'value') {
                    op_val = cond.ops[0].value;
                }
                if op_val == "==" {
                    right = cond.rights[0];
                    tok_name = self.extract_token_kind(right);
                    if tok_name is not None {
                        return ConditionResult(
                            method="check", kind="lookahead", tokens=[tok_name]
                        );
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
                            return ConditionResult(
                                method="check", kind="lookahead", tokens=tok_names
                            );
                        }
                    }
                }
            }
        }
    }
    # BoolExpr: and/or with multiple values
    if isinstance(cond, uni.BoolExpr) {
        is_or = cond?.op and cond.op?.value and cond.op.value == "or";
        if is_or and cond?.values {
            return self._merge_or_conditions(list(cond.values));
        }
        # For AND: find the first grammar-relevant condition
        if cond?.values and len(cond.values) > 0 {
            for val in cond.values {
                nested = self.interpret_condition(val);
                if nested is not None {
                    return nested;
                }
            }
        }
    }
    # BinaryExpr: or/and with left/right
    if isinstance(cond, uni.BinaryExpr) {
        if cond?.op and cond.op?.value {
            if cond.op.value in ("or", "||") {
                return self._merge_or_conditions([cond.left, cond.right]);
            }
            if cond.op.value in ("and", "&&") {
                # For AND: take the first grammar-relevant condition
                left_result = self.interpret_condition(cond.left);
                if left_result is not None {
                    return left_result;
                }
                return self.interpret_condition(cond.right);
            }
        }
    }
    return None;
}

# =========================================================================
# Post-processing helpers
# =========================================================================
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
    if isinstance(expr, GPlus) {
        return self.expr_contains_tok(expr.inner, tok_name);
    }
    return False;
}

"""Collect all GRef names from a grammar expression."""
impl GrammarExtractPass._collect_refs(body: GExpr) -> set {
    refs: set = set();
    if isinstance(body, GRef) {
        refs.add(body.name);
    } elif isinstance(body, GSeq) {
        for item in body.items {
            refs.update(self._collect_refs(item));
        }
    } elif isinstance(body, GAlt) {
        for c in body.choices {
            refs.update(self._collect_refs(c));
        }
    } elif isinstance(body, (GOpt, GStar, GPlus)) {
        refs.update(self._collect_refs(body.inner));
    }
    return refs;
}

"""Walk a grammar expression and remove duplicated parent-child tokens.

When a parent has GTok(X) GRef(Y) (or GAlt of GToks before GRef) and
rule Y starts with those same tokens, the keyword would appear twice.
Remove the duplicate from the parent."""
impl GrammarExtractPass._dedup_parent_child_tokens(
    expr: GExpr, rule_map: dict
) -> GExpr {
    dedup = GrammarExtractPass._dedup_parent_child_tokens;
    if isinstance(expr, GSeq) {
        new_items: list = [];
        i = 0;
        while i < len(expr.items) {
            item = expr.items[i];
            # Check for GTok(X) or GAlt([GTok(A), GTok(B), ...]) followed by GRef(Y)
            if i + 1 < len(expr.items) and isinstance(expr.items[i + 1], GRef) {
                ref = expr.items[i + 1];
                should_remove = False;
                if ref.name in rule_map {
                    child_body = rule_map[ref.name].body;
                    # Extract guard token set from item
                    guard_toks: set = set();
                    if isinstance(item, GTok) {
                        guard_toks.add(item.name);
                    } elif isinstance(item, GAlt) {
                        all_gtoks = True;
                        for c in item.choices {
                            if not isinstance(c, GTok) {
                                all_gtoks = False;
                                break;
                            }
                            guard_toks.add(c.name);
                        }
                        if not all_gtoks {
                            guard_toks = set();
                        }
                    }
                    if len(guard_toks) > 0 {
                        # Check if child body always starts with guard tokens
                        if self.all_paths_start_with(child_body, guard_toks) {
                            should_remove = True;
                        }
                        # Also check GStar/GPlus inner
                        elif isinstance(child_body, (GStar, GPlus)) {
                            if self.all_paths_start_with(child_body.inner, guard_toks) {
                                should_remove = True;
                            }
                        }
                    }
                }
                if should_remove {
                    # Skip the duplicated token(s), keep only GRef
                    i += 1;
                    new_items.append(dedup(self, expr.items[i], rule_map));
                    i += 1;
                    continue;
                }
            }
            new_items.append(dedup(self, item, rule_map));
            i += 1;
        }
        if len(new_items) == 1 {
            return new_items[0];
        }
        return GSeq(items=new_items);
    }
    if isinstance(expr, GAlt) {
        return GAlt(choices=[dedup(self, c, rule_map) for c in expr.choices]);
    }
    if isinstance(expr, GOpt) {
        return GOpt(inner=dedup(self, expr.inner, rule_map));
    }
    if isinstance(expr, GStar) {
        return GStar(inner=dedup(self, expr.inner, rule_map));
    }
    if isinstance(expr, GPlus) {
        return GPlus(inner=dedup(self, expr.inner, rule_map));
    }
    return expr;
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
    if isinstance(expr, GPlus) {
        return self.format_group_pretty(expr.inner, indent, max_line, "+");
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
