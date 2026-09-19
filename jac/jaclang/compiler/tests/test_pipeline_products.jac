"""Product scheduling preserves cancellation and live fact prerequisites."""

import os;
import tempfile;
import threading;
import from jaclang.compiler.driver.pipeline { require_product, CompilationProduct }
import from jaclang.compiler.driver.pipeline_types { AnalysisFact, TaskState }
import from jaclang.compiler.driver.program { JacProgram }


test "cancelled flow does not fabricate CFG facts or schedule analysis" {
    program = JacProgram();
    path = os.path.join(tempfile.gettempdir(), "jac_pipeline_cancel_9151.jac");
    token = threading.Event();
    token.set();
    module = program.parse_str(
        "def answer() -> int { return 42; }\n", path, cancel_token=token
    );
    program.options.cancel_token = token;

    assert not require_product(
        program, module, CompilationProduct.ANALYSIS, cancel_token=token
    );
    assert not program.analysis.analyses_run.provides(module, AnalysisFact.CFG_SUCC);
    assert not program.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF);
    task = program.analysis.product_tasks[id(module)][CompilationProduct.FLOW];
    assert task.state == TaskState.CANCELLED , task.state;
}
