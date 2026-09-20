"""Pprint: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

import from json { loads }
import from pprint { pformat }


def pprint_py -> dict[any, any] {
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
        "p12": pformat(loads("{\"k\":null,\"j\":false}")),
        "p13": pformat(loads("\"a\\\\b\"")),
        "p14": pformat(loads("\"a\\nb\\tc\\rd\"")),
        "p15": pformat(loads("\"say \\\"hi\\\"\"")),
        "p16": pformat(loads("\"both ' and \\\"\"")),
        "p17": pformat(loads("\"c\\u0001d\"")),
        "p18": pformat(loads("\"del\\u007fend\"")),
        "p19": pformat(loads("\"e\\u001fq\""))
    };
}


def pprint_cl -> dict[any, any] {
    return {};
}


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
        "p12": pformat(loads("{\"k\":null,\"j\":false}")),
        "p13": pformat(loads("\"a\\\\b\"")),
        "p14": pformat(loads("\"a\\nb\\tc\\rd\"")),
        "p15": pformat(loads("\"say \\\"hi\\\"\"")),
        "p16": pformat(loads("\"both ' and \\\"\"")),
        "p17": pformat(loads("\"c\\u0001d\"")),
        "p18": pformat(loads("\"del\\u007fend\"")),
        "p19": pformat(loads("\"e\\u001fq\""))
    };
}
