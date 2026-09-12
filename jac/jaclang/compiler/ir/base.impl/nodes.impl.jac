import from jaclang.compiler.ir.identity { RelationFamily }
impl UniNode.postinit -> None {
    import from jaclang.compiler.frontend.source_locations { CodeLocInfo }

    self.__sub_node_tab = None;
    self._ctx_parent = None;
    self._struct_frozen = False;
    self._in_mod_nodes = [];
    self.ct_pruned = False;
    if self?._role_shapes is None {
        self._role_shapes = None;
    }
    (first_tok, last_tok) = self.resolve_tok_range();
    self.loc = CodeLocInfo(first_tok, last_tok);
}

impl UniNode.walk_kids with TreeWalker entry {
    visit : 0 : [
        k
        for k in self.kid
        if k and not k.ct_pruned
    ];
}

impl UniNode._attach(
    child: UniNode, role: type[Role], check_only: bool = False
) -> None {
    if check_only {
        import from jaclang.compiler.ir.mutation { validate_connection }
        validate_connection(self, role, child);
        self.check_connection(child, RelationFamily.STRUCTURE);
    } else {
        self +>:role:+> child;
    }
}

impl UniNode._as_node_list(value: Sequence[UniNode]) -> list[UniNode] {
    return list(value);
}

impl UniNode._link(
    kid: Sequence[UniNode], roles: dict[type, UniNode | Sequence[UniNode] | None]
) -> None {
    import from jaclang.compiler.ir.syntax.edges { Kid }

    if not roles {
        for k in kid {
            if k is not None {
                self +>:Kid:+> k;
            }
        }
        return;
    }

    role_of: dict[int, type] = {};
    extra_roles: dict[int, list[type]] = {};
    if roles {
        shapes: dict[type, str] = self?._role_shapes or {};
        self._role_shapes = shapes;
        for (role, value) in roles.items() {
            if value is None {
                shapes[role] = "none";
            } elif isinstance(value, (list, tuple)) {
                shapes[role] = "many";
                vlist = self._as_node_list(value);
                for v in vlist {
                    if isinstance(v, UniNode) {
                        prev = role_of.get(id(v));
                        if prev is None {
                            role_of[id(v)] = role;
                        } elif prev is not role {
                            extra_roles.setdefault(id(v), []).append(role);
                        }
                    }
                }
            } elif isinstance(value, UniNode) {
                shapes[role] = "one";
                prev = role_of.get(id(value));
                if prev is None {
                    role_of[id(value)] = role;
                } elif prev is not role {
                    extra_roles.setdefault(id(value), []).append(role);
                }
            } else {
                shapes[role] = "none";
            }
        }
    }
    attached: set[int] = set();
    for k in kid {
        if k is not None {
            self +>:Kid:+> k;
            role = role_of.get(id(k));
            if role is not None and id(k) not in attached {
                self._attach(k, role);
                attached.add(id(k));
                if extra_roles {
                    for extra in extra_roles.get(id(k), []) {
                        self._attach(k, extra);
                    }
                }
            }
        }
    }
    for (role, value) in roles.items() {
        if isinstance(value, (list, tuple)) {
            vlist2 = self._as_node_list(value);
            for v in vlist2 {
                if isinstance(v, UniNode) and id(v) not in attached {
                    self._attach(v, role);
                    attached.add(id(v));
                    if extra_roles {
                        for extra in extra_roles.get(id(v), []) {
                            if extra is not role {
                                self._attach(v, extra);
                            }
                        }
                    }
                }
            }
        } elif isinstance(value, UniNode) and id(value) not in attached {
            one: UniNode = value;
            self._attach(one, role);
            attached.add(id(one));
            if extra_roles {
                for extra in extra_roles.get(id(one), []) {
                    if extra is not role {
                        self._attach(one, extra);
                    }
                }
            }
        }
    }
}

impl UniNode._children -> list[UniNode] {
    import from jaclang.compiler.ir.syntax.edges { Role }

    out: list[UniNode] = self.kid;
    seen: set[int] = {id(k) for k in out};
    for tgt in [self->:Role:->] {
        if id(tgt) not in seen {
            seen.add(id(tgt));
            out.append(tgt);
        }
    }
    return out;
}

