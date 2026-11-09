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
    return anchor.id is not None and anchor.`root == anchor.id;
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

impl _take_subtree(group: NodeAnchor, old_owner: UUID) {
    jctx = JacRuntimeInterface.get_context();
    seen: set[UUID] = {group.ensure_id()};
    stack: list[NodeAnchor] = [group];
    while stack {
        cur = stack.pop();
        sv_register_hydrated(cur, fetch_stubs=True);
        for e in sv_live_edges(cur, EdgeDir.OUT.value, None, True) {
            if not isinstance(e, EdgeAnchor) or isinstance(e.archetype, Member) {
                continue;
            }
            if e.`root == old_owner {
                e.`root = group.id;
                jctx.mem.put(e);
            }
            tgt = jctx.mem.get(e.target.id) if e.target.id is not None else None;
            if not isinstance(tgt, NodeAnchor) or tgt.id in seen {
                continue;
            }
            if tgt.`root != old_owner or isinstance(tgt.archetype, Root) {
                continue;
            }
            seen.add(tgt.ensure_id());
            tgt.`root = group.id;
            jctx.mem.put(tgt);
            stack.append(tgt);
        }
    }
}

impl _ensure_group(anchor: NodeAnchor) {
    if _is_group(anchor) {
        return;
    }
    jctx = JacRuntimeInterface.get_context();
    old_owner = anchor.`root;
    if old_owner is None or isinstance(anchor.archetype, Root) {
        anchor.`root = anchor.id;
        jctx.mem.put(anchor);
        return;
    }

    parent = jctx.mem.get(old_owner);
    if isinstance(parent, NodeAnchor) {
        _add_member_edge(parent, anchor, AccessLevel.ADMIN);
    }
    anchor.`root = anchor.id;
    jctx.mem.put(anchor);
    _take_subtree(anchor, old_owner);
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

impl attach_owner(source: NodeAnchor) -> (UUID | None) {
    if not source.persistent or source.`root is None {
        return None;
    }
    jroot = JacRuntimeInterface.get_context().user_root;
    if jroot is None or source.`root == jroot.id {
        return None;
    }
    level = principals().get(str(source.`root));
    if level is None or level.value < AccessLevel.WRITE.value {
        return None;
    }
    return source.`root;
}

impl member_edge_level(
    edge_anchor: EdgeAnchor, held: dict[str, AccessLevel]
) -> AccessLevel {
    level = held.get(str(edge_anchor.target.id));
    if level == AccessLevel.ADMIN {
        return AccessLevel.ADMIN;
    }
    if level is not None and level.value > AccessLevel.NO_ACCESS.value {
        return AccessLevel.READ;
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
    held = JacRuntimeInterface.check_access_level(anchor);
    if held != AccessLevel.ADMIN {
        raise PermissionError(
            f"setting access on {type(anchor.archetype).__name__}[{anchor.id}] "
            f"needs ADMIN; you have {held.name}"
        );
    }
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
        held = JacRuntimeInterface.check_access_level(anchor);
        if held != AccessLevel.ADMIN {
            raise PermissionError(
                f"clearing access on {type(anchor.archetype).__name__}[{anchor.id}] "
                f"needs ADMIN; you have {held.name}"
            );
        }
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
