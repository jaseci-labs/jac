"""Native streaming iterator policies for itertools.

CPython owns the user objects and invokes native iterator slots. Tuple storage
is recycled only under exclusive ownership, with finalizers deferred until the
replacement contents have been published. Derived from CPython 3.14.6;
see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_retain,
    jacpy_iter,
    jacpy_iter_next,
    jacpy_error_pending,
    jacpy_clear_error,
    jacpy_call,
    jacpy_call_one,
    jacpy_call_two,
    jacpy_truth,
    jacpy_add,
    jacpy_none,
    jacpy_is_none,
    jacpy_is_long,
    jacpy_integer_value,
    jacpy_tuple_new,
    jacpy_tuple_size,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    jacpy_tuple_unique,
    jacpy_tuple_exchange,
    jacpy_sequence_tuple,
    jacpy_list_new,
    jacpy_list_size,
    jacpy_list_append,
    jacpy_list_item,
    jacpy_list_exchange,
    required,
    checked,
    boundary_failure,
    object_error,
    text_object,
    repr_value,
    type_name
}

# These values identify iterator policies in the native bindings.
enum pipeline_kind {
    ACCUMULATE = 0,
    BATCHED = 1,
    CHAIN = 2,
    COMPRESS = 3,
    COUNT = 4,
    CYCLE = 5,
    DROPWHILE = 6,
    FILTERFALSE = 7,
    ISLICE = 8,
    PAIRWISE = 9,
    REPEAT = 10,
    STARMAP = 11,
    TAKEWHILE = 12,
    ZIP_LONGEST = 13
}

obj pipeline_state {
    has kind: i64 = 0,
        source: u64 = 0,
        auxiliary: u64 = 0,
        function: u64 = 0,
        value: u64 = 0,
        initial: u64 = 0,
        result: u64 = 0,
        saved: u64 = 0,
        position: i64 = 0,
        stop: i64 = -1,
        step: i64 = 1,
        consumed: i64 = 0,
        active: i64 = 0,
        flag: bool = False;
}

def:pub jacpy_pipeline_new -> pipeline_state {
    return pipeline_state();
}

def:pub jacpy_pipeline_field(state: pipeline_state, field: i64) -> u64 {
    if field == 0 {
        return state.source;
    }
    if field == 1 {
        return state.auxiliary;
    }
    if field == 2 {
        return state.function;
    }
    if field == 3 {
        return state.value;
    }
    if field == 4 {
        return state.initial;
    }
    if field == 5 {
        return state.result;
    }
    return state.saved;
}

def:pub jacpy_pipeline_clear(state: pipeline_state) {
    source = state.source;
    auxiliary = state.auxiliary;
    function = state.function;
    value = state.value;
    initial = state.initial;
    result = state.result;
    saved = state.saved;
    state.source = 0;
    state.auxiliary = 0;
    state.function = 0;
    state.value = 0;
    state.initial = 0;
    state.result = 0;
    state.saved = 0;
    jacpy_release(source);
    jacpy_release(auxiliary);
    jacpy_release(function);
    jacpy_release(value);
    jacpy_release(initial);
    jacpy_release(result);
    jacpy_release(saved);
}

def:pub jacpy_pipeline_init(
    state: pipeline_state,
    kind: i64,
    source: u64,
    second: u64,
    function: u64,
    initial: u64,
    first: i64,
    stop: i64,
    step: i64,
    flag: i64
) -> i64 {
    state.kind = kind;
    state.position = first;
    state.stop = stop;
    state.step = step;
    state.flag = flag != 0;
    item: u64 = 0;
    iterator: u64 = 0;
    try {
        if kind == pipeline_kind.COUNT.value or kind == pipeline_kind.REPEAT.value {
            state.value = jacpy_retain(source);
            if second != 0 {
                state.auxiliary = jacpy_retain(second);
            }
        } elif kind == pipeline_kind.ZIP_LONGEST.value {
            state.source = required(jacpy_list_new());
            state.function = jacpy_retain(function);
            state.active = jacpy_tuple_size(source);
            for i in range(int(state.active)) {
                item = required(jacpy_tuple_item(source, i64(i)));
                iterator = required(jacpy_iter(item));
                checked(jacpy_list_append(state.source, iterator));
                jacpy_release(item);
                item = 0;
                jacpy_release(iterator);
                iterator = 0;
            }
        } else {
            state.source = required(jacpy_iter(source));
            if second != 0 {
                state.auxiliary = required(jacpy_iter(second));
            }
            if function != 0 and jacpy_is_none(function) == 0 {
                state.function = jacpy_retain(function);
            }
            if initial != 0 and jacpy_is_none(initial) == 0 {
                state.initial = jacpy_retain(initial);
            }
            if kind == pipeline_kind.CYCLE.value {
                state.saved = required(jacpy_list_new());
            }
        }
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(item);
        jacpy_release(iterator);
    }
}

# The returned tuple is owned by the caller, so callback-driven next() cannot
# recycle it while its previous elements are being released.
def reusable_tuple(previous: u64, width: i64) -> u64 {
    if previous != 0 and jacpy_tuple_unique(previous) != 0 {
        return jacpy_retain(previous);
    }
    result = required(jacpy_tuple_new(width));
    for i in range(int(width)) {
        checked(jacpy_tuple_set_owned(result, i64(i), jacpy_none()));
    }
    return result;
}

def:priv stop_source(state: pipeline_state) {
    old = state.source;
    state.source = 0;
    jacpy_release(old);
}

def:priv pipeline_pairwise(state: pipeline_state) -> u64 {
    if state.source == 0 {
        return 0;
    }
    old: u64 = 0;
    value: u64 = 0;
    result: u64 = 0;
    previous_left: u64 = 0;
    previous_right: u64 = 0;
    try {
        if state.value == 0 {
            value = jacpy_iter_next(state.source);
            replaced = state.value;
            state.value = value;
            value = 0;
            jacpy_release(replaced);
            if state.value == 0 {
                stop_source(state);
                return 0;
            }
            if state.source == 0 {
                replaced = state.value;
                state.value = 0;
                jacpy_release(replaced);
                return 0;
            }
        }
        old = jacpy_retain(state.value);
        value = jacpy_iter_next(state.source);
        if value == 0 {
            stop_source(state);
            replaced = state.value;
            state.value = 0;
            jacpy_release(replaced);
            return 0;
        }
        result = reusable_tuple(state.result, 2);
        previous_left = jacpy_tuple_exchange(result, 0, old);
        previous_right = jacpy_tuple_exchange(result, 1, value);
        prior = state.result;
        state.result = jacpy_retain(result);
        jacpy_release(prior);
        prior = state.value;
        state.value = value;
        value = 0;
        jacpy_release(prior);
        answer = result;
        result = 0;
        return answer;
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(old);
        jacpy_release(value);
        jacpy_release(result);
        jacpy_release(previous_left);
        jacpy_release(previous_right);
    }
}

def:priv pipeline_zip(state: pipeline_state) -> u64 {
    if state.active == 0 {
        return 0;
    }
    width = jacpy_list_size(state.source);
    result: u64 = 0;
    iterator: u64 = 0;
    item: u64 = 0;
    old_values: list[u64] = [];
    try {
        result = reusable_tuple(state.result, width);
        for i in range(int(width)) {
            iterator = required(jacpy_list_item(state.source, i64(i)));
            if jacpy_is_none(iterator) != 0 {
                item = jacpy_retain(state.function);
            } else {
                item = jacpy_iter_next(iterator);
                if item == 0 {
                    state.active -= 1;
                    if state.active == 0 or jacpy_error_pending() != 0 {
                        state.active = 0;
                        return 0;
                    }
                    empty = jacpy_none();
                    previous = jacpy_list_exchange(state.source, i64(i), empty);
                    jacpy_release(empty);
                    jacpy_release(previous);
                    item = jacpy_retain(state.function);
                }
            }
            old_values.append(jacpy_tuple_exchange(result, i64(i), item));
            jacpy_release(item);
            item = 0;
            jacpy_release(iterator);
            iterator = 0;
        }
        prior = state.result;
        state.result = jacpy_retain(result);
        jacpy_release(prior);
        answer = result;
        result = 0;
        return answer;
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(result);
        jacpy_release(iterator);
        jacpy_release(item);
        for old in old_values {
            jacpy_release(old);
        }
    }
}

def:pub jacpy_pipeline_next(state: pipeline_state) -> u64 {
    kind = state.kind;
    if kind == pipeline_kind.PAIRWISE.value {
        return pipeline_pairwise(state);
    }
    if kind == pipeline_kind.ZIP_LONGEST.value {
        return pipeline_zip(state);
    }
    item: u64 = 0;
    good: u64 = 0;
    result: u64 = 0;
    try {
        if kind == pipeline_kind.COUNT.value {
            item = jacpy_retain(state.value);
            result = required(jacpy_add(item, state.auxiliary));
            prior = state.value;
            state.value = result;
            result = 0;
            jacpy_release(prior);
            answer = item;
            item = 0;
            return answer;
        }
        if kind == pipeline_kind.REPEAT.value {
            if state.stop == 0 {
                return 0;
            }
            if state.stop > 0 {
                state.stop -= 1;
            }
            return jacpy_retain(state.value);
        }
        if kind == pipeline_kind.ACCUMULATE.value and state.initial != 0 {
            prior = state.value;
            state.value = state.initial;
            state.initial = 0;
            jacpy_release(prior);
            return jacpy_retain(state.value);
        }
        if kind == pipeline_kind.CYCLE.value {
            if state.source != 0 {
                item = jacpy_iter_next(state.source);
                if item != 0 {
                    checked(jacpy_list_append(state.saved, item));
                    answer = item;
                    item = 0;
                    return answer;
                }
                if jacpy_error_pending() != 0 {
                    return 0;
                }
                stop_source(state);
            }
            size = jacpy_list_size(state.saved);
            if size == 0 {
                return 0;
            }
            result = jacpy_list_item(state.saved, state.position);
            state.position = (state.position + 1) % size;
            answer = result;
            result = 0;
            return answer;
        }
        if state.source == 0 {
            return 0;
        }
        if kind == pipeline_kind.CHAIN.value {
            while state.source != 0 {
                if state.auxiliary == 0 {
                    item = jacpy_iter_next(state.source);
                    if item == 0 {
                        stop_source(state);
                        return 0;
                    }
                    good = jacpy_iter(item);
                    jacpy_release(item);
                    item = 0;
                    if good == 0 {
                        stop_source(state);
                        return 0;
                    }
                    state.auxiliary = good;
                    good = 0;
                }
                item = jacpy_iter_next(state.auxiliary);
                if item != 0 {
                    answer = item;
                    item = 0;
                    return answer;
                }
                if jacpy_error_pending() != 0 {
                    return 0;
                }
                prior = state.auxiliary;
                state.auxiliary = 0;
                jacpy_release(prior);
            }
            return 0;
        }
        if kind == pipeline_kind.ISLICE.value {
            while state.consumed < state.position {
                item = jacpy_iter_next(state.source);
                if item == 0 {
                    stop_source(state);
                    return 0;
                }
                jacpy_release(item);
                item = 0;
                state.consumed += 1;
            }
            if state.stop >= 0 and state.consumed >= state.stop {
                stop_source(state);
                return 0;
            }
            item = jacpy_iter_next(state.source);
            if item == 0 {
                stop_source(state);
                return 0;
            }
            state.consumed += 1;
            if state.position > i64(9223372036854775807) - state.step {
                state.position = state.stop;
            } else {
                state.position += state.step;
                if state.stop >= 0 and state.position > state.stop {
                    state.position = state.stop;
                }
            }
            answer = item;
            item = 0;
            return answer;
        }
        if kind == pipeline_kind.BATCHED.value {
            result = required(jacpy_tuple_new(state.step));
            for i in range(int(state.step)) {
                item = jacpy_iter_next(state.source);
                if item == 0 {
                    stop_source(state);
                    if jacpy_error_pending() != 0 or i == 0 {
                        return 0;
                    }
                    if state.flag {
                        object_error("ValueError", "batched(): incomplete batch");
                        return 0;
                    }
                    # Copy the initialized prefix; the unused tuple slots stay NULL.
                    short = required(jacpy_tuple_new(i64(i)));
                    for j in range(i) {
                        checked(
                            jacpy_tuple_set_owned(
                                short,
                                i64(j),
                                required(jacpy_tuple_item(result, i64(j)))
                            )
                        );
                    }
                    return short;
                }
                checked(jacpy_tuple_set_owned(result, i64(i), item));
                item = 0;
            }
            answer = result;
            result = 0;
            return answer;
        }
        if kind == pipeline_kind.TAKEWHILE.value and state.flag {
            return 0;
        }
        while True {
            item = jacpy_iter_next(state.source);
            if item == 0 {
                return 0;
            }
            if kind == pipeline_kind.ACCUMULATE.value {
                if state.value == 0 {
                    state.value = jacpy_retain(item);
                    answer = item;
                    item = 0;
                    return answer;
                }
                result = required(
                    jacpy_add(state.value, item)
                        if state.function == 0
                        else jacpy_call_two(state.function, state.value, item)
                );
                prior = state.value;
                state.value = jacpy_retain(result);
                jacpy_release(prior);
                answer = result;
                result = 0;
                return answer;
            }
            if kind == pipeline_kind.STARMAP.value {
                good = required(jacpy_sequence_tuple(item));
                return jacpy_call(state.function, good, 0);
            }
            if kind == pipeline_kind.DROPWHILE.value and state.flag {
                answer = item;
                item = 0;
                return answer;
            }
            if kind == pipeline_kind.COMPRESS.value {
                good = jacpy_iter_next(state.auxiliary);
                if good == 0 {
                    return 0;
                }
            } elif state.function == 0 {
                good = jacpy_retain(item);
            } else {
                good = required(jacpy_call_one(state.function, item));
            }
            truth = jacpy_truth(good);
            checked(truth);
            jacpy_release(good);
            good = 0;
            if kind == pipeline_kind.TAKEWHILE.value {
                if truth == 0 {
                    state.flag = True;
                    return 0;
                }
                answer = item;
                item = 0;
                return answer;
            }
            if (kind == pipeline_kind.COMPRESS.value and truth != 0)
                or (kind != pipeline_kind.COMPRESS.value and truth == 0) {
                if kind == pipeline_kind.DROPWHILE.value {
                    state.flag = True;
                }
                answer = item;
                item = 0;
                return answer;
            }
            jacpy_release(item);
            item = 0;
        }
    } except boundary_failure {
        return 0;
    } finally {
        jacpy_release(item);
        jacpy_release(good);
        jacpy_release(result);
    }
}

def:pub jacpy_pipeline_length(state: pipeline_state) -> i64 {
    return state.stop;
}

def:pub jacpy_pipeline_repr(state: pipeline_state, owner: u64) -> u64 {
    try {
        name = type_name(owner, False);
        if name.startswith("itertools.") {
            name = name[10:];
        }
        if state.kind == pipeline_kind.REPEAT.value {
            return text_object(
                name
                    + "("
                    + repr_value(state.value)
                    + (", " + str(state.stop) if state.stop >= 0 else "")
                    + ")"
            );
        }
        show_step = True;
        if jacpy_is_long(state.auxiliary) != 0 {
            step = jacpy_integer_value(state.auxiliary);
            if jacpy_error_pending() != 0 {
                jacpy_clear_error();
            } else {
                show_step = step != 1;
            }
        }
        return text_object(
            name
                + "("
                + repr_value(state.value)
                + (", " + repr_value(state.auxiliary) if show_step else "")
                + ")"
        );
    } except boundary_failure {
        return 0;
    }
}
