glob UNTYPED: int = -1;

obj OspSlot {
    has trig_tag: int,
        fn: Callable[([any, any], any)];
}

obj OspPlan {
    has ctag: int,
        w_entry: list[OspSlot],
        n_entry_u: list[OspSlot],
        n_entry_t: list[OspSlot],
        n_exit_t: list[OspSlot],
        n_exit_u: list[OspSlot],
        w_exit: list[OspSlot];
}

obj OspWalkerDesc {
    has type_tag: int,
        `entry: list[OspSlot],
        `exit: list[OspSlot],
        plans: (dict[int, OspPlan] | None) = None;
}

obj OspNodeDesc {
    has type_tag: int,
        `entry: list[OspSlot],
        `exit: list[OspSlot];
}

obj OspFrame {
    has loc: int,
        phase: int = 0,
        band: int = 0,
        idx: int = 0,
        budget: int = 0,
        plan: (OspPlan | None) = None;
}

obj OspWalkScope {
    has wlk: any,
        path: list[int],
        next: list[int],
        front: list[int],
        ignores: list[int],
        reports: list[any],
        disengaged: bool = False,
        next_head: int = 0,
        nested: bool = False,
        fenced: bool = False,
        pending_fence: int = 0,
        skip_node: bool = False,
        stage: int = 0,
        sidx: int = 0,
        frames: (list[OspFrame] | None) = None,
        cur_a: any = None,
        cur_b: any = None,
        held: list[int] = [];
}

obj OspRuntime {
    has tag_of: Callable[([any], int)],
        is_a: Callable[([int, int], bool)],
        node_desc: Callable[([int], OspNodeDesc)],
        on_complete: Callable[([OspWalkScope, bool], None)];
}

glob _descs: dict[int, OspNodeDesc] = {};

def osp_register_desc(tag: int, desc: OspNodeDesc);

def osp_has_desc(tag: int) -> bool;

def osp_node_desc(tag: int) -> OspNodeDesc;

def _new_plans -> dict[int, OspPlan];

def _plan_for(
    rt: OspRuntime, wdesc: OspWalkerDesc, wtag: int, ndesc: OspNodeDesc, ctag: int
) -> OspPlan;

def _dequeue(scope: OspWalkScope) -> (int | None);

obj OspEngine {
    has stack: list[OspWalkScope],
        pin_refs: bool = False,
        acquired: list[int] = [],
        released: list[int] = [];

    def scope_of(wlk: any) -> (OspWalkScope | None);
    def current -> (OspWalkScope | None);
    def `visit(targets: list[int], insert_loc: int = -1) -> bool;
    def forget(target: int);
    def `disengage;
    def skip_rest;
    def `report(val: any);
    def begin(wlk: any, starts: list[int]) -> OspWalkScope;
    def finish(scope: OspWalkScope, ok: bool, rt: OspRuntime);
    def next_slot(
        rt: OspRuntime, scope: OspWalkScope, wdesc: OspWalkerDesc, run: bool = False
    ) -> (OspSlot | None);

    def `spawn(
        rt: OspRuntime, wlk: any, wdesc: OspWalkerDesc, starts: list[int]
    ) -> any;
}

glob DEFAULT: OspEngine = OspEngine(stack=[]);

def scope_of(wlk: any) -> (OspWalkScope | None);

def _current_scope -> (OspWalkScope | None);

def osp_visit(targets: list[int], insert_loc: int = -1) -> bool;

def osp_kernel_pin_refs;

def osp_kernel_pending -> int;

def osp_take_acquired -> list[int];

def osp_take_released -> list[int];

def osp_forget(target: int);

def osp_forget_all(targets: list[int]);

def osp_disengage;

def osp_skip_rest;

def osp_report(val: any);

def osp_spawn(
    rt: OspRuntime, wlk: any, wdesc: OspWalkerDesc, starts: list[int]
) -> any;
