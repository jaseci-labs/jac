import from uuid { UUID }

edge Member: any --> any {
    has level: int = 0;

    with entry {
        __jac_membership__: ClassVar[bool] = True;
    }
}

def principals -> dict[str, AccessLevel];

def forget_principals -> None;

def attach_owner(source: NodeAnchor) -> (UUID | None);

def set_access(
    target: (Archetype | Anchor),
    who: (str | UUID | Archetype | Anchor),
    level: (AccessLevel | int | str)
) -> None;

def clear_access(
    target: (Archetype | Anchor), who: (str | UUID | Archetype | Anchor)
) -> None;

def member_edge_level(
    edge_anchor: EdgeAnchor, held: dict[str, AccessLevel]
) -> AccessLevel;

def _members_in(of: NodeAnchor) -> list[EdgeAnchor];

def _member_links(src_ids: list[UUID]) -> list[tuple[UUID, UUID, int]];

def _who_id(who: (str | UUID | Archetype | Anchor)) -> UUID;

def _is_group(anchor: NodeAnchor) -> bool;

def _level_of(edge_anchor: EdgeAnchor) -> AccessLevel;

def _add_member_edge(member: NodeAnchor, group: NodeAnchor, level: AccessLevel);

def _take_subtree(group: NodeAnchor, old_owner: UUID);

def _ensure_group(anchor: NodeAnchor);

def _keep_an_admin(group: NodeAnchor, link: EdgeAnchor);
