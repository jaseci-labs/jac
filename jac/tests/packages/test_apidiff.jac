import from jaclang.packages.apidiff {
    MAJOR,
    MINOR,
    PATCH,
    bump_level,
    check_bump,
    diff_surfaces,
    minimum_next,
    required_level
}
import from jaclang.packages.semver { Version }

def _fn(params: list[tuple[str, str, bool]], returns: str = "int") -> dict[str, any] {
    return {
        "kind": "function",
        "params": [
            {"name": n, "kind": "normal", "type": t, "default": d}
            for (n, t, d) in params
        ],
        "returns": returns
    };
}

def _node(fields: dict[str, tuple[str, bool]]) -> dict[str, any] {
    return {
        "kind": "node",
        "bases": [],
        "members": {
            n: {"kind": "field", "type": t, "default": d}
            for (n, (t, d)) in fields.items()
        }
    };
}

def _surface(symbols: dict[str, any]) -> dict[str, any] {
    return {"format": 1, "modules": {"kit": symbols}};
}

def _v(text: str) -> Version {
    return Version.parse(text);
}

test "additions are minor and an unchanged surface is a patch" {
    old = _surface({"f": _fn([("x", "int", False)])});
    same = diff_surfaces(old, old);
    assert same == [] and required_level(same) == PATCH;
    added = diff_surfaces(
        old, _surface({"f": _fn([("x", "int", False)]), "g": _fn([])})
    );
    assert required_level(added) == MINOR;
    optional = diff_surfaces(
        old, _surface({"f": _fn([("x", "int", False), ("y", "int", True)])})
    );
    assert required_level(optional) == MINOR;
}

test "removals and signature breaks are major" {
    old = _surface({"f": _fn([("x", "int", False)]), "g": _fn([])});
    assert required_level(
        diff_surfaces(old, _surface({"f": _fn([("x", "int", False)])}))
    )
        == MAJOR;
    required = diff_surfaces(
        old,
        _surface({"f": _fn([("x", "int", False), ("y", "int", False)]), "g": _fn([])})
    );
    assert required_level(required) == MAJOR;
    retyped = diff_surfaces(
        old, _surface({"f": _fn([("x", "str", False)]), "g": _fn([])})
    );
    assert required_level(retyped) == MAJOR;
    returns = diff_surfaces(
        old, _surface({"f": _fn([("x", "int", False)], "str"), "g": _fn([])})
    );
    assert required_level(returns) == MAJOR;
}

test "a changed node field is a persistence schema change" {
    old = _surface({"Person": _node({"name": ("str", False), "age": ("int", True)})});
    dropped = diff_surfaces(old, _surface({"Person": _node({"name": ("str", False)})}));
    assert required_level(dropped) == MAJOR;
    assert any(c.schema for c in dropped);
    widened = diff_surfaces(
        old,
        _surface(
            {
                "Person": _node(
                    {"name": ("str", False), "age": ("int", True), "bio": ("str", True)}
                )
            }
        )
    );
    assert required_level(widened) == MINOR;
    assert any(c.schema for c in widened);
}

test "version bumps are classified with pre-1.0 caret rules" {
    assert bump_level(_v("1.2.3"), _v("2.0.0")) == MAJOR;
    assert bump_level(_v("1.2.3"), _v("1.3.0")) == MINOR;
    assert bump_level(_v("1.2.3"), _v("1.2.4")) == PATCH;
    assert bump_level(_v("0.2.3"), _v("0.3.0")) == MAJOR;
    assert bump_level(_v("0.2.3"), _v("0.2.4")) == MINOR;
    assert bump_level(_v("0.0.3"), _v("0.0.4")) == MAJOR;
}

test "a bump smaller than the API change is refused with the smallest valid version" {
    old = _surface({"f": _fn([("x", "int", False)])});
    breaking = diff_surfaces(old, _surface({}));
    verdict = check_bump(_v("1.4.0"), _v("1.5.0"), breaking);
    assert "major" in verdict , verdict;
    assert str(minimum_next(_v("1.4.0"), breaking)) == "2.0.0";
    assert str(minimum_next(_v("0.4.1"), breaking)) == "0.5.0";
    assert check_bump(_v("1.4.0"), _v("2.0.0"), breaking) == "";
    assert "greater" in check_bump(_v("1.4.0"), _v("1.4.0"), []);
}
