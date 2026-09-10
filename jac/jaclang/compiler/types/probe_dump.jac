import os;
import sys;
import from jaclang.compiler.types.types { ClassType }
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
    return f"{state}[t={in_t},s={in_s}]";
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