impl UniNode.kid.getter -> list[UniNode] {
    import from jaclang.compiler.ir.syntax.edges { Kid }

    return [self->:Kid:->];
}

impl UniNode.parent.getter -> (UniNode | None) {
    import from jaclang.compiler.ir.syntax.edges { Role, Kid }

    try {
        return [self<-:Kid:<-][-1];
    } except IndexError {
        holders = [self<-:Role:<-];
        return holders[-1] if holders else self._ctx_parent;
    }
}

impl UniNode._role_shaped(
    role: type[Role], found: list[UniNode]
) -> UniNode | list[UniNode] | None {
    shape = (self?._role_shapes or {}).get(role, "none");
    if shape == "many" {
        return found;
    }
    if shape == "one" {
        return found[0] if found else None;
    }
    return None;
}

impl UniNode._assert_thawed -> None {
    if self.mutation_permit is not None {
        self.mutation_permit.require(RelationFamily.STRUCTURE);
    }
    if self._struct_frozen {
        raise RuntimeError(
            f"structural mutation of frozen node {type(self).__name__}; "
            "call thaw_structure() on the module first"
        );
    }
}

impl UniNode.freeze_structure -> None {
    stack: list[UniNode] = [self];
    seen: set[int] = set();
    while stack {
        nd = stack.pop();
        if id(nd) in seen {
            continue;
        }
        seen.add(id(nd));
        nd._struct_frozen = True;
        for tgt in nd._children() {
            if id(tgt) not in seen {
                stack.append(tgt);
            }
        }
    }
}

impl UniNode.thaw_structure -> None {
    stack: list[UniNode] = [self];
    seen: set[int] = set();
    while stack {
        nd = stack.pop();
        if id(nd) in seen {
            continue;
        }
        seen.add(id(nd));
        nd._struct_frozen = False;
        for tgt in nd._children() {
            if id(tgt) not in seen {
                stack.append(tgt);
            }
        }
    }
}

impl UniNode.structure_thawed -> StructureThaw {
    return StructureThaw(target=self);
}

impl StructureThaw.__enter__ -> StructureThaw {
    self.refreeze = self.target._struct_frozen;
    if self.refreeze {
        self.target.thaw_structure();
    }
    return self;
}

impl StructureThaw.__exit__(exc_type: any, exc: any, tb: any) -> bool {
    if self.refreeze {
        self.target.freeze_structure();
    }
    return False;
}

impl UniNode._role_clear(role: type[Role]) -> None {
    self.changed_relations(RelationFamily.STRUCTURE);
    del [edge self->:role:->];
}

impl UniNode._role_set(
    role: type[Role], value: UniNode | Sequence[UniNode] | None
) -> None {
    proposed: list[UniNode] = [];
    shape = "none";
    if isinstance(value, UniNode) {
        proposed.append(value);
        shape = "one";
    } elif value is not None {
        proposed = self._as_node_list(value);
        shape = "many";
    }
    for node in proposed {
        self._attach(node, role, check_only=True);
    }
    shapes: dict[type, str] = self?._role_shapes or {};
    self._role_shapes = shapes;
    self._role_clear(role);
    shapes[role] = shape;
    for node in proposed {
        self._attach(node, role);
    }
    self._invalidate_sub_node_tab();
}


impl UniNode._sub_node_tab.getter -> dict[(type, list[UniNode])] {
    if (self.__sub_node_tab is None) {
        self.__sub_node_tab = {};
        self._construct_sub_node_tab();
    }
    return self.__sub_node_tab;
}

impl UniNode._construct_sub_node_tab -> None {
    index = self.__sub_node_tab;
    assert index is not None;
    pending: list[tuple[UniNode, bool]] = [
        (child, False) for child in reversed(self.kid)
    ];
    active: set[int] = {id(self)};
    while pending {
        (node, visited) = pending.pop();
        if node.ct_pruned {
            continue;
        }
        if visited {
            active.remove(id(node));
            index.setdefault(type(node), []).append(node);
        } else {
            if id(node) in active {
                raise ValueError("Cycle in compiler syntax structure");
            }
            active.add(id(node));
            pending.append((node, True));
            pending.extend((child, False) for child in reversed(node.kid));
        }
    }
}


