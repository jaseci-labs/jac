"""Unit tests for the package manager's byte / filesystem / JSON / tar layers.

Run from the repo root (fixtures are resolved relative to the cwd):
    jac run engine/tests/unit/test_pm_fs.jac
"""

import from engine.src.ffi.libc { fflush, _exit, getenv }
import from engine.src.runtime.mem { read_byte }
import from engine.src.pm.bytes {
    ByteBuf,
    bytebuf_new,
    bytebuf_append_str,
    bytebuf_append_byte,
    bytebuf_to_str,
    bytebuf_free,
    bytes_to_str,
    str_to_cbuf,
    bytes_find,
    bytes_eq_str,
    b64_encode,
    b64_decode,
    sri_sha512,
    sri_matches,
    digest_b64,
    bytes_hex
}
import from engine.src.pm.fsx {
    fsx_mkdtemp,
    fsx_mkdir_p,
    fsx_write_str,
    fsx_read_text,
    fsx_read_bytes,
    fsx_perm,
    fsx_stat,
    fsx_scandir,
    FsxDir,
    fsx_symlink,
    fsx_readlink,
    fsx_is_symlink,
    fsx_is_dir,
    fsx_is_file,
    fsx_link,
    fsx_chmod,
    fsx_copy_file,
    fsx_rename,
    fsx_rm_rf,
    fsx_exists,
    fsx_umask_get,
    fsx_umask_set,
    fsx_unlink,
    FSX_EEXIST,
    FSX_ENOENT,
    fsx_mkdir
}
import from engine.src.pm.gunzip { gunzip_bytes, gunzip_is_gzip }
import from engine.src.pm.json {
    JVal,
    JsonDoc,
    json_parse_str,
    json_parse_bytes,
    jv_get,
    jv_get_str,
    jv_len,
    jv_at,
    jv_str,
    jv_is_obj,
    jv_is_arr,
    jv_is_missing,
    jv_is_null,
    jv_str_list,
    json_quote,
    json_stringify_compact,
    JV_NUM,
    JV_BOOL,
    JV_STR
}
import from engine.src.pm.tar {
    tar_list,
    tar_extract_npm,
    tar_relative_path,
    TarEntry,
    TarResult,
    TAR_FILE,
    TAR_DIR,
    TAR_SYMLINK
}
import from engine.src.pm.http { http_parse_url, HttpUrl, http_origin }

glob _ok: int = 0,
     _fail: int = 0;

def check(cond: bool, name: str) {
    if cond {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + name);
    }
}

def check_eq(got: str, want: str, name: str) {
    if got == want {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + name + " — got '" + got + "' want '" + want + "'");
    }
}

def check_int(got: int, want: int, name: str) {
    check_eq(str(got), str(want), name);
}

