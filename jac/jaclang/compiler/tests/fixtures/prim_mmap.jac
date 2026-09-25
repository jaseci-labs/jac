"""Bundled native ``mmap`` cross-backend equivalence fixture.

The SAME ``import mmap`` binds CPython's ``mmap`` module on the sv (Python)
backend and the bundled ``na_stdlib/mmap.jac`` Mechanism-B module (over the
``_mmap_native`` OS FFI floors) on the na (native LLVM) backend. This fixture
pins the two congruent using anonymous mappings, which both lanes can create
with ``mmap.mmap(-1, length)``.

Byte results are compared via ``_digest`` of ``read`` output --
raw ``bytes`` cannot be marshalled across the sv/na boundary.

Dunder divergence: the na pathway does not dispatch operator syntax to
dunder methods on objs, so BOTH lanes call them explicitly
(``m.__getitem__``, ``m.__setitem__``, ``m.__len__``) -- explicit calls are
legal on CPython too.

Not exercised (documented na divergences or platform-dependent):
  - ``m[1:3]`` slicing, file-backed maps (so ``size()``'s live fstat path
    and file-backed resize refusal are pinned only by type, not exercised
    end to end), ``ACCESS_COPY`` semantics.
  - the shared-anonymous ``resize`` refusal IS pinned, with the sv lane
    stripping CPython < 3.14.7's `` on <os>`` suffix so the pin survives
    bundled-runtime bumps.

ES/JS opts out (``mmap_cl`` returns an empty dict).
"""

import mmap;


def _digest(data: bytes) -> int {
    acc: int = 2166136261;
    n: int = len(data);
    i: int = 0;
    while i < n {
        acc = (acc * 131 + data[i]) % 2147483647;
        i += 1;
    }
    return acc;
}


