"""pycparser C-AST → CPython ast mapper (Python-AST path).

Covers P1a (scalar expressions, control flow), P1b (structs), P1c (arrays).
Dispatch-miss fallback emits __c2jac_unsupported__ / __c2jac_unsupported_expr__
surrogates that are syntactically valid Jac, satisfying §8.2.

DIRECT_IR nodes (For, Enum, Enumerator, EnumeratorList) are replaced by
placeholder call expressions keyed on a slot_id; the driver splices in the real
uni nodes after PyastBuildPass runs.
"""

import ast as ast3;
import from pycparser { c_ast }
import from jaclang.compiler.c2jac.tags { Tier, Mechanism, Idiom, NodeTag, TagTable }
import from jaclang.compiler.c2jac.boundary { default_tier, default_mechanism }
import from jaclang.compiler.c2jac.c_common {
    C_BINOPS,
    C_AUGOPS,
    parse_c_int,
    parse_c_float,
    coord_of
}

# COUPLING: _SLOT_SENTINEL is emitted here as a plain Name in an ExprStmt
# (`__c2jac_directir__(slot_id)`) and rides PyastBuildPass *untouched* — it is an
# ordinary identifier to that pass — then driver._splice_directir greps the uni
# tree for ExprStmts whose call target Name equals this exact string and swaps in
# the real direct-IR nodes. The string must therefore stay in sync between this
# module and the driver, and must remain something PyastBuildPass never rewrites.
glob _SLOT_SENTINEL: str = "__c2jac_directir__",
     _UNSUPPORTED_STMT: str = "__c2jac_unsupported__",
     _UNSUPPORTED_EXPR: str = "__c2jac_unsupported_expr__",
     # C primitive/builtin type names that must NOT be treated as struct/typedef
     # names when resolving a pointer or sizeof target to a Jac type reference.
     _C_BUILTIN_TYPES: set = {
         "int",
         "float",
         "double",
         "void",
         "char",
         "long",
         "short",
         "unsigned",
         "signed",
         "bool",
         "size_t",

     },
     # Canonical C-primitive → Jac builtin type-name map. Any C type name absent
     # here resolves to "int" (the conservative scalar default). Single source of
     # truth for every scalar type-name lookup in this module.
     _C_PRIM_MAP: dict = {
         "int": "int",
         "float": "float",
         "double": "float",
         "char": "str",
         "void": "None",
         "long": "int",
         "short": "int",
         "unsigned": "int",
         "signed": "int",
         "bool": "bool",

     };