with entry {
    # ── bytes ────────────────────────────────────────────────────────────────
    p: int = str_to_cbuf("hello");
    check_eq(b64_encode(p, 5), "aGVsbG8=", "b64 hello");
    check_eq(b64_encode(p, 2), "aGU=", "b64 he");
    check_eq(b64_encode(p, 3), "aGVs", "b64 hel");
    check_eq(b64_encode(p, 0), "", "b64 empty");
    check_eq(bytes_to_str(p, 1, 3), "ell", "bytes_to_str");
    check_int(bytes_find(p, 5, 0, "ll"), 2, "bytes_find");
    check_int(bytes_find(p, 5, 3, "ll"), -1, "bytes_find from");
    check(bytes_eq_str(p, 3, 5, "lo"), "bytes_eq_str");
    check(not bytes_eq_str(p, 3, 5, "lox"), "bytes_eq_str overflow");
    abc: int = str_to_cbuf("abc");
    check_eq(digest_b64("sha1", abc, 3), "qZk+NkcGgWq6PiVxeFDCbJzQ2J0=", "sha1 abc");
    check_eq(
        sri_sha512(abc, 3),
        "sha512-3a81oZNherrMQXNJriBBMRLm+k6JqX6iCp7u5ktV05ohkpkqJ0/BqDa6PCOj/uu9RU1EI2Q86A4qmslPpUyknw==",
        "sri sha512 abc"
    );
    check(
        sri_matches(
            "sha512-3a81oZNherrMQXNJriBBMRLm+k6JqX6iCp7u5ktV05ohkpkqJ0/BqDa6PCOj/uu9RU1EI2Q86A4qmslPpUyknw==",
            abc,
            3
        ),
        "sri match"
    );
    check(sri_matches("sha1-qZk+NkcGgWq6PiVxeFDCbJzQ2J0=", abc, 3), "sri sha1 match");
    check(not sri_matches("sha1-qZk+NkcGgWq6PiVxeFDCbJzQ2Z0=", abc, 3), "sri mismatch");
    check(sri_matches("md5-whatever", abc, 3), "sri unknown algo passes");
    dec: ByteBuf = b64_decode("aGVsbG8=");
    check_eq(bytebuf_to_str(dec), "hello", "b64 decode");
    dec2: ByteBuf = b64_decode("aGVsbG8");
    check_eq(bytebuf_to_str(dec2), "hello", "b64 decode unpadded");
    bb: ByteBuf = bytebuf_new(4);
    bytebuf_append_str(bb, "abcdefghij");
    bytebuf_append_byte(bb, 33);
    check_eq(bytebuf_to_str(bb), "abcdefghij!", "bytebuf grow");
    check_int(bb.len, 11, "bytebuf len");
    check_eq(bytes_hex(abc, 3), "616263", "hex");

    # ── json ─────────────────────────────────────────────────────────────────
    doc: JsonDoc = json_parse_str(
        "{\"b\": 1, \"a\": [true, null, \"x\\u00e9\\n\", -2.5, 1e3], \"o\": {\"k\": \"v\",},}"
    );
    check(doc.ok, "json parses (trailing commas)");
    check_eq(",".join(doc.value.keys), "b,a,o", "json key order kept");
    check_int(jv_get(doc.value, "b").i, 1, "json int");
    check(jv_get(doc.value, "b").is_int, "json is_int");
    arr: JVal = jv_get(doc.value, "a");
    check_int(jv_len(arr), 5, "json arr len");
    check(jv_at(arr, 0).b, "json true");
    check(jv_is_null(jv_at(arr, 1)), "json null");
    check_eq(jv_str(jv_at(arr, 2)), "x" + chr(233) + "\n", "json escapes");
    check_eq(str(jv_at(arr, 3).num), "-2.5", "json float");
    check_int(jv_at(arr, 4).i, 1000, "json exponent int");
    check_eq(jv_get_str(jv_get(doc.value, "o"), "k", "?"), "v", "json nested get_str");
    check(jv_is_missing(jv_get(doc.value, "zz")), "json missing");
    check_eq(jv_get_str(doc.value, "zz", "dflt"), "dflt", "json get_str default");
    doc2: JsonDoc = json_parse_str("// comment\n{ /* block */ \"x\": \"y\" }");
    check(doc2.ok, "jsonc comments");
    check_eq(jv_get_str(doc2.value, "x", ""), "y", "jsonc value");
    doc3: JsonDoc = json_parse_str("{\"a\": }");
    check(not doc3.ok, "json error detected");
    doc4: JsonDoc = json_parse_str("[1, 2");
    check(not doc4.ok, "json unterminated array");
    doc5: JsonDoc = json_parse_str("\"\\ud83d\\ude00\"");
    check(doc5.ok and len(doc5.value.s) == 4, "json surrogate pair -> 4 utf-8 bytes");
    check_eq(
        json_quote("a\"b\\c\n\t" + chr(1)), "\"a\\\"b\\\\c\\n\\t\\u0001\"", "json_quote"
    );
    check_eq(
        json_stringify_compact(doc.value),
        "{\"b\":1,\"a\":[true,null,\"x"
            + chr(233)
            + "\\n\",-2.5,1000],\"o\":{\"k\":\"v\"}}",
        "json stringify"
    );
    check_eq(
        ",".join(jv_str_list(json_parse_str("[\"linux\", 3, \"!win32\"]").value)),
        "linux,!win32",
        "jv_str_list"
    );
    check_eq(
        ",".join(jv_str_list(json_parse_str("\"darwin\"").value)),
        "darwin",
        "jv_str_list scalar"
    );

    # ── fsx ──────────────────────────────────────────────────────────────────
    tmp_root: str = getenv("TMPDIR");
    if tmp_root == None or tmp_root == "" {
        tmp_root = "/tmp";
    }
    tmp: str = fsx_mkdtemp(tmp_root + "/jbpmtestXXXXXX");
    check(tmp != "" and fsx_is_dir(tmp), "mkdtemp");
    old_umask: int = fsx_umask_set(18);  # 0o022
    check(fsx_mkdir_p(tmp + "/a/b/c", 493), "mkdir_p");
    check(fsx_is_dir(tmp + "/a/b"), "mkdir_p intermediate");
    check_int(fsx_mkdir(tmp + "/a", 493), FSX_EEXIST, "mkdir EEXIST");
    check_int(fsx_write_str(tmp + "/a/f.txt", "content\n", 438), 0, "write_str");
    check_eq(fsx_read_text(tmp + "/a/f.txt"), "content\n", "read_text");
    check_int(fsx_perm(tmp + "/a/f.txt"), 420, "umask 022 applied to 0666 -> 0644");
    check_int(fsx_write_str(tmp + "/a/x.sh", "#!/bin/sh\n", 511), 0, "write exec");
    check_int(fsx_perm(tmp + "/a/x.sh"), 493, "umask 022 applied to 0777 -> 0755");
    fsx_umask_set(0);
    check_int(fsx_write_str(tmp + "/a/g.txt", "g", 438), 0, "write under umask 0");
    check_int(fsx_perm(tmp + "/a/g.txt"), 438, "umask 0 keeps 0666");
    check_int(fsx_umask_get(), 0, "umask_get");
    fsx_umask_set(old_umask);
    check_int(fsx_stat(tmp + "/a/f.txt").size, 8, "stat size");
    check_int(fsx_perm(tmp + "/nope"), -1, "perm missing");
    check_eq(fsx_read_text(tmp + "/nope"), "", "read_text missing");
    check_int(fsx_read_bytes(tmp + "/nope").len, -1, "read_bytes missing");
    check_int(fsx_symlink("f.txt", tmp + "/a/lnk"), 0, "symlink");
    check(fsx_is_symlink(tmp + "/a/lnk"), "is_symlink");
    check(not fsx_is_symlink(tmp + "/a/f.txt"), "not symlink");
    check_eq(fsx_readlink(tmp + "/a/lnk"), "f.txt", "readlink");
    check_eq(fsx_read_text(tmp + "/a/lnk"), "content\n", "read through symlink");
    check_int(fsx_link(tmp + "/a/f.txt", tmp + "/a/hard.txt"), 0, "hardlink");
    check_eq(fsx_read_text(tmp + "/a/hard.txt"), "content\n", "hardlink content");
    check_int(
        fsx_link(tmp + "/a/f.txt", tmp + "/a/hard.txt"), FSX_EEXIST, "hardlink EEXIST"
    );
    check_int(fsx_chmod(tmp + "/a/f.txt", 511), 0, "chmod");
    check_int(fsx_perm(tmp + "/a/hard.txt"), 511, "hardlink shares mode");
    check_int(
        fsx_copy_file(tmp + "/a/f.txt", tmp + "/a/copy.txt", 420), 0, "copy_file"
    );
    check_int(fsx_perm(tmp + "/a/copy.txt"), 420, "copy_file mode");
    check_eq(fsx_read_text(tmp + "/a/copy.txt"), "content\n", "copy_file content");
    d: FsxDir = fsx_scandir(tmp + "/a");
    check_eq(
        ",".join(d.names),
        "b,copy.txt,f.txt,g.txt,hard.txt,lnk,x.sh",
        "scandir sorted names"
    );
}

