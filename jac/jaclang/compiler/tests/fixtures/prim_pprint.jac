"""Bundled native `pprint` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import from pprint { pformat }` binds CPython's `pprint` on the sv
(Python) backend and the bundled `na_stdlib/pprint.na.jac` Mechanism-B module on
the na (native LLVM) backend. Test objects are built with `json.loads` so the
two backends construct identical boxed structures (and so scalar `list[any]`
elements box correctly). Every `pformat` result is compared as an exact string;
inputs are compact (fit CPython's `width=80` on one line) and float-free, the
documented scope. ES/JS opts out.
"""

import from json { loads }
import from pprint { pformat }


def pprint_py -> dict {
    return {
        "p1": pformat(loads("{\"name\":\"alice\",\"age\":30,\"active\":true}")),
        "p2": pformat(loads("[1, 2, 3, \"x\"]")),
        "p3": pformat(loads("{\"b\":[1,2],\"a\":{\"z\":9}}")),
        "p4": pformat(loads("{}")),
        "p5": pformat(loads("[]")),
        "p6": pformat(loads("\"it's\"")),
        "p7": pformat(loads("\"plain\"")),
        "p8": pformat(loads("null")),
        "p9": pformat(loads("true")),
        "p10": pformat(loads("42")),
        "p11": pformat(loads("[\"a\",\"b\",{\"m\":1,\"c\":2}]")),
        "p12": pformat(loads("{\"k\":null,\"j\":false}"))
    };
}


cl def pprint_cl -> dict {
    return {};
}


na {
    def pprint_na -> dict[str, any] {
        return {
            "p1": pformat(loads("{\"name\":\"alice\",\"age\":30,\"active\":true}")),
            "p2": pformat(loads("[1, 2, 3, \"x\"]")),
            "p3": pformat(loads("{\"b\":[1,2],\"a\":{\"z\":9}}")),
            "p4": pformat(loads("{}")),
            "p5": pformat(loads("[]")),
            "p6": pformat(loads("\"it's\"")),
            "p7": pformat(loads("\"plain\"")),
            "p8": pformat(loads("null")),
            "p9": pformat(loads("true")),
            "p10": pformat(loads("42")),
            "p11": pformat(loads("[\"a\",\"b\",{\"m\":1,\"c\":2}]")),
            "p12": pformat(loads("{\"k\":null,\"j\":false}"))
        };
    }
}
