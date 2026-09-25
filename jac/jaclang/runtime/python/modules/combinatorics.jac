"""Native product, combination and permutation state machines.

Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyObject,
    PySequence_Tuple,
    PyTuple_New,
    PyTuple_Size,
    Py_NewRef,
    jacpy_release,
    jacpy_tuple_exchange,
    jacpy_tuple_item,
    jacpy_tuple_set_owned
}
import from jaclang.runtime.python.modules.iterators { reusable_tuple }
import from jaclang.runtime.python.capi {
    jac_heap_size,
    jac_list_heap_size,
    required,
    checked,
    boundary_failure,
    object_error
}

enum combination_kind {
    PRODUCT = 14,
    COMBINATIONS = 15,
    WITH_REPLACEMENT = 16,
    PERMUTATIONS = 17
}

obj combinatorial_state {
    has kind: i64 = 0,
        pools: ptr[PyObject] = NULL,
        result: ptr[PyObject] = NULL,
        width: i64 = 0,
        population: i64 = 0,
        indices: list[i64] = [],
        cycles: list[i64] = [],
        started: bool = False,
        stopped: bool = False;
}

def:pub jacpy_combinatorial_new -> combinatorial_state {
    return combinatorial_state();
}

def:pub jacpy_combinatorial_field(
    state: combinatorial_state, field: i64
) -> ptr[PyObject] {
    return state.pools if field == 0 else state.result;
}

def:pub jacpy_combinatorial_clear(state: combinatorial_state) {
    pools = state.pools;
    result = state.result;
    state.pools = NULL;
    state.result = NULL;
    state.stopped = True;
    jacpy_release(pools);
    jacpy_release(result);
}

def:pub jacpy_combinatorial_memory(state: combinatorial_state) -> i64 {
    return jac_heap_size(u64(id(state)))
        + jac_list_heap_size(u64(id(state.indices)))
        + jac_list_heap_size(u64(id(state.cycles)));
}

def:pub jacpy_combinatorial_init(
    state: combinatorial_state, kind: i64, source: ptr[PyObject], width: i64
) -> i64 {
    state.kind = kind;
    item: ptr[PyObject] = NULL;
    pool: ptr[PyObject] = NULL;
    try {
        if kind == combination_kind.PRODUCT.value {
            count = PyTuple_Size(source);
            if count > 0 and width > i64(9223372036854775807) // count {
                object_error("OverflowError", "repeat argument too large");
                return -1;
            }
            state.width = count * width;
            state.pools = required(PyTuple_New(state.width));
            for i in range(int(count if width > 0 else i64(0))) {
                item = required(jacpy_tuple_item(source, i64(i)));
                pool = required(PySequence_Tuple(item));
                for j in range(int(width)) {
                    checked(
                        jacpy_tuple_set_owned(
                            state.pools, i64(i) + i64(j) * count, Py_NewRef(pool)
                        )
                    );
                }
                jacpy_release(item);
                item = NULL;
                jacpy_release(pool);
                pool = NULL;
            }
            for i in range(int(state.width)) {
                pool = required(jacpy_tuple_item(state.pools, i64(i)));
                if PyTuple_Size(pool) == 0 {
                    state.stopped = True;
                }
                jacpy_release(pool);
                pool = NULL;
                state.indices.append(i64(0));
            }
        } else {
            state.pools = required(PySequence_Tuple(source));
            state.population = PyTuple_Size(state.pools);
            state.width = state.population if width < 0 else width;
            if state.width > i64(9223372036854775807) // 8 {
                object_error("MemoryError", "");
                return -1;
            }
            if kind == combination_kind.WITH_REPLACEMENT.value {
                state.stopped = state.population == 0 and state.width > 0;
            } else {
                state.stopped = state.width > state.population;
            }
            for i in range(
                int(
                    state.population
                        if kind == combination_kind.PERMUTATIONS.value
                        else state.width
                )
            ) {
                state.indices.append(
                    i64(0)
                        if kind == combination_kind.WITH_REPLACEMENT.value
                        else i64(i)
                );
            }
            if kind == combination_kind.PERMUTATIONS.value {
                for i in range(int(state.width)) {
                    state.cycles.append(state.population - i64(i));
                }
            }
        }
        return 0;
    } except boundary_failure {
        return -1;
    } finally {
        jacpy_release(item);
        jacpy_release(pool);
    }
}

def:priv advance_combination(state: combinatorial_state) -> bool {
    r = int(state.width);
    n = state.population;
    i = r - 1;
    if state.kind == combination_kind.WITH_REPLACEMENT.value {
        while i >= 0 and state.indices[i] == n - 1 {
            i -= 1;
        }
        if i < 0 {
            return False;
        }
        value = state.indices[i] + 1;
        for j in range(i, r) {
            state.indices[j] = value;
        }
    } else {
        while i >= 0 and state.indices[i] == i64(i) + n - state.width {
            i -= 1;
        }
        if i < 0 {
            return False;
        }
        state.indices[i] += 1;
        for j in range(i + 1, r) {
            state.indices[j] = state.indices[j - 1] + 1;
        }
    }
    return True;
}

def:priv advance_permutation(state: combinatorial_state) -> bool {
    n = int(state.population);
    r = int(state.width);
    i = r - 1;
    while i >= 0 {
        state.cycles[i] -= 1;
        if state.cycles[i] == 0 {
            first = state.indices[i];
            for j in range(i, n - 1) {
                state.indices[j] = state.indices[j + 1];
            }
            state.indices[n - 1] = first;
            state.cycles[i] = i64(n - i);
        } else {
            j = n - int(state.cycles[i]);
            first = state.indices[i];
            state.indices[i] = state.indices[j];
            state.indices[j] = first;
            return True;
        }
        i -= 1;
    }
    return False;
}

def:priv advance_product(state: combinatorial_state) -> bool {
    i = int(state.width) - 1;
    while i >= 0 {
        pool = required(jacpy_tuple_item(state.pools, i64(i)));
        size = PyTuple_Size(pool);
        jacpy_release(pool);
        state.indices[i] += 1;
        if state.indices[i] < size {
            return True;
        }
        state.indices[i] = 0;
        i -= 1;
    }
    return False;
}

def:pub jacpy_combinatorial_next(state: combinatorial_state) -> ptr[PyObject] {
    if state.stopped {
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    pool: ptr[PyObject] = NULL;
    item: ptr[PyObject] = NULL;
    old_values: list[ptr[PyObject]] = [];
    try {
        if state.started {
            advanced = advance_product(state)
                if state.kind == combination_kind.PRODUCT.value
                else (
                    advance_permutation(state)
                        if state.kind == combination_kind.PERMUTATIONS.value
                        else advance_combination(state)
                );
            if not advanced {
                state.stopped = True;
                return NULL;
            }
        }
        state.started = True;
        result = reusable_tuple(state.result, state.width);
        for i in range(int(state.width)) {
            if state.kind == combination_kind.PRODUCT.value {
                pool = required(jacpy_tuple_item(state.pools, i64(i)));
            } else {
                pool = Py_NewRef(state.pools);
            }
            item = required(jacpy_tuple_item(pool, state.indices[i]));
            old_values.append(jacpy_tuple_exchange(result, i64(i), item));
            jacpy_release(item);
            item = NULL;
            jacpy_release(pool);
            pool = NULL;
        }
        previous = state.result;
        state.result = Py_NewRef(result);
        jacpy_release(previous);
        answer = result;
        result = NULL;
        return answer;
    } except boundary_failure {
        state.stopped = True;
        return NULL;
    } finally {
        jacpy_release(result);
        jacpy_release(pool);
        jacpy_release(item);
        for previous in old_values {
            jacpy_release(previous);
        }
    }
}