obj CMapper {
    has tags: TagTable,
        slot_map: dict[int, object],  # slot_id -> c_node
        _next_slot: int,
        _lineno: int,
        _list_bound: set[str],  # names known to back a Jac list (§7.5 realloc-elide)
        _func_depth: int;  # >0 while building a function body (function-local scope)

    def init(tags: TagTable) {
        self.tags = tags;
        self.slot_map = {};
        self._next_slot = 0;
        self._lineno = 1;
        self._list_bound = set();
        self._func_depth = 0;
    }

    # ------------------------------------------------------------------ #
    # Coordinate helpers                                                   #
    # ------------------------------------------------------------------ #
    def _loc(c_node: object) -> tuple[int, int] {
        # Resolve coords via the shared helper, threading the running last-seen
        # line as the fallback so coord-less synthesized nodes stay near source.
        (line, col) = coord_of(c_node, self._lineno);
        self._lineno = line;
        return (line, col);
    }

    def _stamp(py_node: object, c_node: object, *, text: str = "") -> object {
        (line, col) = self._loc(c_node);
        py_node.lineno = line;
        py_node.col_offset = col;
        py_node.end_lineno = line;
        py_node.end_col_offset = col + max(len(text), 1);
        return py_node;
    }

    def _stamp_manual(
        py_node: object, line: int, col: int, *, text: str = ""
    ) -> object {
        py_node.lineno = line;
        py_node.col_offset = col;
        py_node.end_lineno = line;
        py_node.end_col_offset = col + max(len(text), 1);
        return py_node;
    }

    def _alloc_slot(c_node: object) -> int {
        sid = self._next_slot;
        self._next_slot += 1;
        self.slot_map[sid] = c_node;
        return sid;
    }

    # ------------------------------------------------------------------ #
    # Fallback surrogate (§8.2 validity backstop)                         #
    # ------------------------------------------------------------------ #
    def _surrogate_stmt(c_node: object) -> object {
        (line, col) = self._loc(c_node);
        reason = f"{type(c_node).__name__} @ L{line}";
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_B,
                mechanism=Mechanism.PY_AST,
                idiom=Idiom.TIER_B,
                reason=reason,
                c_line=line,
                snippet=reason
            )
        );
        name_n = self._stamp_manual(
            ast3.Name(id=_UNSUPPORTED_STMT, ctx=ast3.Load()),
            line,
            col,
            text=_UNSUPPORTED_STMT
        );
        # Anchor arg is the C-source line as an INT, not the reason string. A
        # string Constant here would be re-sliced from orig_src (the C source) by
        # PyastBuildPass._get_source_segment — the manual coords point into the C
        # text — emitting invalid Jac (e.g. `__c2jac_unsupported__(U { int i; )`).
        # An int uses str(value) verbatim, so the call stays valid Jac, and the
        # line doubles as the key the post-format comment injector matches on (§7).
        line_c = self._stamp_manual(
            ast3.Constant(value=line), line, col, text=str(line)
        );
        call_n = self._stamp_manual(
            ast3.Call(func=name_n, args=[line_c], keywords=[]), line, col
        );
        return self._stamp_manual(ast3.Expr(value=call_n), line, col);
    }

    def _surrogate_expr(c_node: object) -> object {
        (line, col) = self._loc(c_node);
        reason = f"{type(c_node).__name__} @ L{line}";
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_B,
                mechanism=Mechanism.PY_AST,
                idiom=Idiom.TIER_B,
                reason=reason,
                c_line=line,
                snippet=reason
            )
        );
        name_n = self._stamp_manual(
            ast3.Name(id=_UNSUPPORTED_EXPR, ctx=ast3.Load()),
            line,
            col,
            text=_UNSUPPORTED_EXPR
        );
        # Int line anchor, not the reason string — see _surrogate_stmt for why a
        # string Constant would re-slice the C source into invalid Jac.
        line_c = self._stamp_manual(
            ast3.Constant(value=line), line, col, text=str(line)
        );
        return self._stamp_manual(
            ast3.Call(func=name_n, args=[line_c], keywords=[]), line, col
        );
    }

    def _mark_tier_b(c_node: object, reason: str) {
        # Retag a node Tier-B for a lossy-but-best-effort emission. Unlike the
        # surrogate helpers this does NOT replace the emitted Jac — the handler
        # still emits its best-effort form — it only records the loss so the
        # node is flagged in the Tier-B comments (§3 honest-report invariant). Used by
        # representation-changing casts and side-effect-dropping comma/designated
        # initializers, which would otherwise silently stay at the default
        # Tier-A from _populate_default_tags.
        (line, _) = self._loc(c_node);
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_B,
                mechanism=Mechanism.PY_AST,
                idiom=Idiom.TIER_B,
                reason=reason,
                c_line=line,
                snippet=reason
            )
        );
    }

    def _mark_tier_a(c_node: object, idiom: Idiom, reason: str = "") {
        # Record a recognized Tier-A pointer idiom (§7). The handler still emits
        # the faithful Jac form; this only stamps the verdict so the idiom is
        # queryable (TagTable.by_idiom) for metrics/tests. Tier-A is never
        # flagged in the Tier-B comments (which surface Tier-B only).
        (line, _) = self._loc(c_node);
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_A,
                mechanism=Mechanism.PY_AST,
                idiom=idiom,
                reason=reason,
                c_line=line,
                snippet=reason
            )
        );
    }

    def _mark_tier_b_idiom(c_node: object, idiom: Idiom, reason: str) {
        # Tier-B emission carrying a *specific* idiom verdict (e.g. a realloc we
        # elided but could not prove list-bound). Like _mark_tier_b but preserves
        # the idiom so the report names what was attempted, not a bare "tier_b".
        (line, _) = self._loc(c_node);
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_B,
                mechanism=Mechanism.PY_AST,
                idiom=idiom,
                reason=reason,
                c_line=line,
                snippet=reason
            )
        );
    }

    # ------------------------------------------------------------------ #
    # Direct-IR placeholder                                                #
    # ------------------------------------------------------------------ #
    def _directir_placeholder(c_node: object) -> object {
        (line, col) = self._loc(c_node);
        sid = self._alloc_slot(c_node);
        name_n = self._stamp_manual(
            ast3.Name(id=_SLOT_SENTINEL, ctx=ast3.Load()),
            line,
            col,
            text=_SLOT_SENTINEL
        );
        sid_c = self._stamp_manual(ast3.Constant(value=sid), line, col, text=str(sid));
        call_n = self._stamp_manual(
            ast3.Call(func=name_n, args=[sid_c], keywords=[]), line, col
        );
        return self._stamp_manual(ast3.Expr(value=call_n), line, col);
    }

    # ------------------------------------------------------------------ #
    # Main dispatch                                                        #
    # ------------------------------------------------------------------ #
    def conv(c_node: object, *, stmt: bool = True) -> object {
        # Statement-context increment/decrement (`i++;`) → AugAssign (`i += 1`).
        # Done before dispatch because c_UnaryOp can't know its context and an
        # AugAssign is a statement, not an expression.
        if stmt
        and isinstance(c_node, c_ast.UnaryOp)
        and c_node.op in ("p++", "++", "p--", "--") {
            inc = self._inc_dec_stmt(c_node);
            if inc is not None {
                return inc;
            }
        }
        meth = getattr(self, "c_" + type(c_node).__name__, None);
        if meth is None {
            if stmt {
                return self._surrogate_stmt(c_node);
            } else {
                return self._surrogate_expr(c_node);
            }
        }
        result = meth(c_node);
        # A handler may return a bare expression (e.g. c_FuncCall → ast.Call,
        # or an expr surrogate for `i++` in expr position). In statement
        # context PyastBuildPass needs a statement node, so wrap it in an Expr;
        # otherwise the expression is dropped and the function body length
        # mismatches ("Length mismatch in function body").
        if stmt and isinstance(result, ast3.expr) {
            line = getattr(result, "lineno", self._lineno);
            col = getattr(result, "col_offset", 0);
            return self._stamp_manual(ast3.Expr(value=result), line, col);
        }
        return result;
    }

    def _inc_dec_stmt(nd: object) -> object | None {
        # `i++` / `++i` / `i--` / `--i` as a statement → `i += 1` / `i -= 1`.
        target = self.conv_expr(nd.expr);
        if not (
            isinstance(target, ast3.Name)
            or isinstance(target, ast3.Attribute)
            or isinstance(target, ast3.Subscript)
        ) {
            return None;
        }
        self._to_store(target);
        op = ast3.Add() if nd.op in ("p++", "++") else ast3.Sub();
        (line, col) = self._loc(nd);
        one = self._stamp_manual(ast3.Constant(value=1), line, col, text="1");
        aug = ast3.AugAssign(target=target, op=op, value=one);
        return self._stamp_manual(aug, line, col, text=nd.op);
    }

    def conv_stmt(c_node: object) -> object {
        return self.conv(c_node, stmt=True);
    }

    def conv_expr(c_node: object) -> object {
        return self.conv(c_node, stmt=False);
    }

    # ------------------------------------------------------------------ #
    # P1a handlers                                                         #
    # ------------------------------------------------------------------ #
    def c_FileAST(nd: object) -> object {
        body: list[object] = [];
        for d in nd.ext {
            n = self.conv_stmt(d);
            if isinstance(n, list) {
                body += n;
            } else {
                body.append(n);
            }
        }
        if not body {
            body = [self._stamp_manual(ast3.Pass(), 1, 0)];
        }
        m = ast3.Module(body=body, type_ignores=[]);
        return m;
    }

    def c_Compound(nd: object) -> list[object] {
        stmts: list[object] = [];
        for item in (nd.block_items or []) {
            n = self.conv_stmt(item);
            if isinstance(n, list) {
                stmts += n;
            } else {
                stmts.append(n);
            }
        }
        return stmts;
    }

    def c_FuncDef(nd: object) -> object {
        # Reset list-bound tracking per function — a name proven list-bound in one
        # function must not license a Tier-A realloc-elide on a same-named param in
        # another (§7.5).
        self._list_bound = set();
        name = nd.decl.name;
        params: list[object] = [];
        vararg = None;
        pl = nd.decl.type.args;
        if pl is not None {
            for p in pl.params {
                if isinstance(p, c_ast.EllipsisParam) {
                    # Variadic `...` (§roadmap #9): map the *declaration* to a Jac
                    # `*args` so the signature stays callable, and flag the function
                    # Tier-B — the body's `va_list`/`va_arg` semantics are not modelled.
                    vararg = ast3.arg(arg="args", annotation=None);
                    self._stamp(vararg, p, text="...");
                    self._mark_tier_b(
                        nd.decl,
                        "variadic `...` lowered to Jac `*args`: va_list/va_arg "
                        "semantics are not modelled — verify"
                    );
                    continue;
                }
                if p.name is None {
                    continue;
                }
                ann = self._type_ann(p);
                arg_n = ast3.arg(arg=p.name, annotation=ann);
                self._stamp(arg_n, p, text=p.name);
                params.append(arg_n);
            }
        }
        args = ast3.arguments(
            posonlyargs=[],
            args=params,
            vararg=vararg,
            kwonlyargs=[],
            kw_defaults=[],
            kwarg=None,
            defaults=[],
        );
        # Mark function-local scope so c_Decl can classify function-local
        # `static` (whose cross-call persistence Jac cannot express) distinctly
        # from a file-scope static (a plain module var).
        self._func_depth += 1;
        raw_body = self.c_Compound(nd.body);
        self._func_depth -= 1;
        body: list[object] = raw_body or [self._stamp_manual(ast3.Pass(), 1, 0)];
        ret = self._ret_ann(nd.decl.type);
        fn = ast3.FunctionDef(
            name=name,
            args=args,
            body=body,
            decorator_list=[],
            returns=ret,
            type_params=[],
        );
        return self._stamp(fn, nd, text=name);
    }

    def c_Decl(nd: object) -> object {
        # Typedef handled by c_Typedef; struct decl handled there too.
        # Here we handle: local/global variable decl with optional init.
        if nd.name is None {
            # Bare struct definition (struct Node { ... };) → route to c_Struct.
            if isinstance(nd.type, c_ast.Struct) and nd.type.name is not None {
                return self.conv(nd.type);
            }
            # Bare enum definition (enum Color { ... };) → route to c_Enum
            # so the direct-IR path can emit uni.Enum or GlobalVars.
            if isinstance(nd.type, c_ast.Enum) {
                return self.conv(nd.type);
            }
            # Anonymous struct or function pointer type decl — surrogate.
            return self._surrogate_stmt(nd);
        }
        inner = nd.type;
        storage = nd.storage or [];
        quals = self._all_quals(nd);
        # --- storage class (#5) ---
        # `extern` names a definition in another TU; with no initializer it is a
        # pure declaration → no-op in Jac (like a function prototype). `extern`
        # WITH an initializer is itself the definition, so fall through and emit.
        # NB: read the initializer via 2-arg `getattr(nd, "init")`, never
        # `nd.init` — Jac maps the bare `.init` attribute to the object's
        # constructor (def init → __init__), so `nd.init` returns a bound method,
        # not pycparser's field. (A 3-arg getattr-with-None is also unsafe: it is
        # rewritten by jac-format into `nd?.init`, which hits the same trap.)
        if "extern" in storage and getattr(nd, "init") is None {
            return [];
        }
        # Function-local `static` keeps its value across calls; a Jac local
        # cannot. Emit a best-effort local (re-initialized each call) and flag
        # the lost persistence. File-scope `static` is just a module var — no
        # loss, so only the function-local variant is demoted.
        if "static" in storage and self._func_depth > 0 {
            self._mark_tier_b(
                nd, "function-local 'static' loses cross-call persistence"
            );
        }
        # --- qualifiers (#6) ---
        # `const` is a benign, idiomatic drop (value semantics are preserved;
        # only the immutability guarantee is advisory) → stays Tier-A. `volatile`
        # and `restrict` carry real semantics Jac cannot express, so emit
        # faithfully but flag the loss rather than dropping it silently.
        if "volatile" in quals {
            self._mark_tier_b(
                nd, "'volatile' qualifier dropped (Jac cannot suppress read caching)"
            );
        }
        if "restrict" in quals {
            self._mark_tier_b(
                nd, "'restrict' qualifier dropped (no-alias guarantee not expressible)"
            );
        }
        # Function forward declaration (prototype) — no-op in Jac.
        if isinstance(inner, c_ast.FuncDecl) {
            return [];
        }
        # Array decl.
        if isinstance(inner, c_ast.ArrayDecl) {
            return self._decl_array(nd);
        }
        # Struct decl without typedef — emit ClassDef (P1b).
        if isinstance(inner, c_ast.TypeDecl) and isinstance(inner.type, c_ast.Struct) {
            return self._decl_struct_var(nd);
        }
        # Enum variable decl (enum { ... } varname) — emit constants via DIRECT_IR, skip the var.
        if isinstance(inner, c_ast.TypeDecl)
        and isinstance(inner.type, c_ast.Enum)
        and inner.type.values is not None {
            return self._directir_placeholder(inner.type);
        }
        target = ast3.Name(id=nd.name, ctx=ast3.Store());
        self._stamp(target, nd, text=nd.name);
        nd_init = getattr(nd, "init");
        value = self.conv_expr(nd_init) if nd_init is not None else None;
        # LIST_OF_OBJECTS (§7.2): `T *arr = malloc(n*sizeof(T))` is a list, not a
        # bare T — annotate `list[T]` (not the pointer's `T`) and record the name
        # as list-bound so a later realloc on it elides cleanly (§7.5).
        arr_elem = self._malloc_array_match(nd_init) if nd_init is not None else None;
        if arr_elem is not None {
            ann = self._list_ann_of(arr_elem);
            self._list_bound.add(nd.name);
        } else {
            ann = self._type_ann(nd);
            # A fresh non-list (re)declaration of this name clears any stale
            # list-bound state from an outer-scope binding of the same name.
            self._list_bound.discard(nd.name);
        }
        # Static storage duration (#2): an uninitialized file-scope var or a
        # function-local `static` is zero-initialized in C. Synthesize that zero
        # so the guarantee survives; automatic locals (no static, in a function)
        # stay annotation-only, matching C's indeterminate value.
        if value is None and (self._func_depth == 0 or "static" in storage) {
            value = self._zero_default(inner);
        }
        aa = ast3.AnnAssign(target=target, annotation=ann, value=value, simple=1);
        return self._stamp(aa, nd, text=nd.name);
    }

    def _all_quals(nd: object) -> set {
        # Collect type qualifiers from a Decl and the whole nested type chain.
        # `const`/`volatile` may sit on the Decl or the pointed-to TypeDecl;
        # `restrict` lives on the PtrDecl, not the Decl — so reading nd.quals
        # alone would miss the common `int * restrict p`. The chain is short
        # (pointer/array/typedecl nesting), so a bounded walk suffices.
        quals: set = set(nd?.quals or []);
        t = nd?.type;
        for _ in range(8) {
            if t is None {
                break;
            }
            quals |= set(t?.quals or []);
            t = t?.type;
        }
        return quals;
    }

    def _decl_struct_var(nd: object) -> object {
        # Variable whose type is a struct — just AnnAssign with struct name.
        inner = nd.type;
        struct_name = inner.type.name or "object";
        target = ast3.Name(id=nd.name, ctx=ast3.Store());
        self._stamp(target, nd, text=nd.name);
        ann_n = ast3.Name(id=struct_name, ctx=ast3.Load());
        self._stamp(ann_n, nd, text=struct_name);
        nd_init = getattr(nd, "init");
        value = self.conv_expr(nd_init) if nd_init is not None else None;
        aa = ast3.AnnAssign(target=target, annotation=ann_n, value=value, simple=1);
        return self._stamp(aa, nd, text=nd.name);
    }

    def _zero_default(inner: object) -> object {
        # Zero-initializer for an uninitialized *static-storage-duration* decl
        # (file-scope, or function-local `static`). C guarantees such objects
        # start at zero — NULL for pointers, 0/0.0/false for scalars — so a bare
        # `n: int` annotation would silently drop that guarantee (vs an automatic
        # local, whose value is genuinely indeterminate and stays annotation-only).
        (line, col) = (self._lineno, 0);
        if isinstance(inner, c_ast.PtrDecl) {
            return self._stamp_manual(
                ast3.Constant(value=None), line, col, text="None"
            );
        }
        names: list = [];
        if isinstance(inner, c_ast.TypeDecl) {
            names = inner.type?.names or [];
        }
        jac = self._jac_prim(names);
        if jac == "float" {
            (d, t) = (ast3.Constant(value=0.0), "0.0");
        } elif jac == "bool" {
            (d, t) = (ast3.Constant(value=False), "False");
        } elif jac == "str" {
            # A zero `char` is the NUL byte; modelled as "" (empty string) rather
            # than embedding a literal NUL into the generated Jac source.
            (d, t) = (ast3.Constant(value=""), '""');
        } else {
            (d, t) = (ast3.Constant(value=0), "0");
        }
        return self._stamp_manual(d, line, col, text=t);
    }

    def c_Assignment(nd: object) -> object {
        lhs = self.conv_expr(nd.lvalue);
        # Convert the rvalue BEFORE updating list-bound state so a `realloc` inside
        # it (via _realloc_elide) sees the pointer's pre-assignment binding.
        rhs = self.conv_expr(nd.rvalue);
        # Track list-boundness across reassignment (§7.5) by last-write-wins.
        # `arr = malloc(n*sizeof(T))` marks `arr` list-bound; `arr = realloc(arr,…)`
        # on an already-bound pointer preserves it (same logical buffer); ANY other
        # plain `arr = …` invalidates it. Without the invalidation the set is
        # monotonic, so `arr = malloc(); arr = raw; realloc(arr, n)` would falsely
        # stamp the trailing realloc Tier-A. (Branch-conditional rebinds still need
        # real dataflow tracking — see §9.5; this keeps straight-line flow sound.)
        if nd.op == "=" and isinstance(nd.lvalue, c_ast.ID) {
            if self._malloc_array_match(nd.rvalue) is not None
            or self._realloc_of_list_bound(nd.rvalue) {
                self._list_bound.add(nd.lvalue.name);
            } else {
                self._list_bound.discard(nd.lvalue.name);
            }
        }
        if nd.op == "=" {
            # Convert lhs context to Store.
            lhs_store = self._to_store(lhs);
            assign = ast3.Assign(targets=[lhs_store], value=rhs, type_comment=None);
            return self._stamp(assign, nd, text="=");
        }
        aug_entry = C_AUGOPS.get(nd.op);
        if aug_entry is not None {
            (ast_cls, _, _) = aug_entry;
            lhs_store = self._to_store(lhs);
            aug = ast3.AugAssign(
                target=lhs_store, op=getattr(ast3, ast_cls)(), value=rhs
            );
            return self._stamp(aug, nd, text=nd.op);
        }
        return self._surrogate_stmt(nd);
    }

    def _to_store(py_node: object) -> object {
        if isinstance(py_node, ast3.Name) {
            py_node.ctx = ast3.Store();
        } elif isinstance(py_node, ast3.Attribute) {
            py_node.ctx = ast3.Store();
        } elif isinstance(py_node, ast3.Subscript) {
            py_node.ctx = ast3.Store();
        }
        return py_node;
    }

    def c_BinaryOp(nd: object) -> object {
        entry = C_BINOPS.get(nd.op);
        if entry is None {
            return self._surrogate_expr(nd);
        }
        (kind, ast_cls, _, _) = entry;
        left = self.conv_expr(nd.left);
        right = self.conv_expr(nd.right);
        op_obj = getattr(ast3, ast_cls)();
        if kind == "arith" {
            expr_node = ast3.BinOp(left=left, op=op_obj, right=right);
        } elif kind == "compare" {
            expr_node = ast3.Compare(left=left, ops=[op_obj], comparators=[right]);
        } else {
            # bool — && / ||
            expr_node = ast3.BoolOp(op=op_obj, values=[left, right]);
        }
        return self._stamp(expr_node, nd, text=nd.op);
    }

    def c_If(nd: object) -> object {
        test = self.conv_expr(nd.cond);
        # Snapshot AFTER the condition — a cond like `if ((arr = malloc(...)))`
        # mutates list-bound state, and that effect is on every path. Each branch
        # then walks from its own copy so neither leaks into the other (§9.5).
        base: set = set(self._list_bound);
        self._list_bound = set(base);
        true_stmts = self._stmts_from(nd.iftrue);
        s_true: set = self._list_bound;
        false_stmts: list[object] = [];
        if nd.iffalse is not None {
            self._list_bound = set(base);
            false_stmts = self._stmts_from(nd.iffalse);
            s_false: set = self._list_bound;
        } else {
            # No else → the fall-through path keeps `base` unchanged.
            s_false = base;
        }
        # Join: list-bound after the if only if list-bound on BOTH paths.
        self._list_bound = self._lb_merge([s_true, s_false]);
        ifs = ast3.If(test=test, body=true_stmts, orelse=false_stmts);
        return self._stamp(ifs, nd, text="if");
    }

    def c_While(nd: object) -> object {
        test = self.conv_expr(nd.cond);
        base: set = set(self._list_bound);
        # Drop names the body may rebind to a non-list before walking it, so a
        # realloc in the body is judged against what holds on every iteration's
        # back-edge, not just the first (§9.5). Re-gens in the body re-add them.
        killed: set = set();
        self._collect_lb_kills(nd.stmt, killed);
        self._list_bound = base - killed;
        body = self._stmts_from(nd.stmt);
        s_end: set = self._list_bound;
        # The loop may run zero times: keep only names list-bound on both the
        # skip path (base) and the body-exit path.
        self._list_bound = self._lb_merge([base, s_end]);
        w = ast3.While(test=test, body=body, orelse=[]);
        return self._stamp(w, nd, text="while");
    }

    def c_DoWhile(nd: object) -> object {
        # `do { body } while (cond);` has no Python/Jac analog. Desugar to the
        # faithful `while True { body; if not cond { break } }` — body runs once
        # before the test, exactly like do-while. The one semantic gap is `continue`:
        # in C it jumps to the post-body condition test, but here it re-enters the
        # loop top and skips the `if not cond` guard, so a loop-level continue would
        # spin without ever re-checking cond. Flag that case Tier-B; the common
        # continue-free do-while stays faithful (Tier-A).
        (line, col) = self._loc(nd);
        # Body runs at least once, but still loops: drop names it may rebind to a
        # non-list before walking, so a realloc in the body holds on every
        # back-edge, not just the first iteration (§9.5).
        killed: set = set();
        self._collect_lb_kills(nd.stmt, killed);
        self._list_bound -= killed;
        body = self._stmts_from(nd.stmt);
        cond = self.conv_expr(nd.cond);
        not_cond = self._stamp_manual(
            ast3.UnaryOp(op=ast3.Not(), operand=cond), line, col, text="not"
        );
        brk = self._stamp_manual(ast3.Break(), line, col, text="break");
        guard = self._stamp_manual(
            ast3.If(test=not_cond, body=[brk], orelse=[]), line, col, text="if"
        );
        full_body: list[object] = [*body, guard];
        true_c = self._stamp_manual(ast3.Constant(value=True), line, col, text="True");
        w = ast3.While(test=true_c, body=full_body, orelse=[]);
        if self._has_loop_continue(nd.stmt) {
            self._mark_tier_b(
                nd,
                "do-while desugared to `while True`/break; a loop-level `continue` "
                "skips the post-body condition test (C runs it) — verify",
            );
        }
        return self._stamp(w, nd, text="do");
    }

    def _has_loop_continue(nd: object) -> bool {
        # True if a `continue` belonging to THIS loop appears in nd. Nested loops
        # and switch bodies own their own continue/break, so descent stops at them.
        if nd is None {
            return False;
        }
        if (
            isinstance(nd, c_ast.For)
            or isinstance(nd, c_ast.While)
            or isinstance(nd, c_ast.DoWhile)
            or isinstance(nd, c_ast.Switch)
        ) {
            return False;
        }
        if isinstance(nd, c_ast.Continue) {
            return True;
        }
        for (_, child) in nd.children() {
            if self._has_loop_continue(child) {
                return True;
            }
        }
        return False;
    }

    def c_Switch(nd: object) -> object {
        # C `switch` → nested if/elif/else. pycparser nests each Case/Default as a
        # block_item carrying its own statement list; empty-statement cases
        # (`case 1: case 2: ...`) fold their labels onto the next case that has a
        # body, modelling `1 || 2`. This is always Tier-B: case fall-through between
        # non-empty cases is NOT modelled (if/elif has no fall-through), `break` is
        # dropped as the switch terminator (so a `break` meant for an enclosing loop
        # would be mis-handled), and the selector is re-evaluated per branch rather
        # than once. The clean, common shape (every case ends in `break`) is exact.
        (line, col) = self._loc(nd);
        groups: list[tuple] = [];  # (list[c_value_node], list[c_stmt_node])
        pending: list[object] = [];
        default_stmts: list | None = None;
        items: list = [];
        if isinstance(nd.stmt, c_ast.Compound) and nd.stmt.block_items {
            items = nd.stmt.block_items;
        }
        for it in items {
            if isinstance(it, c_ast.Case) {
                pending.append(it.expr);
                if it.stmts {
                    groups.append((pending, it.stmts));
                    pending = [];
                }
            } elif isinstance(it, c_ast.Default) {
                default_stmts = it.stmts or [];
            }
        }
        self._mark_tier_b(
            nd,
            "switch lowered to an if/elif chain: case fall-through is not modelled, "
            "`break` is dropped as the switch terminator, and the selector is "
            "re-evaluated per branch — verify (faithful when every case ends in break)",
        );
        # Each case body is a distinct path; walk it from a copy of the pre-switch
        # state and merge at the end so list-bound status leaving the switch is
        # what holds on every path, not whatever the last-walked case left (§9.5).
        base: set = set(self._list_bound);
        branch_states: list = [];
        if default_stmts is not None {
            self._list_bound = set(base);
            orelse: list[object] = self._switch_branch_body(default_stmts);
            branch_states.append(self._list_bound);
        } else {
            orelse = [];
            # No default → the no-match path falls through with `base` unchanged.
            branch_states.append(base);
        }
        for grp in reversed(groups) {
            (vals, stmts) = grp;
            self._list_bound = set(base);
            body = self._switch_branch_body(stmts);
            branch_states.append(self._list_bound);
            test = self._switch_test(nd.cond, vals, line, col);
            ifs = self._stamp_manual(
                ast3.If(test=test, body=body, orelse=orelse), line, col, text="case"
            );
            orelse = [ifs];
        }
        self._list_bound = self._lb_merge(branch_states);
        if orelse {
            if len(orelse) == 1 and isinstance(orelse[0], ast3.If) {
                return orelse[0];
            }
            return orelse;
        }
        return self._stamp_manual(ast3.Pass(), line, col);
    }

    def _switch_test(cond_cnode: object, vals: list, line: int, col: int) -> object {
        # `selector == v1 [or selector == v2 ...]`. The selector is re-converted
        # per comparison so no ast node object is shared across the tree.
        cmps: list[object] = [];
        for v in vals {
            sel = self.conv_expr(cond_cnode);
            val = self.conv_expr(v);
            cmp_n = self._stamp_manual(
                ast3.Compare(left=sel, ops=[ast3.Eq()], comparators=[val]),
                line,
                col,
                text="=="
            );
            cmps.append(cmp_n);
        }
        if len(cmps) == 1 {
            return cmps[0];
        }
        return self._stamp_manual(
            ast3.BoolOp(op=ast3.Or(), values=cmps), line, col, text="or"
        );
    }

    def _switch_branch_body(stmts: list | None) -> list[object] {
        # Convert one case's direct statements, dropping the switch-terminating
        # `break` (direct break only — a break inside a nested loop lives in that
        # loop's converted body, not here). Empty bodies get a Pass.
        out: list[object] = [];
        for s in (stmts or []) {
            if isinstance(s, c_ast.Break) {
                continue;
            }
            n = self.conv_stmt(s);
            if isinstance(n, list) {
                out += n;
            } else {
                out.append(n);
            }
        }
        if not out {
            out = [self._stamp_manual(ast3.Pass(), 1, 0)];
        }
        return out;
    }

    def c_TernaryOp(nd: object) -> object {
        # `cond ? a : b` → Python conditional expression `a if cond else b`
        # (PyastBuildPass.proc_if_exp → uni.IfElseExpr). Faithful (Tier-A).
        test = self.conv_expr(nd.cond);
        body = self.conv_expr(nd.iftrue);
        orelse = self.conv_expr(nd.iffalse);
        ie = ast3.IfExp(test=test, body=body, orelse=orelse);
        return self._stamp(ie, nd, text="?:");
    }

    def _stmts_from(nd: object) -> list[object] {
        if isinstance(nd, c_ast.Compound) {
            return self.c_Compound(nd);
        }
        n = self.conv_stmt(nd);
        if isinstance(n, list) {
            return n or [self._stamp_manual(ast3.Pass(), 1, 0)];
        }
        return [n];
    }

    def c_Return(nd: object) -> object {
        val = self.conv_expr(nd.expr) if nd.expr is not None else None;
        r = ast3.Return(value=val);
        return self._stamp(r, nd, text="return");
    }

    def c_Break(nd: object) -> object {
        b = ast3.Break();
        return self._stamp(b, nd, text="break");
    }

    def c_Continue(nd: object) -> object {
        c = ast3.Continue();
        return self._stamp(c, nd, text="continue");
    }

    def c_FuncCall(nd: object) -> object {
        # FREE_ELIDE: free(p) → Pass (GC handles it; §7.3)
        if isinstance(nd.name, c_ast.ID) and nd.name.name == "free" {
            self._mark_tier_a(nd, Idiom.FREE_ELIDE, "free() elided — Jac GC reclaims");
            return self._stamp_manual(ast3.Pass(), self._lineno, 0);
        }
        # REALLOC_ELIDE: realloc(p, n) → p (§7.5). A Jac list grows under GC, so
        # the resize is a no-op that yields the same binding.
        if isinstance(nd.name, c_ast.ID) and nd.name.name == "realloc" {
            re = self._realloc_elide(nd);
            if re is not None {
                return re;
            }
        }
        # LIST_OF_OBJECTS: malloc(n*sizeof(T)) → [T() for _ in range(n)] (§7.2)
        arr = self._malloc_array(nd);
        if arr is not None {
            self._mark_tier_a(
                nd, Idiom.LIST_OF_OBJECTS, "malloc(n*sizeof(T)) → list[T]"
            );
            return arr;
        }
        # OBJECT_CREATE: malloc(sizeof(T)) → T() constructor (§7.1)
        struct_name = self._malloc_struct_type(nd);
        if struct_name is not None {
            self._mark_tier_a(
                nd, Idiom.OBJECT_CREATE, "malloc(sizeof(T)) → T() constructor"
            );
            func_n = ast3.Name(id=struct_name, ctx=ast3.Load());
            self._stamp_manual(func_n, self._lineno, 0, text=struct_name);
            call = ast3.Call(func=func_n, args=[], keywords=[]);
            return self._stamp_manual(call, self._lineno, 0);
        }
        func = self.conv_expr(nd.name);
        args: list[object] = [];
        if nd.args {
            for e in nd.args.exprs {
                args.append(self.conv_expr(e));
            }
        }
        call = ast3.Call(func=func, args=args, keywords=[]);
        call_expr = self._stamp(call, nd, text="call");
        return call_expr;
    }

    def _malloc_struct_type(nd: object) -> str | None {
        # Returns the struct/typedef name if nd is malloc(sizeof(T)) for a named type T, else None.
        if not isinstance(nd.name, c_ast.ID) or nd.name.name != "malloc" {
            return None;
        }
        if nd.args is None or len(nd.args.exprs) != 1 {
            return None;
        }
        arg = nd.args.exprs[0];
        if not isinstance(arg, c_ast.UnaryOp) or arg.op != "sizeof" {
            return None;
        }
        inner = arg.expr;
        if isinstance(inner, c_ast.Typename)
        and isinstance(inner.type, c_ast.TypeDecl) {
            return self._user_type_name(inner.type.type);
        }
        if isinstance(inner, c_ast.ID) {
            return inner.name;
        }
        return None;
    }

    def _realloc_of_list_bound(nd: object) -> bool {
        # True if nd is `realloc(p, …)` where p is an ID currently proven list-bound.
        # Such a reassignment yields the same logical buffer, so list-boundness is
        # preserved across `arr = realloc(arr, …)` rather than dropped (§7.5).
        if not isinstance(nd, c_ast.FuncCall) {
            return False;
        }
        if not isinstance(nd.name, c_ast.ID) or nd.name.name != "realloc" {
            return False;
        }
        if nd.args is None or len(nd.args.exprs) < 1 {
            return False;
        }
        ptr = nd.args.exprs[0];
        return isinstance(ptr, c_ast.ID) and ptr.name in self._list_bound;
    }

    def _realloc_elide(nd: object) -> object | None {
        # realloc(p, n) → p. Tier-A when p is provably list-bound in this function
        # (the list grows under GC, so the resize is moot, §7.5/§9.5); otherwise
        # still elided to p but flagged Tier-B — a raw-buffer resize would be lost.
        if nd.args is None or len(nd.args.exprs) < 1 {
            return None;
        }
        ptr = nd.args.exprs[0];
        py_ptr = self.conv_expr(ptr);
        if isinstance(ptr, c_ast.ID) and ptr.name in self._list_bound {
            self._mark_tier_a(
                nd,
                Idiom.REALLOC_ELIDE,
                "realloc on list-bound pointer elided — Jac list grows under GC",
            );
        } else {
            self._mark_tier_b_idiom(
                nd,
                Idiom.REALLOC_ELIDE,
                "realloc elided to its pointer arg, but the pointer is not proven "
                "list-bound; if it backed a raw buffer the resize is lost — verify",
            );
        }
        return py_ptr;
    }

    # ------------------------------------------------------------------ #
    # List-bound dataflow across control flow (§9.5)                      #
    # ------------------------------------------------------------------ #
    # `_list_bound` is a MUST property: a name is list-bound at a point only when
    # it is provably list-bound on EVERY path reaching it. A single mutable set
    # walked in tree order conflates branches, making a later realloc's Tier-A/B
    # verdict depend on traversal order. The branch handlers below snapshot the
    # set, walk each path from a copy, and merge by intersection at the join so
    # the verdict reflects what is actually provable after the construct.
    def _lb_merge(states: list) -> set {
        # Intersection across path-end states — list-bound only if list-bound on
        # all of them. Empty input (no reachable path) → empty set.
        if not states {
            return set();
        }
        out: set = set(states[0]);
        for s in states[1:] {
            out &= s;
        }
        return out;
    }

    def _lb_assignment_kills(name: str, rhs: object) -> bool {
        # Mirrors c_Assignment's gen/preserve rules: `name = rhs` keeps list-bound
        # status only when rhs is a malloc-array (gen) or a self-realloc
        # `realloc(name, …)` (same logical buffer). Any other rhs rebinds the name
        # to a non-list → a kill. A cross-pointer `name = realloc(other, …)` is
        # treated as a kill here (conservative: at worst it demotes a later realloc
        # to Tier-B, which is always sound).
        if self._malloc_array_match(rhs) is not None {
            return False;
        }
        if isinstance(rhs, c_ast.FuncCall)
        and isinstance(rhs.name, c_ast.ID)
        and rhs.name.name == "realloc"
        and rhs.args is not None
        and len(rhs.args.exprs) >= 1 {
            ptr = rhs.args.exprs[0];
            if isinstance(ptr, c_ast.ID) and ptr.name == name {
                return False;
            }
        }
        return True;
    }

    def _collect_lb_kills(nd: object, killed: set) {
        # Names a loop body may rebind to a non-list on some iteration. Removing
        # them from `_list_bound` before walking the body makes a realloc inside
        # the loop sound across the 0-or-more iterations (a name killed on any
        # iteration is not provably list-bound on the back-edge); a re-gen earlier
        # in the same iteration re-adds it during the walk.
        if nd is None {
            return;
        }
        if isinstance(nd, c_ast.Assignment)
        and nd.op == "="
        and isinstance(nd.lvalue, c_ast.ID) {
            if self._lb_assignment_kills(nd.lvalue.name, nd.rvalue) {
                killed.add(nd.lvalue.name);
            }
        } elif isinstance(nd, c_ast.Decl) and nd.name is not None {
            # A re-decl rebinds the name; only a malloc-array init keeps it bound.
            decl_init = getattr(nd, "init");
            if decl_init is None or self._malloc_array_match(decl_init) is None {
                killed.add(nd.name);
            }
        }
        for (_, child) in nd.children() {
            self._collect_lb_kills(child, killed);
        }
    }

    def _flatten_mult(nd: object, acc: list) {
        # Collect the multiplicative factors of a `*`-chain into acc (so
        # `n * sizeof(T)` and `2 * n * sizeof(T)` both yield a flat factor list).
        if isinstance(nd, c_ast.BinaryOp) and nd.op == "*" {
            self._flatten_mult(nd.left, acc);
            self._flatten_mult(nd.right, acc);
        } else {
            acc.append(nd);
        }
    }

    def _sizeof_type(f: object) -> str | None {
        # Raw C type name of a `sizeof(T)` / `sizeof(T*)` factor, else None.
        if not isinstance(f, c_ast.UnaryOp) or f.op != "sizeof" {
            return None;
        }
        inner = f.expr;
        if isinstance(inner, c_ast.ID) {
            return inner.name;
        }
        if isinstance(inner, c_ast.Typename) {
            tt = inner.type;
            if isinstance(tt, c_ast.PtrDecl) {
                tt = tt.type;
            }
            if isinstance(tt, c_ast.TypeDecl) {
                it = tt.type;
                if isinstance(it, c_ast.Struct) and it.name {
                    return it.name;
                }
                names = it?.names;
                if names {
                    return names[-1];
                }
            }
        }
        return None;
    }

    def _is_listable_elem(tname: str) -> bool {
        # A malloc element type we can default-initialize into a Jac list: any
        # user type, or a numeric/bool primitive. char (string buffer) and void
        # are not list-of-objects — they stay Tier-B.
        if tname in _C_PRIM_MAP {
            return _C_PRIM_MAP.get(tname, "int") in ("int", "float", "bool");
        }
        return True;
    }

    def _malloc_array_match(nd: object) -> str | None {
        # Pure structural test (no node-building, no tagging): if nd is
        # `malloc(<count> * sizeof(T))` with at least one non-sizeof factor and a
        # list-able element T, return T's C name; else None.
        if not isinstance(nd, c_ast.FuncCall) {
            return None;
        }
        if not isinstance(nd.name, c_ast.ID) or nd.name.name != "malloc" {
            return None;
        }
        if nd.args is None or len(nd.args.exprs) != 1 {
            return None;
        }
        factors: list = [];
        self._flatten_mult(nd.args.exprs[0], factors);
        sizeof_name: str | None = None;
        others = 0;
        for f in factors {
            t = self._sizeof_type(f);
            if t is not None and sizeof_name is None {
                sizeof_name = t;
            } else {
                others += 1;
            }
        }
        if sizeof_name is None or others == 0 {
            return None;
        }
        if not self._is_listable_elem(sizeof_name) {
            return None;
        }
        return sizeof_name;
    }

    def _elem_default(tname: str) -> object {
        # Default-element Jac node for a list-of-objects of C type tname.
        if tname in _C_PRIM_MAP {
            jac = _C_PRIM_MAP.get(tname, "int");
            if jac == "float" {
                d = ast3.Constant(value=0.0);
            } elif jac == "bool" {
                d = ast3.Constant(value=False);
            } else {
                d = ast3.Constant(value=0);
            }
            return self._stamp_manual(d, self._lineno, 0);
        }
        fn = ast3.Name(id=tname, ctx=ast3.Load());
        self._stamp_manual(fn, self._lineno, 0, text=tname);
        call = ast3.Call(func=fn, args=[], keywords=[]);
        return self._stamp_manual(call, self._lineno, 0);
    }

    def _product_expr(factors: list) -> object {
        # Fold converted factors into a left-leaning `*` BinOp (the element count).
        exprs = [self.conv_expr(f) for f in factors];
        acc = exprs[0];
        i = 1;
        while i < len(exprs) {
            acc = ast3.BinOp(left=acc, op=ast3.Mult(), right=exprs[i]);
            self._stamp_manual(acc, self._lineno, 0, text="*");
            i += 1;
        }
        return acc;
    }

    def _malloc_array(nd: object) -> object | None {
        # `malloc(n*sizeof(T))` → `[T() for _ in range(n)]` (§7.2). Distinct
        # elements (comprehension, not `[x]*n`) so mutable objects don't alias.
        tname = self._malloc_array_match(nd);
        if tname is None {
            return None;
        }
        default = self._elem_default(tname);
        factors: list = [];
        self._flatten_mult(nd.args.exprs[0], factors);
        others = [
            f
            for f in factors
            if self._sizeof_type(f) is None
        ];
        count = self._product_expr(others);
        range_fn = self._stamp_manual(
            ast3.Name(id="range", ctx=ast3.Load()), self._lineno, 0, text="range"
        );
        range_call = self._stamp_manual(
            ast3.Call(func=range_fn, args=[count], keywords=[]), self._lineno, 0
        );
        tgt = self._stamp_manual(
            ast3.Name(id="_", ctx=ast3.Store()), self._lineno, 0, text="_"
        );
        comp = ast3.comprehension(target=tgt, iter=range_call, ifs=[], is_async=0);
        lc = ast3.ListComp(elt=default, generators=[comp]);
        return self._stamp_manual(lc, self._lineno, 0, text="[]");
    }

    def _list_ann_of(tname: str) -> object {
        # Build a `list[T]` annotation node for a C element type tname.
        jac = _C_PRIM_MAP.get(tname, tname);
        elem = self._stamp_manual(
            ast3.Name(id=jac, ctx=ast3.Load()), self._lineno, 0, text=jac
        );
        lst = self._stamp_manual(
            ast3.Name(id="list", ctx=ast3.Load()), self._lineno, 0, text="list"
        );
        sub = ast3.Subscript(value=lst, slice=elem, ctx=ast3.Load());
        return self._stamp_manual(sub, self._lineno, 0, text="list");
    }

    def c_ID(nd: object) -> object {
        n = ast3.Name(id=nd.name, ctx=ast3.Load());
        return self._stamp(n, nd, text=nd.name);
    }

    def c_Constant(nd: object) -> object {
        # Default the rendered text to the raw C literal; numeric branches
        # override it with the parsed value so a stripped suffix (`10L`→`10`)
        # doesn't leak verbatim into the emitted Jac.
        txt: str = str(nd.value);
        # pycparser reports the widened C type, not a bare keyword: `10L` is
        # "long int", `5U` is "unsigned int", `1.0L` is "long double". Match on
        # the family suffix so every integer / floating constant is normalized.
        if nd.type.endswith("int") {
            iv = parse_c_int(nd.value);
            val: object = iv if iv is not None else repr(nd.value);
            if iv is not None {
                txt = str(iv);
            }
        } elif nd.type.endswith("double") or nd.type.endswith("float") {
            fv = parse_c_float(nd.value);
            val = fv if fv is not None else repr(nd.value);
            if fv is not None {
                txt = str(fv);
            }
        } elif nd.type == "char" {
            # char literal: 'a' → single char string.
            raw = nd.value;
            if raw.startswith("'") and raw.endswith("'") {
                val = raw[1:-1];
            } else {
                val = raw;
            }
        } elif nd.type == "string" {
            raw = nd.value;
            if raw.startswith('"') and raw.endswith('"') {
                try {
                    val = bytes(raw[1:-1], "utf-8").decode("unicode_escape");
                } except Exception {
                    val = raw[1:-1];
                }
            } else {
                val = raw;
            }
        } else {
            val = repr(nd.value);
        }
        c = ast3.Constant(value=val);
        return self._stamp(c, nd, text=txt);
    }

    # ------------------------------------------------------------------ #
    # P1a — unary ops                                                      #
    # ------------------------------------------------------------------ #
    def _is_simple_ref(c_node: object) -> bool {
        # A reference-shaped operand: names a storage location without pointer
        # arithmetic or reinterpretation. ID / s.f / s->f / a[i] qualify; a
        # BinaryOp (`p+1`), Cast, or nested `*`/`&` does not (those are Tier-B).
        return (
            isinstance(c_node, c_ast.ID)
            or isinstance(c_node, c_ast.StructRef)
            or isinstance(c_node, c_ast.ArrayRef)
        );
    }

    def c_UnaryOp(nd: object) -> object {
        unary_map: dict[str, object] = {
            "-": ast3.USub(),
            "+": ast3.UAdd(),
            "~": ast3.Invert(),
            "!": ast3.Not(),

        };
        if nd.op in unary_map {
            operand = self.conv_expr(nd.expr);
            u = ast3.UnaryOp(op=unary_map[nd.op], operand=operand);
            return self._stamp(u, nd, text=nd.op);
        }
        # p++, p--, *p, &p, sizeof — contextual; treat as surrogate or elide.
        if nd.op in ("p++", "++", "p--", "--") {
            # Increment/decrement: emit as augassign in statement context,
            # but here we're in expr context — emit as surrogate.
            return self._surrogate_expr(nd);
        }
        if nd.op == "*" {
            # PTR_REF (§7.4): dereferencing a plain pointer-as-reference is
            # identity in Jac — `*p`/`(*p).f` → `p`/`p.f`. Only when the operand
            # is a simple lvalue (no pointer arithmetic); `*(p+1)` stays Tier-B.
            if self._is_simple_ref(nd.expr) {
                self._mark_tier_a(
                    nd, Idiom.PTR_REF, "pointer dereference → Jac reference"
                );
                return self.conv_expr(nd.expr);
            }
            return self._surrogate_expr(nd);
        }
        if nd.op == "&" {
            # PTR_REF (§7.4): address-of a simple lvalue → pass the object by
            # reference, i.e. identity. `&(p+1)`/computed addresses stay Tier-B.
            if self._is_simple_ref(nd.expr) {
                self._mark_tier_a(nd, Idiom.PTR_REF, "address-of → Jac reference");
                return self.conv_expr(nd.expr);
            }
            return self._surrogate_expr(nd);
        }
        if nd.op == "sizeof" {
            return self._surrogate_expr(nd);
        }
        return self._surrogate_expr(nd);
    }

    # ------------------------------------------------------------------ #
    # P1b — structs → ClassDef                                            #
    # ------------------------------------------------------------------ #
    def c_Struct(nd: object) -> object {
        # Bare struct definition (not through Typedef) encountered as top-level decl.
        name = nd.name or "_AnonStruct";
        fields: list[object] = [];
        if nd.decls {
            for mem in nd.decls {
                ann_assign = self._struct_field(mem);
                if ann_assign is not None {
                    fields.append(ann_assign);
                }
            }
        }
        body: list[object] = fields or [self._stamp_manual(ast3.Pass(), 1, 0)];
        cls = ast3.ClassDef(
            name=name, bases=[], keywords=[], body=body, decorator_list=[]
        );
        return self._stamp(cls, nd, text=name);
    }

    def _struct_field(mem: object) -> object | None {
        if mem.name is None {
            return None;
        }
        target = ast3.Name(id=mem.name, ctx=ast3.Store());
        self._stamp(target, mem, text=mem.name);
        ann = self._type_ann(mem);
        aa = ast3.AnnAssign(target=target, annotation=ann, value=None, simple=1);
        return self._stamp(aa, mem, text=mem.name);
    }

    def c_Typedef(nd: object) -> object {
        # typedef struct { ... } TypeName  →  ClassDef named TypeName.
        inner = nd.type;
        if isinstance(inner, c_ast.TypeDecl) and isinstance(inner.type, c_ast.Struct) {
            s = inner.type;
            name = nd.name;
            fields: list[object] = [];
            if s.decls {
                for mem in s.decls {
                    aa = self._struct_field(mem);
                    if aa is not None {
                        fields.append(aa);
                    }
                }
            }
            body: list[object] = fields or [self._stamp_manual(ast3.Pass(), 1, 0)];
            cls = ast3.ClassDef(
                name=name, bases=[], keywords=[], body=body, decorator_list=[]
            );
            return self._stamp(cls, nd, text=name);
        }
        # Scalar typedef → alias assignment.
        (line, col) = self._loc(nd);
        target = self._stamp_manual(
            ast3.Name(id=nd.name, ctx=ast3.Store()), line, col, text=nd.name
        );
        val_name = self._typename(nd.type);
        value = self._stamp_manual(
            ast3.Name(id=val_name, ctx=ast3.Load()), line, col, text=val_name
        );
        assign = ast3.Assign(targets=[target], value=value, type_comment=None);
        return self._stamp_manual(assign, line, col, text=nd.name);
    }

    def c_StructRef(nd: object) -> object {
        # s.field or s->field.
        obj_expr = self.conv_expr(nd.name);
        field_name = nd.field.name;
        attr = ast3.Attribute(value=obj_expr, attr=field_name, ctx=ast3.Load());
        return self._stamp(attr, nd, text=field_name);
    }

    # ------------------------------------------------------------------ #
    # P1c — arrays                                                         #
    # ------------------------------------------------------------------ #
    def c_ArrayDecl(nd: object) -> object {
        # Top-level handler only called if the parent Decl routes here directly.
        # Most ArrayDecl nodes are handled via c_Decl → _decl_array.
        return self._surrogate_stmt(nd);
    }

    def _decl_array(nd: object) -> object {
        # nd is c_ast.Decl whose .type is ArrayDecl.
        arr_decl = nd.type;
        elem_type = self._type_ann_from_type(arr_decl.type);
        list_ann = ast3.Subscript(
            value=ast3.Name(id="list", ctx=ast3.Load()),
            slice=elem_type,
            ctx=ast3.Load(),
        );
        self._stamp_manual(list_ann, self._lineno, 0, text="list");
        target = ast3.Name(id=nd.name, ctx=ast3.Store());
        self._stamp(target, nd, text=nd.name);
        value: object | None = None;
        nd_init = getattr(nd, "init");
        if nd_init is not None {
            value = self.conv_expr(nd_init);
        } elif arr_decl.dim is not None {
            dim_expr = self.conv_expr(arr_decl.dim);
            elem_default_name = self._typename(arr_decl.type);
            elem_call = ast3.Call(
                func=ast3.Name(id=elem_default_name, ctx=ast3.Load()),
                args=[],
                keywords=[],
            );
            self._stamp_manual(elem_call, self._lineno, 0);
            mult = ast3.BinOp(
                left=ast3.List(elts=[elem_call], ctx=ast3.Load()),
                op=ast3.Mult(),
                right=dim_expr
            );
            self._stamp_manual(mult, self._lineno, 0);
            value = mult;
        }
        aa = ast3.AnnAssign(target=target, annotation=list_ann, value=value, simple=1);
        return self._stamp(aa, nd, text=nd.name);
    }

    def c_InitList(nd: object) -> object {
        elts: list[object] = [];
        for expr in nd.exprs {
            elts.append(self.conv_expr(expr));
        }
        lst = ast3.List(elts=elts, ctx=ast3.Load());
        return self._stamp(lst, nd, text="[]");
    }

    def c_ArrayRef(nd: object) -> object {
        arr = self.conv_expr(nd.name);
        idx = self.conv_expr(nd.subscript);
        s = ast3.Subscript(value=arr, slice=idx, ctx=ast3.Load());
        return self._stamp(s, nd, text="[]");
    }

    def c_NamedInitializer(nd: object) -> object {
        # {.field = val} designated initializer → emit value, but the field name
        # (which determines WHICH struct member receives it) is dropped. That's
        # lossy whenever initializers aren't in declaration order, so flag it.
        field = ".".join([self._desig_name(d) for d in (nd.name or [])]);
        self._mark_tier_b(
            nd,
            f"designated initializer `.{field}=` — target field name dropped; "
            f"value emitted positionally, verify it lands on the intended member",
        );
        return self.conv_expr(nd.expr);
    }

    def _desig_name(d: object) -> str {
        # A designator is an ID (field) or a Constant (array index).
        return d.name if isinstance(d, c_ast.ID) else str(getattr(d, "value", "?"));
    }

    def c_ExprList(nd: object) -> object {
        # Comma-expression: emit last element (common C idiom, conservative).
        # Earlier operands are evaluated for their side effects in C; dropping
        # them is lossy whenever any precedes the last, so flag that case.
        if nd.exprs {
            if len(nd.exprs) > 1 {
                self._mark_tier_b(
                    nd,
                    f"comma expression — side effects of {len(nd.exprs) - 1} "
                    f"leading operand(s) dropped, only the final value emitted; verify",
                );
            }
            return self.conv_expr(nd.exprs[-1]);
        }
        return self._surrogate_expr(nd);
    }

    def c_Cast(nd: object) -> object {
        # C cast — emit inner expression (lossy but better than surrogate for
        # simple cases). A cast to a scalar/numeric type is representation-
        # changing ((int)f truncates, (char)x narrows, (void)e discards); we drop
        # it, so flag those (§5.3 Tier-B). Pointer/struct casts don't change the
        # emitted value, so they stay at the optimistic Tier-A default.
        target = self._cast_scalar_target(nd);
        if target is not None {
            self._mark_tier_b(
                nd,
                f"cast to `{target}` elided — representation-changing conversion "
                f"(truncation/narrowing/discard) not applied; verify",
            );
        }
        return self.conv_expr(nd.expr);
    }

    def _cast_scalar_target(nd: object) -> str | None {
        # Return the C scalar type name a Cast targets when it is a value cast
        # (Typename → TypeDecl → IdentifierType), else None (pointer/array/struct
        # casts, which don't change the emitted value).
        to_type = nd?.to_type;
        if to_type is None {
            return None;
        }
        inner = to_type?.type;
        if isinstance(inner, c_ast.TypeDecl)
        and isinstance(inner.type, c_ast.IdentifierType) {
            names = inner.type.names;
            return names[-1] if names else None;
        }
        return None;
    }

    # ------------------------------------------------------------------ #
    # P1d — DIRECT_IR placeholder emission                                 #
    # ------------------------------------------------------------------ #
    def c_For(nd: object) -> object {
        return self._directir_placeholder(nd);
    }

    def c_Enum(nd: object) -> object {
        return self._directir_placeholder(nd);
    }

    def c_Enumerator(nd: object) -> object {
        # Usually encountered inside Enum, not top-level; emit surrogate.
        return self._surrogate_stmt(nd);
    }

    def c_EnumeratorList(nd: object) -> object {
        return self._surrogate_stmt(nd);
    }

    # ------------------------------------------------------------------ #
    # Type helpers                                                         #
    # ------------------------------------------------------------------ #
    def _jac_prim(names: list) -> str {
        # Map a C IdentifierType name list to a Jac builtin type name.
        # `char` alone is treated as text (→ str), but `signed char` /
        # `unsigned char` are byte-numeric integers (→ int) — keying on
        # names[-1]=="char" alone would wrongly call those str.
        if not names {
            return "int";
        }
        if "char" in names {
            if "signed" in names or "unsigned" in names {
                return "int";
            }
            return "str";
        }
        return _C_PRIM_MAP.get(names[-1], "int");
    }

    def _prim_typename(names: list) -> str {
        # Map a C IdentifierType name list to a Jac builtin type name.
        return self._jac_prim(names);
    }

    def _user_type_name(t: object) -> str | None {
        # Return the user-defined (struct tag / typedef) name carried by a type
        # node, or None when it names only C builtins. Shared by pointer
        # resolution and malloc(sizeof(T)) struct detection.
        if isinstance(t, c_ast.Struct) and t.name {
            return t.name;
        }
        names = t?.names;
        if names and names[-1] not in _C_BUILTIN_TYPES {
            return names[-1];
        }
        return None;
    }

    def _ptr_typename(ptr_decl: object) -> str {
        # Resolve a PtrDecl to a Jac type name:
        #   char*      → str
        #   struct T*  → T   (PTR_REF; also non-builtin typedef pointers)
        #   otherwise  → object
        inner = ptr_decl.type;
        if isinstance(inner, c_ast.TypeDecl) {
            names = inner.type?.names or [];
            # Only a plain `char *` is a C string; `signed/unsigned char *`
            # are byte buffers, so route the decision through _jac_prim.
            if "char" in names and self._jac_prim(names) == "str" {
                return "str";
            }
            user = self._user_type_name(inner.type);
            if user is not None {
                return user;
            }
        }
        return "object";
    }

    def _typename(decl_type: object) -> str {
        # Canonical scalar/pointer/array type-name resolver. Walks the declarator
        # chain (FuncDecl wrappers, etc.) down to the underlying TypeDecl.
        t = decl_type;
        while not isinstance(t, c_ast.TypeDecl) {
            if isinstance(t, c_ast.ArrayDecl) {
                return "list";
            }
            if isinstance(t, c_ast.PtrDecl) {
                return self._ptr_typename(t);
            }
            if isinstance(t, c_ast.FuncDecl) {
                t = t.type;
                continue;
            }
            t = t?.type;
            if t is None {
                return "int";
            }
        }
        names = t.type?.names or ["int"];
        return self._prim_typename(names);
    }

    def _type_ann(decl: object) -> object {
        # Works on a Decl node.
        name = self._typename(decl.type);
        n = ast3.Name(id=name, ctx=ast3.Load());
        return self._stamp(n, decl, text=name);
    }

    def _type_ann_from_type(t: object) -> object {
        # Works on a raw type node (TypeDecl, PtrDecl, etc.).
        name = self._typename(t);
        (line, col) = (self._lineno, 0);
        n = ast3.Name(id=name, ctx=ast3.Load());
        return self._stamp_manual(n, line, col, text=name);
    }

    def _ret_ann(funcdecl: object) -> object {
        name = self._typename(funcdecl.type);
        n = ast3.Name(id=name, ctx=ast3.Load());
        n.lineno = 1;
        n.col_offset = 0;
        n.end_lineno = 1;
        n.end_col_offset = len(name);
        return n;
    }
}
