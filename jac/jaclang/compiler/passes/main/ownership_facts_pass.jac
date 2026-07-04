import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }

obj OwnershipFacts {
    has value_category: dict[int, str] = {},
        last_uses: dict[int, bool] = {};

    def category_of(nd: object) -> str {
        return self.value_category.get(id(nd), "borrowed");
    }

    def is_owned(nd: object) -> bool {
        return self.value_category.get(id(nd), "borrowed") == "owned";
    }

    def is_last_use(nd: object) -> bool {
        return id(nd) in self.last_uses;
    }
}

def get_ownership_facts(module: uni.Module, prog: any = None) -> OwnershipFacts {
    facts = module.gen.ownership_facts;
    if facts is not None {
        return facts;
    }
    OwnershipFactsPass(ir_in=module, prog=prog);
    return module.gen.ownership_facts or OwnershipFacts();
}

obj OwnershipFactsPass(Transform[uni.Module, uni.Module]) {
    has ref_types: dict[str, bool] = {},
        func_returns: dict[str, str] = {},
        method_returns: dict[str, dict[str, str]] = {},
        field_types: dict[str, dict[str, str]] = {},
        local_types: dict[str, str] = {},
        facts: (OwnershipFacts | None) = None;

    def transform(ir_in: uni.Module) -> uni.Module {
        self.facts = OwnershipFacts();
        try {
            self.analyze(ir_in);
            ir_in.gen.ownership_facts = self.facts;
        } except Exception {
            ir_in.gen.ownership_facts = OwnershipFacts();
        }
        return ir_in;
    }

    def analyze(mod: uni.Module) {
        for stmt in mod.body {
            if isinstance(stmt, uni.Archetype) and self.is_ref_arch(stmt) {
                self.ref_types[stmt.name.value] = True;
            }
        }
        for stmt in mod.body {
            if isinstance(stmt, uni.Archetype) {
                self.index_arch(stmt);
            } elif isinstance(stmt, uni.Ability) and stmt.name_ref is not None {
                sig = stmt.signature;
                self.func_returns[stmt.name_ref.value] = self.ret_name(
                    sig.return_type if sig else None
                );
            }
        }
        for stmt in mod.body {
            if isinstance(stmt, uni.Ability) {
                self.analyze_ability(stmt, "");
            } elif isinstance(stmt, uni.Archetype) {
                for member in (stmt.body or []) {
                    if isinstance(member, uni.Ability) {
                        self.analyze_ability(member, stmt.name.value);
                    }
                }
            }
        }
    }

    def is_ref_arch(arch: uni.Archetype) -> bool {
        for stmt in (arch.body or []) {
            if isinstance(stmt, uni.Ability) {
                return True;
            }
        }
        return arch.base_classes is not None and len(arch.base_classes) > 0;
    }

    def index_arch(arch: uni.Archetype) {
        name = arch.name.value;
        fmap: dict[str, str] = {};
        rmap: dict[str, str] = {};
        for member in (arch.body or []) {
            if isinstance(member, uni.ArchHas) {
                for hv in member.vars {
                    fmap[hv.name.value] = self.tag_name(hv.type_tag);
                }
            } elif isinstance(member, uni.Ability) and member.name_ref is not None {
                sig = member.signature;
                rmap[member.name_ref.value] = self.ret_name(
                    sig.return_type if sig else None
                );
            }
        }
        self.field_types[name] = fmap;
        self.method_returns[name] = rmap;
    }

    def tag_name(type_tag: object) -> str {
        if type_tag is None {
            return "";
        }
        tag = type_tag.tag;
        if isinstance(tag, uni.Name) {
            return tag.value;
        }
        return tag.unparse();
    }

    def ret_name(ret: object) -> str {
        if ret is None {
            return "";
        }
        if isinstance(ret, uni.Name) {
            return ret.value;
        }
        return ret.unparse();
    }

    def analyze_ability(ab: uni.Ability, cls: str) {
        self.local_types = {};
        if cls {
            self.local_types["self"] = cls;
        }
        sig = ab.signature;
        if sig and sig.params {
            for p in sig.params {
                self.local_types[p.name.value] = self.tag_name(p.type_tag);
            }
        }
        body = list(ab.body or []);
        for st in body {
            self.categorize_stmt(st);
        }
        if self.is_straight_line(body) {
            self.mark_last_uses(body);
        }
    }

    def is_straight_line(body: list) -> bool {
        for st in body {
            if not isinstance(st, (uni.Assignment, uni.ExprStmt, uni.ReturnStmt)) {
                return False;
            }
        }
        return True;
    }

    def categorize_stmt(st: object) {
        if isinstance(st, uni.Assignment) {
            if st.value is not None {
                self.categorize(st.value);
                self.note_local_type(st);
            }
        } elif isinstance(st, uni.ExprStmt) {
            self.categorize(st.expr);
        } elif isinstance(st, uni.ReturnStmt) {
            if st.expr is not None {
                self.categorize(st.expr);
            }
        }
    }

    def note_local_type(a: uni.Assignment) {
        tgt = a.target[0];
        if not isinstance(tgt, uni.Name) {
            return;
        }
        if a.type_tag is not None {
            self.local_types[tgt.value] = self.tag_name(a.type_tag);
        } else {
            self.local_types[tgt.value] = self.type_of(a.value);
        }
    }

    def categorize(e: object) {
        if isinstance(e, uni.AtomUnit) {
            self.categorize(e.value);
            self.facts.value_category[id(e)] = self.facts.category_of(e.value);
            return;
        }
        if isinstance(e, uni.FuncCall) {
            for p in (e.params or []) {
                if isinstance(p, uni.Expr) {
                    self.categorize(p);
                }
            }
            owned = self.type_of(e) in self.ref_types or self.type_of(e) == "str";
            self.facts.value_category[id(e)] = "owned" if owned else "borrowed";
            return;
        }
        if isinstance(e, uni.BinaryExpr) {
            self.categorize(e.left);
            self.categorize(e.right);
            if e.op.value == "+"
            and (self.type_of(e.left) == "str" or self.type_of(e.right) == "str") {
                self.facts.value_category[id(e)] = "owned";
            } else {
                self.facts.value_category[id(e)] = "borrowed";
            }
            return;
        }
        if isinstance(e, uni.AtomTrailer) {
            self.categorize(e.target);
            self.facts.value_category[id(e)] = "borrowed";
            return;
        }

        self.facts.value_category[id(e)] = "borrowed";
    }

    def type_of(e: object) -> str {
        if isinstance(e, uni.AtomUnit) {
            return self.type_of(e.value);
        }
        if isinstance(e, (uni.String, uni.MultiString)) {
            return "str";
        }
        if isinstance(e, uni.Name) {
            return self.local_types.get(e.value, "");
        }
        if isinstance(e, uni.BinaryExpr) {
            if e.op.value == "+"
            and (self.type_of(e.left) == "str" or self.type_of(e.right) == "str") {
                return "str";
            }
            return "";
        }
        if isinstance(e, uni.FuncCall) {
            tgt = e.target;
            if isinstance(tgt, uni.Name) and tgt.value in self.ref_types {
                return tgt.value;
            }
            if isinstance(tgt, uni.Name) and tgt.value in self.func_returns {
                return self.func_returns[tgt.value];
            }
            if isinstance(tgt, uni.AtomTrailer) and tgt.is_attr {
                recv = self.type_of(tgt.target);
                m = self.attr_name(tgt.right);
                if recv in self.method_returns and m in self.method_returns[recv] {
                    return self.method_returns[recv][m];
                }
            }
            return "";
        }
        if isinstance(e, uni.AtomTrailer) and e.is_attr {
            recv = self.type_of(e.target);
            f = self.attr_name(e.right);
            if recv in self.field_types and f in self.field_types[recv] {
                return self.field_types[recv][f];
            }
        }
        return "";
    }

    def attr_name(nd: object) -> str {
        if isinstance(nd, uni.Name) {
            return nd.value;
        }
        return "";
    }

    def mark_last_uses(body: list) {
        last_read: dict[str, object] = {};
        for st in body {
            self.collect_reads(st, last_read);
        }
        for (nm, node) in last_read.items() {
            self.facts.last_uses[id(node)] = True;
        }
    }

    def collect_reads(e: object, last_read: dict) {
        if isinstance(e, uni.Assignment) {
            if e.value is not None {
                self.collect_reads(e.value, last_read);
            }
            return;
        }
        if isinstance(e, uni.ExprStmt) {
            self.collect_reads(e.expr, last_read);
            return;
        }
        if isinstance(e, uni.ReturnStmt) {
            if e.expr is not None {
                self.collect_reads(e.expr, last_read);
            }
            return;
        }
        if isinstance(e, uni.AtomUnit) {
            self.collect_reads(e.value, last_read);
            return;
        }
        if isinstance(e, uni.Name) {
            if e.value in self.local_types and e.value != "self" {
                last_read[e.value] = e;
            }
            return;
        }
        if isinstance(e, uni.FuncCall) {
            self.collect_reads(e.target, last_read);
            for p in (e.params or []) {
                if isinstance(p, uni.Expr) {
                    self.collect_reads(p, last_read);
                }
            }
            return;
        }
        if isinstance(e, uni.BinaryExpr) {
            self.collect_reads(e.left, last_read);
            self.collect_reads(e.right, last_read);
            return;
        }
        if isinstance(e, uni.AtomTrailer) {
            self.collect_reads(e.target, last_read);
            return;
        }
    }
}
