import os;
import sys;
import from jaclang.compiler.types.types { ClassType, UnknownType }
import from jaclang.compiler.frontend.unitree { Module }

def probe_on -> bool {
    return bool(os.environ.get("JAC_XREF_PROBE", ""));
}

def truncated_mro(src: any) -> bool {
    if not isinstance(src, ClassType) or src._shared is None {
        return False;
    }
    names: set[str] = set();
    for c in (src.shared.mro or []) {
        names.add(c.shared.class_name);
    }
    for b in (src.shared.base_classes or []) {
        if not isinstance(b, ClassType) or b._shared is None {
            continue;
        }
        bmro = b.shared.mro or [];
        if not bmro and (b.shared.base_classes or []) {
            return True;
        }
        for c in bmro {
            if c.shared.class_name not in names {
                return True;
            }
        }
    }
    return False;
}

def _mod_of(t: any) -> any {
    cur = t.shared.symbol_table if t._shared is not None else None;
    while cur is not None and not isinstance(cur, Module) {
        cur = cur.parent_scope;
    }
    return cur;
}

def _state(prog: any, selfhost_prog: any, m: any) -> str {
    if m is None {
        return "nomod";
    }
    mp = m.loc.mod_path if m.loc is not None else "";
    if prog is None {
        return f"?[{os.path.basename(mp)}]";
    }
    found = prog.find_module(mp) if mp else None;
    state = "gone";
    if found is m {
        state = "live";
    } elif found is not None {
        state = "stale";
    }
    in_t = "y" if mp in prog.mod.hub else "n";
    in_s = "y" if mp in selfhost_prog.mod.hub else "n";
    kind = "cat" if m?.cat_kids is not None else "tree";
    stub = ",stub" if getattr(m, "stub_only", False) else "";
    return f"{state}[t={in_t},s={in_s},{kind}{stub}]";
}

def _rec(prog: any, selfhost_prog: any, t: any) -> str {
    if not isinstance(t, ClassType) or t._shared is None {
        return f"<{type(t).__name__}>";
    }
    key = t.shared.canonical_key();
    site = "<nokey>";
    if key is not None {
        site = f"{os.path.basename(key[0])}:{key[1]}:{key[2]}";
    }
    state = _state(prog, selfhost_prog, _mod_of(t));
    mro_names = ",".join([c.shared.class_name for c in (t.shared.mro or [])]);
    base_names = ",".join(
        [
            (
                b.shared.class_name
                    if isinstance(b, ClassType) and b._shared is not None
                    else type(b).__name__
            ) for b in (t.shared.base_classes or [])
        ]
    );
    return (
        f"{t.shared.class_name}@{site} id={id(t.shared)} {state} "
        f"mro=[{mro_names}] bases=[{base_names}]"
    );
}

def _progs(evaluator: any) -> tuple {
    prog = evaluator.program;
    return (prog, prog._get_compiler().selfhost.program);
}

def _tail(tag: str, prog: any, selfhost_prog: any) -> str {
    te_state = "set" if selfhost_prog.type_evaluator is not None else "none";
    return (
        f"[{tag}]   selfhost_te={te_state} "
        f"selfhost_hub={len(selfhost_prog.mod.hub)} "
        f"target_hub={len(prog.mod.hub)} "
        f"depth={prog.scratch.compile_depth}/{selfhost_prog.scratch.compile_depth}"
    );
}

def dump_assign_fail(evaluator: any, src_type: any, dest_type: any, tag: str) {
    try {
        (prog, sh) = _progs(evaluator);
        lines = [
            f"[{tag}] pid={os.getpid()} src={_rec(prog, sh, src_type)}",
            f"[{tag}]   dest={_rec(prog, sh, dest_type)}"
        ];
        if isinstance(src_type, ClassType) and src_type._shared is not None {
            for b in (src_type.shared.base_classes or []) {
                lines.append(f"[{tag}]   src.base={_rec(prog, sh, b)}");
                if isinstance(b, ClassType) and b._shared is not None {
                    for bb in (b.shared.base_classes or []) {
                        lines.append(f"[{tag}]     src.base.base={_rec(prog, sh, bb)}");
                    }
                }
            }
        }
        lines.append(_tail(tag, prog, sh));
        sys.stderr.write("\n".join(lines) + "\n");
    } except Exception as e {
        sys.stderr.write(f"[{tag}-PROBE-ERR] {e!r}" + "\n");
    }
}

