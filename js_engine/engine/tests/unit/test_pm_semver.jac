"""Unit tests for the semver port (engine/src/pm/semver.jac) against bun's
semantics (bun/src/semver).

Run from the repo root:  jac run engine/tests/unit/test_pm_semver.jac
"""

import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.pm.semver {
    SemVer,
    SemVerParse,
    SemGroup,
    semver_parse_version,
    semver_parse_exact,
    semver_format,
    semver_order,
    semver_parse_range,
    semver_satisfies,
    semver_group_is_exact,
    semver_group_is_any,
    semver_group_format,
    semver_sort,
    semver_tag_parse,
    WILD_NONE,
    WILD_MAJOR,
    WILD_MINOR,
    WILD_PATCH
}

glob _ok: int = 0,
     _fail: int = 0;

def check(cond: bool, name: str) {
    if cond {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + name);
    }
}

def check_eq(got: str, want: str, name: str) {
    if got == want {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + name + " — got '" + got + "' want '" + want + "'");
    }
}

def v(s: str) -> SemVer {
    r: tuple[bool, SemVer] = semver_parse_exact(s);
    return r[1];
}

def sat(range: str, version: str) -> bool {
    return semver_satisfies(semver_parse_range(range), v(version));
}

def check_sat(range: str, version: str) {
    check(
        sat(range, version),
        "'"
            + version
            + "' satisfies '"
            + range
            + "'  ["
            + semver_group_format(semver_parse_range(range))
            + "]"
    );
}

def check_nsat(range: str, version: str) {
    check(
        not sat(range, version),
        "'"
            + version
            + "' does not satisfy '"
            + range
            + "'  ["
            + semver_group_format(semver_parse_range(range))
            + "]"
    );
}

def order_str(a: str, b: str) -> str {
    return str(semver_order(v(a), v(b)));
}