def mmap_py -> dict[any, any] {
    m = mmap.mmap(-1, 64);
    m.write(b"hello mmap world");
    m.seek(0);
    first = m.read(5);
    m.__setitem__(0, 74);
    m.seek(6);
    m.write_byte(88);
    m.seek(0);
    whole = m.read(16);
    r: dict[str, any] = {
        "len": m.__len__(),
        "g0": m.__getitem__(0),
        "g6": m.__getitem__(6),
        "read5_digest": _digest(first),
        "whole_digest": _digest(whole),
        "find": m.find(b"mmap"),
        "rfind": m.rfind(b"o"),
        "find_none": m.find(b"zzz"),
        "tell_after": m.tell(),
        "readbyte": m.read_byte()
    };
    m.seek(0);
    r["find2"] = m.find(b"mmap");
    r["rfind2"] = m.rfind(b"o");
    m.move(20, 0, 5);
    m.seek(20);
    r["move_digest"] = _digest(m.read(5));
    m.close();
    pm = mmap.mmap(-1, 64, access=mmap.ACCESS_WRITE);
    pm.write(b"hello mmap world");
    try {
        pm.resize(128);
        r["err_resize"] = "noraise";
    } except ValueError as e {
        # CPython < 3.14.7 words this "mmap: can't expand a shared anonymous
        # mapping on Linux"; the " on <os>" suffix was dropped in 3.14.7.
        # Strip it so the pin survives bundled-runtime bumps -- the na
        # surface carries the suffix-less text.
        r["err_resize"] = str(e).split(" on ")[0];
    }
    pm.close();
    m2 = mmap.mmap(-1, 64);
    m2.seek(0);
    m2.seek(2, 1);
    r["seek_cur"] = m2.tell();
    m2.seek(-2, 2);
    r["seek_end"] = m2.tell();
    try {
        m2.seek(999);
        r["err_seek"] = "noraise";
    } except ValueError as e {
        r["err_seek"] = str(e);
    }
    try {
        m2.__setitem__(200, 65);
        r["err_setitem"] = "noraise";
    } except IndexError as e {
        r["err_setitem"] = str(e);
    }
    try {
        m2.__getitem__(200);
        r["err_getitem"] = "noraise";
    } except IndexError as e {
        r["err_getitem"] = str(e);
    }
    m2.close();
    r["closed"] = 1 if m2.closed else 0;
    try {
        m2.read(1);
        r["err_closed"] = "noraise";
    } except ValueError as e {
        r["err_closed"] = str(e);
    }
    ro = mmap.mmap(-1, 32, access=mmap.ACCESS_READ);
    try {
        ro.write(b"x");
        r["err_rote"] = "noraise";
    } except TypeError as e {
        r["err_rote"] = str(e);
    }
    try {
        ro.resize(16);
        r["err_ro_resize"] = "noraise";
    } except TypeError as e {
        r["err_ro_resize"] = str(e);
    }
    ro.close();
    # size() answers the FILE size like CPython's fstat; an anonymous map has
    # no fd, so both lanes raise CPython's EBADF OSError.
    sz = mmap.mmap(-1, 64);
    try {
        sz.size();
        r["err_anon_size"] = "noraise";
    } except OSError as e {
        r["err_anon_size"] = str(e);
    }
    sz.close();
    # context-manager protocol: __exit__ closes on scope exit, both lanes.
    with mmap.mmap(-1, 8) as wm {
        wm.write(b"ok");
        wm.seek(0);
        r["wm_read_digest"] = _digest(wm.read(2));
    }
    # init validation: negative length/offset and fd errors. The fd-branch
    # checks fire before the fd is touched, so a bogus fd (-5) pins them on
    # both lanes without needing a real file.
    try {
        mmap.mmap(-1, -5);
        r["err_anon_neg"] = "noraise";
    } except OverflowError as e {
        r["err_anon_neg"] = str(e);
    }
    try {
        mmap.mmap(-1, 0);
        r["err_anon_zero"] = "noraise";
    } except OSError as e {
        r["err_anon_zero"] = str(e);
    }
    try {
        mmap.mmap(-5, -1);
        r["err_fd_neg_len"] = "noraise";
    } except OverflowError as e {
        r["err_fd_neg_len"] = str(e);
    }
    try {
        mmap.mmap(-5, 10, offset=-1);
        r["err_fd_neg_off"] = "noraise";
    } except OverflowError as e {
        r["err_fd_neg_off"] = str(e);
    }
    try {
        mmap.mmap(-5, 100);
        r["err_fd_bad"] = "noraise";
    } except OSError as e {
        r["err_fd_bad"] = str(e);
    }
    try {
        mmap.mmap(-1, 64, offset=-1);
        r["err_anon_neg_off"] = "noraise";
    } except OverflowError as e {
        r["err_anon_neg_off"] = str(e);
    }
    # item/write_byte range checks and whence/flush/move/resize validation
    m3 = mmap.mmap(-1, 16);
    try {
        m3.__setitem__(0, 300);
        r["err_setitem_range"] = "noraise";
    } except ValueError as e {
        r["err_setitem_range"] = str(e);
    }
    try {
        m3.__setitem__(0, -1);
        r["err_setitem_neg"] = "noraise";
    } except ValueError as e {
        r["err_setitem_neg"] = str(e);
    }
    try {
        m3.write_byte(-1);
        r["err_wb_neg"] = "noraise";
    } except OverflowError as e {
        r["err_wb_neg"] = str(e);
    }
    try {
        m3.write_byte(300);
        r["err_wb_big"] = "noraise";
    } except OverflowError as e {
        r["err_wb_big"] = str(e);
    }
    r["after_range_g0"] = m3.__getitem__(0);
    try {
        m3.seek(0, 5);
        r["err_whence"] = "noraise";
    } except ValueError as e {
        r["err_whence"] = str(e);
    }
    try {
        m3.flush(-1);
        r["err_flush"] = "noraise";
    } except ValueError as e {
        r["err_flush"] = str(e);
    }
    try {
        m3.move(-1, 0, 1);
        r["err_move"] = "noraise";
    } except ValueError as e {
        r["err_move"] = str(e);
    }
    try {
        m3.resize(-1);
        r["err_resize_neg"] = "noraise";
    } except ValueError as e {
        r["err_resize_neg"] = str(e);
    }
    m3.close();
    # find/rfind: defaults scan from pos to end; explicit negatives are
    # slice-adjusted (+= size, clamped)
    mb = mmap.mmap(-1, 10);
    mb.write(b"x........x");
    r["find_default_pos10"] = mb.find(b"x");
    r["rfind_default_pos10"] = mb.rfind(b"x");
    mb.seek(0);
    r["find_all"] = mb.find(b"x");
    r["rfind_all"] = mb.rfind(b"x");
    r["find_excl_last"] = mb.find(b"x", 0, -1);
    r["rfind_excl_last"] = mb.rfind(b"x", 0, -1);
    mb.seek(5);
    r["find_neg_start"] = mb.find(b"x", -100);
    r["rfind_neg_start"] = mb.rfind(b"x", -100);
    r["find_default_pos5"] = mb.find(b"x");
    r["rfind_default_pos5"] = mb.rfind(b"x");
    mb.close();
    return r;
}


