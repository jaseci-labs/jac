import operator as pyop;
import jaclang.jac0core.parser.lexer as ct_lexer;

import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.helpers { pascal_to_snake }
import from jaclang.jac0core.parser.parser { Parser }
import from jaclang.jac0core.unitree {
    Ability,
    Bool,
    CtBlock,
    CtElse,
    CtFor,
    CtIf,
    CtName,
    CtSplice,
    DictVal,
    Expr,
    Float,
    GlobalVars,
    Int,
    KVPair,
    ListVal,
    Module,
    Name,
    Null,
    Source,
    ElementStmt,
    EmptyToken,
    String,
    Token,
    TupleVal,
    UnaryExpr,
    UniNode
}
import jaclang.jac0core.ct_reflect as ct_reflect;

glob CT_FUEL_DEFAULT: int = 50000000,
     _CT_SKIP_FIELDS: tuple[str, ...] = (
         "parent",
         "kid",
         "loc",
         "orig_src",
         "name_of",
         "terminals",
         "src_terminals",
         "source"
     );


def module_has_ct(mod: Module) -> bool {
    stack: list[UniNode] = [mod];
    while stack {
        nd = stack.pop();
        if isinstance(nd, (CtFor, CtIf, CtElse, CtBlock, CtSplice, CtName)) {
            return True;
        }
        for k in nd.kid {
            stack.append(k);
        }
    }
    return False;
}


obj CtFragment {
    has kind: str,
        text: str;
}


obj CtHelpers {
    def name(s: str) -> CtFragment {
        return CtFragment(kind="name", text=str(s));
    }

    def typ(src: str) -> CtFragment {
        return CtFragment(kind="type", text=str(src));
    }

    def expr(src: str) -> CtFragment {
        return CtFragment(kind="expr", text=str(src));
    }

    def snake(s: str) -> str {
        return pascal_to_snake(str(s));
    }

    def parts(ann: str) -> list[str] {
        t = str(ann).strip();
        if t.startswith("(") and t.endswith(")") {
            t = t[1:-1];
        }
        out: list[str] = [];
        depth = 0;
        cur = "";
        for ch in t {
            if ch == "[" or ch == "(" {
                depth += 1;
            } elif ch == "]" or ch == ")" {
                depth -= 1;
            }
            if ch == "|" and depth == 0 {
                out.append(cur.strip());
                cur = "";
            } else {
                cur += ch;
            }
        }
        out.append(cur.strip());
        return out;
    }
}


obj CtReflectNS {
    has cur_dir: str = "";

    def module(dotted: str) -> ct_reflect.CtModuleInfo {
        return ct_reflect.load_module(dotted, self.cur_dir);
    }
}


obj CtTarget {
    has contexts: list[str] = [];

    def postinit {
        if not self.contexts {
            self.contexts = ["server", "client", "native"];
        }
    }

    def has(ctx: any) -> bool {
        want = ctx.value if isinstance(ctx, CodeContext) else str(ctx);
        return want in self.contexts;
    }
}


def _ct_err(msg: str) {
    raise RuntimeError(f"comptime: {msg}");
}


