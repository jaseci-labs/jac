"""CLI consumers retain their compilation context until artifact inspection."""

import gc;
import io;
import tempfile;
import from contextlib { redirect_stdout }
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.cli.commands { execution, transform }
import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import type from jaclang.compiler.backends.common.artifacts { NodeArtifacts }
import type from jaclang.compiler.ir.base { UniNode }

def read_after_collection(nd: UniNode) -> NodeArtifacts {
    gc.collect();
    return artifact_for(nd);
}

test "jac2py keeps its artifact context after compilation" {
    with tempfile.TemporaryDirectory() as tmp {
        source = Path(tmp) / "main.jac";
        source.write_text("def answer -> int { return 42; }\n");
        output = io.StringIO();
        with patch.object(
            transform, "artifact_for", side_effect=read_after_collection
        ), redirect_stdout(output) {
            assert transform.jac2py(str(source)) == 0;
        }
        assert "return 42" in output.getvalue();
    }
}

test "debug keeps its artifact context after compilation" {
    import from jaclang.runtime.debugger { debugger }
    with tempfile.TemporaryDirectory() as tmp {
        source = Path(tmp) / "main.jac";
        source.write_text("with entry { print(42); }\n");
        with patch.object(
            execution, "artifact_for", side_effect=read_after_collection
        ), patch.object(debugger, "has_breakpoint", return_value=False), patch.object(
            debugger, "runcall"
        ) as run, redirect_stdout(io.StringIO()) {
            assert execution.debug(str(source)) == 0;
            assert run.call_count == 1;
        }
    }
}