glob kinds: list[str] = [];
with entry {
    for k in d.kinds {
        kinds.append(str(k));
    }
    check_eq(",".join(kinds), "2,1,1,1,1,3,1", "scandir kinds");
    check_int(fsx_scandir(tmp + "/nope").rc, FSX_ENOENT, "scandir missing");
    check_int(fsx_rename(tmp + "/a/copy.txt", tmp + "/a/moved.txt"), 0, "rename");
    check(
        fsx_is_file(tmp + "/a/moved.txt") and not fsx_exists(tmp + "/a/copy.txt"),
        "rename effect"
    );
    fsx_rm_rf(tmp);
    check(not fsx_exists(tmp), "rm_rf");

    # ── gunzip ───────────────────────────────────────────────────────────────
    gz: ByteBuf = fsx_read_bytes("engine/tests/unit/fixtures/pm/hello.txt.gz");
    check(gz.len > 0, "fixture hello.txt.gz readable");
    check(gunzip_is_gzip(gz.ptr, gz.len), "gzip magic");
    plain: ByteBuf = gunzip_bytes(gz.ptr, gz.len);
    check_int(plain.len, 12 + 256 * 300, "gunzip length (binary-safe)");
    check(bytes_eq_str(plain.ptr, 0, plain.len, "hello world\n"), "gunzip prefix");
    check_int(read_byte(plain.ptr, 12), 0, "gunzip keeps NUL bytes");
    check_int(read_byte(plain.ptr, 12 + 255), 255, "gunzip byte 255");
    bad: ByteBuf = gunzip_bytes(abc, 3);
    check_int(bad.len, -1, "gunzip error on garbage");

    # ── tar ──────────────────────────────────────────────────────────────────
    tgz: ByteBuf = fsx_read_bytes("engine/tests/unit/fixtures/pm/sample-1.0.0.tgz");
    check(tgz.len > 0, "fixture tgz readable");
    want_sri: str = fsx_read_text(
        "engine/tests/unit/fixtures/pm/sample-1.0.0.tgz.sha512"
    );
    check_eq(sri_sha512(tgz.ptr, tgz.len), want_sri, "tgz sha512 matches python");
    tar: ByteBuf = gunzip_bytes(tgz.ptr, tgz.len);
    check(tar.len > 0, "tgz inflates");
    entries: list[TarEntry] = tar_list(tar.ptr, tar.len);
}

