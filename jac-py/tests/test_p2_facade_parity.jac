"""Semantic facade parity: native jacpython bisect/heapq/stat/_opcode vs host stdlib.

Modules/*.jac stay C-API hand oracles (byte-identity is getplatform-only).
"""

import bisect as host_bisect;
import heapq as host_heapq;
import stat as host_stat;
import _opcode as host_opcode;
import from _bisectmodule {
    _p2_bisect_right,
    _p2_bisect_left,
    _p2_insort,
    _p2_insort_left,
}
import from _heapqmodule { _p2_heappush, _p2_heappop, _p2_heapify }
import from _statmodule {
    _p2_S_ISDIR,
    _p2_S_ISCHR,
    _p2_S_ISBLK,
    _p2_S_ISREG,
    _p2_S_ISFIFO,
    _p2_S_ISLNK,
    _p2_S_ISSOCK,
    _p2_S_IMODE,
    _p2_S_IFMT,
    _p2_filemode,
}
import from _opcodemodule {
    _p2_stack_effect,
    _p2_is_valid,
    _p2_has_arg,
    _p2_has_const,
    _p2_has_name,
    _p2_has_jump,
    _p2_has_free,
    _p2_has_local,
    _p2_has_exc,
    _p2_get_nb_ops,
}


test "P2 bisect facade agrees with host bisect on representative cases" {
    cases: list = [
        ([], 1),
        ([1], 1),
        ([1, 2, 3], 2),
        ([1, 1, 2, 2], 1.5),
        ([1, 2, 2, 3, 3, 3, 4, 4, 4, 4], 3),
        ([0, 0, 0, 0], 0),
        (list(range(20)), 7),
    ];
    for (data, item) in cases {
        a = list(data);
        b = list(data);
        assert _p2_bisect_right(a, item) == host_bisect.bisect_right(b, item) , (
            f"bisect_right {data!r} {item!r}"
        );
        assert _p2_bisect_left(a, item) == host_bisect.bisect_left(b, item) , (
            f"bisect_left {data!r} {item!r}"
        );
    }
    a = [1, 2, 3];
    b = [1, 2, 3];
    assert _p2_bisect_right(a, 2, 0, 2) == host_bisect.bisect_right(b, 2, 0, 2);
    assert _p2_bisect_left(a, 2, 1, 3) == host_bisect.bisect_left(b, 2, 1, 3);

    d1 = [1, 3, 5];
    d2 = [1, 3, 5];
    _p2_insort(d1, 4);
    host_bisect.insort(d2, 4);
    assert d1 == d2 , d1;
    _p2_insort_left(d1, 3);
    host_bisect.insort_left(d2, 3);
    assert d1 == d2 , d1;
}

test "P2 heapq facade agrees with host heapq on representative cases" {
    src = [5, 1, 9, 3, 7, 2, 8, 4, 6, 0];
    a = list(src);
    b = list(src);
    _p2_heapify(a);
    host_heapq.heapify(b);
    assert a == b , (a, b);

    a = [];
    b = [];
    for x in [3, 1, 4, 1, 5, 9, 2, 6] {
        _p2_heappush(a, x);
        host_heapq.heappush(b, x);
        assert a == b , (a, b);
    }
    out_a: list = [];
    out_b: list = [];
    while a {
        out_a.append(_p2_heappop(a));
        out_b.append(host_heapq.heappop(b));
    }
    assert out_a == out_b , (out_a, out_b);
    assert out_a == sorted([3, 1, 4, 1, 5, 9, 2, 6]);
}

test "P2 stat facade agrees with host stat on representative modes" {
    modes: list = [
        0o000000, 0o100644, 0o100755, 0o040755, 0o120777,
        0o060600, 0o020666, 0o140000, 0o010000, 0o104710,
    ];
    for mode in modes {
        assert _p2_S_ISDIR(mode) == host_stat.S_ISDIR(mode) , mode;
        assert _p2_S_ISCHR(mode) == host_stat.S_ISCHR(mode) , mode;
        assert _p2_S_ISBLK(mode) == host_stat.S_ISBLK(mode) , mode;
        assert _p2_S_ISREG(mode) == host_stat.S_ISREG(mode) , mode;
        assert _p2_S_ISFIFO(mode) == host_stat.S_ISFIFO(mode) , mode;
        assert _p2_S_ISLNK(mode) == host_stat.S_ISLNK(mode) , mode;
        assert _p2_S_ISSOCK(mode) == host_stat.S_ISSOCK(mode) , mode;
        assert _p2_S_IMODE(mode) == host_stat.S_IMODE(mode) , mode;
        assert _p2_S_IFMT(mode) == host_stat.S_IFMT(mode) , mode;
        assert _p2_filemode(mode) == host_stat.filemode(mode) , mode;
    }
    for perm in [0, 0o400, 0o200, 0o100, 0o040, 0o020, 0o010, 0o004, 0o002, 0o001] {
        assert _p2_filemode(perm) == host_stat.filemode(perm) , perm;
    }
}

def _host_stack_effect(op: int, oparg: int | None = None, jump: int | None = None) -> int | None {
    try {
        if oparg is None and jump is None {
            return host_opcode.stack_effect(op);
        }
        if jump is None {
            return host_opcode.stack_effect(op, oparg);
        }
        return host_opcode.stack_effect(op, oparg, jump=bool(jump));
    } except ValueError {
        return None;
    }
}

test "P2 opcode facade agrees with host _opcode over the opcode space" {
    for op in range(-2, 300) {
        assert _p2_is_valid(op) == host_opcode.is_valid(op) , op;
        assert _p2_has_arg(op) == host_opcode.has_arg(op) , op;
        assert _p2_has_const(op) == host_opcode.has_const(op) , op;
        assert _p2_has_name(op) == host_opcode.has_name(op) , op;
        assert _p2_has_jump(op) == host_opcode.has_jump(op) , op;
        assert _p2_has_free(op) == host_opcode.has_free(op) , op;
        assert _p2_has_local(op) == host_opcode.has_local(op) , op;
        assert _p2_has_exc(op) == host_opcode.has_exc(op) , op;
    }
    # stack_effect: compare where both sides define an effect. The native
    # compiler only emits non-specialized opcodes; facade defers specialized
    # entries (deopt targets) which opcode_meta rejects by design.
    for op in range(0, 256) {
        if not _p2_is_valid(op) {
            continue;
        }
        got = _p2_stack_effect(op, None, None);
        want = _host_stack_effect(op);
        if got is None {
            continue;
        }
        assert got == want , (op, got, want);
        assert _p2_stack_effect(op, 0, 0) == _host_stack_effect(op, 0, 0) , op;
        assert _p2_stack_effect(op, 0, 1) == _host_stack_effect(op, 0, 1) , op;
    }
    nb_ops = _p2_get_nb_ops();
    assert len(nb_ops) == 27 , len(nb_ops);
    assert nb_ops[0] == ["NB_ADD", "+"] , nb_ops[0];
    assert nb_ops[26] == ["NB_SUBSCR", "[]"] , nb_ops[26];
}
