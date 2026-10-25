glob:priv MAX_CANDIDATE_ITEMS: Final[i64] = 750,
     MAX_STRING_SIZE: Final[u64] = 40,
     MOVE_COST: Final[u64] = 2,
     CASE_COST: Final[u64] = 1,
     PY_SSIZE_T_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF;

def substitution_cost(a_in: u8, b_in: u8) -> u64;

def levenshtein_distance(
    a_in: ptr[u8],
    a_size_in: u64,
    b_in: ptr[u8],
    b_size_in: u64,
    max_cost: u64,
    buffer: ptr[u64]
) -> u64;

import from c {
    def _Py_CalculateSuggestions(
        dir: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject] {
        dir_size = object_size(dir);
        if dir_size >= MAX_CANDIDATE_ITEMS {
            return NULL;
        }
        suggestion_distance: i64 = PY_SSIZE_T_MAX;
        suggestion = NULL;
        name_size: i64 = 0;
        name_str = PyUnicode_AsUTF8AndSize(name, &mut name_size);
        if not name_str {
            return NULL;
        }
        buffer = ptr[u64](PyMem_Malloc(MAX_STRING_SIZE * u64(8)));
        if not buffer {
            return PyErr_NoMemory();
        }
        items = ptr[PyListObject](dir).view(1)[0].ob_item;
        i: i64 = 0;
        while i < dir_size {
            item = (items + i).view(1)[0];
            i += 1;
            if _PyUnicode_Equal(name, item) != i32(0) {
                continue;
            }
            item_size: i64 = 0;
            item_str = PyUnicode_AsUTF8AndSize(item, &mut item_size);
            if not item_str {
                PyMem_Free(ptr(buffer));
                return NULL;
            }

            max_distance = (name_size + item_size + 3) * i64(MOVE_COST) // 6;

            if suggestion_distance - 1 < max_distance {
                max_distance = suggestion_distance - 1;
            }
            current_distance = i64.wrap(
                levenshtein_distance(
                    name_str,
                    u64(name_size),
                    item_str,
                    u64(item_size),
                    u64.wrap(max_distance),
                    buffer
                )
            );
            if current_distance > max_distance {
                continue;
            }
            if not suggestion or current_distance < suggestion_distance {
                suggestion = item;
                suggestion_distance = current_distance;
            }
        }
        PyMem_Free(ptr(buffer));
        return object_xnewref(suggestion);
    }  def _Py_UTF8_Edit_Cost(
        a: ptr[PyObject], b: ptr[PyObject], max_cost_in: i64
    ) -> i64 {
        size_a: i64 = 0;
        utf8_a = PyUnicode_AsUTF8AndSize(a, &mut size_a);
        if not utf8_a {
            return -1;
        }
        size_b: i64 = 0;
        utf8_b = PyUnicode_AsUTF8AndSize(b, &mut size_b);
        if not utf8_b {
            return -1;
        }
        max_cost = max_cost_in;
        if max_cost == -1 {
            max_cost = i64(MOVE_COST) * (size_a if size_a > size_b else size_b);
        }
        buffer = ptr[u64](PyMem_Malloc(MAX_STRING_SIZE * u64(8)));
        if not buffer {
            PyErr_NoMemory();
            return -1;
        }
        res = i64.wrap(
            levenshtein_distance(
                utf8_a, u64(size_a), utf8_b, u64(size_b), u64.wrap(max_cost), buffer
            )
        );
        PyMem_Free(ptr(buffer));
        return res;
    }
}

impl substitution_cost(a_in: u8, b_in: u8) -> u64 {
    a = a_in;
    b = b_in;
    if (a & u8(31)) != (b & u8(31)) {
        return MOVE_COST;
    }
    if a == b {
        return u64(0);
    }
    if u8(65) <= a and a <= u8(90) {
        a = a + u8(32);
    }
    if u8(65) <= b and b <= u8(90) {
        b = b + u8(32);
    }
    if a == b {
        return CASE_COST;
    }
    return MOVE_COST;
}

impl levenshtein_distance(
    a_in: ptr[u8],
    a_size_in: u64,
    b_in: ptr[u8],
    b_size_in: u64,
    max_cost: u64,
    buffer: ptr[u64]
) -> u64 {
    a = a_in;
    b = b_in;
    a_size = a_size_in;
    b_size = b_size_in;

    if a == b {
        return u64(0);
    }

    while a_size != u64(0) and b_size != u64(0) and a.view(1)[0] == b.view(1)[0] {
        a = a + 1;
        a_size = a_size - u64(1);
        b = b + 1;
        b_size = b_size - u64(1);
    }
    while a_size != u64(0)
        and b_size != u64(0)
        and (a + i64(a_size) - 1).view(1)[0] == (b + i64(b_size) - 1).view(1)[0] {
        a_size = a_size - u64(1);
        b_size = b_size - u64(1);
    }
    if a_size == u64(0) or b_size == u64(0) {
        return (a_size + b_size) * MOVE_COST;
    }
    if a_size > MAX_STRING_SIZE or b_size > MAX_STRING_SIZE {
        return wrapping_add(max_cost, u64(1));
    }

    if b_size < a_size {
        t = a;
        a = b;
        b = t;
        t_size = a_size;
        a_size = b_size;
        b_size = t_size;
    }

    if (b_size - a_size) * MOVE_COST > max_cost {
        return wrapping_add(max_cost, u64(1));
    }

    tmp = MOVE_COST;
    i = u64(0);
    while i < a_size {
        (buffer + i64(i)).view(1)[0] = tmp;
        tmp = tmp + MOVE_COST;
        i = i + u64(1);
    }
    result = u64(0);
    b_index = u64(0);
    while b_index < b_size {
        code = (b + i64(b_index)).view(1)[0];

        result = b_index * MOVE_COST;
        distance = result;
        minimum = ~u64(0);
        index = u64(0);
        while index < a_size {
            substitute = distance
                + substitution_cost(code, (a + i64(index)).view(1)[0]);

            distance = (buffer + i64(index)).view(1)[0];

            insert_delete = (result if result < distance else distance) + MOVE_COST;
            result = insert_delete if insert_delete < substitute else substitute;

            (buffer + i64(index)).view(1)[0] = result;
            if result < minimum {
                minimum = result;
            }
            index = index + u64(1);
        }
        if minimum > max_cost {
            return wrapping_add(max_cost, u64(1));
        }
        b_index = b_index + u64(1);
    }
    return result;
}
