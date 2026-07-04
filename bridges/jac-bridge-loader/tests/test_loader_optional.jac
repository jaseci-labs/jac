# OPT-bit (nullable Option<T>) return handling in the jac rust-bridge loader.
#
# The `owning` bridge (jac-bridge-owning) exercises every nullable shape the D2
# ABI carries:
#   * Regex.find      -> Option<Ref>  (OwnedMatch handle, or None)
#   * Regex.captures  -> Option<Ref>  (OwnedCaptures handle, or None)
#   * OwnedCaptures.name -> Option<Str>  (matched group text, or None)
#
# None crosses in-band on an OK status -- a null handle for Option<Ref>, a null
# JacBuf.ptr for Option<Str> -- and the loader must map it to Python `None`, not
# a zero handle or an empty string.
import from jaclang.compiler.rust_bridge { load_bridge }
import from jaclang.compiler.rust_bridge._blob { TAG_OPT_BIT, TAG_REF_BIT, TAG_STR }
import from _fixtures { owning_so }


glob _MOD = load_bridge(owning_so()),
     _Regex = _MOD.Regex;


# -- metadata: the OPT bit is set on exactly the nullable returns --------------
test "find ret is opt ref" {
    fd = [
        f
        for f in _MOD._meta.fns
        if f.name == "find"
    ][0];
    assert fd.ret & TAG_OPT_BIT , "find must set TAG_OPT_BIT";
    assert fd.ret & TAG_REF_BIT , "find must set TAG_REF_BIT (Option<Ref>)";
}

test "name ret is opt str" {
    fd = [
        f
        for f in _MOD._meta.fns
        if f.name == "name"
    ][0];
    assert fd.ret == (TAG_OPT_BIT | TAG_STR) , "name must be Option<Str>";
}

test "as_str ret is plain str" {
    # The non-nullable reader must NOT carry the OPT bit.
    fd = [
        f
        for f in _MOD._meta.fns
        if f.name == "as_str"
    ][0];
    assert fd.ret == TAG_STR;
}


# -- Option<Ref>: find returns a handle on a match, None otherwise -------------
test "find match returns wrapper" {
    with _Regex(r"\d+") as re {
        m = re.find("abc123def");
        assert m is not None;
        assert m.as_str() == "123";
        m.close();
    }
}

test "find no match returns none" {
    with _Regex(r"\d+") as re {
        assert re.find("no digits here") is None;
    }
}

test "find empty match is not none" {
    # An empty (zero-width) match is a real match -- must be a handle, not None.
    with _Regex(r"") as re {
        m = re.find("anything");
        assert m is not None;
        assert m.as_str() == "";
        m.close();
    }
}

test "returned wrapper is a context manager" {
    with _Regex(r"\w+") as re {
        with re.find("hello") as m {
            assert m.as_str() == "hello";
        }
    }
}

test "returned wrapper drops cleanly" {
    # No explicit close: GC/finalizer path must drop the wrapper handle.
    with _Regex(r"\d+") as re {
        for _i in range(200) {
            m = re.find("x1");
            assert m.as_str() == "1";
            # deliberately drop the reference without close()
        }
    }
}


# -- Option<Ref>: captures behaves the same -----------------------------------
test "captures no match returns none" {
    with _Regex(r"(\d+)-(\d+)") as re {
        assert re.captures("nothing") is None;
    }
}


# -- Option<Str>: OwnedCaptures.name yields text or None ----------------------
test "named group present returns str" {
    with _Regex(r"(?P<year>\d{4})") as re {
        caps = re.captures("in 2026 today");
        assert caps is not None;
        assert caps.name("year") == "2026";
        caps.close();
    }
}

test "named group absent returns none" {
    # Group exists in the pattern but a non-matching alternation branch means it
    # did not participate -> Option<Str> None, distinct from an empty string.
    with _Regex(r"(?P<a>x)|(?P<b>y)") as re {
        caps = re.captures("y");
        assert caps is not None;
        assert caps.name("a") is None;  # 'a' did not participate
        assert caps.name("b") == "y";
        caps.close();
    }
}

test "unknown group name returns none" {
    with _Regex(r"(?P<g>\d+)") as re {
        caps = re.captures("42");
        assert caps is not None;
        assert caps.name("nonexistent") is None;
        caps.close();
    }
}