obj CtEval {
    has mod: Module,
        file_path: str = "<input>",
        cur_dir: str = "",
        fuel: int = 50000000,
        frames: list[dict[str, any]] = [],
        frame_barriers: list[bool] = [],
        module_defs: dict[str, Ability] = {},
        module_glob_ids: dict[str, UniNode] = {},
        module_globals: dict[str, any] = {},
        targets: list[str] = [],
        loc_stack: list[UniNode] = [],
        _call_memo: dict[Ability, any] = {},
        _ret: any = None,
        _builtins: dict[str, any] = {},
        _ns: dict[str, any] = {};

    def postinit {
        if not self.targets {
            self.targets = ["server", "client", "native"];
        }
        self._builtins = {
            "len": len,
            "str": str,
            "int": int,
            "float": float,
            "bool": bool,
            "repr": repr,
            "sorted": sorted,
            "range": range,
            "enumerate": enumerate,
            "list": list,
            "dict": dict,
            "set": set,
            "tuple": tuple,
            "min": min,
            "max": max,
            "sum": sum,
            "abs": abs,
            "any": any,
            "all": all,
            "zip": zip,
            "reversed": reversed,
            "fail": _ct_err
        };
        self._ns = {
            "ct": CtHelpers(),
            "reflect": CtReflectNS(cur_dir=self.cur_dir),
            "target": CtTarget(contexts=list(self.targets)),
            "CodeContext": CodeContext
        };
    }

    def source -> Source {
        return self.mod.source;
    }

    def burn(n: int = 1) {
        self.fuel -= n;
        if self.fuel < 0 {
            _ct_err("fuel exhausted (runaway comptime expansion?)");
        }
    }

    def cls_name(i: (UniNode | None)) -> str {
        if i is None {
            return "";
        }
        return type(i).__name__;
    }

    def node_arg(i: UniNode, pname: str) -> (UniNode | None) {
        got = getattr(i, pname, None);
        return got if isinstance(got, UniNode) else None;
    }

    def req(got: (UniNode | None), what: str) -> UniNode {
        if got is None {
            raise RuntimeError(f"comptime: missing {what}");
        }
        return got;
    }

    def req_arg(i: UniNode, pname: str) -> UniNode {
        return self.req(self.node_arg(i, pname), f"'{pname}' on {type(i).__name__}");
    }

    def list_arg(i: (UniNode | None), pname: str) -> list[UniNode] {
        got = getattr(i, pname, None);
        if got is None or isinstance(got, UniNode) {
            return [];
        }
        return list(got);
    }

    def poly_arg(i: UniNode, pname: str) -> list[UniNode] {
        got = getattr(i, pname, None);
        if got is None {
            return [];
        }
        if isinstance(got, UniNode) {
            return [got];
        }
        return list(got);
    }

    def str_arg(i: UniNode, pname: str) -> str {
        got = getattr(i, pname, None);
        return got if isinstance(got, str) else "";
    }

    def tok_value(i: (UniNode | None)) -> str {
        if i is None {
            return "";
        }
        return self.str_arg(i, "value");
    }

    def loc_of(i: (UniNode | None)) -> tuple[int, int, int, int] {
        if i is None {
            return (0, 0, 0, 0);
        }
        return (i.loc.first_line, i.loc.last_line, i.loc.col_start, i.loc.col_end);
    }

    def push_frame(barrier: bool = False) {
        self.frames.append({});
        self.frame_barriers.append(barrier);
    }

    def pop_frame {
        self.frames.pop();
        self.frame_barriers.pop();
    }

    def bind(name: str, v: any) {
        self.frames[-1][name] = v;
    }

    def lookup(name: str) -> any {
        idx = len(self.frames) - 1;
        while idx >= 0 {
            if name in self.frames[idx] {
                return self.frames[idx][name];
            }
            if self.frame_barriers[idx] {
                break;
            }
            idx -= 1;
        }
        if name in self._ns {
            return self._ns[name];
        }
        if name in self.module_globals {
            return self.module_globals[name];
        }
        if name in self.module_glob_ids {
            gid = self.module_glob_ids[name];
            self.module_globals[name] = self.eval(gid);
            return self.module_globals[name];
        }
        if name in self._builtins {
            return self._builtins[name];
        }
        _ct_err(f"name '{name}' is not defined in comptime scope");
    }

    def assign(name: str, v: any) {
        idx = len(self.frames) - 1;
        while idx >= 0 {
            if name in self.frames[idx] {
                self.frames[idx][name] = v;
                return;
            }
            if self.frame_barriers[idx] {
                break;
            }
            idx -= 1;
        }
        if self.frames {
            self.frames[-1][name] = v;
        } else {
            self.module_globals[name] = v;
        }
    }

    def unquote(txt: str) -> any {
        import ast as pyast;
        try {
            return pyast.literal_eval(txt);
        } except Exception {
            return txt.strip("\"'");
        }
    }

    def eval(i: UniNode) -> any {
        self.burn();
        self.loc_stack.append(i);
        try {
            return self._eval_inner(i);
        } finally {
            self.loc_stack.pop();
        }
    }

    def _eval_inner(i: UniNode) -> any {
        cn = self.cls_name(i);
        if cn == "Name" {
            return self.lookup(self.tok_value(i));
        }
        if cn == "Int" {
            txt = self.tok_value(i).replace("_", "");
            return int(txt, 0) if txt.startswith("0") and len(txt) > 1 else int(txt);
        }
        if cn == "Float" {
            return float(self.tok_value(i));
        }
        if cn == "Bool" {
            return self.tok_value(i) == "True";
        }
        if cn == "Null" {
            return None;
        }
        if cn == "String" {
            return self.unquote(self.tok_value(i));
        }
        if cn == "MultiString" {
            out = "";
            for p in self.list_arg(i, "strings") {
                v = self.eval(p);
                out += str(v);
            }
            return out;
        }
        if cn == "FString" {
            out = "";
            for p in self.list_arg(i, "parts") {
                pcn = self.cls_name(p);
                if pcn == "String" {
                    out += str(self.tok_value(p));
                } elif pcn == "FormattedValue" {
                    fv = self.eval(self.req_arg(p, "format_part"));
                    out += str(fv);
                } elif pcn == "ExprStmt" {
                    out += str(self.eval(self.req_arg(p, "expr")));
                } else {
                    out += str(self.eval(p));
                }
            }
            return out;
        }
        if cn == "CtBlock" or cn == "CfgExpr" {
            return self.eval(self.req_arg(i, "expr"));
        }
        if cn == "AtomUnit" {
            return self.eval(self.req_arg(i, "value"));
        }
        if cn == "BinaryExpr" {
            return self._binop(
                self.tok_value(self.node_arg(i, "op")),
                self.eval(self.req_arg(i, "left")),
                self.eval(self.req_arg(i, "right"))
            );
        }
        if cn == "CompareExpr" {
            left = self.eval(self.req_arg(i, "left"));
            rights = self.list_arg(i, "rights");
            ops = self.list_arg(i, "ops");
            idx = 0;
            while idx < len(rights) {
                right = self.eval(rights[idx]);
                if not self._cmp(self.tok_value(ops[idx]), left, right) {
                    return False;
                }
                left = right;
                idx += 1;
            }
            return True;
        }
        if cn == "BoolExpr" {
            op = self.tok_value(self.node_arg(i, "op"));
            vals = self.list_arg(i, "values");
            if op == "and" {
                r: any = True;
                for v in vals {
                    r = self.eval(v);
                    if not r {
                        return r;
                    }
                }
                return r;
            }
            r2: any = False;
            for v in vals {
                r2 = self.eval(v);
                if r2 {
                    return r2;
                }
            }
            return r2;
        }
        if cn == "UnaryExpr" {
            op = self.tok_value(self.node_arg(i, "op"));
            v = self.eval(self.req_arg(i, "operand"));
            if op == "-" {
                return -v;
            }
            if op == "+" {
                return +v;
            }
            if op == "not" {
                return not v;
            }
            if op == "~" {
                return ~v;
            }
            _ct_err(f"unary operator '{op}' not supported in comptime");
        }
        if cn == "IfElseExpr" {
            if self.eval(self.req_arg(i, "condition")) {
                return self.eval(self.req_arg(i, "value"));
            }
            return self.eval(self.req_arg(i, "else_value"));
        }
        if cn == "ListVal" {
            return [self.eval(v) for v in self.list_arg(i, "values")];
        }
        if cn == "TupleVal" {
            return tuple([self.eval(v) for v in self.list_arg(i, "values")]);
        }
        if cn == "SetVal" {
            return {self.eval(v) for v in self.list_arg(i, "values")};
        }
        if cn == "DictVal" {
            out2: dict[any, any] = {};
            for kv in self.list_arg(i, "kv_pairs") {
                key = self.node_arg(kv, "key");
                if key is None {
                    raise RuntimeError(
                        "comptime: dict spread not supported in comptime"
                    );
                }
                out2[self.eval(key)] = self.eval(self.req_arg(kv, "value"));
            }
            return out2;
        }
        if cn in ("ListCompr", "GenCompr", "SetCompr") {
            items = self._compr_items(
                self.list_arg(i, "compr"), 0, self.node_arg(i, "out_expr")
            );
            return set(items) if cn == "SetCompr" else items;
        }
        if cn == "DictCompr" {
            kvp = self.node_arg(i, "kv_pair");
            pairs = self._compr_items(self.list_arg(i, "compr"), 0, None, kvp);
            out3: dict[any, any] = {};
            for entry in pairs {
                out3[entry[0]] = entry[1];
            }
            return out3;
        }
        if cn == "AtomTrailer" {
            return self._eval_trailer(i);
        }
        if cn == "FuncCall" {
            return self._eval_call(i);
        }
        _ct_err(f"'{cn}' expression not supported in comptime");
    }

    def _compr_items(
        comprs: list[UniNode],
        depth: int,
        out_expr: (UniNode | None),
        kv_pair: (UniNode | None) = None
    ) -> list[any] {
        if depth >= len(comprs) {
            if kv_pair is not None {
                k = self.eval(self.req_arg(kv_pair, "key"));
                v = self.eval(self.req_arg(kv_pair, "value"));
                return [(k, v, )];
            }
            return [self.eval(self.req(out_expr, "comprehension output expression"))];
        }
        c = comprs[depth];
        coll = self.eval(self.req_arg(c, "collection"));
        conds = self.list_arg(c, "conditional");
        tgt = self.req_arg(c, "target");
        out: list[any] = [];
        for item in coll {
            self.push_frame();
            self._bind_target(tgt, item);
            keep = True;
            for cond in conds {
                if not self.eval(cond) {
                    keep = False;
                    break;
                }
            }
            if keep {
                out.extend(self._compr_items(comprs, depth + 1, out_expr, kv_pair));
            }
            self.pop_frame();
        }
        return out;
    }

    def _bind_target(tgt: UniNode, v: any) {
        cn = self.cls_name(tgt);
        if cn == "Name" {
            self.bind(self.tok_value(tgt), v);
            return;
        }
        if cn == "TupleVal" {
            names = self.list_arg(tgt, "values");
            vals = list(v);
            if len(names) != len(vals) {
                _ct_err("comptime destructuring arity mismatch");
            }
            idx = 0;
            while idx < len(names) {
                self._bind_target(names[idx], vals[idx]);
                idx += 1;
            }
            return;
        }
        _ct_err(f"'{cn}' target not supported in comptime");
    }

    def _assign_target(tgt: UniNode, v: any) {
        cn = self.cls_name(tgt);
        if cn == "Name" {
            self.assign(self.tok_value(tgt), v);
            return;
        }
        if cn == "TupleVal" {
            names = self.list_arg(tgt, "values");
            vals = list(v);
            if len(names) != len(vals) {
                _ct_err("comptime destructuring arity mismatch");
            }
            idx = 0;
            while idx < len(names) {
                self._assign_target(names[idx], vals[idx]);
                idx += 1;
            }
            return;
        }
        if cn == "AtomTrailer" {
            tv = self.eval(self.req_arg(tgt, "target"));
            right = self.node_arg(tgt, "right");
            if self.cls_name(right) == "IndexSlice" {
                slices = self.list_arg(right, "slices");
                if len(slices) == 1 {
                    s0 = slices[0];
                    if self.cls_name(s0) == "Slice" {
                        lo = self.node_arg(s0, "start");
                        if lo is not None {
                            tv[self.eval(lo)] = v;
                            return;
                        }
                    } else {
                        tv[self.eval(s0)] = v;
                        return;
                    }
                }
            }
            _ct_err("attribute/slice assignment not supported in comptime");
        }
        _ct_err(f"'{cn}' assign target not supported in comptime");
    }

    def _attr_get(base: any, name: str) -> any {
        if name.startswith("_") {
            _ct_err(f"access to '{name}' not allowed in comptime");
        }
        try {
            return getattr(base, name);
        } except AttributeError {
            _ct_err(f"'{type(base).__name__}' has no attribute '{name}'");
        }
    }

    def _eval_trailer(i: UniNode) -> any {
        tv = self.eval(self.req_arg(i, "target"));
        right = self.req_arg(i, "right");
        rcn = self.cls_name(right);
        if rcn == "Name" {
            return self._attr_get(tv, self.tok_value(right));
        }
        if rcn == "IndexSlice" {
            slices = self.list_arg(right, "slices");
            is_range = False;
            got_r = right?.is_range;
            if got_r is not None {
                is_range = bool(got_r);
            }
            if len(slices) != 1 {
                _ct_err("multi-dimension index not supported in comptime");
            }
            s0 = slices[0];
            if self.cls_name(s0) == "Slice" {
                lo = self.node_arg(s0, "start");
                hi = self.node_arg(s0, "stop");
                st = self.node_arg(s0, "step");
                if not is_range {
                    if lo is None {
                        raise RuntimeError(
                            "comptime: empty index not supported in comptime"
                        );
                    }
                    return tv[self.eval(lo)];
                }
                lo_v = self.eval(lo) if lo is not None else None;
                hi_v = self.eval(hi) if hi is not None else None;
                st_v = self.eval(st) if st is not None else None;
                return tv[slice(lo_v, hi_v, st_v)];
            }
            return tv[self.eval(s0)];
        }
        if rcn == "FuncCall" {
            inner_tgt = self.node_arg(right, "target");
            fn: any = None;
            if self.cls_name(inner_tgt) == "Name" {
                fn = self._attr_get(tv, self.tok_value(inner_tgt));
            } else {
                _ct_err("computed method call not supported in comptime");
            }
            (args, kwargs) = self._call_args(right);
            return fn(*args, **kwargs);
        }
        _ct_err(f"'{rcn}' trailer not supported in comptime");
    }

    def _call_args(call: UniNode) -> tuple[list[any], dict[str, any]] {
        args: list[any] = [];
        kwargs: dict[str, any] = {};
        for p in self.list_arg(call, "params") {
            if self.cls_name(p) == "KWPair" {
                key = self.node_arg(p, "key");
                if key is None {
                    _ct_err("** spread not supported in comptime calls");
                }
                kwargs[self.tok_value(key)] = self.eval(self.req_arg(p, "value"));
            } else {
                args.append(self.eval(p));
            }
        }
        return (args, kwargs, );
    }

    def _eval_call(i: UniNode) -> any {
        tgt = self.req_arg(i, "target");
        tcn = self.cls_name(tgt);
        if tcn == "AtomTrailer" {
            tv = self.eval(self.req_arg(tgt, "target"));
            right = self.node_arg(tgt, "right");
            if self.cls_name(right) == "Name" {
                fn = self._attr_get(tv, self.tok_value(right));
                (args, kwargs) = self._call_args(i);
                self.burn(10);
                return fn(*args, **kwargs);
            }
            _ct_err("computed call target not supported in comptime");
        }
        if tcn == "Name" {
            fname = self.tok_value(tgt);
            if fname in self.module_defs {
                (args, kwargs) = self._call_args(i);
                return self.call_def(self.module_defs[fname], args, kwargs);
            }
            fn2 = self.lookup(fname);
            (args2, kwargs2) = self._call_args(i);
            self.burn(10);
            return fn2(*args2, **kwargs2);
        }
        if tcn == "BuiltinType" {
            fn3 = self._builtins.get(self.str_arg(tgt, "value") or "");
            if fn3 is None {
                fn3 = self._builtins.get(self.tok_value(tgt));
            }
            if fn3 is None {
                _ct_err("builtin-type call not supported in comptime");
            }
            (args3, kwargs3) = self._call_args(i);
            return fn3(*args3, **kwargs3);
        }
        _ct_err(f"'{tcn}' call target not supported in comptime");
    }

    def call_def(abil: Ability, args: list[any], kwargs: dict[str, any]) -> any {
        self.burn(20);
        if not args and not kwargs and abil in self._call_memo {
            return self._call_memo[abil];
        }
        sig = self.node_arg(abil, "signature");
        pids = self.list_arg(sig, "params") if sig is not None else [];
        self.push_frame(barrier=True);
        idx = 0;
        for pid in pids {
            pname_id = self.node_arg(pid, "name");
            pname = self.tok_value(pname_id);
            if idx < len(args) {
                self.bind(pname, args[idx]);
            } elif pname in kwargs {
                self.bind(pname, kwargs[pname]);
            } else {
                dflt = self.node_arg(pid, "value");
                if dflt is None {
                    self.pop_frame();
                    raise RuntimeError(
                        f"comptime: missing comptime argument '{pname}'"
                    );
                }
                self.bind(pname, self.eval(dflt));
            }
            idx += 1;
        }
        self._ret = None;
        body = self.poly_arg(abil, "body");
        _sig = self.exec_block(body);
        out = self._ret;
        self._ret = None;
        self.pop_frame();
        if not args and not kwargs {
            self._call_memo[abil] = out;
        }
        return out;
    }

    def exec_block(ids: list[UniNode]) -> int {
        for i in ids {
            sig = self.exec_stmt(i);
            if sig != 0 {
                return sig;
            }
        }
        return 0;
    }

    def exec_stmt(i: UniNode) -> int {
        self.burn();
        self.loc_stack.append(i);
        try {
            return self._exec_inner(i);
        } finally {
            self.loc_stack.pop();
        }
    }

    def _exec_inner(i: UniNode) -> int {
        cn = self.cls_name(i);
        if cn == "Assignment" {
            aug = self.node_arg(i, "aug_op");
            targets = self.list_arg(i, "target");
            val = self.eval(self.req_arg(i, "value"));
            if aug is not None {
                op = self.tok_value(aug);
                cur = self.eval(targets[0]);
                self._assign_target(targets[0], self._binop(op.rstrip("="), cur, val));
                return 0;
            }
            for t in targets {
                self._assign_target(t, val);
            }
            return 0;
        }
        if cn == "ExprStmt" {
            self.eval(self.req_arg(i, "expr"));
            return 0;
        }
        if cn in ("IfStmt", "ElseIf") {
            if self.eval(self.req_arg(i, "condition")) {
                return self.exec_block(self.list_arg(i, "body"));
            }
            eb = self.node_arg(i, "else_body");
            if eb is not None {
                return self.exec_stmt(eb);
            }
            return 0;
        }
        if cn == "ElseStmt" {
            return self.exec_block(self.list_arg(i, "body"));
        }
        if cn == "WhileStmt" {
            while self.eval(self.req_arg(i, "condition")) {
                self.burn(2);
                sig = self.exec_block(self.list_arg(i, "body"));
                if sig == 1 {
                    return 1;
                }
                if sig == 2 {
                    break;
                }
            }
            return 0;
        }
        if cn == "InForStmt" {
            tgt = self.req_arg(i, "target");
            coll = self.eval(self.req_arg(i, "collection"));
            for item in coll {
                self.burn(2);
                self.push_frame();
                self._bind_target(tgt, item);
                sig = self.exec_block(self.list_arg(i, "body"));
                self.pop_frame();
                if sig == 1 {
                    return 1;
                }
                if sig == 2 {
                    break;
                }
            }
            return 0;
        }
        if cn == "ReturnStmt" {
            e = self.node_arg(i, "expr");
            self._ret = self.eval(e) if e is not None else None;
            return 1;
        }
        if cn == "CtrlStmt" {
            word = self.tok_value(self.node_arg(i, "ctrl"));
            if word == "break" {
                return 2;
            }
            if word == "continue" {
                return 3;
            }
            _ct_err(f"'{word}' not supported in comptime");
        }
        if cn == "Semi" {
            return 0;
        }
        _ct_err(f"'{cn}' statement not supported in comptime");
        return 0;
    }

    def _binop(op: str, l: any, r: any) -> any {
        if op == "+" {
            return l + r;
        }
        if op == "-" {
            return l - r;
        }
        if op == "*" {
            return l * r;
        }
        if op == "/" {
            return l / r;
        }
        if op == "//" {
            return l // r;
        }
        if op == "%" {
            return l % r;
        }
        if op == "**" {
            return l ** r;
        }
        if op == "|" {
            return l | r;
        }
        if op == "&" {
            return l & r;
        }
        _ct_err(f"operator '{op}' not supported in comptime");
    }

    def _cmp(op: str, l: any, r: any) -> bool {
        if op == "==" {
            return l == r;
        }
        if op == "!=" {
            return l != r;
        }
        if op == "<" {
            return pyop.lt(l, r);
        }
        if op == "<=" {
            return pyop.le(l, r);
        }
        if op == ">" {
            return pyop.gt(l, r);
        }
        if op == ">=" {
            return pyop.ge(l, r);
        }
        if op == "in" {
            return pyop.contains(r, l);
        }
        if op == "not in" {
            return not pyop.contains(r, l);
        }
        if op == "is" {
            return l is r;
        }
        if op == "is not" {
            return l is not r;
        }
        _ct_err(f"comparison '{op}' not supported in comptime");
        return False;
    }
}

