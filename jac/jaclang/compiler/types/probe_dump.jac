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

def _rec(prog: any, selfhost_prog: any, t: any) -> str {
    if not isinstance(t, ClassType) or t._shared is None {
        return f"<{type(t).__name__}>";
    }
    key = t.shared.canonical_key();
    site = "<nokey>";
    if key is not None {
        site = f"{os.path.basename(key[0])}:{key[1]}:{key[2]}";
    }
    m = _mod_of(t);
    state = "nomod";
    if m is not None {
        mp = m.loc.mod_path if m.loc is not None else "";
        found = prog.find_module(mp) if mp else None;
        if found is m {
            state = "live";
        } elif found is not None {
            state = "stale";
        } else {
            state = "gone";
        }
        in_t = "y" if mp in prog.mod.hub else "n";
        in_s = "y" if mp in selfhost_prog.mod.hub else "n";
        state = f"{state}[t={in_t},s={in_s}]";
    }
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

def dump_assign_fail(evaluator: any, src_type: any, dest_type: any, tag: str) {
    try {
        prog = evaluator.program;
        selfhost_prog = prog._get_compiler().selfhost.program;
        lines = [
            f"[{tag}] pid={os.getpid()} src={_rec(prog, selfhost_prog, src_type)}",
            f"[{tag}]   dest={_rec(prog, selfhost_prog, dest_type)}"
        ];
        if isinstance(src_type, ClassType) and src_type._shared is not None {
            for b in (src_type.shared.base_classes or []) {
                lines.append(f"[{tag}]   src.base={_rec(prog, selfhost_prog, b)}");
                if isinstance(b, ClassType) and b._shared is not None {
                    for bb in (b.shared.base_classes or []) {
                        lines.append(
                            f"[{tag}]     src.base.base={_rec(prog, selfhost_prog, bb)}"
                        );
                    }
                }
            }
        }
        te_state = "set" if selfhost_prog.type_evaluator is not None else "none";
        lines.append(
            f"[{tag}]   selfhost_te={te_state} "
            f"selfhost_hub={len(selfhost_prog.mod.hub)} "
            f"target_hub={len(prog.mod.hub)} "
            f"depth={prog.scratch.compile_depth}/{selfhost_prog.scratch.compile_depth}"
        );
        sys.stderr.write("\n".join(lines) + "\n");
    } except Exception as e {
        sys.stderr.write(f"[{tag}-PROBE-ERR] {e!r}" + "\n");
    }
}
