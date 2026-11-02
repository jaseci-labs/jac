"""Bundled native `mimetypes` cross-backend equivalence fixture (#6978).

The same `import mimetypes` binds CPython's pure-Python `mimetypes` on the sv
backend and `na_stdlib/mimetypes.jac` on the na (native LLVM) backend. Both
lanes load the identical default tables AND read the same `knownfiles`
(`/etc/mime.types` when present), so the guesses stay congruent on a
configured host. Pins suffix_map chaining (`.tgz` -> `.tar.gz`), the
case-sensitive encodings_map vs case-insensitive type map, `data:` URL
handling, URL-vs-path dispatch, and the inverse (type -> extension) lookups
where the preferred extension must come first. ES/JS opts out.
"""

import mimetypes;


def mimetypes_py -> dict[any, any] {
    gt = mimetypes.guess_type("index.html");
    gz = mimetypes.guess_type("archive.tar.gz");
    tgz = mimetypes.guess_type("archive.tgz");
    unk = mimetypes.guess_type("mystery.zzzz");
    data = mimetypes.guess_type("data:text/css;base64,AAA");
    datap = mimetypes.guess_type("data:,hello");
    url = mimetypes.guess_type("http://example.com/a/b/c.png");
    caps = mimetypes.guess_type("README.TXT");
    ext_json = mimetypes.guess_extension("application/json");
    ext_txt = mimetypes.guess_extension("text/plain");
    ext_none = mimetypes.guess_extension("application/x-nope-nope");
    all_js = mimetypes.guess_all_extensions("text/javascript");
    ft = mimetypes.guess_file_type("styles.css");
    return {
        "html_type": gt[0],
        "html_enc_none": 1 if gt[1] is None else 0,
        "targz_type": gz[0],
        "targz_enc": gz[1],
        "tgz_type": tgz[0],
        "tgz_enc": tgz[1],
        "unk_type_none": 1 if unk[0] is None else 0,
        "data_type": data[0],
        "datap_type": datap[0],
        "url_type": url[0],
        "caps_type": caps[0],
        "ext_json": ext_json,
        "ext_txt": ext_txt,
        "ext_none_is_none": 1 if ext_none is None else 0,
        "all_js_count": len(all_js),
        "all_js_first": all_js[0],
        "css_type": ft[0],

    };
}


def mimetypes_cl -> dict[any, any] {
    return {};
}


def mimetypes_na -> dict[str, any] {
    gt = mimetypes.guess_type("index.html");
    gz = mimetypes.guess_type("archive.tar.gz");
    tgz = mimetypes.guess_type("archive.tgz");
    unk = mimetypes.guess_type("mystery.zzzz");
    data = mimetypes.guess_type("data:text/css;base64,AAA");
    datap = mimetypes.guess_type("data:,hello");
    url = mimetypes.guess_type("http://example.com/a/b/c.png");
    caps = mimetypes.guess_type("README.TXT");
    ext_json = mimetypes.guess_extension("application/json");
    ext_txt = mimetypes.guess_extension("text/plain");
    ext_none = mimetypes.guess_extension("application/x-nope-nope");
    all_js = mimetypes.guess_all_extensions("text/javascript");
    ft = mimetypes.guess_file_type("styles.css");
    return {
        "html_type": gt[0],
        "html_enc_none": 1 if gt[1] is None else 0,
        "targz_type": gz[0],
        "targz_enc": gz[1],
        "tgz_type": tgz[0],
        "tgz_enc": tgz[1],
        "unk_type_none": 1 if unk[0] is None else 0,
        "data_type": data[0],
        "datap_type": datap[0],
        "url_type": url[0],
        "caps_type": caps[0],
        "ext_json": ext_json,
        "ext_txt": ext_txt,
        "ext_none_is_none": 1 if ext_none is None else 0,
        "all_js_count": len(all_js),
        "all_js_first": all_js[0],
        "css_type": ft[0],

    };
}
