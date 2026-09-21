import from contextvars { ContextVar }
import from jaclang.runtime.object_model { MISSING }
import from logging { getLogger }
import from queue { Queue }
import from typing { cast, Generator, AsyncGenerator }
import from uuid { UUID }

import from jaclang.runtime.archetype { NodeAnchor, PermissionDenied, Root }
import from jaclang.runtime.constants { Constants as Con }
import from jaclang.runtime.memory { Memory }

glob __all__ = ['ExecutionContext'],
     logger = getLogger(__name__);

obj CallState {
    has reports: Queue = Queue(),
        _sentinel: object = object();
}

obj ExecutionContext {
    has mem: Memory postinit,
        reports: list[any] = [],
        diagnostics: list[PermissionDenied] = [],
        pending_effects: list[Callable] = [],
        read_versions: dict[UUID, int] = {},
        custom: any = MISSING,
        call_state: ContextVar[CallState] = ContextVar('call_state'),
        base_path_dir: (str | None) = None,
        full_target_path: (str | None) = None,
        _parent: (ExecutionContext | None) = None,
        _own_session: bool = False,
        _system_root: (NodeAnchor | None) = None,
        _user_root: (NodeAnchor | None) = None,
        _entry_node: (NodeAnchor | None) = None;

    def postinit -> None;
    static async def for_target(
        target: object, parent: ExecutionContext, user_root_id: str
    ) -> ExecutionContext {
        import from jaclang.runtime.prepared { application_of }
        application = application_of(target);
        if application is None
            or not parent.full_target_path
            or application.entry == parent.full_target_path {
            context = ExecutionContext(_parent=parent);
        } else {
            context = ExecutionContext(
                _parent=parent, _own_session=True, full_target_path=application.entry
            );
        }
        try {
            await context.aset_user_root(user_root_id);
        } except BaseException {
            context.mem.abort();
            context.close();
            raise;
        }
        return context;
    }

    has system_root: NodeAnchor { getter; }
    has user_root: NodeAnchor { getter; }
    has entry_node: NodeAnchor { getter; }

    def _resolve_roots -> None;
    def _get_anchor(anchor_id: str) -> NodeAnchor;
    def set_user_root(root_id: str) -> None;
    def set_entry_node(entry_node: (str | None)) -> None;
    def close -> None;
    async def bind_stream(value: any) -> any;
    def on_commit(callback: Callable) -> None;
    def run_pending_effects -> None;
    def note_traversal_reads(origins: list[NodeAnchor]) -> None;
    def get_root -> Root;
    async def _aget_anchor(anchor_id: str) -> NodeAnchor;
    async def aset_user_root(root_id: str) -> None;
}