def dump_member_miss(evaluator: any, obj_type: any, member: str, tag: str) {
    try {
        (prog, sh) = _progs(evaluator);
        lines = [
            f"[{tag}] pid={os.getpid()} member={member} obj={_rec(prog, sh, obj_type)}"
        ];
        if isinstance(obj_type, ClassType) and obj_type._shared is not None {
            for cls in (obj_type.shared.mro or []) {
                hit = "miss";
                try {
                    syms: list = [];
                    if cls.lookup_member_symbol(member, syms) {
                        hit = "HIT";
                    }
                } except Exception as e {
                    hit = f"err:{e!r}";
                }
                lines.append(f"[{tag}]   mro {hit} {_rec(prog, sh, cls)}");
            }
            for b in (obj_type.shared.base_classes or []) {
                lines.append(f"[{tag}]   base={_rec(prog, sh, b)}");
                if isinstance(b, ClassType) and b._shared is not None {
                    for bb in (b.shared.base_classes or []) {
                        lines.append(f"[{tag}]     base.base={_rec(prog, sh, bb)}");
                    }
                }
            }
        }
        lines.append(_tail(tag, prog, sh));
        sys.stderr.write("\n".join(lines) + "\n");
    } except Exception as e {
        sys.stderr.write(f"[{tag}-PROBE-ERR] {e!r}" + "\n");
    }
}

def _expr_head_node(expr: any) -> any {
    cur = expr;
    hops = 0;
    while cur is not None and hops < 12 {
        hops += 1;
        nxt = cur?.target;
        if nxt is None {
            break;
        }
        cur = nxt;
    }
    return cur;
}

def describe_expr(evaluator: any, expr: any, sh: any) -> str {
    prog = evaluator.program;
    head_node = _expr_head_node(expr);
    memo = expr?.type;
    parts = [f"expr={type(expr).__name__}", f"head_node={type(head_node).__name__}"];
    val = head_node?.value;
    if isinstance(val, str) {
        parts.append(f"name={val}");
    }
    memo_desc = type(memo).__name__;
    if isinstance(memo, UnknownType) {
        memo_desc = f"{memo_desc}[diag={memo.is_diagnosed},inc={memo.is_incomplete}]";
    }
    parts.append(f"memo={memo_desc}");
    sym = head_node?.sym;
    if sym is None {
        parts.append("sym=None");
        return " ".join(parts);
    }
    prov = type(sym.provider).__name__ if sym.provider is not None else "None";
    parts.append(
        f"sym_type={getattr(sym, 'sym_type', '?')} imported={getattr(
            sym, 'imported', '?'
        )} provider={prov}"
    );
    decl = sym?.decl;
    m = decl.find_parent_of_type(Module) if decl is not None else None;
    if m is None {
        parts.append("decl_mod=None");
    } else {
        mp = m.loc.mod_path if m.loc is not None else "";
        typed = prog.analysis.analyses_run.provides(m, "TypeOf");
        parts.append(
            f"decl_mod={os.path.basename(mp)} {_state(prog, sh, m)} typed={typed}"
        );
    }
    return " ".join(parts);
}

def _memo_desc(nd: any) -> str {
    memo = nd?.type;
    d = type(memo).__name__;
    if isinstance(memo, UnknownType) {
        d = f"{d}[diag={memo.is_diagnosed},inc={memo.is_incomplete}]";
    }
    return d;
}