with entry {
    # ── version parsing ──────────────────────────────────────────────────────
    p: SemVerParse = semver_parse_version("1.2.3");
    check(
        p.valid
            and p.ver.major == 1
            and p.ver.minor == 2
            and p.ver.patch == 3
            and p.wildcard == WILD_NONE
            and p.consumed == 5,
        "parse 1.2.3"
    );
    p = semver_parse_version("v1.2.3-beta.1+build.5");
    check(
        p.valid and p.ver.pre == "beta.1" and p.ver.build == "build.5",
        "parse v + pre + build"
    );
    check_eq(semver_format(p.ver), "1.2.3-beta.1+build.5", "format round trip");
    p = semver_parse_version("1.2");
    check(
        p.valid and p.wildcard == WILD_PATCH and p.has_minor and not p.has_patch,
        "partial 1.2 -> patch wildcard"
    );
    p = semver_parse_version("1");
    check(p.valid and p.wildcard == WILD_MINOR, "partial 1 -> minor wildcard");
    p = semver_parse_version("1.x");
    check(p.valid and p.wildcard == WILD_MINOR and p.consumed == 3, "1.x wildcard");
    p = semver_parse_version("*");
    check(p.valid and p.wildcard == WILD_MAJOR, "* wildcard");
    p = semver_parse_version("1.2.x");
    check(p.valid and p.wildcard == WILD_PATCH, "1.2.x wildcard");
    p = semver_parse_version("1.0.0rc.1");
    check(
        p.valid and p.ver.pre == "rc.1" and p.wildcard == WILD_NONE,
        "1.0.0rc.1 quirk -> prerelease rc.1"
    );
    p = semver_parse_version("1.2.3 <2");
    check(p.valid and p.consumed == 5, "stops at space");
    p = semver_parse_version("=1.2.3");
    check(p.valid and p.ver.major == 1, "leading = skipped");
    p = semver_parse_version("abc");
    check(not p.valid, "garbage invalid");
    p = semver_parse_version("");
    check(not p.valid, "empty invalid");
    p = semver_parse_version("1.2.3.4");
    check(
        not p.valid and p.consumed == 5,
        "fourth part makes it invalid (bun), 5 bytes consumed"
    );
    e: tuple[bool, SemVer] = semver_parse_exact("1.2.3");
    check(e[0], "exact ok");
    e = semver_parse_exact("1.2");
    check(not e[0], "exact rejects partial");
    e = semver_parse_exact("^1.2.3");
    check(not e[0], "exact rejects range");
    t: tuple[str, str, int] = semver_tag_parse("-alpha.1+001", 0);
    check_eq(
        t[0] + "|" + t[1] + "|" + str(t[2]), "alpha.1|001|12", "tag parse pre+build"
    );
    t = semver_tag_parse("+meta", 0);
    check_eq(t[0] + "|" + t[1], "|meta", "tag parse build only");
    t = semver_tag_parse("--canary.67e7966.0", 0);
    check_eq(t[0], "-canary.67e7966.0", "double-dash prerelease keeps inner dash");

    # ── ordering ─────────────────────────────────────────────────────────────
    check_eq(order_str("1.2.3", "1.2.4"), "-1", "order patch");
    check_eq(order_str("1.10.0", "1.9.0"), "1", "order numeric minor");
    check_eq(order_str("1.0.0-alpha", "1.0.0"), "-1", "prerelease < release");
    check_eq(
        order_str("1.0.0-alpha", "1.0.0-alpha.1"), "-1", "shorter prerelease first"
    );
    check_eq(
        order_str("1.0.0-alpha.1", "1.0.0-alpha.beta"), "-1", "numeric < alpha part"
    );
    check_eq(
        order_str("1.0.0-beta.11", "1.0.0-beta.2"),
        "1",
        "numeric parts compare as numbers"
    );
    check_eq(order_str("1.0.0-rc.1", "1.0.0-beta.11"), "1", "rc > beta");
    check_eq(order_str("1.0.0", "1.0.0"), "0", "equal");
    check_eq(
        order_str("1.0.0+b1", "1.0.0+b2"), "-1", "build breaks ties in full order"
    );
    sorted: list[SemVer] = semver_sort(
        [v("1.0.0"), v("0.9.0"), v("1.0.0-beta"), v("1.10.0"), v("1.2.0")]
    );
}

