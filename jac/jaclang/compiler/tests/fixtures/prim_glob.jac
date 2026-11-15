"""Bundled native ``glob`` cross-backend equivalence fixture.

The SAME `import from glob { ... }` binds CPython's ``glob`` on the sv
(Python) backend and the bundled `na_stdlib/glob.jac` Mechanism-B module on
the na (native LLVM) backend. Each lane builds the identical throwaway tree
under /tmp (nested dirs, dotfiles, mixed extensions), runs the same pattern
grid, SORTS each result (CPython documents glob order as undefined --
scandir order -- while the na module returns each directory listing sorted),
and pins results as "\n"-joined strings because raw lists do not marshal
across the native boundary. Also pins escape/has_magic and iglob==glob
agreement (iteration only: CPython's iglob yields, the na one returns an
eager list). `glob` is a Jac keyword, so the function is imported and called
under the `` `glob `` keyword escape (the bundled module declares it as
`def:pub `glob``); the escape compiles to a plain `glob` name on sv. Bodies
are duplicated per lane per the textwrap fixture convention. ES/JS opts out.
"""

import os;
import shutil;
import from glob { `glob, iglob, escape, has_magic }


def glob_py -> dict[any, any] {
    base = "/tmp/jac_prim_glob_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(os.path.join(base, "sub", "deep"));
    os.makedirs(os.path.join(base, "dirc"));
    for name in ["a.txt", "b.log", ".hidden"] {
        f = open(os.path.join(base, name), "w");
        f.write("x");
        f.close();
    }
    for name in ["b.txt", ".hs"] {
        f = open(os.path.join(base, "sub", name), "w");
        f.write("x");
        f.close();
    }
    f = open(os.path.join(base, "sub", "deep", "c.txt"), "w");
    f.write("x");
    f.close();
    d: dict[any, any] = {};
    pat: list[str] = [];
    rec: list[bool] = [];
    pat.append(base + "/*");
    rec.append(False);
    pat.append(base + "/*.txt");
    rec.append(False);
    pat.append(base + "/*.log");
    rec.append(False);
    pat.append(base + "/?.txt");
    rec.append(False);
    pat.append(base + "/[ab].*");
    rec.append(False);
    pat.append(base + "/.h*");
    rec.append(False);
    pat.append(base + "/.*");
    rec.append(False);
    pat.append(base + "/sub/*");
    rec.append(False);
    pat.append(base + "/*/");
    rec.append(False);
    pat.append(base + "/**");
    rec.append(True);
    pat.append(base + "/sub/**");
    rec.append(True);
    pat.append(base + "/**/*.txt");
    rec.append(True);
    pat.append(base + "/**/");
    rec.append(True);
    pat.append(base + "/**/deep");
    rec.append(True);
    pat.append(base + "/*/*");
    rec.append(False);
    pat.append(base + "/sub/*/*");
    rec.append(True);
    pat.append(base + "/missing/*");
    rec.append(False);
    pat.append(base + "/**/missing/*.txt");
    rec.append(True);
    pat.append(base + "/a.txt");
    rec.append(False);
    pat.append(base + "/nope");
    rec.append(False);
    pat.append(escape(base + "/*.txt"));
    rec.append(False);
    pat.append(base);
    rec.append(False);
    pat.append(base + "/");
    rec.append(False);
    pat.append("");
    rec.append(False);
    pat.append(base + "/*.txt");
    rec.append(True);
    i: int = 0;
    while i < len(pat) {
        r = `glob(pat[i], recursive=rec[i]);
        d["g" + str(i)] = "\n".join(sorted(r));
        d["n" + str(i)] = len(r);
        i += 1;
    }
    d["hidden_on"] = "\n".join(sorted(`glob(base + "/*.log", include_hidden=True)));
    acc: list[str] = [];
    for x in iglob(base + "/[ab].*") {
        acc.append(x);
    }
    d["iglob_n"] = len(acc);
    d["iglob_join"] = "\n".join(sorted(acc));
    d["esc1"] = escape("/tmp/[x]*?.jac");
    d["esc2"] = escape("plain.txt");
    d["magic1"] = has_magic("a[bc]");
    d["magic2"] = has_magic("abc");
    d["magic3"] = has_magic("**");
    shutil.rmtree(base);
    return d;
}


def glob_cl -> dict[any, any] {
    return {};
}


def glob_na -> dict[str, any] {
    base = "/tmp/jac_prim_glob_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(os.path.join(base, "sub", "deep"));
    os.makedirs(os.path.join(base, "dirc"));
    for name in ["a.txt", "b.log", ".hidden"] {
        f = open(os.path.join(base, name), "w");
        f.write("x");
        f.close();
    }
    for name in ["b.txt", ".hs"] {
        f = open(os.path.join(base, "sub", name), "w");
        f.write("x");
        f.close();
    }
    f = open(os.path.join(base, "sub", "deep", "c.txt"), "w");
    f.write("x");
    f.close();
    d: dict[str, any] = {};
    pat: list[str] = [];
    rec: list[bool] = [];
    pat.append(base + "/*");
    rec.append(False);
    pat.append(base + "/*.txt");
    rec.append(False);
    pat.append(base + "/*.log");
    rec.append(False);
    pat.append(base + "/?.txt");
    rec.append(False);
    pat.append(base + "/[ab].*");
    rec.append(False);
    pat.append(base + "/.h*");
    rec.append(False);
    pat.append(base + "/.*");
    rec.append(False);
    pat.append(base + "/sub/*");
    rec.append(False);
    pat.append(base + "/*/");
    rec.append(False);
    pat.append(base + "/**");
    rec.append(True);
    pat.append(base + "/sub/**");
    rec.append(True);
    pat.append(base + "/**/*.txt");
    rec.append(True);
    pat.append(base + "/**/");
    rec.append(True);
    pat.append(base + "/**/deep");
    rec.append(True);
    pat.append(base + "/*/*");
    rec.append(False);
    pat.append(base + "/sub/*/*");
    rec.append(True);
    pat.append(base + "/missing/*");
    rec.append(False);
    pat.append(base + "/**/missing/*.txt");
    rec.append(True);
    pat.append(base + "/a.txt");
    rec.append(False);
    pat.append(base + "/nope");
    rec.append(False);
    pat.append(escape(base + "/*.txt"));
    rec.append(False);
    pat.append(base);
    rec.append(False);
    pat.append(base + "/");
    rec.append(False);
    pat.append("");
    rec.append(False);
    pat.append(base + "/*.txt");
    rec.append(True);
    i: int = 0;
    while i < len(pat) {
        r = `glob(pat[i], recursive=rec[i]);
        d["g" + str(i)] = "\n".join(sorted(r));
        d["n" + str(i)] = len(r);
        i += 1;
    }
    d["hidden_on"] = "\n".join(sorted(`glob(base + "/*.log", include_hidden=True)));
    acc: list[str] = [];
    for x in iglob(base + "/[ab].*") {
        acc.append(x);
    }
    d["iglob_n"] = len(acc);
    d["iglob_join"] = "\n".join(sorted(acc));
    d["esc1"] = escape("/tmp/[x]*?.jac");
    d["esc2"] = escape("plain.txt");
    d["magic1"] = has_magic("a[bc]");
    d["magic2"] = has_magic("abc");
    d["magic3"] = has_magic("**");
    shutil.rmtree(base);
    return d;
}
