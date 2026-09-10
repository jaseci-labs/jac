"""A comptime fold keys on the content of the modules it folded from.

A module that folds a value out of another module at compile time bakes
that value into its own artifact, so its cache must stop being valid the
moment the producing module's content moves -- transitively, through
whatever the comptime evaluation actually read. The ordinary
interface-hash cutoff cannot see this: a producer whose comptime value
changed still exports the same interface.

Every test builds its own throwaway project in a tempdir and points the
platform cache-home variables at that tempdir while it runs, so the JIR
the test writes lands under the tempdir instead of the user's shared
cache, and tests are isolated from each other.
"""

import os;
import sys;
import tempfile;
import time;
import from jaclang.compiler.driver.compiler { JacCompiler }
import from jaclang.compiler.driver.jir { native_section_payload, SEC_NBITCODE }
import jaclang.compiler.backends.native.llvm.binding as llvm;
import from jaclang.compiler.driver.jir {
    SEC_CTDEPS,
    get_module_cache_path,
    precompiled_jir_matches_source,
    read_section_bytes
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.dist.precompile_bytecode { precompile_unit }
import from types { CodeType }
import from unittest.mock { patch }

glob CACHE_HOME_VARS: tuple = (
         "HOME",
         "USERPROFILE",
         "XDG_CACHE_HOME",
         "LOCALAPPDATA"
     ),
     SPEC_SRC: str = "obj Spec {\n    has name: str,\n        help: str;\n}\n",
     OTHER_SRC: str = "def helper -> int {\n    return 1;\n}\n",
     OTHER_SRC_EDIT: str = "def helper -> int {\n    return 2;\n}\n",
     CONSUMER_SRC: str = (
         "import from specmod { Spec }\n"
         "import from othermod { helper }\n\n"
         "comptime import from prodmod { SPEC }\n\n"
         "comptime FOLDED: str = SPEC.help;\n\n"
         "with entry {\n"
         "    print(FOLDED);\n"
         "    print(helper());\n"
         "}\n"
     );

def _isolated(tmp: str) -> any {
    env: dict[str, str] = {var: tmp for var in CACHE_HOME_VARS};
    env["JAC_REBUILD"] = "";
    env["JAC_NO_PRECOMPILE"] = "";
    return patch.dict(os.environ, env);
}

def _base_src(text: str) -> str {
    return f"comptime BASE: str = \"{text}\";\n";
}

def _prod_src(text: str) -> str {
    return (
        "import from specmod { Spec }\n\n"
        "comptime import from basemod { BASE }\n\n"
        f"comptime SPEC: Spec = Spec(name=\"create\", help=BASE + \"{text}\");\n"
    );
}

def _write(path: str, body: str, backdate: bool = False) {
    with open(path, "w") as fh {
        fh.write(body);
    }
    if backdate {
        past = time.time() - 5;
        os.utime(path, (past, past));
    }
}

def _project -> dict[str, str] {
    tmp = tempfile.mkdtemp();
    paths: dict[str, str] = {"root": tmp};
    for name in ("specmod", "othermod", "basemod", "prodmod", "consmod") {
        paths[name] = os.path.realpath(os.path.join(tmp, f"{name}.jac"));
    }
    _write(paths["specmod"], SPEC_SRC, backdate=True);
    _write(paths["othermod"], OTHER_SRC, backdate=True);
    _write(paths["basemod"], _base_src("base one"), backdate=True);
    _write(paths["prodmod"], _prod_src(" help"), backdate=True);
    _write(paths["consmod"], CONSUMER_SRC, backdate=True);
    return paths;
}

def _pair(producer: str, consumer: str) -> dict[str, str] {
    tmp = tempfile.mkdtemp();
    paths: dict[str, str] = {"root": tmp};
    paths["producer"] = os.path.realpath(os.path.join(tmp, "prodmod.jac"));
    paths["consumer"] = os.path.realpath(os.path.join(tmp, "consmod.jac"));
    _write(paths["producer"], producer, backdate=True);
    _write(paths["consumer"], consumer, backdate=True);
    return paths;
}

def _consts(code: CodeType) -> list[str] {
    out: list[str] = [];
    for c in code.co_consts {
        if isinstance(c, str) {
            out.append(c);
        } elif hasattr(c, "co_consts") {
            out.extend(_consts(c));
        }
    }
    return out;
}

def _folded(path: str) -> list[str] {
    compiler = JacCompiler();
    prog = JacProgram();
    code = compiler.get_bytecode(path, prog);
    assert code is not None , (
        f"no bytecode for {path}: " f"{[a.pretty_print() for a in prog.errors_had]}"
    );
    return _consts(code);
}

def _refolds(paths: dict[str, str], producer_v2: str, want: str) {
    cold = _folded(paths["consumer"]);
    assert want.replace(" two", " one") in cold , f"cold compile did not fold: {cold}";
    _write(paths["producer"], producer_v2);
    warm = _folded(paths["consumer"]);
    assert want in warm , f"the consumer served a stale fold: {warm}";
}

test "a direct comptime producer edit is observed without manual invalidation" {
    paths = _project();
    with _isolated(paths["root"]) {
        cold = _folded(paths["consmod"]);
        assert "base one help" in cold , f"cold compile did not fold: {cold}";
        _write(paths["prodmod"], _prod_src(" HELP"));
        warm = _folded(paths["consmod"]);
        assert "base one HELP" in warm , (
            f"the consumer served a stale fold after its producer changed: {warm}"
        );
    }
}

test "a transitive comptime producer edit is observed too" {
    paths = _project();
    with _isolated(paths["root"]) {
        cold = _folded(paths["consmod"]);
        assert "base one help" in cold , f"cold compile did not fold: {cold}";
        _write(paths["basemod"], _base_src("base two"));
        warm = _folded(paths["consmod"]);
        assert "base two help" in warm , (
            "the consumer served a stale fold after a transitive producer "
            f"changed: {warm}"
        );
    }
}

test "the comptime producers are recorded on the consumer's cache" {
    paths = _project();
    with _isolated(paths["root"]) {
        _folded(paths["consmod"]);
        data = get_module_cache_path(paths["consmod"]).read_bytes();
        raw = read_section_bytes(data, SEC_CTDEPS);
        assert raw is not None , "the consumer recorded no comptime dependencies";
        text = raw.decode("utf-8");
        assert paths["prodmod"] in text , (
            f"the direct comptime producer is missing from SEC_CTDEPS: {text}"
        );
        assert paths["basemod"] in text , (
            f"the transitive comptime producer is missing from SEC_CTDEPS: {text}"
        );
    }
}

test "an edit to a module no fold read leaves the consumer's cache alone" {
    paths = _project();
    with _isolated(paths["root"]) {
        _folded(paths["consmod"]);
        cache = get_module_cache_path(paths["consmod"]);
        stamp = os.path.getmtime(cache);
        _write(paths["othermod"], OTHER_SRC_EDIT);
        _folded(paths["consmod"]);
        assert os.path.getmtime(cache) == stamp , (
            "a body-only edit to an ordinary dependency rebuilt the consumer"
        );
    }
}

test "a fold still resolves when the producer is served from its cache" {
    paths = _project();
    with _isolated(paths["root"]) {
        cold = _folded(paths["consmod"]);
        assert "base one help" in cold , f"cold compile did not fold: {cold}";
        get_module_cache_path(paths["consmod"]).unlink();
        again = _folded(paths["consmod"]);
        assert "base one help" in again , (
            f"the fold broke once the producer came back from cache: {again}"
        );
    }
}

test "an embedded file is re-read when its content changes" {
    tmp = tempfile.mkdtemp();
    with _isolated(tmp) {
        data = os.path.join(tmp, "payload.txt");
        _write(data, "alpha payload", backdate=True);
        src = os.path.realpath(os.path.join(tmp, "embedder.jac"));
        _write(
            src,
            "import from jaclang.comptime { embed_file }\n\n"
            "comptime BLOB: str = embed_file(\"payload.txt\");\n\n"
            "with entry {\n"
            "    print(BLOB);\n"
            "}\n",
            backdate=True
        );
        cold = _folded(src);
        assert "alpha payload" in cold , f"cold compile did not embed: {cold}";
        _write(data, "beta payload");
        warm = _folded(src);
        assert "beta payload" in warm , (
            f"the embedder served the stale file content: {warm}"
        );
    }
}

test "a comptime function body edit is observed by its callers" {
    paths = _pair(
        "comptime def banner -> str {\n    return \"banner one\";\n}\n",
        "comptime import from prodmod { banner }\n\n"
        "comptime TITLE: str = banner();\n\n"
        "with entry {\n    print(TITLE);\n}\n"
    );
    with _isolated(paths["root"]) {
        _refolds(
            paths,
            "comptime def banner -> str {\n    return \"banner two\";\n}\n",
            "banner two"
        );
    }
}

test "a class-body comptime constant edit is observed by its readers" {
    paths = _pair(
        "obj Palette {\n    comptime PRIMARY: str = \"ink one\";\n}\n",
        "comptime import from prodmod { Palette }\n\n"
        "comptime SHADE: str = Palette.PRIMARY;\n\n"
        "with entry {\n    print(SHADE);\n}\n"
    );
    with _isolated(paths["root"]) {
        _refolds(
            paths,
            "obj Palette {\n    comptime PRIMARY: str = \"ink two\";\n}\n",
            "ink two"
        );
    }
}

test "an enum member value edit is observed by its readers" {
    paths = _pair(
        "enum Level {\n    LOW = \"low one\"\n}\n",
        "comptime import from prodmod { Level }\n\n"
        "comptime TAG: str = Level.LOW.value;\n\n"
        "with entry {\n    print(TAG);\n}\n"
    );
    with _isolated(paths["root"]) {
        _refolds(paths, "enum Level {\n    LOW = \"low two\"\n}\n", "low two");
    }
}

test "a has-variable default edit is observed by its readers" {
    paths = _pair(
        "obj Box {\n    has label: str = \"box one\";\n}\n",
        "comptime import from prodmod { Box }\n\n"
        "comptime LABEL: str = Box().label;\n\n"
        "with entry {\n    print(LABEL);\n}\n"
    );
    with _isolated(paths["root"]) {
        _refolds(
            paths,
            "obj Box {\n    has label: str = \"box one\";\n}\n".replace(
                "box one", "box two"
            ),
            "box two"
        );
    }
}

def _bundle(paths: dict[str, str]) -> str {
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    bundle = os.path.join(paths["root"], "_precompiled", pyver);
    os.makedirs(bundle, exist_ok=True);
    for src in (paths["producer"], paths["consumer"]) {
        blob = precompile_unit(src, paths["root"]);
        assert blob is not None , f"precompile produced nothing for {src}";
        stem = os.path.splitext(os.path.basename(src))[0];
        with open(os.path.join(bundle, f"{stem}.jir"), "wb") as fh {
            fh.write(blob);
        }
    }
    return bundle;
}

def _spec_pair(text: str) -> dict[str, str] {
    return _pair(
        f"comptime SPEC: str = \"{text}\";\n",
        "comptime import from prodmod { SPEC }\n\n"
        "comptime USED: str = SPEC;\n\n"
        "with entry {\n    print(USED);\n}\n"
    );
}

test "an unsealed precompiled bundle does not serve a stale fold" {
    paths = _spec_pair("spec one");
    with _isolated(paths["root"]) {
        cold = _folded(paths["consumer"]);
        assert "spec one" in cold , f"cold compile did not fold: {cold}";
        _bundle(paths);
        _write(paths["producer"], "comptime SPEC: str = \"spec two\";\n");
        warm = _folded(paths["consumer"]);
        assert "spec two" in warm , (
            f"the unsealed precompiled bundle served a stale fold: {warm}"
        );
    }
}

test "a bundle promoted into the module cache carries its comptime deps" {
    paths = _spec_pair("spec one");
    with _isolated(paths["root"]) {
        cold = _folded(paths["consumer"]);
        assert "spec one" in cold , f"cold compile did not fold: {cold}";
        _bundle(paths);
        get_module_cache_path(paths["consumer"]).unlink();
        promoted = _folded(paths["consumer"]);
        assert "spec one" in promoted , (
            f"the bundle did not serve the consumer: {promoted}"
        );
        data = get_module_cache_path(paths["consumer"]).read_bytes();
        raw = read_section_bytes(data, SEC_CTDEPS);
        assert raw is not None , (
            "the promoted module cache recorded no comptime dependencies"
        );
        assert paths["producer"] in raw.decode("utf-8") , (
            f"the promoted rows are not absolute: {raw.decode('utf-8')}"
        );
        _write(paths["producer"], "comptime SPEC: str = \"spec two\";\n");
        warm = _folded(paths["consumer"]);
        assert "spec two" in warm , (
            f"the promoted module cache served a stale fold: {warm}"
        );
    }
}

def _native_compile(path: str) {
    prog = JacProgram();
    prog.compile(path);
    assert not prog.errors_had , (
        f"native compile of {path} failed: "
        f"{[a.pretty_print() for a in prog.errors_had]}"
    );
}

def _native_ir(path: str) -> str {
    cache_path = get_module_cache_path(path);
    if not cache_path.is_file() {
        return "";
    }
    payload = native_section_payload(
        read_section_bytes(cache_path.read_bytes(), SEC_NBITCODE),
        JacProgram().native_units().stamp_for()
    );
    return str(llvm.parse_bitcode(payload)) if payload is not None else "";
}

test "a native-placed fold is not served from stale JIR bitcode" {
    tmp = tempfile.mkdtemp();
    with _isolated(tmp) {
        _write(
            os.path.join(tmp, "jac.toml"),
            "[project]\nname = \"natfold\"\n\n"
            "[placement.pins]\nnatmod = \"native\"\n",
            backdate=True
        );
        producer = os.path.realpath(os.path.join(tmp, "tagmod.jac"));
        native = os.path.realpath(os.path.join(tmp, "natmod.jac"));
        main_mod = os.path.realpath(os.path.join(tmp, "entrymod.jac"));
        _write(producer, "comptime TAG: str = \"alpha\";\n", backdate=True);
        _write(
            native,
            "comptime import from tagmod { TAG }\n\n"
            "comptime LABEL: str = TAG;\n\n"
            "def tagged -> str {\n    return LABEL;\n}\n",
            backdate=True
        );
        _write(
            main_mod,
            "import from natmod { tagged }\n\n"
            "with entry {\n    print(tagged());\n}\n",
            backdate=True
        );
        _native_compile(main_mod);
        cold = _native_ir(native);
        assert cold , "the native lane wrote no JIR bitcode for the pinned module";
        assert "alpha" in cold , f"the cold native IR did not fold the producer";
        _write(producer, "comptime TAG: str = \"beta\";\n");
        _native_compile(main_mod);
        warm = _native_ir(native);
        assert "beta" in warm , (
            "the native JIR served a stale fold after its comptime " "producer changed"
        );
    }
}


test "precompile reuse rejects changed producers before sealing" {
    paths = _spec_pair("spec one");
    with _isolated(paths["root"]) {
        _folded(paths["consumer"]);
        blob = precompile_unit(paths["consumer"], paths["root"]);
        assert blob is not None;
        assert precompiled_jir_matches_source(
            blob, paths["consumer"], package_root=paths["root"]
        );
        _write(paths["producer"], "comptime SPEC: str = \"spec two\";\n");
        assert not precompiled_jir_matches_source(
            blob, paths["consumer"], package_root=paths["root"]
        ) , "precompile would reuse and seal the old producer's value";
    }
}
