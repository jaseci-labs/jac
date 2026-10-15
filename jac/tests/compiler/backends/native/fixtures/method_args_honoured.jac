"""Primitive method calls whose positional arguments the native lowering used
to drop (issue #9823), next to calls it must refuse rather than run wrong."""

def index_from -> int {
    s = "ab/> cd <img x />";
    return s.index("/>", 5);
}

def find_window -> int {
    s = "ab/> cd <img x />";
    return s.find("/>", 0, 3);
}

def rfind_window -> int {
    s = "ab/> cd <img x />";
    return s.rfind("/>", 0, 6);
}

def rindex_window -> int {
    s = "ab/> cd <img x />";
    return s.rindex("/>", 0, 6);
}

def rfind_from -> int {
    s = "ab/> cd <img x />";
    return s.rfind("/>", 5);
}

def count_from -> int {
    s = "ab/> cd <img x />";
    return s.count("/>", 5);
}

def count_window -> int {
    s = "ab/> cd <img x />";
    return s.count("/>", 0, 6);
}

def find_negative_window -> int {
    s = "ab/> cd <img x />";
    return s.find("img", -9, -2);
}

def find_empty_past_end -> int {
    s = "abc";
    return s.find("", 5);
}

def rfind_empty_window -> int {
    s = "ab/> cd <img x />";
    return s.rfind("", 0, 4);
}

def count_empty_window -> int {
    s = "ab/> cd <img x />";
    return s.count("", 0, 4);
}

def rfind_overlapping -> int {
    s = "aaa";
    return s.rfind("aa");
}

def index_window_miss -> int {
    s = "ab/> cd";
    try {
        return s.index("/>", 3);
    } except ValueError {
        return -7;
    }
}

def rindex_window_miss -> int {
    s = "ab/> cd";
    try {
        return s.rindex("/>", 0, 3);
    } except ValueError {
        return -7;
    }
}

def center_fill -> int {
    s = "ab";
    return 1 if s.center(7, "*") == "***ab**" else 0;
}

def ljust_fill -> int {
    s = "ab";
    return 1 if s.ljust(6, "-") == "ab----" else 0;
}

def rjust_zero_fill -> int {
    s = "7";
    return 1 if s.rjust(3, "0") == "007" else 0;
}

def center_multibyte_fill -> int {
    s = "ab";
    return 1 if s.center(6, "─") == "──ab──" else 0;
}

def center_default_fill -> int {
    s = "ab";
    return 1 if s.center(7) == "   ab  " else 0;
}

def pad_negative_width -> int {
    s = "abc";
    return 1 if s.center(-1) == "abc" and s.ljust(-5, "*") == "abc" else 0;
}

def pad_rejects_long_fill -> int {
    s = "ab";
    try {
        s.center(5, "**");
    } except TypeError {
        return 1;
    }
    return 0;
}

def list_index_from -> int {
    xs: list[int] = [7, 1, 7, 3];
    return xs.index(7, 1);
}

def list_index_negative_start -> int {
    xs: list[int] = [7, 1, 7, 3];
    return xs.index(7, -2);
}

def list_index_window_miss -> int {
    xs: list[int] = [7, 1, 7, 3];
    try {
        return xs.index(7, 3, 4);
    } except ValueError {
        return -7;
    }
}

def tuple_index_from -> int {
    t: tuple[int, int, int, int] = (7, 7, 1, 2);
    return t.index(7, 1);
}

def tuple_index_window_miss -> int {
    t: tuple[int, int, int, int] = (7, 7, 1, 2);
    try {
        return t.index(7, 2);
    } except ValueError {
        return -7;
    }
}

def tuple_index_miss -> int {
    t: tuple[int, int, int, int] = (7, 7, 1, 2);
    try {
        return t.index(9);
    } except ValueError {
        return -7;
    }
}

def set_union_many -> int {
    a: set[int] = {1};
    b: set[int] = {2};
    c: set[int] = {3, 1};
    return len(a.union(b, c));
}

def set_intersection_many -> int {
    a: set[int] = {1, 2, 3};
    b: set[int] = {1, 2};
    c: set[int] = {2, 3};
    return len(a.intersection(b, c));
}

def set_difference_many -> int {
    a: set[int] = {1, 2, 3, 4};
    b: set[int] = {1};
    c: set[int] = {4};
    return len(a.difference(b, c));
}

def set_update_many -> int {
    a: set[int] = {1};
    b: set[int] = {2};
    c: set[int] = {3};
    a.update(b, c);
    return len(a);
}

def set_intersection_update_many -> int {
    a: set[int] = {1, 2, 3};
    b: set[int] = {1, 2};
    c: set[int] = {2, 3};
    a.intersection_update(b, c);
    return len(a);
}

def set_difference_update_many -> int {
    a: set[int] = {1, 2, 3, 4};
    b: set[int] = {1};
    c: set[int] = {4};
    a.difference_update(b, c);
    return len(a);
}

def encode_utf8_names -> int {
    s = "héllo";
    return len(s.encode("utf-8")) * 100 + len(s.encode("UTF8", "strict"));
}

def zfill_three -> int {
    s = "7";
    return len(s.zfill(3));
}

def expandtabs_keyword -> int {
    s = "a\tb";
    return len(s.expandtabs(tabsize=2));
}

def to_bytes_signed_keyword -> int {
    n = -2;
    return len(n.to_bytes(2, "big", signed=True));
}

def encode_latin1 -> int {
    s = "é";
    return len(s.encode("latin-1"));
}
