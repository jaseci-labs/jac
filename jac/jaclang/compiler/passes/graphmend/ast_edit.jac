import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.roles { BodyRole, Kid }
import from jaclang.compiler.frontend.constant { GraphBreakKind, GraphMendHelper }
import type from jaclang.compiler.frontend.unitree { Ability, UniNode }

obj GraphMendFacts {
    has breaks: dict[(UniNode, GraphBreakKind)] = {},
        boundary: dict[(Ability, Ability)] = {},
        helpers: set[GraphMendHelper] = set(),
        noop: bool = False,
        wrapped_keys: set[str] = set(),
        covered_by: dict[(str, str)] = {};
}

def facts_for(nd: uni.UniNode) -> GraphMendFacts {
    mod: (uni.Module | None) = None;
    if isinstance(nd, uni.Module) {
        mod = nd;
    } else {
        mod = nd.find_parent_of_type(uni.Module);
    }
    if mod is None {
        return GraphMendFacts();
    }
    facts = mod.gen.graphmend_facts;
    if facts is None {
        facts = GraphMendFacts();
        mod.gen.graphmend_facts = facts;
    }
    return facts;
}

def gen_name(at: uni.UniNode, value: str, store: bool) -> uni.Name {
    anchor: any = at;
    nm = uni.Name.gen_stub_from_node(anchor, value);
    if store {
        nm.expr_ctx = uni.ExprCtx.STORE;
    }
    return nm;
}

def gen_string(at: uni.UniNode, value: str) -> uni.String {
    return uni.String(
        orig_src=at.loc.orig_src,
        name='STRING',
        value=value,
        line=at.loc.first_line,
        end_line=at.loc.last_line,
        col_start=at.loc.col_start,
        col_end=at.loc.col_end,
        pos_start=at.loc.pos_start,
        pos_end=at.loc.pos_end
    );
}

def gen_bool(at: uni.UniNode, value: bool) -> uni.Bool {
    return uni.Bool(
        orig_src=at.loc.orig_src,
        name='BOOL',
        value='True' if value else 'False',
        line=at.loc.first_line,
        end_line=at.loc.last_line,
        col_start=at.loc.col_start,
        col_end=at.loc.col_end,
        pos_start=at.loc.pos_start,
        pos_end=at.loc.pos_end
    );
}

def need_helper(at: uni.UniNode, helper: GraphMendHelper) {
    facts_for(at).helpers.add(helper);
    mod = at if isinstance(at, uni.Module) else at.find_parent_of_type(uni.Module);
    if mod is not None and helper.value not in mod.gen.graphmend_imports {
        mod.gen.graphmend_imports.append(helper.value);
    }
}

def torch_call(at: uni.UniNode, fname: str, args: list[uni.Expr]) -> uni.FuncCall {
    torch_nm = gen_name(at, 'torch', False);
    fn_nm = gen_name(at, fname, False);
    target = uni.AtomTrailer(
        target=torch_nm,
        right=fn_nm,
        is_attr=True,
        is_null_ok=False,
        kid=[torch_nm, fn_nm]
    );
    return uni.FuncCall(
        target=target, params=args, genai_call=None, kid=[target] + args
    );
}

def split_params(params: any) -> tuple[list[uni.Expr], list[uni.KWPair]] {
    pos: list[uni.Expr] = [];
    kws: list[uni.KWPair] = [];
    for p in (params or []) {
        if isinstance(p, uni.KWPair) {
            kws.append(p);
        } else {
            pos.append(p);
        }
    }
    return (pos, kws);
}

def split_params_keyed(params: any) -> tuple[list[uni.Expr], dict[str, uni.KWPair]] {
    (pos, kws) = split_params(params);
    keyed: dict[str, uni.KWPair] = {};
    for kw in kws {
        if kw.key is not None {
            keyed[kw.key.sym_name] = kw;
        }
    }
    return (pos, keyed);
}

def stmt_slot(
    at: uni.UniNode
) -> (tuple[uni.UniNode, uni.UniNode, list[uni.UniNode]] | None) {
    cur: (uni.UniNode | None) = at;
    while cur is not None {
        parent = cur.parent;
        if parent is None {
            return None;
        }
        holder: any = parent;
        body = holder?.body;
        if isinstance(body, list) {
            return (parent, cur, body)
                if ((cur in body) and (cur in [parent->:Kid:->]))
                else None;
        }
        cur = parent;
    }
    return None;
}

def _splice(parent: uni.UniNode, body: list[uni.UniNode], kids: list[uni.UniNode]) {
    parent._role_set(BodyRole, body);
    parent.set_kids(kids);
}

def insert_after(stmt: uni.UniNode, new_stmt: uni.UniNode) -> bool {
    slot = stmt_slot(stmt);
    if slot is None {
        return False;
    }
    (parent, anchor, body) = slot;
    kids = [parent->:Kid:->];
    i = body.index(anchor);
    j = kids.index(anchor);
    _splice(
        parent,
        list(body[:(i + 1)]) + [new_stmt] + list(body[(i + 1):]),
        list(kids[:(j + 1)]) + [new_stmt] + list(kids[(j + 1):])
    );
    return True;
}

def insert_before(stmt: uni.UniNode, new_stmt: uni.UniNode) -> bool {
    slot = stmt_slot(stmt);
    if slot is None {
        return False;
    }
    (parent, anchor, body) = slot;
    kids = [parent->:Kid:->];
    i = body.index(anchor);
    j = kids.index(anchor);
    _splice(
        parent,
        list(body[:i]) + [new_stmt] + list(body[i:]),
        list(kids[:j]) + [new_stmt] + list(kids[j:])
    );
    return True;
}

def append_stmt(owner: uni.UniNode, new_stmt: uni.UniNode) -> bool {
    holder: any = owner;
    body = holder?.body;
    if not isinstance(body, list) {
        return False;
    }
    kids = [owner->:Kid:->];
    last = body[-1] if body else None;
    if (last is not None) and (last in kids) {
        j = kids.index(last);
        kids = list(kids[:(j + 1)]) + [new_stmt] + list(kids[(j + 1):]);
    } else {
        kids = list(kids) + [new_stmt];
    }
    _splice(owner, list(body) + [new_stmt], kids);
    return True;
}

def replace_stmt(old: uni.UniNode, new_nodes: list[uni.UniNode]) -> bool {
    parent = old.parent;
    if parent is None {
        return False;
    }
    holder: any = parent;
    body = holder?.body;
    kids = [parent->:Kid:->];
    if (not isinstance(body, list)) or (old not in body) or (old not in kids) {
        return False;
    }
    i = body.index(old);
    j = kids.index(old);
    _splice(
        parent,
        list(body[:i]) + new_nodes + list(body[(i + 1):]),
        list(kids[:j]) + new_nodes + list(kids[(j + 1):])
    );
    return True;
}
