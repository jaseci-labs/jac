"""Fixture: full ES match lowering (#7881 / #7922).

match lowers to a guarded if-chain over a cached subject; every pattern
kind here must compile and produce Python-identical results at runtime.
"""

obj Point {
    has x: int = 0,
        y: int = 0;
}

def m_value(x: str) -> str {
    match x {
        case "a":
            return "AAA";

        case "b":
            return "BBB";

        case _:
            return "OTHER";

    }
}

def m_guard(n: int) -> str {
    match n {
        case v if v > 10:
            return "big";

        case v if v > 5:
            return "mid";

        case _:
            return "small";

    }
}

def m_seq(xs: list) -> str {
    match xs {
        case [ 1 , 2 , 3 ]:
            return "exact";

        case [ 1 , * rest ]:
            return "starts1:" + str(len(rest));

        case [ ]:
            return "empty";

        case _:
            return "other";

    }
}

def m_map(d: dict) -> str {
    match d {
        case { "kind" : "circle" , "r" : r }:
            return "circle:" + str(r);

        case { "kind" : k }:
            return "kind:" + str(k);

        case _:
            return "nokind";

    }
}

def m_arch(p: any) -> str {
    match p {
        case Point(x = 0, y = 0):
            return "origin";

        case Point(0, y):
            return "yaxis:" + str(y);

        case Point():
            return "point";

        case _:
            return "notpoint";

    }
}

def m_or(x: any) -> str {
    match x {
        case 1 | 2 | 3:
            return "small";

        case "a" | "b":
            return "letter";

        case None:
            return "none";

        case _:
            return "big";

    }
}

def m_as(x: any) -> str {
    match x {
        case [ 1 , y ] as pair:
            return "pair:" + str(y) + ":" + str(len(pair));

        case _:
            return "no";

    }
}

def m_rest(d: dict) -> str {
    match d {
        case { "a" : v , ** rest }:
            return "rest:" + str(v) + ":" + str(len(rest));

        case _:
            return "no";

    }
}

def m_singleton(x: any) -> str {
    match x {
        case True:
            return "T";

        case False:
            return "F";

        case None:
            return "N";

        case _:
            return "V";

    }
}

def m_all -> dict {
    p0 = Point(x=0, y=0);
    py = Point(x=0, y=7);
    pv = Point(x=3, y=4);
    return {
        "v_a": m_value("a"),
        "v_b": m_value("b"),
        "v_z": m_value("z"),
        "g_big": m_guard(20),
        "g_mid": m_guard(7),
        "g_small": m_guard(1),
        "s_exact": m_seq([1, 2, 3]),
        "s_star": m_seq([1, 9, 9, 9]),
        "s_empty": m_seq([]),
        "s_other": m_seq([2]),
        "m_circle": m_map({"kind": "circle", "r": 5}),
        "m_kind": m_map({"kind": "sq"}),
        "m_none": m_map({"z": 1}),
        "a_origin": m_arch(p0),
        "a_yaxis": m_arch(py),
        "a_point": m_arch(pv),
        "a_not": m_arch(3),
        "o_small": m_or(2),
        "o_letter": m_or("b"),
        "o_none": m_or(None),
        "o_big": m_or(9),
        "r_hit": m_rest({"a": 1, "b": 2, "c": 3}),
        "r_no": m_rest({"z": 1}),
        "as_pair": m_as([1, 5]),
        "as_no": m_as([2, 5]),
        "t": m_singleton(True),
        "f": m_singleton(False),
        "n": m_singleton(None),
        "v": m_singleton(3)
    };
}
