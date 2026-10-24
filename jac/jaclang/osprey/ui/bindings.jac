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

impl binding_key(source_id: str, target_id: str, event_type: str) -> str {
    return source_id + "\x1f" + target_id + "\x1f" + event_type;
}


impl _validate_binding_ids(source_id: str, target_id: str) {
    if not source_id {
        raise ValueError("source_id must not be empty");
    }
    if not target_id {
        raise ValueError("target_id must not be empty");
    }
}


impl _binding_matches(
    binding: Binding, source_id: str, target_id: str, event_type: str,
) -> bool {
    return (
        binding.source_id == source_id
        and binding.target_id == target_id
        and binding.event_type == event_type
    );
}


impl _append_binding(registry: BindingRegistry, binding: Binding) {
    if binding.source_id not in registry.by_source {
        registry.by_source[binding.source_id] = [];
    }
    registry.by_source[binding.source_id].append(binding);
    if binding.target_id not in registry.by_target {
        registry.by_target[binding.target_id] = [];
    }
    registry.by_target[binding.target_id].append(binding);
}


impl _remove_binding(
    registry: BindingRegistry, source_id: str, target_id: str, event_type: str,
) -> bool {
    source_list = registry.by_source.get(source_id, []);
    kept_source: list[Binding] = [];
    removed = False;
    for binding in source_list {
        if (
            not removed and _binding_matches(binding, source_id, target_id, event_type)
        ) {
            removed = True;
        } else {
            kept_source.append(binding);
        }
    }
    if not removed {
        return False;
    }
    if kept_source {
        registry.by_source[source_id] = kept_source;
    } elif source_id in registry.by_source {
        del registry.by_source[source_id];
    }

    target_list = registry.by_target.get(target_id, []);
    kept_target: list[Binding] = [];
    for binding in target_list {
        if _binding_matches(binding, source_id, target_id, event_type) {
            continue;
        }
        kept_target.append(binding);
    }
    if kept_target {
        registry.by_target[target_id] = kept_target;
    } elif target_id in registry.by_target {
        del registry.by_target[target_id];
    }
    return True;
}


impl _binding_sorts_before(binding: Binding, anchor: Binding) -> bool {
    if binding.source_id != anchor.source_id {
        return binding.source_id < anchor.source_id;
    }
    if binding.target_id != anchor.target_id {
        return binding.target_id < anchor.target_id;
    }
    return binding.event_type < anchor.event_type;
}


impl _sort_bindings_in_place(items: list[Binding]) {
    i: int = 1;
    while i < len(items) {
        cur = items[i];
        j: int = i - 1;
        while j >= 0 and _binding_sorts_before(cur, items[j]) {
            items[j + 1] = items[j];
            j -= 1;
        }
        items[j + 1] = cur;
        i += 1;
    }
}


impl subscribe(
    registry: BindingRegistry, source_id: str, target_id: str, event_type: str,
) -> bool {
    _validate_binding_ids(source_id, target_id);
    for binding in registry.by_source.get(source_id, []) {
        if _binding_matches(binding, source_id, target_id, event_type) {
            return False;
        }
    }
    _append_binding(
        registry,
        Binding(source_id=source_id, target_id=target_id, event_type=event_type,),
    );
    return True;
}


impl unsubscribe(
    registry: BindingRegistry, source_id: str, target_id: str, event_type: str,
) -> bool {
    _validate_binding_ids(source_id, target_id);
    return _remove_binding(registry, source_id, target_id, event_type);
}


impl unsubscribe_target(registry: BindingRegistry, target_id: str) -> int {
    if not target_id {
        raise ValueError("target_id must not be empty");
    }
    bindings = list(registry.by_target.get(target_id, []));
    count = 0;
    for binding in bindings {
        if _remove_binding(
            registry, binding.source_id, binding.target_id, binding.event_type,
        ) {
            count += 1;
        }
    }
    return count;
}


impl clear_bindings(registry: BindingRegistry) {
    registry.by_source.clear();
    registry.by_target.clear();
}


impl binding_count(registry: BindingRegistry) -> int {
    count = 0;
    for source_id in registry.by_source {
        count += len(registry.by_source[source_id]);
    }
    return count;
}


impl is_empty(registry: BindingRegistry) -> bool {
    return binding_count(registry) == 0;
}


impl bindings_for_source(registry: BindingRegistry, source_id: str) -> list[Binding] {
    return list(registry.by_source.get(source_id, []));
}


impl bindings_for_target(registry: BindingRegistry, target_id: str) -> list[Binding] {
    return list(registry.by_target.get(target_id, []));
}


impl dump_bindings(registry: BindingRegistry) -> list[dict[str, str]] {
    rows: list[dict[str, str]] = [];
    for source_id in sorted(registry.by_source.keys()) {
        bindings = list(registry.by_source[source_id]);
        _sort_bindings_in_place(bindings);
        for binding in bindings {
            rows.append(
                {
                    "source_id": binding.source_id,
                    "target_id": binding.target_id,
                    "event_type": binding.event_type,

                }
            );
        }
    }
    return rows;
}


impl deliver(
    registry: BindingRegistry, source_id: str, event_type: str,
) -> list[DeliveryResult] {
    results: list[DeliveryResult] = [];
    bindings = bindings_for_source(registry, source_id);
    _sort_bindings_in_place(bindings);
    for binding in bindings {
        if binding.event_type != event_type {
            continue;
        }
        results.append(
            DeliveryResult(target_id=binding.target_id, event_type=binding.event_type,)
        );
    }
    return results;
}


impl find_orphan_bindings(
    registry: BindingRegistry, live_target_ids: set[str],
) -> list[Binding] {
    orphans: list[Binding] = [];
    for target_id in sorted(registry.by_target.keys()) {
        if target_id in live_target_ids {
            continue;
        }
        bindings = list(registry.by_target[target_id]);
        _sort_bindings_in_place(bindings);
        for binding in bindings {
            orphans.append(binding);
        }
    }
    return orphans;
}
