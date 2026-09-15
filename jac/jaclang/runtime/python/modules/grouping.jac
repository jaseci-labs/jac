"""Native shared-cursor grouping for itertools.groupby.

Comparisons may advance either iterator recursively. Snapshot comparison
operands and publish state before releasing Python references.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_retain,
    jacpy_iter,
    jacpy_iter_next,
    jacpy_call_one,
    jacpy_is_none,
    jacpy_compare_bool,
    jacpy_tuple_new,
    jacpy_tuple_set_owned,
    required,
    checked,
    boundary_failure
}

obj group_state {
    has make_group: Callable[[u64, u64], u64],
        source: u64 = 0,
        function: u64 = 0,
        target: u64 = 0,
        key: u64 = 0,
        value: u64 = 0,
        active_group: u64 = 0;
}

def:pub jacpy_group_init(state: group_state, iterable: u64, function: u64) -> i64 {
    state.source = jacpy_iter(iterable);
    if state.source == 0 {
        return -1;
    }
    if jacpy_is_none(function) == 0 {
        state.function = jacpy_retain(function);
    }
    return 0;
}

def:pub jacpy_group_field(state: group_state, field: i64) -> u64 {
    if field == 0 {
        return state.source;
    }
    if field == 1 {
        return state.function;
    }
    if field == 2 {
        return state.target;
    }
    if field == 3 {
        return state.key;
    }
    return state.value;
}

def:pub jacpy_group_clear(state: group_state) {
    source = state.source;
    function = state.function;
    target = state.target;
    key = state.key;
    value = state.value;
    state.source = 0;
    state.function = 0;
    state.target = 0;
    state.key = 0;
    state.value = 0;
    state.active_group = 0;
    jacpy_release(source);
    jacpy_release(function);
    jacpy_release(target);
    jacpy_release(key);
    jacpy_release(value);
}

def:pub jacpy_group_activate(state: group_state, group: u64) {
    state.active_group = group;
}

def:priv group_step(state: group_state) -> bool {
    value = jacpy_iter_next(state.source);
    if value == 0 {
        return False;
    }
    key = jacpy_retain(value)
        if state.function == 0
        else jacpy_call_one(state.function, value);
    if key == 0 {
        jacpy_release(value);
        return False;
    }
    old_value = state.value;
    old_key = state.key;
    state.value = value;
    state.key = key;
    jacpy_release(old_value);
    jacpy_release(old_key);
    return True;
}

def:pub jacpy_group_next(state: group_state, owner: u64) -> u64 {
    state.active_group = 0;
    target: u64 = 0;
    key: u64 = 0;
    group: u64 = 0;
    result: u64 = 0;
    try {
        while True {
            if state.key != 0 {
                if state.target == 0 {
                    break;
                }
                target = jacpy_retain(state.target);
                key = jacpy_retain(state.key);
                comparison = jacpy_compare_bool(target, key, 2);
                jacpy_release(target);
                target = 0;
                jacpy_release(key);
                key = 0;
                checked(comparison);
                if comparison == 0 {
                    break;
                }
            }
            if not group_step(state) {
                return 0;
            }
        }
        key = jacpy_retain(state.key);
        previous = state.target;
        state.target = jacpy_retain(key);
        jacpy_release(previous);
        group = required(state.make_group(owner, key));
        result = required(jacpy_tuple_new(2));
        checked(jacpy_tuple_set_owned(result, 0, jacpy_retain(key)));
        checked(jacpy_tuple_set_owned(result, 1, jacpy_retain(group)));
        answer = result;
        result = 0;
        return answer;
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(target);
        jacpy_release(key);
        jacpy_release(group);
        jacpy_release(result);
    }
}

def:pub jacpy_grouper_next(state: group_state, owner: u64, target: u64) -> u64 {
    if state.active_group != owner {
        return 0;
    }
    if state.value == 0 and not group_step(state) {
        return 0;
    }
    target_snapshot = jacpy_retain(target);
    key_snapshot = jacpy_retain(state.key);
    comparison = jacpy_compare_bool(target_snapshot, key_snapshot, 2);
    jacpy_release(target_snapshot);
    jacpy_release(key_snapshot);
    if comparison <= 0 {
        return 0;
    }
    result = state.value;
    old_key = state.key;
    state.value = 0;
    state.key = 0;
    jacpy_release(old_key);
    return result;
}
