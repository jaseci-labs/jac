"""Bundled native `tomllib` cross-backend equivalence fixture.

The SAME `import from tomllib { loads }` binds CPython's `tomllib` on the sv
(Python) backend and the bundled `na_stdlib/tomllib.jac` Mechanism-B module on
the na (native LLVM) backend. Values are extracted to SCALARS (lists are
probed via len + indexed element reads; the harness reads returned lists as
raw i64). Datetimes come back as `datetime.date`/`time`/`datetime` on both
lanes; they are pinned through `isoformat()`/`tzname()`/`isinstance` probes
since the harness compares scalars, not object identity.
Integers >= 2^63 raise OverflowError natively (i64 machine) --
not probed here; documented SCOPE divergence. Errors pinned as
"TOMLDecodeError: " + str(e) with a WRONG-TYPE fallback arm so a wrong class
or a drifted message shows as a value diff, not a lane abort. The probe body is DUPLICATED into
each lane fn (a shared helper's dict[str, any] signature cannot cross the
native->Python call boundary in the harness). ES/JS opts out.
"""

import from tomllib { loads, TOMLDecodeError }
import from datetime { date, time, datetime }


def parse_float_marker(raw: str) -> str {
    return "float:" + raw;
}


def tomllib_py -> dict[any, any] {
    v: dict[any, any] = loads(
        "title = \"bench\"\nlimit = 4_000\nratio = 0.7284\nflag = true\noff = false\nhexval = 0xdeadbee\noctval = 0o755\nbinval = 0b1010\nneg = -17\nexpf = 6.626e-34\nports = [80, 443, 8080]\nmatrix = [[1, 2], [3, 4]]\ninline = { a = 1, b = \"x\", c = { d = 2.5 } }\nlit = 'C:\\\\path\\\\x'\nmulti = \"\"\"\nfirst line\\\nstill first\"\"\"\nmlit = '''\nraw \\n text'''\n[owner]\nname = \"ops\"\ndob = 1979-05-27\n[server]\nenabled = true\nip = \"10.0.0.1\"\nrun_at = 2026-09-25T10:30:00Z\noff_at = 2026-09-25T10:30:00+02:30\nlocal_at = 1979-05-27T07:32:00\ntea = 07:32:00.999999\n[server.tls]\nkey = \"k.pem\"\ncert = \"c.pem\"\nnested.x.y = 41\ntop.end = true\n[[items]]\nid = 0\nname = \"zero\"\nvec = [5, 6, 7]\n[[items]]\nid = 1\nname = \"one\"\nvec = [8, 9, 10]\n[[items]]\nid = 2\nname = \"two\"\nvec = [11, 12, 13]\n[[shape]]\n[shape.sides]\ncount = 3\n"
    );
    items: any = v["items"];
    item1: any = items[1];
    matrix: any = v["matrix"];
    mrow1: any = matrix[1];
    ports: any = v["ports"];
    server: dict[str, any] = v["server"];
    owner: dict[str, any] = v["owner"];
    tls: any = server["tls"];
    inline: any = v["inline"];
    ic: any = inline["c"];
    shape: any = v["shape"];
    run_at: datetime = server["run_at"];
    off_at: datetime = server["off_at"];
    local_at: datetime = server["local_at"];
    tea: time = server["tea"];
    dob: date = owner["dob"];
    custom_float: any = loads("value = 1.25", parse_float=parse_float_marker)["value"];
    e1: str = "";
    try {
        loads("a = \"abc");
    } except TOMLDecodeError as e {
        e1 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e1 = "WRONG-TYPE";
    }
    e2: str = "";
    try {
        loads("a = 01");
    } except TOMLDecodeError as e {
        e2 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e2 = "WRONG-TYPE";
    }
    e3: str = "";
    try {
        loads("a = 1\na = 2");
    } except TOMLDecodeError as e {
        e3 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e3 = "WRONG-TYPE";
    }
    e4: str = "";
    try {
        loads("[a]\n[a]");
    } except TOMLDecodeError as e {
        e4 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e4 = "WRONG-TYPE";
    }
    e5: str = "";
    try {
        loads("a = \"\\x41\"");
    } except TOMLDecodeError as e {
        e5 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e5 = "WRONG-TYPE";
    }
    e6: str = "";
    try {
        loads("a = {b = 1,}");
    } except TOMLDecodeError as e {
        e6 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e6 = "WRONG-TYPE";
    }
    e7: str = "";
    try {
        loads("a=\"é\" b=1");
    } except TOMLDecodeError as e {
        e7 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e7 = "WRONG-TYPE";
    }
    return {
        "title": v["title"],
        "limit": v["limit"],
        "ratio": v["ratio"],
        "flag": v["flag"],
        "off": v["off"],
        "hexval": v["hexval"],
        "octval": v["octval"],
        "binval": v["binval"],
        "neg": v["neg"],
        "expf": v["expf"],
        "custom_float": custom_float,
        "ports_n": len(ports),
        "ports_0": ports[0],
        "ports_2": ports[2],
        "matrix_n": len(matrix),
        "mrow1_n": len(mrow1),
        "mrow1_0": mrow1[0],
        "inline_n": len(inline),
        "inline_a": inline["a"],
        "inline_b": inline["b"],
        "ic_d": ic["d"],
        "lit": v["lit"],
        "multi": v["multi"],
        "mlit": v["mlit"],
        "owner_name": v["owner"]["name"],
        "server_ip": server["ip"],
        "tls_key": tls["key"],
        "nested_xy": tls["nested"]["x"]["y"],
        "top_end": tls["top"]["end"],
        "items_n": len(items),
        "item0_id": items[0]["id"],
        "item2_name": items[2]["name"],
        "item1_vec_n": len(item1["vec"]),
        "item1_vec2": item1["vec"][2],
        "shape_sides": shape[0]["sides"]["count"],
        "zero_eof": loads("a=0")["a"],
        "run_iso": run_at.isoformat(),
        "run_tz": run_at.tzname(),
        "off_iso": off_at.isoformat(),
        "off_tz": off_at.tzname(),
        "local_iso": local_at.isoformat(),
        "tea_iso": tea.isoformat(),
        "dob_iso": dob.isoformat(),
        "run_is_dt": isinstance(run_at, datetime),
        "dob_is_date": isinstance(dob, date),
        "tea_is_time": isinstance(tea, time),
        "e1": e1,
        "e2": e2,
        "e3": e3,
        "e4": e4,
        "e5": e5,
        "e6": e6,
        "e7": e7
    };
}


