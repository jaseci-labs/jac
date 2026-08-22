"""os.environ get/set/pop parity (#7626 C7: llvm/__init__.jac blocker).

The native os intercept had getenv but no `environ` attribute, so
`os.environ.get(...)` died at the capability gate (E5090 attribute access).
Pins the call shapes the compiler tree actually uses: .get with and without
a default (including a nested .get default), `[]=` assignment, and .pop.

`[]=` is pinned with the value arriving as a function PARAMETER as well as a
literal: a `str` parameter is a string descriptor (`%JacStr`) rather than a
raw `i8*` at the native seam, and the setitem lowering once accepted only raw
pointers, so a module function assigning its parameter into the environment
fell through to the generic subscript path and was demoted to Python-only.
"""
import os;

def _set_from_param_py(key: str, val: str) -> str {
    os.environ[key] = val;
    return os.environ.get(key, "");
}


def _set_from_param_na(key: str, val: str) -> str {
    os.environ[key] = val;
    return os.environ.get(key, "");
}

def environ_py -> dict {
    os.environ["JAC_ENVFIX_A"] = "alpha";
    got = os.environ.get("JAC_ENVFIX_A", "");
    missing = os.environ.get("JAC_ENVFIX_MISSING", "fallback");
    nested = os.environ.get(
        "JAC_ENVFIX_MISSING", os.environ.get("JAC_ENVFIX_A", "inner")
    );
    os.environ.pop("JAC_ENVFIX_A", None);
    after_pop = os.environ.get("JAC_ENVFIX_A", "gone");
    popped_missing = os.environ.pop("JAC_ENVFIX_MISSING", None);
    from_param = _set_from_param_py("JAC_ENVFIX_P", "from-param");
    os.environ.pop("JAC_ENVFIX_P", None);
    return {
        "got": got,
        "missing": missing,
        "nested": nested,
        "after_pop": after_pop,
        "popped_missing_none": popped_missing is None,
        "from_param": from_param,
    };
}

def environ_cl -> dict {
    return {};
}


def environ_na -> dict[str, any] {
    os.environ["JAC_ENVFIX_A"] = "alpha";
    got = os.environ.get("JAC_ENVFIX_A", "");
    missing = os.environ.get("JAC_ENVFIX_MISSING", "fallback");
    nested = os.environ.get(
        "JAC_ENVFIX_MISSING", os.environ.get("JAC_ENVFIX_A", "inner")
    );
    os.environ.pop("JAC_ENVFIX_A", None);
    after_pop = os.environ.get("JAC_ENVFIX_A", "gone");
    popped_missing = os.environ.pop("JAC_ENVFIX_MISSING", None);
    from_param = _set_from_param_na("JAC_ENVFIX_P", "from-param");
    os.environ.pop("JAC_ENVFIX_P", None);
    return {
        "got": got,
        "missing": missing,
        "nested": nested,
        "after_pop": after_pop,
        "popped_missing_none": popped_missing is None,
        "from_param": from_param,
    };
}