impl UniNode._invalidate_sub_node_tab -> None {
    cur: (UniNode | None) = self;
    while cur is not None {
        cur.__sub_node_tab = None;
        cur = cur.parent;
    }
}

impl UniNode.sym_tab.getter -> UniScopeNode {
    import from jaclang.compiler.ir.symbols.nodes { UniScopeNode }
    import from jaclang.compiler.ir.syntax.nodes { Module }

    nd: (UniNode | None) = self;

    while nd is not None {
        if isinstance(nd, UniScopeNode) {
            if isinstance(nd, Module) {
                return nd;
            }

            if nd.parent_scope is not None {
                return nd;
            }
        }
        nd = nd.parent;
    }
    raise ValueError("No scope found");
}

impl UniNode.add_kids_left(
    nodes: Sequence[UniNode],
    pos_update: bool = True,
    parent_update: bool = False,
    role: (type[Role] | None) = None
) -> UniNode {
    self.set_kids([*nodes, *self.kid], pos_update=pos_update);
    if role is not None {
        for n in nodes {
            self._attach(n, role);
        }
    }
    return self;
}

impl UniNode.add_kids_right(
    nodes: Sequence[UniNode],
    pos_update: bool = True,
    parent_update: bool = False,
    role: (type[Role] | None) = None
) -> UniNode {
    self.set_kids([*self.kid, *nodes], pos_update=pos_update);
    if role is not None {
        for n in nodes {
            self._attach(n, role);
        }
    }
    return self;
}

impl UniNode.insert_kids_at_pos(
    nodes: Sequence[UniNode],
    pos: int,
    pos_update: bool = True,
    role: (type[Role] | None) = None
) -> UniNode {
    cur = self.kid;
    self.set_kids([*cur[:pos], *nodes, *cur[pos:]], pos_update=pos_update);
    if role is not None {
        for n in nodes {
            self._attach(n, role);
        }
    }
    return self;
}

impl UniNode.set_kids(nodes: Sequence[UniNode], pos_update: bool = True) -> UniNode {
    import from jaclang.compiler.ir.syntax.edges { Kid }

    for node in nodes {
        if not isinstance(node, UniNode) {
            raise TypeError("Kid requires a compiler syntax node");
        }
    }
    self._assert_thawed();
    self.changed_relations(RelationFamily.STRUCTURE);
    del [edge self->:Kid:->];
    for n in nodes {
        if n is not None {
            self +>:Kid:+> n;
        }
    }
    self._invalidate_sub_node_tab();
    if pos_update {
        self.loc.update_token_range(*self.resolve_tok_range());
    }
    return self;
}

impl UniNode.replace_kid(old: UniNode, new: UniNode) -> UniNode {
    import from jaclang.compiler.ir.syntax.edges { Role }

    self._assert_thawed();
    roles: list[type] = [];
    for e in [edge self->:Role:->] {
        if getattr(e, "__jac__").target.archetype is old and `type(e) not in roles {
            roles.append(`type(e));
        }
    }
    for role in roles {
        targets = [self->:role:->];
        del [edge self->:role:->];
        for t in targets {
            self._attach(new if t is old else t, role);
        }
    }
    self.set_kids([new if k is old else k for k in self.kid], pos_update=False);
    return self;
}

impl UniNode.detached_copy -> UniNode {
    import copy;

    return copy.deepcopy(self);
}

impl UniNode.__deepcopy__(memo: dict) -> UniNode {
    import from jaclang.compiler.ir.identity { MutationPermit }

    import copy;