def mmap_cl -> dict[any, any] {
    return {};
}


def _digest_na(data: bytes) -> int {
    acc: int = 2166136261;
    n: int = len(data);
    i: int = 0;
    while i < n {
        acc = (acc * 131 + data[i]) % 2147483647;
        i += 1;
    }
    return acc;
}


def _core_na(r: dict[str, any]) {
    m = mmap.mmap(-1, 64);
    m.write(b"hello mmap world");
    m.seek(0);
    first = m.read(5);
    m.__setitem__(0, 74);
    m.seek(6);
    m.write_byte(88);
    m.seek(0);
    whole = m.read(16);
    r["len"] = m.__len__();
    r["g0"] = m.__getitem__(0);
    r["g6"] = m.__getitem__(6);
    r["read5_digest"] = _digest_na(first);
    r["whole_digest"] = _digest_na(whole);
    r["find"] = m.find(b"mmap");
    r["rfind"] = m.rfind(b"o");
    r["find_none"] = m.find(b"zzz");
    r["tell_after"] = m.tell();
    r["readbyte"] = m.read_byte();
    m.seek(0);
    r["find2"] = m.find(b"mmap");
    r["rfind2"] = m.rfind(b"o");
    m.move(20, 0, 5);
    m.seek(20);
    r["move_digest"] = _digest_na(m.read(5));
    m.close();
}


def _seek_resize_na(r: dict[str, any]) {
    # ACCESS_WRITE maps are MAP_SHARED; both lanes refuse to EXPAND a shared
    # anonymous mapping. The na surface carries the suffix-less CPython
    # 3.14.7+ text; the sv lane strips the " on <os>" suffix its older
    # runtime appends, so the compared values agree on any bundled runtime.
    pm = mmap.mmap(-1, 64, access=mmap.ACCESS_WRITE);
    pm.write(b"hello mmap world");
    try {
        pm.resize(128);
        r["err_resize"] = "noraise";
    } except ValueError as e {
        r["err_resize"] = str(e);
    }
    pm.close();
    m = mmap.mmap(-1, 64);
    m.seek(0);
    m.seek(2, 1);
    r["seek_cur"] = m.tell();
    m.seek(-2, 2);
    r["seek_end"] = m.tell();
    m.close();
}


def _err_na(r: dict[str, any]) {
    m = mmap.mmap(-1, 64);
    m.write(b"hello mmap world");
    try {
        m.seek(999);
        r["err_seek"] = "noraise";
    } except ValueError as e {
        r["err_seek"] = str(e);
    }
    try {
        m.__setitem__(200, 65);
        r["err_setitem"] = "noraise";
    } except IndexError as e {
        r["err_setitem"] = str(e);
    }
    try {
        m.__getitem__(200);
        r["err_getitem"] = "noraise";
    } except IndexError as e {
        r["err_getitem"] = str(e);
    }
    m.close();
    r["closed"] = 1 if m.closed else 0;
    try {
        m.read(1);
        r["err_closed"] = "noraise";
    } except ValueError as e {
        r["err_closed"] = str(e);
    }
    ro = mmap.mmap(-1, 32, access=mmap.ACCESS_READ);
    try {
        ro.write(b"x");
        r["err_rote"] = "noraise";
    } except TypeError as e {
        r["err_rote"] = str(e);
    }
    try {
        ro.resize(16);
        r["err_ro_resize"] = "noraise";
    } except TypeError as e {
        r["err_ro_resize"] = str(e);
    }
    ro.close();
    sz = mmap.mmap(-1, 64);
    try {
        sz.size();
        r["err_anon_size"] = "noraise";
    } except OSError as e {
        r["err_anon_size"] = str(e);
    }
    sz.close();
    with mmap.mmap(-1, 8) as wm {
        wm.write(b"ok");
        wm.seek(0);
        r["wm_read_digest"] = _digest_na(wm.read(2));
    }
}