obj CtExpander {
    has ev: CtEval,
        subst: dict[int, tuple[UniNode, list[UniNode]]] = {},
        _visited: dict[int, UniNode] = {};

    def sweep_kids {
        stack: list[UniNode] = [self.ev.mod];
        seen: dict[int, bool] = {};
        while stack {
            nd = stack.pop();
            if id(nd) in seen {
                continue;
            }
            seen[id(nd)] = True;
            hit = False;
            for k in nd.kid {
                if id(k) in self.subst {
                    hit = True;
                    break;
                }
            }
            if hit {
                rebuilt: list[UniNode] = [];
                for k in nd.kid {
                    if id(k) in self.subst {
                        for r in self.subst[id(k)][1] {
                            rebuilt.append(r);
                        }
                    } else {
                        rebuilt.append(k);
                    }
                }
                nd.set_kids(rebuilt);
            }
            for k in nd.kid {
                stack.append(k);
            }
        }
    }

    def _tok(
        mk_name: str, tok_name: str, text: str, loc: tuple[int, int, int, int]
    ) -> Expr {
        (line, end_line, cs, ce) = (loc[0], loc[1], loc[2], loc[3]);
        src = self.ev.source();
        if mk_name == "NAME" {
            return Name(
                orig_src=src,
                name="NAME",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce,
                pos_start=0,
                pos_end=0
            );
        }
        if mk_name == "INT" {
            return Int(
                orig_src=src,
                name="INT",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce,
                pos_start=0,
                pos_end=0
            );
        }
        if mk_name == "FLOAT" {
            return Float(
                orig_src=src,
                name="FLOAT",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce,
                pos_start=0,
                pos_end=0
            );
        }
        if mk_name == "STRING" {
            return String(
                orig_src=src,
                name="STRING",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce,
                pos_start=0,
                pos_end=0
            );
        }
        if mk_name == "BOOL" {
            return Bool(
                orig_src=src,
                name="BOOL",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce,
                pos_start=0,
                pos_end=0
            );
        }
        if mk_name == "NULL" {
            return Null(
                orig_src=src,
                name="NULL",
                value=text,
                line=line,
                end_line=end_line,
                col_start=cs,
                col_end=ce,
                pos_start=0,
                pos_end=0
            );
        }
        raise RuntimeError(f"comptime: internal: unknown token builder {mk_name}");
    }

    def value_to_nodes(v: any, loc: tuple[int, int, int, int]) -> Expr {
        self.ev.burn(2);
        if isinstance(v, CtFragment) {
            frag_node = self.parse_frag(v, loc);
            if not isinstance(frag_node, Expr) {
                raise RuntimeError(
                    "comptime: fragment in value position is not an expression"
                );
            }
            return frag_node;
        }
        if isinstance(v, bool) {
            return self._tok("BOOL", "BOOL", "True" if v else "False", loc);
        }
        if isinstance(v, int) {
            if v < 0 {
                operand = self._tok("INT", "INT", str(-v), loc);
                return UnaryExpr(
                    op=self._minus_tok(loc), operand=operand, kid=[operand]
                );
            }
            return self._tok("INT", "INT", str(v), loc);
        }
        if isinstance(v, float) {
            return self._tok("FLOAT", "FLOAT", repr(v), loc);
        }
        if isinstance(v, str) {
            return self._tok("STRING", "STRING", _jac_str_lit(v), loc);
        }
        if v is None {
            return self._tok("NULL", "NULL", "None", loc);
        }
        if isinstance(v, (list, tuple)) {
            vals: list[Expr] = [];
            for item in v {
                vals.append(self.value_to_nodes(item, loc));
            }
            if isinstance(v, tuple) {
                lt = self._punct("LPAREN", "(", loc);
                rt = self._punct("RPAREN", ")", loc);
                return TupleVal(values=vals, kid=[lt] + vals + [rt]);
            }
            lt2 = self._punct("LSQUARE", "[", loc);
            rt2 = self._punct("RSQUARE", "]", loc);
            return ListVal(values=vals, kid=[lt2] + vals + [rt2]);
        }
        if isinstance(v, dict) {
            pairs: list[KVPair] = [];
            for entry in v.items() {
                kk = self.value_to_nodes(entry[0], loc);
                vv = self.value_to_nodes(entry[1], loc);
                pairs.append(KVPair(key=kk, value=vv, kid=[kk, vv]));
            }
            lb = self._punct("LBRACE", "{", loc);
            rb = self._punct("RBRACE", "}", loc);
            return DictVal(kv_pairs=pairs, kid=[lb] + pairs + [rb]);
        }
        raise RuntimeError(
            f"comptime: value of type '{type(v).__name__}' cannot lower to a literal"
        );
    }

    def _minus_tok(loc: tuple[int, int, int, int]) -> Token {
        return self._punct("MINUS", "-", loc);
    }

    def _punct(name: str, text: str, loc: tuple[int, int, int, int]) -> Token {
        return Token(
            orig_src=self.ev.source(),
            name=name,
            value=text,
            line=loc[0],
            end_line=loc[1],
            col_start=loc[2],
            col_end=loc[3],
            pos_start=0,
            pos_end=0
        );
    }

    def parse_frag(f: CtFragment, loc: tuple[int, int, int, int]) -> UniNode {
        self.ev.burn(50);
        if f.kind == "name" {
            if not _is_ident(f.text) {
                _ct_err(f"ct.name('{f.text}') is not a valid identifier");
            }
            return self._tok("NAME", "NAME", f.text, loc);
        }
        (tokens, _c, _ld, lex_errs) = ct_lexer.tokenize_full(f.text, "<comptime>");
        parser = Parser(tokens=tokens, file_path="<comptime>", source_code=f.text);
        parser._tokens_len = len(tokens);
        frag_root = parser.parse_expression();
        if parser.error_count > 0 or lex_errs > 0 {
            _ct_err(f"cannot parse ct fragment '{f.text}'");
        }
        self._rebind_src(frag_root);
        return frag_root;
    }

    def _rebind_src(frag_root: UniNode) {
        src = self.ev.source();
        stack: list[UniNode] = [frag_root];
        while stack {
            nd = stack.pop();
            if isinstance(nd, Token) {
                nd.orig_src = src;
            }
            for k in nd.kid {
                stack.append(k);
            }
        }
    }

    def copy_tree(i: (UniNode | None)) -> (UniNode | None) {
        if i is None {
            return None;
        }
        self.ev.burn();
        import copy as pycopy;
        memo: dict[int, any] = {};
        if i.parent is not None {
            memo[id(i.parent)] = i.parent;
        }
        src = self.ev.source();
        memo[id(src)] = src;
        return pycopy.deepcopy(i, memo);
    }

    def ct_name_text(i: UniNode) -> str {
        out = "";
        for p in self.ev.list_arg(i, "parts") {
            if isinstance(p, CtSplice) {
                v = self.ev.eval(self.ev.req_arg(p, "expr"));
                if isinstance(v, CtFragment) and v.kind == "name" {
                    v = v.text;
                }
                if not isinstance(v, str) {
                    _ct_err("name splice must evaluate to a string");
                }
                out += v;
            } else {
                out += self.ev.tok_value(p);
            }
        }
        if not _is_ident(out) {
            _ct_err(f"interpolated name '{out}' is not a valid identifier");
        }
        return out;
    }

    def subst_expr(i: UniNode) -> UniNode {
        loc = self.ev.loc_of(i);
        if isinstance(i, CtName) {
            return self._tok("NAME", "NAME", self.ct_name_text(i), loc);
        }
        v = self.ev.eval(self.ev.req_arg(i, "expr"));
        if isinstance(i, CtSplice) and isinstance(v, CtFragment) {
            if v.kind == "name" {
                if not _is_ident(v.text) {
                    _ct_err(f"ct.name('{v.text}') is not a valid identifier");
                }
                return self._tok("NAME", "NAME", v.text, loc);
            }
            return self.parse_frag(v, loc);
        }
        return self.value_to_nodes(v, loc);
    }

    def expand_node(i: (UniNode | None)) {
        if i is None {
            return;
        }
        if id(i) in self._visited {
            return;
        }
        self._visited[id(i)] = i;
        self.ev.burn();
        for entry in list(i.__dict__.items()) {
            fname: str = entry[0];
            val: any = entry[1];
            if fname.startswith("_") or fname in _CT_SKIP_FIELDS {
                continue;
            }
            if isinstance(val, UniNode) {
                if isinstance(val, (CtBlock, CtSplice, CtName)) {
                    nid = self.subst_expr(val);
                    setattr(i, fname, nid);
                    self.subst[id(val)] = (val, [nid], );
                } elif isinstance(val, (CtFor, CtIf, CtElse)) {
                    _ct_err(
                        "comptime for/if is not valid where a single "
                        "expression is required"
                    );
                } else {
                    self.expand_node(val);
                }
            } elif isinstance(val, (list, tuple)) {
                ids: list[UniNode] = [
                    x
                    for x in val
                    if isinstance(x, UniNode)
                ];
                if len(ids) != len(list(val)) {
                    continue;
                }
                found_ct = False;
                for x in ids {
                    if isinstance(
                        x, (CtFor, CtIf, CtElse, CtBlock, CtSplice, CtName)
                    ) {
                        found_ct = True;
                        break;
                    }
                }
                if found_ct {
                    new_ids = self.expand_items(ids, i);
                    setattr(i, fname, new_ids);
                } else {
                    for x in ids {
                        self.expand_node(x);
                    }
                }
            }
        }
    }

    def expand_items(ids: list[UniNode], parent: UniNode) -> list[UniNode] {
        out: list[UniNode] = [];
        for x in ids {
            if isinstance(x, CtFor) {
                news = self.expand_ct_for(x);
                self.subst[id(x)] = (x, news, );
                out.extend(news);
            } elif isinstance(x, CtIf) {
                news = self.expand_ct_if(x, parent);
                self.subst[id(x)] = (x, news, );
                out.extend(news);
            } elif isinstance(x, (CtBlock, CtSplice, CtName)) {
                nid = self.subst_expr(x);
                self.subst[id(x)] = (x, [nid], );
                out.append(nid);
            } else {
                self.expand_node(x);
                out.append(x);
            }
        }
        return out;
    }

    def expand_ct_for(i: UniNode) -> list[UniNode] {
        ev = self.ev;
        tgt = ev.node_arg(i, "target");
        tname = ev.tok_value(tgt);
        coll = ev.eval(ev.req_arg(i, "iter"));
        body = ev.list_arg(i, "body");
        out: list[UniNode] = [];
        for v in coll {
            ev.burn(5);
            ev.push_frame();
            ev.bind(tname, v);
            for b in body {
                nb = self.copy_tree(b);
                if nb is not None {
                    out.extend(self.expand_items([nb], i));
                }
            }
            ev.pop_frame();
        }
        return out;
    }

    def expand_ct_if(i: UniNode, parent: UniNode) -> list[UniNode] {
        ev = self.ev;
        if ev.eval(ev.req_arg(i, "condition")) {
            return self.expand_items(ev.list_arg(i, "body"), i);
        }
        eb = ev.node_arg(i, "else_body");
        if eb is None {
            return [];
        }
        if isinstance(eb, CtIf) {
            return self.expand_ct_if(eb, parent);
        }
        return self.expand_items(ev.list_arg(eb, "body"), eb);
    }

    def strip_ct_only(mod: Module) {
        removed: dict[int, bool] = {};
        kept: list[ElementStmt | String | EmptyToken] = [];
        for b in mod.body {
            if isinstance(b, Ability) and b.is_ct_only {
                removed[id(b)] = True;
            } else {
                kept.append(b);
            }
        }
        if not removed {
            return;
        }
        mod.body = kept;
        new_kid: list[UniNode] = [
            k
            for k in mod.kid
            if id(k) not in removed
        ];
        mod.set_kids(new_kid);
    }

    def collect_module(mod: Module) {
        ev = self.ev;
        for item in mod.body {
            if isinstance(item, Ability) {
                nref = ev.node_arg(item, "name_ref");
                if nref is not None and ev.cls_name(nref) == "Name" {
                    ev.module_defs[ev.tok_value(nref)] = item;
                }
            } elif isinstance(item, GlobalVars) {
                for asg in ev.list_arg(item, "assignments") {
                    tgts = ev.list_arg(asg, "target");
                    gval = ev.node_arg(asg, "value");
                    if (
                        gval is not None
                        and len(tgts) == 1
                        and ev.cls_name(tgts[0]) == "Name"
                    ) {
                        ev.module_glob_ids[ev.tok_value(tgts[0])] = gval;
                    }
                }
            }
        }
    }
}


