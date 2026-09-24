import from jaclang.packages.semver {
    Requirement,
    SemverError,
    Version,
    VersionSet,
    caret_for
}

def _v(text: str) -> Version {
    return Version.parse(text);
}

def _allows(req: str, versions: list[str]) -> list[str] {
    r = Requirement.parse(req);
    return [
        v
        for v in versions
        if r.matches(_v(v))
    ];
}

glob LADDER: list[str] = [
         "0.0.3",
         "0.0.4",
         "0.2.3",
         "0.2.9",
         "0.3.0",
         "1.0.0",
         "1.2.0",
         "1.2.3",
         "1.2.9",
         "1.3.0",
         "1.9.9",
         "2.0.0-alpha.1",
         "2.0.0",
         "2.1.0"
     ];

test "versions order by precedence including pre-releases" {
    ordered = sorted(
        [
            _v(t)
            for t in ["1.0.0", "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-beta", "0.9.9"]
        ]
    );
    assert [str(v) for v in ordered]
        == ["0.9.9", "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-beta", "1.0.0"];
    assert _v("1.0.0+build.5") == _v("1.0.0");
    for bad in ["1.0", "01.0.0", "1.0.0.0", "v1.0.0", ""] {
        try {
            Version.parse(bad);
            assert False , bad;
        } except SemverError {}
    }
}

test "caret ranges follow the leftmost non-zero component" {
    assert _allows("^1.2.3", LADDER) == ["1.2.3", "1.2.9", "1.3.0", "1.9.9"];
    assert _allows("1.2.3", LADDER) == ["1.2.3", "1.2.9", "1.3.0", "1.9.9"];
    assert _allows("^0.2.3", LADDER) == ["0.2.3", "0.2.9"];
    assert _allows("^0.0.3", LADDER) == ["0.0.3"];
    assert _allows("^1", LADDER)
        == ["1.0.0", "1.2.0", "1.2.3", "1.2.9", "1.3.0", "1.9.9"];
}

test "tilde, comparator, wildcard and union forms" {
    assert _allows("~1.2.3", LADDER) == ["1.2.3", "1.2.9"];
    assert _allows(">=1.2.9, <2", LADDER) == ["1.2.9", "1.3.0", "1.9.9"];
    assert _allows("<=1.2", LADDER)[-1] == "1.2.9";
    assert _allows(">1.2", LADDER)[0] == "1.3.0";
    assert _allows("=1.2.3", LADDER) == ["1.2.3"];
    assert _allows("1.2.*", LADDER) == ["1.2.0", "1.2.3", "1.2.9"];
    assert _allows("^0.2 || ^2", LADDER) == ["0.2.3", "0.2.9", "2.0.0", "2.1.0"];
    assert _allows("*", LADDER)
        == [
            v
            for v in LADDER
            if "-" not in v
        ];
    assert _allows(">=2.0.0-alpha", LADDER) == ["2.0.0-alpha.1", "2.0.0", "2.1.0"];
}

test "version sets support the algebra the solver needs" {
    a = Requirement.parse("^1.2").versions;
    b = Requirement.parse(">=1.5, <3").versions;
    both = a.intersect(b);
    assert both.contains(_v("1.5.0")) and not both.contains(_v("1.4.0"));
    assert not both.contains(_v("2.0.0"));
    assert both.subset_of(a) and both.subset_of(b);
    assert a.union(b).contains(_v("2.5.0"));
    comp = a.complement();
    assert comp.contains(_v("1.1.0")) and comp.contains(_v("2.0.0"));
    assert not comp.contains(_v("1.2.0"));
    assert a.intersect(comp).is_empty();
    assert comp.complement().same_as(a);
    assert VersionSet.any_version().complement().is_empty();
    assert VersionSet.none().complement().is_any();
    assert Requirement.parse("^1").versions.disjoint(Requirement.parse("^2").versions);
}

test "a caret requirement is recorded for a chosen version" {
    assert caret_for(_v("1.4.2")) == "^1.4.2";
    assert caret_for(_v("1.4.2-rc.1")) == "^1.4.2";
}
