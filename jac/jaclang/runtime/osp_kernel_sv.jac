import inspect;
import from contextvars { ContextVar }
import from types { UnionType }
import from typing { cast }

obj _ContextStack {
    has _var: any postinit;

    def postinit;
    def _list -> list[any];
    def append(x: any);
    def pop -> any;
    def __getitem__(k: any) -> any;
    def __bool__ -> bool;
    def __len__ -> int;
}

with entry {
    _kernel.DEFAULT.stack = cast(list[OspWalkScope], _ContextStack());
}

def isolate_request_walk_stack;

glob _desc_of_cls: dict[(any, OspWalkerDesc)] = {};

def _trigger_members(trig: any) -> list[type];

def _slots_from(funcs: list[ObjectSpatialFunction]) -> list[OspSlot];

def _mro_funcs(cls: any, attr: str) -> list[any];

def desc_for(cls: any) -> OspWalkerDesc;

def _sv_tag_of(handle: any) -> int;

def _sv_is_a(tag: int, base: int) -> bool;

glob _ndesc_of_cls: dict[type, OspNodeDesc] = {};

def _sv_node_desc(tag: int) -> OspNodeDesc;

def _sv_settle(scope: OspWalkScope) -> bool;

def _sv_on_complete(scope: OspWalkScope, ok: bool);

def _sv_on_complete_uncommitted(scope: OspWalkScope, ok: bool);

def make_sv_runtime(commit: bool = True) -> OspRuntime;

async def osp_spawn_async(
    rt: OspRuntime, wlk: any, wdesc: OspWalkerDesc, starts: list[any]
) -> any;
