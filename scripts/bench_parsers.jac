import from time { monotonic_ns }
import json as jsonmod;
import csv as csvmod;
import tomllib as tomlmod;
import configparser as cpmod;


def build_json -> str {
    doc: str = "{\"name\": \"widget-batch\", \"id\": 4271, \"active\": true, \"ratio\": 0.7284, \"tag\": null, \"tags\": [\"alpha\", \"beta\", \"gamma\"], \"meta\": {\"src\": \"bench\", \"deep\": [1, 2, 3, 4, 5], \"ok\": false}, \"orders\": [";
    i: int = 0;
    while i < 20 {
        if i > 0 {
            doc += ", ";
        }
        doc += "{\"oid\": "
            + str(1000 + i)
            + ", \"sku\": \"SKU-"
            + str(i)
            + "\", \"qty\": "
            + str((i * 7) % 13)
            + ", \"price\": "
            + str(1.5 + i)
            + ", \"note\": \"line "
            + str(i)
            + "\"}";
        i += 1;
    }
    return doc + "]}";
}


def build_csv -> str {
    lines: list[str] = ["sku,qty,price,note"];
    i: int = 0;
    while i < 200 {
        if i % 3 == 0 {
            lines.append(
                str(i)
                    + ",\""
                    + str(i * 2)
                    + ",x\",\""
                    + str(1.5 + i)
                    + "\",\"say \"\"hi\"\" "
                    + str(i)
                    + "\""
            );
        } else {
            lines.append(
                str(i) + "," + str(i * 2) + "," + str(1.5 + i) + ",plain" + str(i)
            );
        }
        i += 1;
    }
    return "\n".join(lines);
}


def build_toml -> str {
    doc: str = "title = \"bench\"\nrun_at = 2026-09-25T10:30:00Z\nlimit = 4_000\nratio = 0.7284\nports = [80, 443, 8080]\n[owner]\nname = \"ops\"\ndob = 1979-05-27\n[server]\nenabled = true\nip = \"10.0.0.1\"\n[server.tls]\nkey = \"k.pem\"\ncert = \"c.pem\"\n";
    i: int = 0;
    while i < 20 {
        doc += "[[items]]\nid = "
            + str(i)
            + "\nname = \"item-"
            + str(i)
            + "\"\nvec = ["
            + str(i)
            + ", "
            + str(i + 1)
            + ", "
            + str(i + 2)
            + "]\n";
        i += 1;
    }
    return doc;
}


def build_ini -> str {
    doc: str = "[DEFAULT]\nbase = 100\nname = bench\n";
    i: int = 0;
    while i < 40 {
        doc += "[s"
            + str(i)
            + "]\nnum = "
            + str(i)
            + "\nref = %(base)s\nlabel = sec-"
            + str(i)
            + "\n";
        i += 1;
    }
    return doc;
}


def count_all(v: any) -> int {
    acc: int = 0;
    if isinstance(v, dict) {
        d: dict[str, any] = v;
        for k in d {
            acc += 1 + count_all(d[k]);
        }
    } elif isinstance(v, list) {
        arr: list[any] = v;
        i: int = 0;
        while i < len(arr) {
            acc += 1 + count_all(arr[i]);
            i += 1;
        }
    } elif isinstance(v, str) {
        s: str = v;
        acc += len(s);
    }
    return acc;
}


def json_lane(reps: int, doc: str) -> tuple[(int, int)] {
    acc: int = 0;
    t0: int = monotonic_ns();
    k: int = 0;
    while k < reps {
        v: any = jsonmod.loads(doc);
        acc += count_all(v);
        s: str = jsonmod.dumps(v);
        acc += len(s);
        k += 1;
    }
    return (acc, monotonic_ns() - t0);
}


def scan_lane(reps: int, doc: str) -> tuple[(int, int)] {
    acc: int = 0;
    t0: int = monotonic_ns();
    k: int = 0;
    while k < reps {
        n: int = len(doc);
        i: int = 0;
        while i < n {
            ch: int = ord(doc[i]);
            if ch == 34 or ch == 92 {
                acc += 1;
            }
            i += 1;
        }
        k += 1;
    }
    return (acc, monotonic_ns() - t0);
}


