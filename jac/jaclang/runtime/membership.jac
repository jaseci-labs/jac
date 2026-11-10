import from uuid { UUID }

edge Member: any --> any {
    has level: int = 0;

    with entry {
        __jac_membership__: ClassVar[bool] = True;
    }

    def who -> str;
}

def principals -> dict[str, AccessLevel];

def forget_principals -> None;

def inherit_access(source: NodeAnchor, link: EdgeAnchor, target: NodeAnchor) -> None;

def owned_by(owner: UUID, limit: int = 20) -> list[UUID];

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

def _saved_and_pending(
    sql: str, params: dict[str, any], keep: Callable[[Anchor], bool]
) -> tuple[list[tuple[any, ...]], list[Anchor]];

glob MEMBER_EDGES_SQL = """
    SELECT e.id, e.src, e.dst, COALESCE((e.props->'archetype'->>'level')::int, 0)
      FROM anchors e
     WHERE e.kind = 'EdgeAnchor' AND e.arch_type = 'Member'
       AND e.arch_module = 'jaclang.runtime.membership'
       AND e.src = ANY(CAST(:ids AS uuid[]))
""",
     OWNED_SQL = """
    SELECT id FROM anchors
     WHERE root_id = CAST(:owner AS uuid) AND id <> CAST(:owner AS uuid)
       AND NOT (kind = 'EdgeAnchor' AND arch_type = 'Member'
                AND arch_module = 'jaclang.runtime.membership')
     LIMIT :lim
""";

def _who_id(who: (str | UUID | Archetype | Anchor)) -> UUID;

def _is_group(anchor: NodeAnchor) -> bool;

def _level_of(edge_anchor: EdgeAnchor) -> AccessLevel;

def _add_member_edge(member: NodeAnchor, group: NodeAnchor, level: AccessLevel);

def _labels_of(anchor: Anchor) -> dict[str, AccessLevel];

def _add_labels(anchor: Anchor, labels: dict[str, AccessLevel]);

def _label_subtree(share: NodeAnchor);

def _ensure_group(anchor: NodeAnchor);

def _keep_an_admin(group: NodeAnchor, link: EdgeAnchor);