glob names: list[str] = [];
with entry {
    for e in entries {
        names.append(e.path);
    }
    check_int(len(entries), 9, "tar entry count");
    check_eq(names[0], "package/", "tar dir entry");
    check_int(entries[0].kind, TAR_DIR, "tar dir kind");
    check_eq(names[1], "package/package.json", "tar first file");
    check_int(entries[2].mode, 493, "tar exec mode");
    check_int(entries[1].mode, 420, "tar file mode");
    check_int(entries[4].size, 0, "tar empty file");
    check(
        names[6].startswith("package/long/long/")
            and names[6].endswith("/deep.js")
            and len(names[6]) > 100,
        "tar pax long path"
    );
    check_int(entries[7].kind, TAR_SYMLINK, "tar symlink kind");
    check_eq(entries[7].linkname, "lib/a.js", "tar symlink target");
    check_eq(
        tar_relative_path("package/./dotslash.js", 1),
        "dotslash.js",
        "relative path strips ./"
    );
    check_eq(tar_relative_path("package/", 1), "", "relative path of root dir");
    check_eq(
        tar_relative_path("package/a/../b.js", 1), "b.js", "relative path resolves .."
    );
    check_eq(
        tar_relative_path("package/../../etc/passwd", 1),
        "",
        "relative path escape blocked"
    );
    check_eq(
        tar_relative_path("weird-root/lib/x.js", 1),
        "lib/x.js",
        "relative path any root name"
    );
    dest: str = fsx_mkdtemp(tmp_root + "/jbpmtarXXXXXX");
    old2: int = fsx_umask_set(18);
    res: TarResult = tar_extract_npm(tar.ptr, tar.len, dest, 1);
    fsx_umask_set(old2);
    check(res.ok, "tar extract ok: " + res.error);
    check_int(res.files, 7, "tar extract file count (dirs/symlinks skipped)");
    check_eq(
        fsx_read_text(dest + "/lib/a.js"),
        "module.exports = 1;\n",
        "tar extracted content"
    );
    check_int(fsx_perm(dest + "/bin/cli.js"), 493, "tar exec -> 0777 & ~022 = 0755");
    check_int(fsx_perm(dest + "/lib/a.js"), 420, "tar file -> 0666 & ~022 = 0644");
    check_int(fsx_perm(dest + "/lib"), 493, "tar implicit dir 0755");
    check_int(fsx_stat(dest + "/lib/empty.js").size, 0, "tar empty file extracted");
    check_int(fsx_stat(dest + "/README.md").size, 22, "tar file with NUL bytes intact");
    check(fsx_is_file(dest + "/dotslash.js"), "tar ./ entry extracted");
    check(not fsx_exists(dest + "/link.js"), "tar symlink not materialised (npm mode)");
    check(
        fsx_is_file(
            dest
                + "/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/long/deep.js"
        ),
        "tar long path extracted"
    );
    fsx_rm_rf(dest);

    # ── http url ─────────────────────────────────────────────────────────────
    u: HttpUrl = http_parse_url("http://127.0.0.1:4873/@esbuild%2Faix-ppc64");
    check(
        u.ok
            and u.scheme == "http"
            and u.host == "127.0.0.1"
            and u.port == 4873
            and u.path == "/@esbuild%2Faix-ppc64",
        "url http with port"
    );
    u2: HttpUrl = http_parse_url(
        "https://registry.npmjs.org/is-odd/-/is-odd-3.0.1.tgz"
    );
    check(
        u2.ok
            and u2.port == 443
            and u2.host == "registry.npmjs.org"
            and u2.path == "/is-odd/-/is-odd-3.0.1.tgz",
        "url https default port"
    );
    check_eq(
        http_origin(u2), "https://registry.npmjs.org", "origin elides default port"
    );
    check_eq(http_origin(u), "http://127.0.0.1:4873", "origin keeps custom port");
    check(not http_parse_url("ftp://x").ok, "url unsupported scheme");
    check_eq(
        http_parse_url("https://user:pw@host.example/x").host,
        "host.example",
        "url userinfo dropped"
    );

    print("pm_fs: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
