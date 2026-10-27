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
import from jaclang.packages.api { api_shape, package_surface, surface_digest }
import from jaclang.packages.semver { Version }
import from tests.packages.fixture_registry { fresh_dir, write_tree }

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

"""Diff a function and a method declared with each parameter list, using
the surfaces the compiler extracts from real source."""
def _source_diff(old_params: str, new_params: str) -> list[any] {
    tmp = fresh_dir("jac-apidiff-");
    surfaces: list[dict[str, any]] = [];
    for (tag, params) in [("old", old_params), ("new", new_params)] {
        body = "(" + params + ") -> int {\n    return 0;\n}\n";
        write_tree(
            tmp / tag,
            {"kit.jac": "def f" + body + "obj Box {\n    def f" + body + "}\n"}
        );
        surfaces.append(package_surface(tmp / tag, ["kit"]));
    }
    return diff_surfaces(surfaces[0], surfaces[1]);
}

"""The surface the compiler extracts from a `kit` module with this source."""
def _kit_surface(tmp: any, tag: str, src: str) -> dict[str, any] {
    write_tree(tmp / tag, {"kit.jac": src});
    return package_surface(tmp / tag, ["kit"]);
}

def _kit_diff(old_src: str, new_src: str) -> list[any] {
    tmp = fresh_dir("jac-apidiff-");
    return diff_surfaces(
        _kit_surface(tmp, "old", old_src), _kit_surface(tmp, "new", new_src)
    );
}