glob names: list[str] = [];
with entry {
    for s in sorted {
        names.append(semver_format(s));
    }
    check_eq(",".join(names), "0.9.0,1.0.0-beta,1.0.0,1.2.0,1.10.0", "sort ascending");

    # ── ranges: caret / tilde ────────────────────────────────────────────────
    check_eq(
        semver_group_format(semver_parse_range("^1.2.3")),
        ">=1.2.3 <2.0.0",
        "caret format"
    );
    check_sat("^1.2.3", "1.2.3");
    check_sat("^1.2.3", "1.9.9");
    check_nsat("^1.2.3", "2.0.0");
    check_nsat("^1.2.3", "1.2.2");
    check_sat("^0.2.3", "0.2.9");
    check_nsat("^0.2.3", "0.3.0");
    check_sat("^0.0.3", "0.0.3");
    check_nsat("^0.0.3", "0.0.4");
    check_sat("^1", "1.99.0");
    check_nsat("^1", "2.0.0");
    check_sat("^0.2", "0.2.5");
    check_nsat("^0.2", "0.3.0");
    check_sat("~1.2.3", "1.2.9");
    check_nsat("~1.2.3", "1.3.0");
    check_nsat("~1.2.3", "1.2.2");
    check_sat("~1.2", "1.2.0");
    check_nsat("~1.2", "1.3.0");
    check_sat("~1", "1.9.0");
    check_nsat("~1", "2.0.0");
    check_sat("~>1.2.3", "1.2.5");

    # ── ranges: comparators, wildcards, hyphen, OR ───────────────────────────
    check_sat(">=1.2.0 <2.0.0", "1.5.0");
    check_nsat(">=1.2.0 <2.0.0", "2.0.0");
    check_nsat(">=1.2.0 <2.0.0", "1.1.9");
    check_sat(">1.2.3", "1.2.4");
    check_nsat(">1.2.3", "1.2.3");
    check_sat("<=1.2.3", "1.2.3");
    check_nsat("<=1.2.3", "1.2.4");
    check_sat("1.x", "1.9.9");
    check_nsat("1.x", "2.0.0");
    check_sat("1.2.x", "1.2.9");
    check_nsat("1.2.x", "1.3.0");
    check_sat("*", "0.0.1");
    check_sat("*", "99.0.0");
    check_sat("", "1.0.0");
    check_sat("x", "3.2.1");
    check_sat("1.2.3 - 2.3.4", "2.0.0");
    check_sat("1.2.3 - 2.3.4", "2.3.4");
    check_nsat("1.2.3 - 2.3.4", "2.3.5");
    check_sat("1.2 - 2.3", "2.3.9");
    check_nsat("1.2 - 2.3", "2.4.0");
    check_sat("1.2.3 || 2.0.0", "2.0.0");
    check_sat("1.2.3 || 2.0.0", "1.2.3");
    check_nsat("1.2.3 || 2.0.0", "1.2.4");
    check_sat("^1.0.0 || ^2.0.0", "2.5.0");
    check_nsat("^1.0.0 || ^2.0.0", "3.0.0");
    check_sat("=1.2.3", "1.2.3");
    check_nsat("=1.2.3", "1.2.4");
    check_sat("v1.2.3", "1.2.3");
    check_sat("1.2.3", "1.2.3");
    check_nsat("1.2.3", "1.2.4");
    check_sat(">=1", "1.0.0");
    check_sat(">=1", "5.0.0");
    check_nsat(">=1", "0.9.0");
    check_sat("<2", "1.9.9");
    check_nsat("<2", "2.0.0");
    check_sat(">= 1.2.0", "1.2.0");
    check_sat("^18.0.0 || ^19.0.0", "18.3.1");
    check_sat("^4.0.0 || ^5.0.0 || ^6.0.0", "6.4.3");

    # ── prerelease rules ─────────────────────────────────────────────────────
    check_nsat("^1.2.3", "1.5.0-beta.1");
    check_sat("^1.2.3-alpha", "1.2.3-beta");
    check_nsat("^1.2.3-alpha", "1.3.0-beta");
    check_sat("^1.2.3-alpha", "1.3.0");
    check_sat(">=1.0.0-0", "1.0.0-alpha");
    check_nsat("*", "1.0.0-beta");
    check_sat("1.0.0-beta", "1.0.0-beta");
    check_sat("6.0.0-beta.1", "6.0.0-beta.1");
    check_nsat(">=2.0.0", "3.0.0-rc.1");
    check_nsat(">=2.0.0-0 <3.0.0", "2.5.0-alpha");
    check_nsat(">=2.0.0-0 <3.0.0", "3.0.0-alpha");

    # ── group helpers ────────────────────────────────────────────────────────
    check(semver_group_is_exact(semver_parse_range("1.2.3")), "exact group");
    check(not semver_group_is_exact(semver_parse_range("^1.2.3")), "caret not exact");
    check(semver_group_is_any(semver_parse_range("*")), "* is any");
    check(semver_group_is_any(semver_parse_range("")), "empty is any");
    check(not semver_group_is_any(semver_parse_range("^1.0.0")), "caret not any");
    check_eq(
        semver_group_format(semver_parse_range("~1.2.3")),
        ">=1.2.3 <1.3.0",
        "tilde format"
    );
    check_eq(
        semver_group_format(semver_parse_range("1.x")),
        "<2.0.0 >=1.0.0",
        "x-range format (bun's operand order)"
    );
    check_eq(
        semver_group_format(semver_parse_range("1.2.3 - 2.3.4")),
        ">=1.2.3 <=2.3.4",
        "hyphen format"
    );
    check(semver_parse_range("^1.0.0-beta").flag_pre, "pre flag recorded");

    print("pm_semver: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