def _is_ident(s: str) -> bool {
    if not s {
        return False;
    }
    first = s[0];
    if not (first.isalpha() or first == "_") {
        return False;
    }
    for ch in s[1:] {
        if not (ch.isalnum() or ch == "_") {
            return False;
        }
    }
    return True;
}


def _jac_str_lit(s: str) -> str {
    body = "";
    for ch in s {
        if ch == "\\" {
            body += "\\\\";
        } elif ch == "\"" {
            body += "\\\"";
        } elif ch == "\n" {
            body += "\\n";
        } elif ch == "\t" {
            body += "\\t";
        } elif ch == "\r" {
            body += "\\r";
        } else {
            body += ch;
        }
    }
    return "\"" + body + "\"";
}


def _refresh_locs(mod: Module) {
    stack: list[tuple[UniNode, bool]] = [(mod, False)];
    while stack {
        entry: tuple[UniNode, bool] = stack.pop();
        nd: UniNode = entry[0];
        expanded: bool = entry[1];
        if expanded {
            if len(nd.kid) {
                nd.loc.update_token_range(*nd.resolve_tok_range());
            }
            continue;
        }
        stack.append((nd, True));
        for k in nd.kid {
            stack.append((k, False));
        }
    }
}


def _refresh_in_mod_nodes(mod: Module) {
    node_list: list[UniNode] = [];
    seen: dict[int, bool] = {};
    walk: list[UniNode] = [mod];
    while walk {
        nd = walk.pop();
        nid = id(nd);
        if nid not in seen {
            seen[nid] = True;
            node_list.append(nd);
            for child in nd.kid {
                walk.append(child);
            }
        }
    }
    mod._in_mod_nodes = node_list;
}


def expand_module(
    mod: Module,
    file_path: str = "<input>",
    targets: (list[str] | None) = None,
    fuel: int = 50000000
) -> list[tuple[int, int, int, int, str]] {
    import os;
    ev = CtEval(
        mod=mod,
        file_path=file_path,
        cur_dir=os.path.dirname(file_path),
        fuel=fuel,
        targets=(targets if targets is not None else ["server", "client", "native"])
    );
    ev.push_frame();
    ex = CtExpander(ev=ev);
    try {
        ex.collect_module(mod);
        ex.expand_node(mod);
        ex.sweep_kids();
        ex.strip_ct_only(mod);
        _refresh_locs(mod);
        _refresh_in_mod_nodes(mod);
    } except Exception as e {
        at = ev.loc_stack[-1] if ev.loc_stack else mod;
        loc = ev.loc_of(at);
        msg = str(e);
        if not msg.startswith("comptime") {
            msg = f"comptime: {msg}";
        }
        return [(loc[0], loc[1], loc[2], loc[3], msg, )];
    }
    return [];
}
