import from uuid { UUID }

impl _members_in(of: NodeAnchor) -> list[EdgeAnchor] {
    sv_register_hydrated(of, fetch_stubs=True);
    return [
        e
        for e in sv_live_edges(of, EdgeDir.IN.value, Member, True)
        if isinstance(e, EdgeAnchor)
    ];
}

impl _who_id(who: (str | UUID | Archetype | Anchor)) -> UUID {
    if isinstance(who, UUID) {
        return who;
    }
    if isinstance(who, str) {
        return UUID(who);
    }
    if isinstance(who, Archetype) {
        return who.__jac__.ensure_id();
    }
    if isinstance(who, Anchor) {
        return who.ensure_id();
    }
    raise TypeError(
        f"who must be a root id, a root or a group, not {type(who).__name__}"
    );
}

impl _is_group(anchor: NodeAnchor) -> bool {
    if anchor.id is None {
        return False;
    }
    return anchor.`root == anchor.id or str(anchor.id) in _labels_of(anchor);
}

impl _labels_of(anchor: Anchor) -> dict[str, AccessLevel] {
    perm = anchor.access;
    if perm is None {
        return {};
    }
    return {
        k: v
        for (k, v) in perm.groups.anchors.items()
        if v == AccessLevel.ADMIN
    };
}

impl _add_labels(anchor: Anchor, labels: dict[str, AccessLevel]) {
    if not labels {
        return;
    }
    named = anchor.own_access().groups.anchors;
    for (k, v) in labels.items() {
        named[k] = v;
    }
    JacRuntimeInterface.get_context().mem.put(anchor);
}

impl _level_of(edge_anchor: EdgeAnchor) -> AccessLevel {
    arch: any = edge_anchor.archetype;
    return access_level_cast(arch.level);
}

impl _add_member_edge(member: NodeAnchor, group: NodeAnchor, level: AccessLevel) {
    jctx = JacRuntimeInterface.get_context();
    made = JacRuntimeInterface.heavy_edge(
        member, group, Member(level=level.value), False, None
    );
    eanch = made.__jac__;
    eanch.`root = group.id;
    jctx.mem.put(eanch);
    forget_principals();
}

impl _label_subtree(share: NodeAnchor) {
    jctx = JacRuntimeInterface.get_context();
    label = {str(share.ensure_id()): AccessLevel.ADMIN};
    owner = share.`root;
    _add_labels(share, label);
    seen: set[UUID] = {share.ensure_id()};
    stack: list[NodeAnchor] = [share];
    while stack {
        cur = stack.pop();
        sv_register_hydrated(cur, fetch_stubs=True);
        for e in sv_live_edges(cur, EdgeDir.OUT.value, None, True) {
            if not isinstance(e, EdgeAnchor) or isinstance(e.archetype, Member) {
                continue;
            }
            if e.`root == owner {
                _add_labels(e, label);
            }
            tgt = jctx.mem.get(e.target.id) if e.target.id is not None else None;
            if not isinstance(tgt, NodeAnchor) or tgt.id in seen {
                continue;
            }
            if tgt.`root != owner
                or tgt.`root == tgt.id
                or isinstance(tgt.archetype, Root) {
                continue;
            }
            seen.add(tgt.ensure_id());
            _add_labels(tgt, label);
            stack.append(tgt);
        }
    }
}