def slice_lane(reps: int, doc: str) -> tuple[(int, int)] {
    acc: int = 0;
    t0: int = monotonic_ns();
    k: int = 0;
    while k < reps {
        out: str = "";
        n: int = len(doc);
        i: int = 0;
        start: int = 0;
        while i < n {
            ch: int = ord(doc[i]);
            if ch == 34 or ch == 92 {
                out += doc[start:i];
                out += "|";
                i += 1;
                start = i;
            } else {
                i += 1;
            }
        }
        out += doc[start:n];
        acc += len(out);
        k += 1;
    }
    return (acc, monotonic_ns() - t0);
}


def csv_lane(reps: int, doc: str) -> tuple[(int, int)] {
    acc: int = 0;
    lines: list[str] = doc.split("\n");
    t0: int = monotonic_ns();
    k: int = 0;
    while k < reps {
        rows: list[list[str]] = list(csvmod.reader(lines));
        r: int = 0;
        while r < len(rows) {
            acc += len(rows[r]);
            r += 1;
        }
        k += 1;
    }
    return (acc, monotonic_ns() - t0);
}


def toml_lane(reps: int, doc: str) -> tuple[(int, int)] {
    acc: int = 0;
    t0: int = monotonic_ns();
    k: int = 0;
    while k < reps {
        v: dict[str, any] = tomlmod.loads(doc);
        acc += count_all(v);
        k += 1;
    }
    return (acc, monotonic_ns() - t0);
}


def ini_lane(reps: int, doc: str) -> tuple[(int, int)] {
    acc: int = 0;
    t0: int = monotonic_ns();
    k: int = 0;
    while k < reps {
        cp: cpmod.ConfigParser = cpmod.ConfigParser();
        cp.read_string(doc);
        acc += len(cp.sections());
        acc += cp.getint("s17", "num");
        acc += len(cp.get("s17", "ref"));
        acc += len(cp.get("s17", "label"));
        k += 1;
    }
    return (acc, monotonic_ns() - t0);
}


def emit_line(name: str, r: tuple[(int, int)], ops: int) {
    print(name, r[1] / ops, str(r[0]));
}


with entry {
    jd: str = build_json();
    cd: str = build_csv();
    td: str = build_toml();
    id_: str = build_ini();
    print("doclens", len(jd), len(cd), len(td), len(id_));
    w: tuple[(int, int)] = json_lane(2, jd);
    w = csv_lane(2, cd);
    w = toml_lane(2, td);
    w = ini_lane(2, id_);
    w = scan_lane(2, jd);
    w = slice_lane(2, jd);
}

glob reps: int = 4000;

with entry {
    rj: tuple[(int, int)] = (0, 0);
    rc: tuple[(int, int)] = (0, 0);
    rt: tuple[(int, int)] = (0, 0);
    ri: tuple[(int, int)] = (0, 0);
    rs: tuple[(int, int)] = (0, 0);
    rl: tuple[(int, int)] = (0, 0);
    k: int = 0;
    while k < 3 {
        cand: tuple[(int, int)] = json_lane(reps, jd);
        if rj[1] == 0 or cand[1] < rj[1] {
            rj = cand;
        }
        cand = csv_lane(500, cd);
        if rc[1] == 0 or cand[1] < rc[1] {
            rc = cand;
        }
        cand = toml_lane(reps, td);
        if rt[1] == 0 or cand[1] < rt[1] {
            rt = cand;
        }
        cand = ini_lane(reps, id_);
        if ri[1] == 0 or cand[1] < ri[1] {
            ri = cand;
        }
        cand = scan_lane(2000, jd);
        if rs[1] == 0 or cand[1] < rs[1] {
            rs = cand;
        }
        cand = slice_lane(2000, jd);
        if rl[1] == 0 or cand[1] < rl[1] {
            rl = cand;
        }
        k += 1;
    }
    emit_line("json", rj, reps);
    emit_line("csv", rc, 500);
    emit_line("toml", rt, reps);
    emit_line("configparser", ri, reps);
    emit_line("scan", rs, 2000);
    emit_line("slice", rl, 2000);
}
# CPython oracle lane (not committed - new .py files are blocked):
# run the same build_json/build_csv/build_toml/build_ini workloads under
# python3 with json/csv/tomllib/configparser and compare acc checksums and
# ns/op. Recorded results live in the PR description and the na-bin playbook.