    dup = object.__new__(type(self));
    memo[id(self)] = dup;
    for (key, val) in self.__dict__.items() {
        if key == "__jac__" {
            continue;
        }
        if key == "mutation_permit" {
            permit = memo.get(id(val));
            dup.mutation_permit = permit
                if isinstance(permit, MutationPermit)
                else None;
            continue;
        }
        if key
            in (
                "_ctx_parent",
                "_type_sym_tab",
                "_type_cache",
                "_names_index",
                "_overload_index",
                "declaration_symbol",
                "ct_value"
            )
            or key.endswith("__sub_node_tab") {
            dup.__dict__[key] = None;
        } elif key in ("_struct_frozen", "_type_cache_ok") {
            dup.__dict__[key] = False;
        } elif key == "capture_symbols" {
            dup.__dict__[key] = [];
        } elif key == "implicit_rebinds" {
            dup.__dict__[key] = {};
        } elif key
            in ("_type_generation", "_names_generation", "_overload_generation") {
            dup.__dict__[key] = -1;
        } elif key == "orig_src" {
            dup.__dict__[key] = val;
        } elif val is None or isinstance(val, (str, int, float, bool, bytes, type)) {
            dup.__dict__[key] = val;
        } else {
            dup.__dict__[key] = copy.deepcopy(val, memo);
        }
    }
    import from jaclang.compiler.ir.syntax.cloning { copy_syntax_edges }
    copy_syntax_edges(self, dup, memo);
    return dup;
}

impl UniNode.set_parent(parent: UniNode) -> UniNode {
    self._ctx_parent = parent;
    return self;
}

impl UniNode.resolve_tok_range -> tuple[(Token, Token)] {
    import from jaclang.compiler.ir.syntax.nodes { Token }

    kids = self.kid;
    if kids {
        return (kids[0].loc.first_tok, kids[-1].loc.last_tok);
    } elif isinstance(self, Token) {
        return (self, self);
    } else {
        raise ValueError(f"Empty kid for Token {type(self).__name__}");
    }
}

impl UniNode.gen_token(name: Tok, value: (str | None) = None) -> Token {
    import from jaclang.compiler.ir.syntax.nodes { Token }
    import from jaclang.compiler.ir.enums { DELIM_MAP }

    import from jaclang.compiler.ir.enums { TOKEN_MAP }
    if value is None {
        value = DELIM_MAP[name]
            if (name in DELIM_MAP)
            else TOKEN_MAP.get(name.value, name.value);
    }
    return Token(
        name=name,
        value=value,
        orig_src=self.loc.orig_src,
        col_start=self.loc.col_start,
        col_end=0,
        line=self.loc.first_line,
        end_line=self.loc.last_line,
        pos_start=0,
        pos_end=0
    );
}


impl UniNode.codespace -> CodeContext {
    import from jaclang.compiler.ir.placement.nodes { ContextAwareNode }
    import from jaclang.compiler.ir.syntax.nodes { Module }
    import from jaclang.compiler.ir.enums { CodeContext }

    if isinstance(self, ContextAwareNode) {
        if (self.code_context == CodeContext.CLIENT) {
            return CodeContext.CLIENT;
        }
        if (self.code_context == CodeContext.NATIVE) {
            return CodeContext.NATIVE;
        }
    }
    nd: (UniNode | None) = self.parent;
    while (nd is not None) {
        if isinstance(nd, ContextAwareNode) {
            context = nd.code_context;
            if (context == CodeContext.CLIENT) {
                return CodeContext.CLIENT;
            }
            if (context == CodeContext.NATIVE) {
                return CodeContext.NATIVE;
            }
        }
        if isinstance(nd, Module) {
            if nd.decided_codespace == CodeContext.NATIVE.value {
                return CodeContext.NATIVE;
            }
            if nd.decided_codespace == CodeContext.CLIENT.value {
                return CodeContext.CLIENT;
            }
            return CodeContext.SERVER;
        }
        nd = nd.parent;
    }
    return CodeContext.SERVER;
}

impl UniNode.in_client_context -> bool {
    import from jaclang.compiler.ir.enums { CodeContext }

    return self.codespace() == CodeContext.CLIENT;
}

impl UniNode.in_native_context -> bool {
    import from jaclang.compiler.ir.enums { CodeContext }

    return self.codespace() == CodeContext.NATIVE;
}

impl UniNode.flatten -> list[UniNode] {
    ret: list[UniNode] = [self];
    for k in self.kid {
        if k.ct_pruned {
            continue;
        }
        ret += k.flatten();
    }
    return ret;
}
