"""Bench the bundled native uuid / sched / ipaddress / mimetypes / colorsys /
locale / gettext / logging modules against CPython 3.14.

Build and run natively (demotions are fatal in a native build, so a clean
build is itself proof that every benched lane is native):

    jac build --native scripts/bench_na_general.jac -o /tmp/bench_na_general
    /tmp/bench_na_general

CPython oracle (new .py files are blocked repo-wide, so the oracle lives in
this comment block; run it with python3 -):

    import time, uuid, sched, ipaddress, mimetypes, colorsys, locale, gettext

    def best(fn, reps, n):
        out = []
        for _ in range(reps):
            t0 = time.perf_counter_ns()
            acc = fn(n)
            out.append((time.perf_counter_ns() - t0) / n)
            chk = acc
        return min(out), chk

    def l_colorsys(n):
        acc = 0.0
        for i in range(n):
            h, l, s = colorsys.rgb_to_hls(0.2, 0.4, 0.6)
            acc += h + l + s
        return acc

    def l_uuid4(n):
        acc = 0
        for i in range(n):
            acc += len(uuid.uuid4().hex)
        return acc

    def l_hex(n):
        u = uuid.uuid4()
        acc = 0
        for i in range(n):
            acc += len(u.hex)
        return acc

    def l_str(n):
        u = uuid.uuid4()
        acc = 0
        for i in range(n):
            acc += len(str(u))
        return acc

    def l_uuid5(n):
        acc = 0
        for i in range(n):
            acc += len(uuid.uuid5(uuid.NAMESPACE_DNS, "example.com").hex)
        return acc

    def l_uuid_parse(n):
        acc = 0
        for i in range(n):
            acc += uuid.UUID("12345678-1234-5678-1234-567812345678").fields[0]
        return acc

    def l_ip_parse(n):
        acc = 0
        for i in range(n):
            acc += int(ipaddress.IPv4Address("192.168.0.1").version)
        return acc

    def l_ip_net(n):
        acc = 0
        for i in range(n):
            acc += ipaddress.IPv4Network("192.168.0.0/24").num_addresses
        return acc

    def l_mime(n):
        acc = 0
        for i in range(n):
            acc += len(mimetypes.guess_type("index.html")[0])
        return acc

    def l_sched(n):
        acc = 0
        for i in range(n):
            s = sched.scheduler()
            box = []
            s.enterabs(-1.0, 1, lambda: box.append(1))
            s.run()
            acc += len(box)
        return acc

    def l_locale_norm(n):
        acc = 0
        for i in range(n):
            acc += len(locale.normalize("en_US.UTF-8"))
        return acc

    def l_gettext_plural(n):
        f = gettext.c2py("n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 &&"
                         " (n%100<10 || n%100>=20) ? 1 : 2")
        acc = 0
        for i in range(n):
            acc += f(i % 100)
        return acc

    def l_logging(n):
        import logging
        fmt = logging.Formatter("%(levelname)s:%(name)s:%(message)s")
        acc = 0
        for i in range(n):
            rec = logging.LogRecord("bench", 30, "/tmp/b.jac", 1, "hello",
                                    None, None)
            acc += len(fmt.format(rec))
        return acc

    for name, fn, n in (("colorsys.rgb_to_hls", l_colorsys, 200000),
                        ("uuid .hex", l_hex, 200000),
                        ("uuid str(u)", l_str, 200000),
                        ("uuid.uuid4", l_uuid4, 100000),
                        ("uuid.uuid5", l_uuid5, 100000),
                        ("uuid.UUID(parse)", l_uuid_parse, 100000),
                        ("ipaddress.IPv4Address", l_ip_parse, 100000),
                        ("ipaddress.IPv4Network", l_ip_net, 50000),
                        ("mimetypes.guess_type", l_mime, 100000),
                        ("sched enter+run", l_sched, 50000),
                        ("locale.normalize", l_locale_norm, 200000),
                        ("gettext plural", l_gettext_plural, 200000),
                        ("logging format", l_logging, 100000)):
        ns, chk = best(fn, 3, n)
        print("%-24s %10.1f ns/op  acc=%s" % (name, ns, chk))
"""

