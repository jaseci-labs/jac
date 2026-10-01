"""Bundled native `logging` cross-backend equivalence fixture (#6978).

The same `import logging` binds CPython's `logging` on the sv backend and
`na_stdlib/logging.jac` on the na (native LLVM) backend. Pins the parts that
produce values rather than side effects on a stream: the level constants and
`getLevelName`/`getLevelNamesMapping`, the dotted-name logger hierarchy
(`getLogger` identity, `parent`, `getEffectiveLevel` walking up through NOTSET,
`isEnabledFor`, `propagate`), `addHandler`/`removeHandler` bookkeeping, and the
`%`-style `Formatter` rendering of a `LogRecord`. The bundled `LogRecord` takes CPython's positional
parameter order (`name, level, pathname, lineno, msg, args, exc_info, func,
sinfo`) precisely so one call shape type-checks on both lanes: the fixture's py
lane is checked against the BUNDLED module's signatures even though it binds
CPython's module at runtime, so a fixture may only use the intersection of the
two APIs.

Both lanes narrow `child.parent` through an `is not None` guard: the checker types
it from the bundled module's `Logger | None` field on the py lane too, so a bare
`child.parent.name` is E1099 there as well. ES/JS opts out.
"""

import logging;


def logging_py -> dict[any, any] {
    names = logging.getLevelNamesMapping();
    parent = logging.getLogger("prim_a");
    child = logging.getLogger("prim_a.prim_b");
    grand = logging.getLogger("prim_a.prim_b.prim_c");
    parent.setLevel(logging.INFO);
    eff_child = child.getEffectiveLevel();
    eff_grand = grand.getEffectiveLevel();
    enabled_info = 1 if child.isEnabledFor(logging.INFO) else 0;
    enabled_debug = 1 if child.isEnabledFor(logging.DEBUG) else 0;
    same = 1 if logging.getLogger("prim_a") is parent else 0;
    pref = child.parent;
    parent_name = "";
    if pref is not None {
        parent_name = pref.name;
    }
    hdlr = logging.StreamHandler();
    child.addHandler(hdlr);
    after_add = len(child.handlers);
    child.addHandler(hdlr);
    after_dup = len(child.handlers);
    child.removeHandler(hdlr);
    after_remove = len(child.handlers);
    fmt = logging.Formatter("%(levelname)s:%(name)s:%(message)s");
    rec = logging.LogRecord(
        "prim_a", logging.WARNING, "/tmp/x/y.py", 7, "boom", None, None
    );
    rendered = fmt.format(rec);
    plain = logging.Formatter().format(rec);
    rich = logging.Formatter(
        "%(levelno)d|%(filename)s|%(lineno)d|%(module)s|%(message)s"
    ).format(
        rec
    );
    return {
        "critical": logging.CRITICAL,
        "error": logging.ERROR,
        "warning": logging.WARNING,
        "info": logging.INFO,
        "debug": logging.DEBUG,
        "notset": logging.NOTSET,
        "name_40": logging.getLevelName(40),
        "name_25": logging.getLevelName(25),
        "basic_format": logging.BASIC_FORMAT,
        "map_len_ge": 1 if len(names) >= 8 else 0,
        "map_info": names["INFO"],
        "eff_child": eff_child,
        "eff_grand": eff_grand,
        "enabled_info": enabled_info,
        "enabled_debug": enabled_debug,
        "same": same,
        "parent_name": parent_name,
        "after_add": after_add,
        "after_dup": after_dup,
        "after_remove": after_remove,
        "rendered": rendered,
        "plain": plain,
        "rich": rich,
        "levelname": rec.levelname,
        "levelno": rec.levelno,
        "msg": rec.getMessage(),

    };
}


def logging_cl -> dict[any, any] {
    return {};
}


def logging_na -> dict[str, any] {
    names = logging.getLevelNamesMapping();
    parent = logging.getLogger("prim_a");
    child = logging.getLogger("prim_a.prim_b");
    grand = logging.getLogger("prim_a.prim_b.prim_c");
    parent.setLevel(logging.INFO);
    eff_child = child.getEffectiveLevel();
    eff_grand = grand.getEffectiveLevel();
    enabled_info = 1 if child.isEnabledFor(logging.INFO) else 0;
    enabled_debug = 1 if child.isEnabledFor(logging.DEBUG) else 0;
    same = 1 if logging.getLogger("prim_a") is parent else 0;
    pref = child.parent;
    parent_name = "";
    if pref is not None {
        parent_name = pref.name;
    }
    hdlr = logging.StreamHandler();
    child.addHandler(hdlr);
    after_add = len(child.handlers);
    child.addHandler(hdlr);
    after_dup = len(child.handlers);
    child.removeHandler(hdlr);
    after_remove = len(child.handlers);
    fmt = logging.Formatter("%(levelname)s:%(name)s:%(message)s");
    rec = logging.LogRecord(
        "prim_a", logging.WARNING, "/tmp/x/y.py", 7, "boom", None, None
    );
    rendered = fmt.format(rec);
    bare = logging.Formatter();
    plain = bare.format(rec);
    richfmt = logging.Formatter(
        "%(levelno)d|%(filename)s|%(lineno)d|%(module)s|%(message)s"
    );
    rich = richfmt.format(rec);
    return {
        "critical": logging.CRITICAL,
        "error": logging.ERROR,
        "warning": logging.WARNING,
        "info": logging.INFO,
        "debug": logging.DEBUG,
        "notset": logging.NOTSET,
        "name_40": logging.getLevelName(40),
        "name_25": logging.getLevelName(25),
        "basic_format": logging.BASIC_FORMAT,
        "map_len_ge": 1 if len(names) >= 8 else 0,
        "map_info": names["INFO"],
        "eff_child": eff_child,
        "eff_grand": eff_grand,
        "enabled_info": enabled_info,
        "enabled_debug": enabled_debug,
        "same": same,
        "parent_name": parent_name,
        "after_add": after_add,
        "after_dup": after_dup,
        "after_remove": after_remove,
        "rendered": rendered,
        "plain": plain,
        "rich": rich,
        "levelname": rec.levelname,
        "levelno": rec.levelno,
        "msg": rec.getMessage(),

    };
}
