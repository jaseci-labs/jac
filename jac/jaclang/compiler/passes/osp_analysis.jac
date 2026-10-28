glob OSP_ANY_TAGS: dict[str, int] = {
         "Node": -2,
         "Edge": -3,
         "Walker": -4,
         "Root": -5
     };

obj OspSlot {
    has owner: str,
        kind: str,
        ability: str,
        is_entry: bool,
        has_body: bool,
        trigger_names: list[str] = [];
}


obj OspModel {
    has arch_kind: dict[(str, str)] = {},
        tags: dict[(str, int)] = {},
        order: list[str] = [],
        order_index: dict[(str, int)] = {},
        isa: dict[(str, list[str])] = {},
        slots: list[OspSlot] = [],
        collisions: list[tuple[str, str]] = [],
        uses_construct: bool = False;

    def has_event_ability -> bool;
    def local_slots -> list[OspSlot];
    def has_local_ability -> bool;
    def local_index(name: str) -> int;
    def trigger_tags(slot: OspSlot) -> list[int];
    def entry_slots(owner: str) -> list[OspSlot];
    def exit_slots(owner: str) -> list[OspSlot];
}


def get_osp_model(
    module: uni.Module,
    archetypes: (list[uni.Archetype] | None) = None,
    context: (CodeContext | None) = None,
    native_names: bool = False
) -> OspModel;

obj OspAnalysis {
    static def head_name(nd: (uni.UniNode | None)) -> (str | None);
    static def flatten_trigger(nd: (uni.UniNode | None)) -> list[str];
    static def slot_triggers(
        ability: uni.Ability, native_names: bool = False
    ) -> list[str];

    static def native_slot_triggers(ability: uni.Ability) -> list[str];
    static def trigger_heads(nd: (uni.UniNode | None)) -> list[uni.UniNode];
    static def arch_slots(
        arch: uni.Archetype, native_names: bool = False
    ) -> list[OspSlot];

    static def arch_key(arch: uni.Archetype, native_names: bool) -> str;
    static def compute(
        module: uni.Module,
        archetypes: list[uni.Archetype],
        context: (CodeContext | None) = None,
        native_names: bool = False
    ) -> OspModel;

    static def _isa_closure(
        name: str, archs: dict[(str, uni.Archetype)], native_names: bool = False
    ) -> list[str];

    static def _uses_construct(
        module: uni.Module, context: (CodeContext | None)
    ) -> bool;
}