def _init_err_na(r: dict[str, any]) {
    # The fd-branch checks fire before the fd is touched, so a bogus fd (-5)
    # pins them on both lanes without needing a real file.
    try {
        mmap.mmap(-1, -5);
        r["err_anon_neg"] = "noraise";
    } except OverflowError as e {
        r["err_anon_neg"] = str(e);
    }
    try {
        mmap.mmap(-1, 0);
        r["err_anon_zero"] = "noraise";
    } except OSError as e {
        r["err_anon_zero"] = str(e);
    }
    try {
        mmap.mmap(-5, -1);
        r["err_fd_neg_len"] = "noraise";
    } except OverflowError as e {
        r["err_fd_neg_len"] = str(e);
    }
    try {
        mmap.mmap(-5, 10, offset=-1);
        r["err_fd_neg_off"] = "noraise";
    } except OverflowError as e {
        r["err_fd_neg_off"] = str(e);
    }
    try {
        mmap.mmap(-5, 100);
        r["err_fd_bad"] = "noraise";
    } except OSError as e {
        r["err_fd_bad"] = str(e);
    }
    try {
        mmap.mmap(-1, 64, offset=-1);
        r["err_anon_neg_off"] = "noraise";
    } except OverflowError as e {
        r["err_anon_neg_off"] = str(e);
    }
}


def _mask_na(r: dict[str, any]) {
    m3 = mmap.mmap(-1, 16);
    try {
        m3.__setitem__(0, 300);
        r["err_setitem_range"] = "noraise";
    } except ValueError as e {
        r["err_setitem_range"] = str(e);
    }
    try {
        m3.__setitem__(0, -1);
        r["err_setitem_neg"] = "noraise";
    } except ValueError as e {
        r["err_setitem_neg"] = str(e);
    }
    try {
        m3.write_byte(-1);
        r["err_wb_neg"] = "noraise";
    } except OverflowError as e {
        r["err_wb_neg"] = str(e);
    }
    try {
        m3.write_byte(300);
        r["err_wb_big"] = "noraise";
    } except OverflowError as e {
        r["err_wb_big"] = str(e);
    }
    r["after_range_g0"] = m3.__getitem__(0);
    try {
        m3.seek(0, 5);
        r["err_whence"] = "noraise";
    } except ValueError as e {
        r["err_whence"] = str(e);
    }
    try {
        m3.flush(-1);
        r["err_flush"] = "noraise";
    } except ValueError as e {
        r["err_flush"] = str(e);
    }
    try {
        m3.move(-1, 0, 1);
        r["err_move"] = "noraise";
    } except ValueError as e {
        r["err_move"] = str(e);
    }
    try {
        m3.resize(-1);
        r["err_resize_neg"] = "noraise";
    } except ValueError as e {
        r["err_resize_neg"] = str(e);
    }
    m3.close();
}


def _bounds_na(r: dict[str, any]) {
    mb = mmap.mmap(-1, 10);
    mb.write(b"x........x");
    r["find_default_pos10"] = mb.find(b"x");
    r["rfind_default_pos10"] = mb.rfind(b"x");
    mb.seek(0);
    r["find_all"] = mb.find(b"x");
    r["rfind_all"] = mb.rfind(b"x");
    r["find_excl_last"] = mb.find(b"x", 0, -1);
    r["rfind_excl_last"] = mb.rfind(b"x", 0, -1);
    mb.seek(5);
    r["find_neg_start"] = mb.find(b"x", -100);
    r["rfind_neg_start"] = mb.rfind(b"x", -100);
    r["find_default_pos5"] = mb.find(b"x");
    r["rfind_default_pos5"] = mb.rfind(b"x");
    mb.close();
}


def mmap_na -> dict[str, any] {
    r: dict[str, any] = {};
    _core_na(r);
    _seek_resize_na(r);
    _err_na(r);
    _init_err_na(r);
    _mask_na(r);
    _bounds_na(r);
    return r;
}
