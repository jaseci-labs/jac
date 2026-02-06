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
        return GStar(inner=simp(self, expr.inner));
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
impl GrammarExtractPass.enter_impl_def(<>node: uni.ImplDef) -> None {
    names = self.get_impl_target_names(node);
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
    body = node.body;
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
impl GrammarExtractPass.get_impl_target_names(node: uni.ImplDef) -> list {
    names: list = [];
    for name_atom in node.target {
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
        }

        # If we hit a return after dispatch branches, it's the fallback
        if isinstance(stmt, uni.ReturnStmt) and len(alt_branches) > 0 {
            if stmt.expr is not None {
                call = self.get_call_from_expr(stmt.expr);
                if call is not None {
                    fallback = self.analyze_func_call(call);
                    if fallback is not None {
                        alt_branches.append(fallback);
                    }
                }
            }
            if len(alt_branches) == 1 {
                parts.append(alt_branches[0]);
            } elif len(alt_branches) > 1 {
                parts.append(GAlt(choices=alt_branches));
            }
            alt_branches = [];
            i += 1;
            continue;
        }

        # Flush any pending alternatives
        if len(alt_branches) > 0 {
            if len(alt_branches) == 1 {
                parts.append(GOpt(inner=alt_branches[0]));
            } else {
                parts.append(GOpt(inner=GAlt(choices=alt_branches)));
            }
            alt_branches = [];
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

"""Check if a statement list contains a return statement."""
impl GrammarExtractPass.has_early_return(stmts: list) -> bool {
    for stmt in stmts {
        if isinstance(stmt, uni.ReturnStmt) {
            return True;
        }
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
    if method is None {
        return None;
    }
    if method == "expect" {
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
    return None;
}

# -------------------------------------------------------------------------
# Analyze if statements
# -------------------------------------------------------------------------
"""Extract grammar from an if statement."""
impl GrammarExtractPass.analyze_if_stmt(stmt: uni.IfStmt) -> GExpr | None {
    cond_info = self.analyze_condition(stmt.condition);
    if cond_info is None {
        body_expr = self.extract_from_stmts(list(stmt.body));
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
    if method in ("check", "check_any") {
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
            if method in ("check", "check_any") {
                tok_expr: GExpr | None = None;
                if len(tokens) > 1 {
                    tok_expr = GAlt(choices=[GTok(name=t) for t in tokens]);
                } elif len(tokens) == 1 {
                    tok_expr = GTok(name=tokens[0]);
                }
                if tok_expr is not None and branch_body is not None {
                    branches.append(GSeq(items=[tok_expr, branch_body]));
                } elif tok_expr is not None {
                    branches.append(tok_expr);
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
    if method in ("check", "check_any") and len(tokens) > 0 {
        body_expr = self.extract_from_stmts(list(stmt.body));
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
# Condition analysis
# -------------------------------------------------------------------------
"""Analyze condition. Returns (method_name, [token_names]) or None."""
impl GrammarExtractPass.analyze_condition(cond: uni.Expr) -> tuple | None {
    if isinstance(cond, uni.FuncCall) {
        method = self.get_self_method(cond.target);
        if method in ("check", "check_any", "match_tok") {
            tokens = self.get_token_args(cond);
            return (method, tokens);
        }
    }
    # Boolean AND: self.check(X) and something_else
    if isinstance(cond, uni.BoolExpr) {
        if cond?.values and len(cond.values) > 0 {
            first = cond.values[0];
            if isinstance(first, uni.FuncCall) {
                method = self.get_self_method(first.target);
                if method in ("check", "check_any", "match_tok") {
                    tokens = self.get_token_args(first);
                    return (method, tokens);
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
                    if method in ("check", "check_any", "match_tok") {
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
"""Extract method name from self.method access."""
impl GrammarExtractPass.get_self_method(node: uni.Expr) -> str | None {
    if isinstance(node, uni.AtomTrailer) and node.is_attr {
        target = node.target;
        right = node.right;
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
"""Emit all extracted rules in EBNF format."""
impl GrammarExtractPass.emit_ebnf -> str {
    lines: list = [];
    for rule in self.rules {
        lines.append(rule.to_ebnf());
    }
    return "\n".join(lines);
}

"""Emit all extracted rules in Lark format."""
impl GrammarExtractPass.emit_lark -> str {
    lines: list = [];
    for rule in self.rules {
        lines.append(rule.to_lark());
    }
    return "\n".join(lines);
}
