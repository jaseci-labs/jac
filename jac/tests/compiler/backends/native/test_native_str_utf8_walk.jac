"""Walking multibyte text natively matches CPython and leaks nothing.

A multibyte character read out of a string (`s[i]`, `for ch in s`, `next`
on a string iterator, a generator yielding it) is an immortal interned
string, so no caller owns it and none can leak or double-free it, under the
refcounting profiles and the headerless one alike. `for ch in s` advances by
byte offset, so a long non-ASCII string is walked in one pass, and views
read the ASCII flag from their root instead of probing their own data.

`str_utf8_walk.jac` pins the output against the Python backend under the
refcounting profiles, `str_utf8_walk_owned.jac` does the owned-world subset
under every profile (nogc included), `str_utf8_json.jac` pins json.dumps and
json.loads (which reads its source through a byte cursor, so a long non-ASCII
document with escapes parses in one pass), and `str_utf8_walk_leaks.jac`
repeats the shapes under an RC debug build, whose live-object dump at exit
must hold no leak.
"""

import from tests.support { assert_native_identity, jac_command }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "walking multibyte text agrees with the Python backend" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "str_utf8_walk.jac"), profiles=["rc", "managed"]
    );
    assert "40000 80001" in out , out[:400];
    assert "h|é|l|l|o 5 olléh él" in out , out[:600];
}

test "owned-world loops over multibyte text agree under every profile" {
    out = assert_native_identity(os.path.join(FIXTURES, "str_utf8_walk_owned.jac"));
    assert "40000 80001" in out , out[:400];
    assert "é 語 🙂x🙂 本語 a" in out , out[:400];
}

test "json.dumps and json.loads handle multibyte text the way CPython does" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "str_utf8_json.jac"), profiles=["managed"]
    );
    assert '"h\\u00e9llo" "héllo"' in out , out[:400];
    assert "150000 True True" in out , out[-400:];
    assert "True 3 [97, 55296, 233]" in out , out[-600:];
    assert '["a\\tb", "🙂é", "plain é", 1.5, -2, true, null]' in out , out[-400:];
}

test "walking multibyte text leaves no character alive" {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command(
            "build",
            "--native",
            os.path.join(FIXTURES, "str_utf8_walk_leaks.jac"),
            "-o",
            out_bin,
            "--debug"
        ),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"native build failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    assert "RC LIVE OBJECTS at exit" in proc.stdout , proc.stdout[-400:];
    leaks = [
        line
        for line in proc.stdout.split("\n")
        if "<- LEAK" in line
    ];
    assert not leaks , f"string walk leaked: {len(leaks)} e.g. {leaks[:3]}";
}
