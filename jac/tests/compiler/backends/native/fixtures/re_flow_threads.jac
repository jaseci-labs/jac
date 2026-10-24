"""flow workers share re's compiled-pattern cache and each Pattern's scratch."""

import re;

obj Job {
    has seed: int = 0,
        bad: int = 0;
}

glob SHARED: re.Pattern = re.compile("([a-z]+)-(\\d+)");

def digits(s: str) -> int {
    n: int = 0;
    for ch in s {
        if ch >= "0" and ch <= "9" {
            n += 1;
        }
    }
    return n;
}

def work(seed: int) -> int {
    bad: int = 0;
    for i in range(300) {
        s: str = "id" + str(seed) + "-" + str(i) + " tail";
        m = re.search("([a-z]+)(\\d+)-(\\d+)", s);
        if m is None or str(m.group(3)) != str(i) {
            bad += 1;
        }
        k: str = str((seed * 300 + i) % 700);
        p: re.Pattern = re.compile("k" + k + "x");
        if p.search("ak" + k + "xb") is None {
            bad += 1;
        }
        m2 = SHARED.search("zz-" + str(i));
        if m2 is None or str(m2.group(2)) != str(i) {
            bad += 1;
        }
        if re.subn("\\d", "#", s)[1] != digits(s) {
            bad += 1;
        }
        if i % 97 == 0 {
            re.purge();
        }
    }
    return bad;
}

def build(n: int) -> list[Job] {
    jobs: list[Job] = [];
    for i in range(n) {
        jobs.append(Job(seed=i));
    }
    return jobs;
}

with entry {
    jobs = build(48);
    flow for j in &mut jobs {
        j.bad = work(j.seed);
    }
    total: int = 0;
    for j in jobs {
        total += j.bad;
    }
    print("bad", total);
}