def _level_at(changes: list[any], path: str) -> int {
    return required_level(
        [
            c
            for c in changes
            if c.path == path
        ]
    );
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

test "an added parameter that takes an existing positional argument is major" {
    for (old, new) in [
        ("a: int = 10", "b: int = 20, a: int = 10"),
        ("a: int, c: int = 30", "a: int, b: int = 20, c: int = 30"),
        ("a: int, *rest: int", "a: int, b: int = 20, *rest: int"),
        ("a: int = 10, /", "b: int = 20, a: int = 10, /"),
        ("a: int, /, *rest: int", "a: int, b: int = 20, /, *rest: int"),
        ("a: int = 10, b: int = 20", "b: int = 20, a: int = 10")
    ] {
        changes = _source_diff(old, new);
        for path in ("kit.f", "kit.Box.f") {
            assert _level_at(changes, path) == MAJOR , (old, new, path, changes);
        }
        assert "major" in check_bump(_v("1.4.0"), _v("1.5.0"), changes);
        assert str(minimum_next(_v("1.4.0"), changes)) == "2.0.0";
        assert str(minimum_next(_v("0.4.1"), changes)) == "0.5.0";
    }
}

test "an added parameter past every positional slot stays minor" {
    for (old, new) in [
        ("a: int = 10", "a: int = 10, b: int = 20"),
        ("a: int = 10", "a: int = 10, *, b: int = 20"),
        ("a: int = 10, /", "a: int = 10, /, b: int = 20"),
        ("a: int, *rest: int", "a: int, *rest: int, b: int = 20"),
        ("a: int", "a: int, *rest: int")
    ] {
        changes = _source_diff(old, new);
        for path in ("kit.f", "kit.Box.f") {
            assert _level_at(changes, path) == MINOR , (old, new, path, changes);
        }
        assert check_bump(_v("1.4.0"), _v("1.5.0"), changes) == "";
    }
}

glob BASE_AND_CHILD: str = "obj Base {\n    has a: int = 1;\n}\n\nobj C(Base) {\n    has c: int = 3;\n}\n",
     PRIVATE_BASE_AND_CHILD: str = "obj _Base {\n    has a: int = 1;\n}\n\nobj C(_Base) {\n    has c: int = 3;\n}\n";

test "a field that moves an existing constructor argument is major" {
    rows = [
        (
            "a field inserted before an existing one",
            "obj Foo {\n    has a: int = 1;\n}\n",
            "obj Foo {\n    has b: int = 2;\n    has a: int = 1;\n}\n",
            "kit.Foo"
        ),
        (
            "fields reordered",
            "obj Foo {\n    has a: int = 1;\n    has b: int = 2;\n}\n",
            "obj Foo {\n    has b: int = 2;\n    has a: int = 1;\n}\n",
            "kit.Foo"
        ),
        (
            "a field added to a base class",
            BASE_AND_CHILD,
            BASE_AND_CHILD.replace(
                "has a: int = 1;", "has a: int = 1;\n    has b: int = 2;"
            ),
            "kit.C"
        ),
        (
            "a field removed from a private base class",
            PRIVATE_BASE_AND_CHILD,
            PRIVATE_BASE_AND_CHILD.replace("    has a: int = 1;\n", ""),
            "kit.C"
        ),
        (
            "a field added to a private base class",
            PRIVATE_BASE_AND_CHILD.replace("    has a: int = 1;\n", ""),
            PRIVATE_BASE_AND_CHILD,
            "kit.C"
        ),
        (
            "a required field added to a private base class",
            "obj _Base {\n    has x: int;\n}\n\nobj C(_Base) {}\n",
            "obj _Base {\n    has x: int;\n    has b: int;\n}\n\nobj C(_Base) {}\n",
            "kit.C"
        ),
        (
            "a node field inserted before an existing one",
            "node P {\n    has name: str = \"\";\n}\n",
            "node P {\n    has age: int = 0;\n    has name: str = \"\";\n}\n",
            "kit.P"
        )
    ];
    for (label, old, new, path) in rows {
        changes = _kit_diff(old, new);
        assert _level_at(changes, path) == MAJOR , (label, changes);
        assert str(minimum_next(_v("1.4.0"), changes)) == "2.0.0" , (label, changes);
    }
}

test "a field that leaves every existing constructor argument in place is not major" {
    rows = [
        (
            "a field appended",
            "obj Foo {\n    has a: int = 1;\n}\n",
            "obj Foo {\n    has a: int = 1;\n    has b: int = 2;\n}\n",
            MINOR
        ),
        (
            "a field appended to a subclass",
            BASE_AND_CHILD,
            BASE_AND_CHILD.replace(
                "has c: int = 3;", "has c: int = 3;\n    has d: int = 4;"
            ),
            MINOR
        ),
        (
            "fields reordered behind a user-defined init",
            "obj U {\n    has a: int = 1;\n    has b: int = 2;\n\n    def init(x: int) {\n        self.a = x;\n    }\n}\n",
            "obj U {\n    has b: int = 2;\n    has a: int = 1;\n\n    def init(x: int) {\n        self.a = x;\n    }\n}\n",
            PATCH
        )
    ];
    for (label, old, new, level) in rows {
        changes = _kit_diff(old, new);
        assert required_level(changes) == level , (label, changes);
    }
}

test "a surface from before API format 2 skips the order check and keeps its digest" {
    import hashlib;
    import json;
    tmp = fresh_dir("jac-apidiff-");
    old = _kit_surface(
        tmp, "old", "obj Foo {\n    has a: int = 1;\n    has b: int = 2;\n}\n"
    );
    new = _kit_surface(
        tmp, "new", "obj Foo {\n    has b: int = 2;\n    has a: int = 1;\n}\n"
    );
    assert old["modules"]["kit"]["Foo"]["positional_fields"] == ["a", "b"];
    legacy = {
        "format": 1,
        "modules": {
            "kit": {
                name: {
                    k: v
                    for (k, v) in d.items()
                    if k not in ("positional_fields", "required_fields")
                } for (name, d) in old["modules"]["kit"].items()
            }
        }
    };
    assert diff_surfaces(legacy, new) == [];
    published = "sha256:"
        + hashlib.sha256(
            json.dumps(
                api_shape(legacy), sort_keys=True, separators=(",", ":")
            ).encode()
        ).hexdigest();
    assert surface_digest(old, 1) == published;
    assert surface_digest(old) != published;
}