def describe_rhs(evaluator: any, sym: any, sh: any) -> list[str] {
    import from jaclang.compiler.frontend.unitree { Assignment, AtomTrailer, FuncCall }
    prog = evaluator.program;
    decl = sym?.decl;
    asg = decl.find_parent_of_type(Assignment) if decl is not None else None;
    if asg is None {
        return ["  rhs=<no assignment>"];
    }
    out: list[str] = [];
    cur = asg.value;
    hops = 0;
    while cur is not None and hops < 12 {
        hops += 1;
        line = f"  rhs[{hops}] {type(cur).__name__}@{cur.loc.first_line}:{cur.loc.col_start} memo={_memo_desc(
            cur
        )}";
        if isinstance(cur, AtomTrailer) {
            line += f" right=<{describe_expr(evaluator, cur.right, sh)}>";
            out.append(line);
            cur = cur.target;
            continue;
        }
        if isinstance(cur, FuncCall) {
            out.append(line);
            cur = cur.target;
            continue;
        }
        line += f" head=<{describe_expr(evaluator, cur, sh)}>";
        out.append(line);
        hsym = cur?.sym;
        if hsym is not None {
            try {
                dsym = evaluator.resolve_to_definition_symbol(hsym);
                if dsym is not None and dsym is not hsym {
                    ddecl = dsym?.decl;
                    dm = ddecl.find_parent_of_type(Module)
                        if ddecl is not None
                        else None;
                    dprov = type(dsym.provider).__name__
                        if dsym.provider is not None
                        else "None";
                    dpath = os.path.basename(dm.loc.mod_path)
                        if dm is not None and dm.loc is not None
                        else "?";
                    dtyped = prog.analysis.analyses_run.provides(dm, "TypeOf")
                        if dm is not None
                        else "?";
                    out.append(
                        f"  rhs-def name={dsym.name} sym_type={getattr(
                            dsym, 'sym_type', '?'
                        )} provider={dprov} "
                        f"decl_type={_memo_desc(ddecl)} def_mod={dpath} {_state(
                            prog, sh, dm
                        )} typed={dtyped}"
                    );
                }
            } except Exception as e {
                out.append(f"  rhs-def <err {e!r}>");
            }
        }
        break;
    }
    return out;
}

def dump_unknown(evaluator: any, expr: any, tag: str) {
    try {
        (prog, sh) = _progs(evaluator);
        sys.stderr.write(
            f"[{tag}] pid={os.getpid()} {describe_expr(evaluator, expr, sh)}" + "\n"
        );
        sys.stderr.write(_tail(tag, prog, sh) + "\n");
        hsym = _expr_head_node(expr)?.sym;
        if hsym is not None
            and hsym.provider is None
            and not getattr(hsym, "imported", False) {
            for line in describe_rhs(evaluator, hsym, sh) {
                sys.stderr.write(f"[{tag}]{line}" + "\n");
            }
        }
    } except Exception as e {
        sys.stderr.write(f"[{tag}-PROBE-ERR] {e!r}" + "\n");
    }
}

def dump_host_contract(scope: any, host_type: any, name: str, methods: list) {
    tag = "E5110-DUMP";
    try {
        import from jaclang.runtime.runtime { JacRuntime }
        sh = JacRuntime.get_compiler().selfhost.program;
        lines = [
            f"[{tag}] pid={os.getpid()} missing={name} host={_rec(sh, sh, host_type)}",
            f"[{tag}]   methods_seen={methods}"
        ];
        for base in (scope?.base_classes or []) {
            bt = base?.type;
            rec = _rec(sh, sh, bt) if isinstance(bt, ClassType) else "";
            lines.append(
                f"[{tag}]   base_expr={type(base).__name__} "
                f"base.type={type(bt).__name__} {rec}"
            );
        }
        lines.append(f"[{tag}]   selfhost_hub={len(sh.mod.hub)}");
        sys.stderr.write("\n".join(lines) + "\n");
    } except Exception as e {
        sys.stderr.write(f"[{tag}-PROBE-ERR] {e!r}" + "\n");
    }
}