impl _ensure_group(anchor: NodeAnchor) {
    if _is_group(anchor) {
        return;
    }
    jctx = JacRuntimeInterface.get_context();
    if anchor.`root is None or isinstance(anchor.archetype, Root) {
        anchor.`root = anchor.id;
        jctx.mem.put(anchor);
        return;
    }
    owner = jctx.mem.get(anchor.`root);
    if isinstance(owner, NodeAnchor) {
        _add_member_edge(owner, anchor, AccessLevel.ADMIN);
    }
    _label_subtree(anchor);
}

impl _keep_an_admin(group: NodeAnchor, link: EdgeAnchor) {
    if _level_of(link) != AccessLevel.ADMIN {
        return;
    }
    for other in _members_in(group) {
        if other is not link and _level_of(other) == AccessLevel.ADMIN {
            return;
        }
    }
    raise PermissionError(
        f"{type(group.archetype).__name__}[{group.id}] would have no admin; "
        'give someone else ADMIN first'
    );
}

impl principals -> dict[str, AccessLevel] {
    jctx = JacRuntimeInterface.get_context();
    jroot = jctx.user_root;
    if jroot is None {
        return {};
    }
    cached = jctx._principals;
    if cached is not None and cached[0] == jroot.id {
        known: dict[str, AccessLevel] = cached[1];
        return known;
    }
    held: dict[str, AccessLevel] = {str(jroot.id): AccessLevel.ADMIN};
    blocked: set[str] = set();
    frontier: dict[UUID, AccessLevel] = {jroot.ensure_id(): AccessLevel.ADMIN};
    while frontier {
        reached: dict[UUID, AccessLevel] = {};
        for (src, dst, raw) in _member_links(list(frontier.keys())) {
            key = str(dst);
            level = access_level_cast(raw);
            if level == AccessLevel.NO_ACCESS {
                blocked.add(key);
                continue;
            }
            reach = frontier[src];
            capped = level if level.value < reach.value else reach;
            if capped.value > held.get(key, AccessLevel.NO_ACCESS).value {
                held[key] = capped;
                reached[dst] = capped;
            }
        }
        frontier = reached;
    }
    for key in blocked {
        if held.get(key) != AccessLevel.ADMIN {
            held[key] = AccessLevel.NO_ACCESS;
        }
    }
    jctx._principals = (jroot.ensure_id(), held);
    return held;
}

impl _member_links(src_ids: list[UUID]) -> list[tuple[UUID, UUID, int]] {
    mem = JacRuntimeInterface.get_context().mem;
    wanted = set(src_ids);
    links: dict[UUID, tuple[UUID, UUID, int]] = {};
    store = mem.store;
    if store is not None {
        mem.read_barrier();
        for (eid, src, dst, level) in store.member_edges(src_ids) {
            if eid not in mem._deleted {
                links[eid] = (src, dst, level);
            }
        }
    }

    pending = list(mem._dirty.keys())
        if store is not None
        else list(mem.__mem__.keys());
    for aid in pending {
        e = mem.__mem__.get(aid);
        if not isinstance(e, EdgeAnchor)
            or not isinstance(e.archetype, Member)
            or e.destroyed {
            continue;
        }
        if e.source.id in wanted and e.target.id is not None {
            arch: any = e.archetype;
            links[aid] = (e.source.id, e.target.id, int(arch.level));
        }
    }
    return list(links.values());
}

impl forget_principals -> None {
    jctx = JacRuntimeInterface.peek_context();
    if jctx is not None {
        jctx._principals = None;
    }
}

impl inherit_access(source: NodeAnchor, link: EdgeAnchor, target: NodeAnchor) -> None {
    if not source.persistent {
        return;
    }
    jctx = JacRuntimeInterface.get_context();
    jroot = jctx.user_root;
    if jroot is None {
        return;
    }
    fresh = target.hash == 0 and target.`root == jroot.id;
    labels = _labels_of(source);
    _add_labels(link, labels);
    if fresh {
        _add_labels(target, labels);
    }
    if source.`root is None or source.`root == jroot.id {
        return;
    }
    held = principals();
    best = max(
        [
            held.get(k, AccessLevel.NO_ACCESS).value
            for k in [str(source.`root), *labels.keys()]
        ]
    );
    if best < AccessLevel.WRITE.value {
        return;
    }
    link.`root = source.`root;
    jctx.mem.put(link);
    if fresh {
        target.`root = source.`root;
        jctx.mem.put(target);
    }
}

impl owned_by(owner: UUID, limit: int = 20) -> list[UUID] {
    mem = JacRuntimeInterface.get_context().mem;
    found: set[UUID] = set();
    if mem.store is not None {
        mem.read_barrier();
        found.update(mem.store.owned_ids(owner, limit + len(mem._deleted)));
        found = {
            i
            for i in found
            if i not in mem._deleted
        };
    }
    for (aid, a) in list(mem.__mem__.items()) {
        if isinstance(a, Anchor)
            and a.`root == owner
            and aid != owner
            and not a.destroyed
            and not (isinstance(a, EdgeAnchor) and isinstance(a.archetype, Member)) {
            found.add(aid);
        }
    }
    return sorted(found, key=str)[:limit];
}

impl member_edge_level(
    edge_anchor: EdgeAnchor, held: dict[str, AccessLevel]
) -> AccessLevel {
    if held.get(str(edge_anchor.target.id)) == AccessLevel.ADMIN {
        return AccessLevel.ADMIN;
    }
    if str(edge_anchor.source.id) in held {
        return AccessLevel.READ;
    }
    return AccessLevel.NO_ACCESS;
}

impl set_access(
    target: (Archetype | Anchor),
    who: (str | UUID | Archetype | Anchor),
    level: (AccessLevel | int | str)
) -> None {
    (anchor, jctx) = JacAccessValidation._resolve_anchor(
        target if isinstance(target, Archetype) else target.archetype
    );
    if not isinstance(anchor, NodeAnchor) {
        raise TypeError("set_access takes a node; edges follow the nodes they join");
    }
    wanted = access_level_cast(level);
    if not anchor.persistent {
        JacRuntimeInterface.save(anchor);
    }
    JacAccessValidation._require_admin(anchor);
    who_id = _who_id(who);
    if who_id == anchor.id {
        raise ValueError("a node cannot be a member of itself");
    }
    sys = jctx.system_root;
    if (sys is not None and who_id == sys.id)
        or who_id == JacRuntime.shared_root_id() {
        raise ValueError("the guest, shared and system roots cannot be members");
    }
    member = jctx.mem.get(who_id);
    if not isinstance(member, NodeAnchor)
        or not (isinstance(member.archetype, Root) or _is_group(member)) {
        raise ValueError(f"{who_id} is not a root or a group");
    }
    _ensure_group(anchor);
    for e in _members_in(anchor) {
        if e.source.id == who_id {
            if _level_of(e) != wanted {
                if wanted != AccessLevel.ADMIN {
                    _keep_an_admin(anchor, e);
                }
                arch: any = e.archetype;
                arch.level = wanted.value;
            }
            forget_principals();
            return;
        }
    }
    _add_member_edge(member, anchor, wanted);
}

impl clear_access(
    target: (Archetype | Anchor), who: (str | UUID | Archetype | Anchor)
) -> None {
    (anchor, jctx) = JacAccessValidation._resolve_anchor(
        target if isinstance(target, Archetype) else target.archetype
    );
    who_id = _who_id(who);
    jroot = jctx.user_root;
    leaving = jroot is not None and jroot.id == who_id;
    if not leaving {
        JacAccessValidation._require_admin(anchor);
    }
    key = str(who_id);
    perm = anchor.access;
    if not leaving
        and perm is not None
        and (key in perm.roots.anchors or key in perm.groups.anchors) {
        perm.roots.anchors.pop(key, None);
        perm.groups.anchors.pop(key, None);
        jctx.mem.put(anchor);
    }
    if isinstance(anchor, NodeAnchor) and _is_group(anchor) {
        for e in _members_in(anchor) {
            if e.source.id == who_id {
                _keep_an_admin(anchor, e);
                JacRuntimeInterface.drop_anchor(e);
            }
        }
    }
    forget_principals();
}

impl Member.who -> str {
    return str(self.__jac__.source.id);
}
