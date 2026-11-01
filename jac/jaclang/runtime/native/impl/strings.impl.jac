impl __jac_rt_str_cmp(a: ptr[u8], an: int, b: ptr[u8], bn: int) -> int {
    n = an;
    if bn < n {
        n = bn;
    }
    if n > 0 {
        order = int(memcmp(a, b, i64(n)));
        if order < 0 {
            return -1;
        }
        if order > 0 {
            return 1;
        }
    }
    if an < bn {
        return -1;
    }
    if an > bn {
        return 1;
    }
    return 0;
}

impl __jac_rt_str_len(owner: ptr[u8], data: ptr[u8], n: int) -> int {
    if n <= 0 {
        return 0;
    }
    if int(owner) == int(data) and int(owner) != 0 {
        tag = __mem_load_i64(int(owner) + STR_TAG_OFF);
        if (tag & 1) != 0
            and tag < 0
            and ((tag & STR_LEN_PAYLOAD_MASK) >> 1) == n {
            return n;
        }
    }
    bytes = data.view(n);
    count = 0;
    i = 0;
    while i < n {
        if (int(bytes[i]) & 192) != 128 {
            count += 1;
        }
        i += 1;
    }
    return count;
}

impl __jac_rt_str_size(text: ptr[u8]) -> int {
    if int(text) == 0 {
        return 0;
    }
    tag = __mem_load_i64(int(text) + STR_TAG_OFF);
    if (tag & 1) != 0 {
        return (tag & STR_LEN_PAYLOAD_MASK) >> 1;
    }
    return int(strlen(text));
}

impl __jac_rt_write(fd: int, data: ptr[u8], n: int) {
    if n > 0 {
        fwrite(data, i64(1), i64(n), __jac_stdio(i32(fd)));
    }
}

impl __jac_rt_write_int(fd: int, value: int) {
    buf = __thread_local_block("jac_rt_int_text", 32);
    start = _int_text(value, buf);
    __jac_rt_write(fd, ptr[u8](buf + start), INT_TEXT_MAX - start);
}

impl _int_text(value: int, buf: int) -> int {
    pos = INT_TEXT_MAX;
    rest = value;
    if rest == 0 {
        pos -= 1;
        __mem_store_i8(buf + pos, i8(48));
    }
    while rest != 0 {
        digit = rest % 10;
        rest = rest // 10;
        if value < 0 and digit != 0 {
            digit = 10 - digit;
            rest += 1;
        }
        pos -= 1;
        __mem_store_i8(buf + pos, i8(48 + digit));
    }
    if value < 0 {
        pos -= 1;
        __mem_store_i8(buf + pos, i8(45));
    }
    return pos;
}

impl _str_alloc(n: int) -> ptr[u8] {
    made = __jac_rt_alloc(n + 1);
    __jac_rt_set_type(made, int(ptr[u8]("str")));
    return ptr[u8](made);
}

impl _str_finish(text: ptr[u8], n: int) -> ptr[u8] {
    bytes = text.view(n + 1);
    bytes[n] = u8(0);
    high = 0;
    i = 0;
    while i < n {
        high = high | int(bytes[i]);
        i += 1;
    }
    tag = (n << 1) | 1;
    if (high & 128) == 0 {
        tag = tag | (-9223372036854775807 - 1);
    }
    __mem_store_i64(int(text) + STR_TAG_OFF, tag);
    return text;
}

impl __jac_rt_str_new(data: ptr[u8], n: int) -> ptr[u8] {
    made = _str_alloc(n);
    if n > 0 {
        memcpy(made, data, i64(n));
    }
    return _str_finish(made, n);
}

impl __jac_rt_str_concat(a: ptr[u8], an: int, b: ptr[u8], bn: int) -> ptr[u8] {
    made = _str_alloc(an + bn);
    if an > 0 {
        memcpy(made, a, i64(an));
    }
    if bn > 0 {
        memcpy(made + an, b, i64(bn));
    }
    return _str_finish(made, an + bn);
}

impl __jac_rt_str_from_int(value: int) -> ptr[u8] {
    buf = __thread_local_block("jac_rt_int_text", 32);
    start = _int_text(value, buf);
    return __jac_rt_str_new(ptr[u8](buf + start), INT_TEXT_MAX - start);
}

impl __jac_rt_str_ref(owner: ptr[u8], data: ptr[u8], n: int) -> ptr[u8] {
    if int(owner) != 0 and int(owner) == int(data) and __jac_rt_str_size(owner) == n {
        __jac_rt_retain(int(owner));
        return owner;
    }
    return __jac_rt_str_new(data, n);
}

impl __jac_rt_str_char_at(data: ptr[u8], n: int, index: int) -> ptr[u8] {
    bytes = data.view(n);
    seen = -1;
    i = 0;
    while i < n {
        if (int(bytes[i]) & 192) != 128 {
            seen += 1;
            if seen == index {
                start = i;
                i += 1;
                while i < n and (int(bytes[i]) & 192) == 128 {
                    i += 1;
                }
                return __jac_rt_str_new(data + start, i - start);
            }
        }
        i += 1;
    }
    return __jac_rt_str_new(data, 0);
}