def tomllib_cl -> dict[any, any] {
    return {};
}


def tomllib_na -> dict[str, any] {
    v: dict[str, any] = loads(
        "title = \"bench\"\nlimit = 4_000\nratio = 0.7284\nflag = true\noff = false\nhexval = 0xdeadbee\noctval = 0o755\nbinval = 0b1010\nneg = -17\nexpf = 6.626e-34\nports = [80, 443, 8080]\nmatrix = [[1, 2], [3, 4]]\ninline = { a = 1, b = \"x\", c = { d = 2.5 } }\nlit = 'C:\\\\path\\\\x'\nmulti = \"\"\"\nfirst line\\\nstill first\"\"\"\nmlit = '''\nraw \\n text'''\n[owner]\nname = \"ops\"\ndob = 1979-05-27\n[server]\nenabled = true\nip = \"10.0.0.1\"\nrun_at = 2026-09-25T10:30:00Z\noff_at = 2026-09-25T10:30:00+02:30\nlocal_at = 1979-05-27T07:32:00\ntea = 07:32:00.999999\n[server.tls]\nkey = \"k.pem\"\ncert = \"c.pem\"\nnested.x.y = 41\ntop.end = true\n[[items]]\nid = 0\nname = \"zero\"\nvec = [5, 6, 7]\n[[items]]\nid = 1\nname = \"one\"\nvec = [8, 9, 10]\n[[items]]\nid = 2\nname = \"two\"\nvec = [11, 12, 13]\n[[shape]]\n[shape.sides]\ncount = 3\n"
    );
    items: any = v["items"];
    item1: any = items[1];
    matrix: any = v["matrix"];
    mrow1: any = matrix[1];
    ports: any = v["ports"];
    server: dict[str, any] = v["server"];
    owner: dict[str, any] = v["owner"];
    tls: any = server["tls"];
    inline: any = v["inline"];
    ic: any = inline["c"];
    shape: any = v["shape"];
    run_at: datetime = server["run_at"];
    off_at: datetime = server["off_at"];
    local_at: datetime = server["local_at"];
    tea: time = server["tea"];
    dob: date = owner["dob"];
    e1: str = "";
    try {
        loads("a = \"abc");
    } except TOMLDecodeError as e {
        e1 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e1 = "WRONG-TYPE";
    }
    e2: str = "";
    try {
        loads("a = 01");
    } except TOMLDecodeError as e {
        e2 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e2 = "WRONG-TYPE";
    }
    e3: str = "";
    try {
        loads("a = 1\na = 2");
    } except TOMLDecodeError as e {
        e3 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e3 = "WRONG-TYPE";
    }
    e4: str = "";
    try {
        loads("[a]\n[a]");
    } except TOMLDecodeError as e {
        e4 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e4 = "WRONG-TYPE";
    }
    e5: str = "";
    try {
        loads("a = \"\\x41\"");
    } except TOMLDecodeError as e {
        e5 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e5 = "WRONG-TYPE";
    }
    e6: str = "";
    try {
        loads("a = {b = 1,}");
    } except TOMLDecodeError as e {
        e6 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e6 = "WRONG-TYPE";
    }
    e7: str = "";
    try {
        loads("a=\"é\" b=1");
    } except TOMLDecodeError as e {
        e7 = "TOMLDecodeError: " + str(e);
    } except Exception {
        e7 = "WRONG-TYPE";
    }
    return {
        "title": v["title"],
        "limit": v["limit"],
        "ratio": v["ratio"],
        "flag": v["flag"],
        "off": v["off"],
        "hexval": v["hexval"],
        "octval": v["octval"],
        "binval": v["binval"],
        "neg": v["neg"],
        "expf": v["expf"],
        "ports_n": len(ports),
        "ports_0": ports[0],
        "ports_2": ports[2],
        "matrix_n": len(matrix),
        "mrow1_n": len(mrow1),
        "mrow1_0": mrow1[0],
        "inline_n": len(inline),
        "inline_a": inline["a"],
        "inline_b": inline["b"],
        "ic_d": ic["d"],
        "lit": v["lit"],
        "multi": v["multi"],
        "mlit": v["mlit"],
        "owner_name": v["owner"]["name"],
        "server_ip": server["ip"],
        "tls_key": tls["key"],
        "nested_xy": tls["nested"]["x"]["y"],
        "top_end": tls["top"]["end"],
        "items_n": len(items),
        "item0_id": items[0]["id"],
        "item2_name": items[2]["name"],
        "item1_vec_n": len(item1["vec"]),
        "item1_vec2": item1["vec"][2],
        "shape_sides": shape[0]["sides"]["count"],
        "zero_eof": loads("a=0")["a"],
        "run_iso": run_at.isoformat(),
        "run_tz": run_at.tzname(),
        "off_iso": off_at.isoformat(),
        "off_tz": off_at.tzname(),
        "local_iso": local_at.isoformat(),
        "tea_iso": tea.isoformat(),
        "dob_iso": dob.isoformat(),
        "run_is_dt": isinstance(run_at, datetime),
        "dob_is_date": isinstance(dob, date),
        "tea_is_time": isinstance(tea, time),
        "e1": e1,
        "e2": e2,
        "e3": e3,
        "e4": e4,
        "e5": e5,
        "e6": e6,
        "e7": e7
    };
}
