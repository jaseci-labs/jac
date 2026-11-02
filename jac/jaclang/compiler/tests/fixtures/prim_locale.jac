"""Bundled native `locale` cross-backend equivalence fixture (#6978).

The same `import locale` binds CPython's `locale` (a thin layer over the C
library) on the sv backend and `na_stdlib/locale.jac` over the same
`setlocale(3)`/`localeconv(3)`/`strcoll(3)` on the na (native LLVM) backend.
Both lanes are pinned in the `C` locale so `localeconv()` is deterministic.
The alias engine (`normalize`) is table driven from CPython's own
`locale_alias`/`locale_encoding_alias`, including the `@euro` modifier path,
the `:`-as-encoding-delimiter path, and the unknown-name passthrough.
`locale.Error` is caught by its exact class: a parent-class `except` arm does not
catch a module-defined subclass on the ctypes-JIT path (jaseci-labs/jac#9380), so
`except Exception` would let the raise escape and abort the JIT with no
diagnostic. The `currency` failure is a genuine builtin `ValueError`.
ES/JS opts out.
"""

import locale;


def locale_py -> dict[any, any] {
    en = locale.normalize("en_US.UTF-8");
    de = locale.normalize("de");
    ja = locale.normalize("ja_JP");
    fr_euro = locale.normalize("fr_FR@euro");
    unknown = locale.normalize("zz_ZZ.NOPE");
    colon = locale.normalize("en_US:UTF-8");
    c_loc = locale.setlocale(locale.LC_ALL, "C");
    conv = locale.localeconv();
    coll_eq = locale.strcoll("abc", "abc");
    coll_lt = 1 if locale.strcoll("abc", "abd") < 0 else 0;
    coll_gt = 1 if locale.strcoll("abd", "abc") > 0 else 0;
    err = "";
    try {
        locale.setlocale(locale.LC_ALL, "xx_YY.NOPE-NOPE");
    } except locale.Error as e {
        err = str(e);
    }
    curr_err = "";
    try {
        locale.currency(1.5);
    } except ValueError as e {
        curr_err = str(e);
    }
    return {
        "lc_all_gt_zero": 1 if locale.LC_ALL >= 0 else 0,
        "char_max": locale.CHAR_MAX,
        "n_en": en,
        "n_de": de,
        "n_ja": ja,
        "n_fr_euro": fr_euro,
        "n_unknown": unknown,
        "n_colon": colon,
        "c_locale": c_loc,
        "dp": conv["decimal_point"],
        "ts": conv["thousands_sep"],
        "frac_digits": conv["frac_digits"],
        "coll_eq": coll_eq,
        "coll_lt": coll_lt,
        "coll_gt": coll_gt,
        "delocalized": locale.delocalize("1234.5"),
        "atof": locale.atof("12.5"),
        "atoi": locale.atoi("42"),
        "err": err,
        "curr_err": curr_err,

    };
}


def locale_cl -> dict[any, any] {
    return {};
}


def locale_na -> dict[str, any] {
    en = locale.normalize("en_US.UTF-8");
    de = locale.normalize("de");
    ja = locale.normalize("ja_JP");
    fr_euro = locale.normalize("fr_FR@euro");
    unknown = locale.normalize("zz_ZZ.NOPE");
    colon = locale.normalize("en_US:UTF-8");
    c_loc = locale.setlocale(locale.LC_ALL, "C");
    conv = locale.localeconv();
    coll_eq = locale.strcoll("abc", "abc");
    coll_lt = 1 if locale.strcoll("abc", "abd") < 0 else 0;
    coll_gt = 1 if locale.strcoll("abd", "abc") > 0 else 0;
    err = "";
    try {
        locale.setlocale(locale.LC_ALL, "xx_YY.NOPE-NOPE");
    } except locale.Error as e {
        err = str(e);
    }
    curr_err = "";
    try {
        locale.currency(1.5);
    } except ValueError as e {
        curr_err = str(e);
    }
    return {
        "lc_all_gt_zero": 1 if locale.LC_ALL >= 0 else 0,
        "char_max": locale.CHAR_MAX,
        "n_en": en,
        "n_de": de,
        "n_ja": ja,
        "n_fr_euro": fr_euro,
        "n_unknown": unknown,
        "n_colon": colon,
        "c_locale": c_loc,
        "dp": conv["decimal_point"],
        "ts": conv["thousands_sep"],
        "frac_digits": conv["frac_digits"],
        "coll_eq": coll_eq,
        "coll_lt": coll_lt,
        "coll_gt": coll_gt,
        "delocalized": locale.delocalize("1234.5"),
        "atof": locale.atof("12.5"),
        "atoi": locale.atoi("42"),
        "err": err,
        "curr_err": curr_err,

    };
}
