import from jaclang.jac0core { unitree as ut_mod }
import from jaclang.jac0core { constant as const_mod }
import from jaclang.jac0core.arena {
    SyntaxArena,
    TAG_BOOL,
    TAG_ENUM,
    TAG_INT,
    TAG_LIST,
    TAG_NODE,
    TAG_NONE,
    TAG_STR
}
import from jaclang.jac0core.arena_specs { SPECS }
import from jaclang.jac0core.unitree { Module, Source, UniNode }

glob _CLS_CACHE: dict[int, tuple] = {};


def _resolved_spec(kind: int) -> tuple {
    got = _CLS_CACHE.get(kind);
    if got is not None {
        return got;
    }
    (cls_name, params, token_family, has_kid) = SPECS[kind];
    cls = getattr(ut_mod, cls_name);
    enums: list = [];
    for p in params {
        ename = p[2];
        if ename {
            enums.append(getattr(const_mod, ename, None) or getattr(ut_mod, ename));
        } else {
            enums.append(None);
        }
    }
    resolved = (cls, params, tuple(enums), token_family, has_kid);
    _CLS_CACHE[kind] = resolved;
    return resolved;
}


def _deps_of(a: SyntaxArena, i: int) -> list[int] {
    deps = a.kid_ids(i);
    n = a.arg_ns[i];
    p = a.arg_los[i];
    s = 0;
    while s < n {
        tag = a.args[p];
        v = a.args[p + 1];
        if tag == TAG_NODE {
            deps.append(v);
        } elif tag == TAG_LIST {
            for d in a.seq_ids(v) {
                deps.append(d);
            }
        }
        p += 2;
        s += 1;
    }
    return deps;
}


def _decode_post(key: str, v: int) -> any {
    if key == "param_kind" {
        return ut_mod.ParamKind(v);
    }
    if key == "code_context" {
        return list(const_mod.CodeContext)[v];
    }
    raise ValueError(f"materialize: unknown post-set key {key}");
}


def materialize_module(a: SyntaxArena, source: Source) -> Module {
    built = materialize(a, source);
    if not isinstance(built, Module) {
        raise ValueError("arena root is not a Module");
    }
    return built;
}


def materialize(a: SyntaxArena, source: Source) -> (UniNode | None) {
    if a.root_id == 0 {
        return None;
    }
    posts_by_id: dict[int, list] = {};
    pi = 0;
    pn = len(a.posts);
    while pi < pn {
        posts_by_id.setdefault(a.posts[pi], []).append(
            (a.strtab[a.posts[pi + 1]], a.posts[pi + 2])
        );
        pi += 3;
    }

    objs: dict[int, any] = {};
    stack: list = [(a.root_id, False)];
    while stack {
        (i, expanded) = stack.pop();
        if i in objs {
            continue;
        }
        if not expanded {
            stack.append((i, True));
            for d in _deps_of(a, i) {
                if d != 0 and d not in objs {
                    stack.append((d, False));
                }
            }
            continue;
        }
        (cls, params, enums, token_family, has_kid) = _resolved_spec(a.kinds[i]);
        kwargs: dict[str, any] = {};
        p = a.arg_los[i];
        slot = 0;
        for (pspec, ecls) in zip(params, enums) {
            (pname, cat, _ename, has_default) = pspec;
            if cat == "SOURCE" {
                kwargs[pname] = source;
                continue;
            }
            tag = a.args[p + (slot * 2)];
            v = a.args[p + (slot * 2) + 1];
            slot += 1;
            if tag == TAG_NONE {
                if not has_default {
                    kwargs[pname] = None;
                }
            } elif tag == TAG_NODE {
                kwargs[pname] = objs[v];
            } elif tag == TAG_LIST {
                kwargs[pname] = [objs[k] for k in a.seq_ids(v)];
            } elif tag == TAG_STR {
                kwargs[pname] = a.strtab[v];
            } elif tag == TAG_INT {
                kwargs[pname] = v;
            } elif tag == TAG_BOOL {
                kwargs[pname] = v != 0;
            } elif tag == TAG_ENUM {
                kwargs[pname] = ecls(v);
            }
        }
        kid_ids = a.kid_ids(i);
        if has_kid {
            kwargs["kid"] = [objs[k] for k in kid_ids];
        }
        made = cls(**kwargs);
        if kid_ids and not has_kid {
            made.set_kids([objs[k] for k in kid_ids]);
        }
        for entry in posts_by_id.get(i, []) {
            (key, pv) = entry;
            setattr(made, key, _decode_post(key, pv));
        }
        objs[i] = made;
    }

    built = objs[a.root_id];
    if isinstance(built, Module) {
        node_list: list[UniNode] = [];
        seen: dict[int, bool] = {};
        walk: list[UniNode] = [built];
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
        built._in_mod_nodes = node_list;
    }
    return built;
}
