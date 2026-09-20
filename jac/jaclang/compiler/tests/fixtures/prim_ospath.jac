"""Ospath: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

import from os.path {
    normpath,
    dirname,
    basename,
    splitext,
    split,
    isabs,
    join,
    abspath
}

def ospath_py -> dict[any, any] {
    (stem, ext) = splitext("/a/archive.tar.gz");
    (sh_trail, st_trail) = split("/a/b/");
    (sh_all, st_all) = split("//");
    (sh_rel, st_rel) = split("file.txt");
    return {
        "join2": join("a", "b"),
        "join_trail": join("a/", "b"),
        "join_abs": join("a", "/b"),
        "join_empty_tail": join("a", ""),
        "join_empty_head": join("", "b"),
        "join3": join("a", "b", "c"),
        "abspath_abs": abspath("/a/../b"),
        "abspath_rel": abspath("x/./y"),
        "abspath_dot": abspath("."),
        "abspath_empty": abspath(""),
        "np_rel": normpath("a/b/../c"),
        "np_abs": normpath("/a//b/./c/"),
        "np_dot": normpath("."),
        "np_empty": normpath(""),
        "np_updir": normpath("../../a"),
        "np_double": normpath("//a/b"),
        "np_triple": normpath("///a"),
        "np_collapse": normpath("a/./b/../../c"),
        "dirname": dirname("/usr/local/bin"),
        "basename": basename("/usr/local/bin"),
        "dirname_bare": dirname("file.txt"),
        "dirname_root": dirname("/"),
        "basename_root": basename("/"),
        "split_trail": sh_trail + "|" + st_trail,
        "split_allslash": sh_all + "|" + st_all,
        "split_rel": sh_rel + "|" + st_rel,
        "splitext_root": stem,
        "splitext_ext": ext,
        "isabs_yes": 1 if isabs("/x") else 0,
        "isabs_no": 1 if isabs("rel/x") else 0,

    };
}

def ospath_cl -> dict[any, any] {
    return {};
}


def ospath_na -> dict[str, any] {
    (stem, ext) = splitext("/a/archive.tar.gz");
    (sh_trail, st_trail) = split("/a/b/");
    (sh_all, st_all) = split("//");
    (sh_rel, st_rel) = split("file.txt");
    return {
        "join2": join("a", "b"),
        "join_trail": join("a/", "b"),
        "join_abs": join("a", "/b"),
        "join_empty_tail": join("a", ""),
        "join_empty_head": join("", "b"),
        "join3": join("a", "b", "c"),
        "abspath_abs": abspath("/a/../b"),
        "abspath_rel": abspath("x/./y"),
        "abspath_dot": abspath("."),
        "abspath_empty": abspath(""),
        "np_rel": normpath("a/b/../c"),
        "np_abs": normpath("/a//b/./c/"),
        "np_dot": normpath("."),
        "np_empty": normpath(""),
        "np_updir": normpath("../../a"),
        "np_double": normpath("//a/b"),
        "np_triple": normpath("///a"),
        "np_collapse": normpath("a/./b/../../c"),
        "dirname": dirname("/usr/local/bin"),
        "basename": basename("/usr/local/bin"),
        "dirname_bare": dirname("file.txt"),
        "dirname_root": dirname("/"),
        "basename_root": basename("/"),
        "split_trail": sh_trail + "|" + st_trail,
        "split_allslash": sh_all + "|" + st_all,
        "split_rel": sh_rel + "|" + st_rel,
        "splitext_root": stem,
        "splitext_ext": ext,
        "isabs_yes": 1 if isabs("/x") else 0,
        "isabs_no": 1 if isabs("rel/x") else 0,

    };
}