import sys;
import time;
import uuid;
import sched;
import ipaddress;
import mimetypes;
import colorsys;
import locale;
import gettext;
import logging;


def _row(name: str, ns: float, acc: float) {
    sys.stdout.write(
        name + " " + format(ns, ".1f") + " ns/op  acc=" + format(acc, ".4f") + "\n"
    );
}


def bench_colorsys(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            hls = colorsys.rgb_to_hls(0.2, 0.4, 0.6);
            acc += hls[0] + hls[1] + hls[2];
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("colorsys.rgb_to_hls", best, acc);
}


def bench_uuid_str(n: int) {
    u = uuid.uuid4();
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += float(len(str(u)));
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("uuid str(u)", best, acc);
}


def bench_uuid4(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += float(len(uuid.uuid4().hex));
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("uuid.uuid4", best, acc);
}


def bench_uuid5(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += float(len(uuid.uuid5(uuid.NAMESPACE_DNS, "example.com").hex));
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("uuid.uuid5", best, acc);
}


def bench_uuid_parse(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            u = uuid.UUID(hex="12345678-1234-5678-1234-567812345678");
            acc += float(u.fields[0]);
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("uuid.UUID(parse)", best, acc);
}


def bench_ip_address(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += float(ipaddress.IPv4Address("192.168.0.1").version);
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("ipaddress.IPv4Address", best, acc);
}


def bench_ip_network(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += float(ipaddress.IPv4Network("192.168.0.0/24").num_addresses);
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("ipaddress.IPv4Network", best, acc);
}


def bench_mimetypes(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            guess = mimetypes.guess_type("index.html");
            mt: str | None = guess[0];
            if mt is not None {
                acc += float(len(mt));
            }
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("mimetypes.guess_type", best, acc);
}


def _tick {
    _COUNT.value += 1;
}


obj _Counter {
    has value: int = 0;
}

glob _COUNT: _Counter = _Counter();


def bench_sched(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        _COUNT.value = 0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            s = sched.scheduler();
            s.enterabs(-1.0, 1, _tick);
            s.run();
            i += 1;
        }
        acc = float(_COUNT.value);
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("sched enter+run", best, acc);
}


def bench_locale(n: int) {
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += float(len(locale.normalize("en_US.UTF-8")));
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("locale.normalize", best, acc);
}


def bench_gettext(n: int) {
    tree: any = gettext.c2py_ast(
        "n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 &&"
        " (n%100<10 || n%100>=20) ? 1 : 2"
    );
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            acc += float((gettext.plural_index(tree, i % 100) as int));
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("gettext plural", best, acc);
}


def bench_logging(n: int) {
    fmt = logging.Formatter(fmt="%(levelname)s:%(name)s:%(message)s");
    best: float = -1.0;
    acc: float = 0.0;
    rep: int = 0;
    while rep < 3 {
        acc = 0.0;
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < n {
            rec = logging.LogRecord(
                name="bench", level=30, pathname="/tmp/b.jac", lineno=1, msg="hello"
            );
            acc += float(len(fmt.format(rec)));
            i += 1;
        }
        el: float = float(time.perf_counter_ns() - t0) / float(n);
        if best < 0.0 or el < best {
            best = el;
        }
        rep += 1;
    }
    _row("logging format", best, acc);
}


with entry {
    bench_colorsys(200000);
    bench_uuid_str(200000);
    bench_uuid4(100000);
    bench_uuid5(100000);
    bench_uuid_parse(100000);
    bench_ip_address(100000);
    bench_ip_network(50000);
    bench_mimetypes(100000);
    bench_sched(50000);
    bench_locale(200000);
    bench_gettext(200000);
    bench_logging(100000);
}
