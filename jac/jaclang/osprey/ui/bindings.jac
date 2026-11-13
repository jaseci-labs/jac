obj Binding {
    has source_id: str,
        target_id: str,
        event_type: str;
}


obj BindingRegistry {
    has by_source: dict[str, list[Binding]] = {},
        by_target: dict[str, list[Binding]] = {};
}


obj DeliveryResult {
    has target_id: str,
        event_type: str,
        delivered: bool = True;
}


def binding_key(source_id: str, target_id: str, event_type: str) -> str;


def _validate_binding_ids(source_id: str, target_id: str);


def _binding_matches(
    binding: Binding, source_id: str, target_id: str, event_type: str,
) -> bool;


def _append_binding(registry: BindingRegistry, binding: Binding);


def _remove_binding(
    registry: BindingRegistry, source_id: str, target_id: str, event_type: str,
) -> bool;


def _binding_sorts_before(binding: Binding, anchor: Binding) -> bool;


def _sort_bindings_in_place(items: list[Binding]);


def subscribe(
    registry: BindingRegistry, source_id: str, target_id: str, event_type: str,
) -> bool;


def unsubscribe(
    registry: BindingRegistry, source_id: str, target_id: str, event_type: str,
) -> bool;


def unsubscribe_target(registry: BindingRegistry, target_id: str) -> int;


def clear_bindings(registry: BindingRegistry);


def binding_count(registry: BindingRegistry) -> int;


def is_empty(registry: BindingRegistry) -> bool;


def bindings_for_source(registry: BindingRegistry, source_id: str) -> list[Binding];


def bindings_for_target(registry: BindingRegistry, target_id: str) -> list[Binding];


def dump_bindings(registry: BindingRegistry) -> list[dict[str, str]];


def deliver(
    registry: BindingRegistry, source_id: str, event_type: str,
) -> list[DeliveryResult];


def find_orphan_bindings(
    registry: BindingRegistry, live_target_ids: set[str],
) -> list[Binding];
