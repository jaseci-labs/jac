"""os.environ get/set/pop parity (#7626 C7: llvm/__init__.jac blocker).

The native os intercept had getenv but no `environ` attribute, so
`os.environ.get(...)` died at the capability gate (E5090 attribute access).
Pins the call shapes the compiler tree actually uses: .get with and without
a default (including a nested .get default), `[]=` assignment, and .pop.
"""
import os;

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
    return {
        "got": got,
        "missing": missing,
        "nested": nested,
        "after_pop": after_pop,
        "popped_missing_none": popped_missing is None,

    };
}

cl def environ_cl -> dict {
    return {};
}

na {
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
        return {
            "got": got,
            "missing": missing,
            "nested": nested,
            "after_pop": after_pop,
            "popped_missing_none": popped_missing is None,

        };
    }
}
