"""def:pub endpoints reachable only through client imports must mount on
the server: the compiler bridges the call into an RPC stub, so a server
that never imports the module leaves a silent contract mismatch (the stub
POSTs into a 404/405)."""

import os;
import shutil;
import tempfile;
import from jaclang.runtimelib.testing { JacTestClient }

def _proj -> str {
    d = tempfile.mkdtemp(prefix="jacbridge_");
    with open(os.path.join(d, "jac.toml"), "w") as f {
        f.write('[project]\nname = "t"\nentry-point = "main.jac"\n');
    }
    with open(os.path.join(d, "storage.jac"), "w") as f {
        f.write(
            "node Doc {\n    has label: str = \"\";\n}\n\n"
                + "def:pub save_doc(label: str) -> str {\n"
                + "    root ++> Doc(label=label);\n"
                + "    return \"saved:\" + label;\n"
                + "}\n\n"
                + "def:pub count_docs() -> int {\n"
                + "    return len([root-->]);\n"
                + "}\n"
        );
    }
    with open(os.path.join(d, "main.jac"), "w") as f {
        f.write(
            "import from .storage { save_doc, count_docs }\n\n"
                + "def:pub app -> JsxElement {\n"
                + "    has n: int = 0;\n"
                + "    <button onClick={lambda { save_doc(\"x\"); }}>save {n}</button>;\n"
                + "}\n"
        );
    }
    return d;
}

test "client-only imported def:pubs are mounted as endpoints" {
    d = _proj();
    try {
        client = JacTestClient.from_file(os.path.join(d, "main.jac"));
        r = client.post("/function/save_doc", json={"label": "a"});
        assert r.ok , f"save_doc not mounted: {r.status_code}";
        assert r.data["result"] == "saved:a" , f"got {r.data}";
        r2 = client.post("/function/count_docs", json={});
        assert r2.ok , f"count_docs not mounted: {r2.status_code}";
        assert r2.data["result"] == 1 , f"got {r2.data}";
        client.close();
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}
