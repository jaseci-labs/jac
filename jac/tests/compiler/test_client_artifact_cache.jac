"""Client output lives in the module cache, beside the bytecode.

A warm `jac run` served the server side of `main.jac` from its JIR cache in
well under a second and then spent most of a minute recompiling the same
graph for the client, because nothing cached what the ES backend emitted. A
module's client artifact (its JS, client manifest, the native modules it pulls
in, and its source map) is now a section of the same cache file: written
whenever the module's JS is produced, restored by the same cache hit that
serves bytecode, and rejected once the module or any file it imports changes.
"""

import os;
import tempfile;
import time;
import from jaclang.compiler.driver.jir {
    SEC_CLIENT,
    get_module_cache_path,
    read_section_bytes
}
import from jaclang.compiler.driver.pass_driver { compile_progress }
import from jaclang.compiler.driver.program { JacProgram }


glob _HELPER_SRC: str = (
         "def:pub label_of(i: int) -> str {\n" "    return f\"row-{i}\";\n" "}\n"
     ),
     _WIDGET_SRC: str = (
         "import from .helper { label_of }\n"
         "\n"
         "def:pub Widget(rows: list[str]) -> any {\n"
         "    out: list[str] = [];\n"
         "    for (i, r) in enumerate(rows) {\n"
         "        out.append(label_of(i) + r);\n"
         "    }\n"
         "    return <div>{out}</div>;\n"
         "}\n"
     );


"""A two-module client project; returns (helper path, widget path)."""
def _project -> tuple[str, str] {
    base = os.path.realpath(tempfile.mkdtemp(prefix="jac_client_cache_"));
    with open(os.path.join(base, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"clientcache\"\nkind = \"web-app\"\n");
    }
    helper = os.path.join(base, "helper.jac");
    with open(helper, "w") as f {
        f.write(_HELPER_SRC);
    }
    widget = os.path.join(base, "widget.jac");
    with open(widget, "w") as f {
        f.write(_WIDGET_SRC);
    }
    return (helper, widget);
}


"""Rewrite `path` with `text`, stamped clearly later than any cache file."""
def _edit(path: str, text: str) {
    with open(path, "w") as f {
        f.write(text);
    }
    later = time.time() + 5.0;
    os.utime(path, (later, later));
}


"""The modules that entered the compiler while `prog` built `target`."""
def _compiled_for(prog: JacProgram, target: str) -> tuple[any, list[str]] {
    seen: list[str] = [];
    with compile_progress.listen(seen.append) {
        artifact = prog.get_client_artifact(target);
    }
    return (artifact, [os.path.basename(p) for p in seen]);
}


test "the first client build persists the artifact beside the bytecode" {
    (_, widget) = _project();
    (artifact, compiled) = _compiled_for(JacProgram(), widget);
    assert artifact is not None and "label_of" in artifact.js , (
        "the cold build must produce the module's JS"
    );
    assert "widget.jac" in compiled , f"the cold build compiles the module, saw {compiled}";
    cached = read_section_bytes(get_module_cache_path(widget).read_bytes(), SEC_CLIENT);
    assert cached is not None , "the client artifact must land in the module cache";
}


test "a warm client build is served without compiling anything" {
    (_, widget) = _project();
    cold = JacProgram().get_client_artifact(widget);
    assert cold is not None;
    (warm, compiled) = _compiled_for(JacProgram(), widget);
    assert compiled == [] , f"a warm client build compiled {compiled}";
    assert warm is not None and warm.js == cold.js , "the cached JS must match the cold build";
    assert warm.manifest.exports == cold.manifest.exports , (
        "the cached manifest must match the cold build"
    );
}


test "the cache hit that serves bytecode also serves the client artifact" {
    (_, widget) = _project();
    assert JacProgram().get_client_artifact(widget) is not None;
    prog = JacProgram();
    assert prog.get_bytecode(widget) is not None , "the module's bytecode is cached too";
    (artifact, compiled) = _compiled_for(prog, widget);
    assert artifact is not None and compiled == [] , (
        f"the artifact restored with the bytecode must be served, compiled {compiled}"
    );
}


test "editing the module invalidates its cached artifact" {
    (_, widget) = _project();
    assert JacProgram().get_client_artifact(widget) is not None;
    _edit(widget, _WIDGET_SRC.replace("<div>{out}</div>", "<section>{out}</section>"));
    (artifact, compiled) = _compiled_for(JacProgram(), widget);
    assert "widget.jac" in compiled , f"an edited module must recompile, saw {compiled}";
    assert artifact is not None;
}


test "editing a module it imports invalidates the cached artifact" {
    (helper, widget) = _project();
    assert JacProgram().get_client_artifact(widget) is not None;
    _edit(helper, _HELPER_SRC.replace("row-", "line-"));
    (artifact, compiled) = _compiled_for(JacProgram(), widget);
    assert "widget.jac" in compiled , (
        f"a module whose import changed must recompile, saw {compiled}"
    );
    assert artifact is not None;
}


test "an artifact built for another framework is not served" {
    (_, widget) = _project();
    first = JacProgram().get_client_artifact(widget);
    assert first is not None and first.framework == "react" , (
        f"the artifact records the framework it was lowered for, got {first}"
    );
    other = JacProgram();
    held = other.get_client_artifact(widget);
    assert held is not None;
    held.framework = "solid";
    other._get_compiler()._persist_client_artifact(widget, held);
    (again, compiled) = _compiled_for(JacProgram(), widget);
    assert "widget.jac" in compiled , (
        f"an artifact lowered for another framework must recompile, saw {compiled}"
    );
    assert again is not None and again.framework == "react";
}
