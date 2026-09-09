"""Chunked `flow for` (#7870 item 4a): `&mut xs.chunks(n)` fans out
per-chunk tasks whose loop variable is a stack list-view header into
the parent's element buffer -- no allocation per chunk, writes land in
the parent, reductions combine at the join. Output byte-identical
across gc modes, thread widths, and the Python backend (list views via
the `_jac_chunks` runtime)."""

import os;
import re;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "chunked_flow_for.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

test "chunk bodies build view headers without allocating" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE, options=CompileOptions(aot_mode=True, memory_profile="nogc")
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    text = str(ir.gen.llvm_ir);
    m = re.search(
        r'define[^\n]*@"__jac_ffor_body_\d+"\([^\n]*\n(.*?)\n\}', text, re.DOTALL
    );
    assert m , "no outlined flow-for body in IR";
    body = m.group(1);
    assert "chunk.hdr" not in body or "chunk.eb" in body , body[:400];
    assert "chunk.eb" in text , "no chunk header construction in IR";
    assert "__jac_halloc" not in m.group(1) , "chunk body allocates per chunk";
}

test "chunked output is identical across modes, widths, and python" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"ck_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", "--native", FIXTURE]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            outs[mode] = ran.stdout;
            if mode == "none" {
                for w in ("1", "8") {
                    _env = dict(os.environ);
                    _env["JAC_FLOW_THREADS"] = w;
                    wran = subprocess.run(
                        [out_bin], capture_output=True, text=True, env=_env
                    );
                    outs[f"w{w}"] = wran.stdout;
                }
            }
        }
        assert len(outs["none"].split("\n")) >= 3 , outs["none"];
        for k in ("rc", "cycles", "w1", "w8") {
            assert outs[k] == outs["none"] , f"{k}: {outs[k]} vs {outs['none']}";
        }
        py_src = os.path.join(tmp, "ck_py.jac");
        with open(FIXTURE) as f {
            _src = f.read();
        }
        with open(py_src, "w") as f {
            f.write(
                _src.replace('with entry {', 'with entry {\n    _force_py = eval("0");')
            );
        }
        pyr = subprocess.run(
            [sys.executable, "-m", "jaclang", "run", py_src],
            capture_output=True,
            text=True
        );
        assert pyr.returncode == 0 , f"py: {pyr.stderr}";
        _py_lines = [
            _l
            for _l in pyr.stdout.split("\n")
            if _l.strip().isdigit() or _l.strip().lstrip("-").isdigit()
        ];
        _na_lines = [
            _l
            for _l in outs["none"].split("\n")
            if _l.strip()
        ];
        assert _py_lines == _na_lines , f"py {_py_lines} vs native {_na_lines}";
    }
}
