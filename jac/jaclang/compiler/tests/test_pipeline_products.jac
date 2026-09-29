"""Product scheduling preserves cancellation and live fact prerequisites."""

import os;
import from tempfile { TemporaryDirectory }
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CancelToken }
import from unittest.mock { patch }
import jaclang.compiler.driver.pass_driver as pass_driver;
import from jaclang.testing.test { parametrize }
import from jaclang.compiler.driver.pipeline {
    require_product,
    product_ready,
    validate_product_specs,
    _analysis_sched_loading,
    CompilationProduct
}
import from jaclang.compiler.driver.pipeline_types {
    AnalysisFact,
    ProductTask,
    TaskState
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { Module }
import from jaclang.compiler.passes.cfg_build_pass { CFGBuildPass }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }


def tasks_of(
    program: JacProgram, module: Module
) -> dict[CompilationProduct, ProductTask] {
    return program.analysis.product_tasks[id(module)];
}


# (row id, token cancelled before the first scheduling attempt, CFG_SUCC live
# after the cancelled run). Both rows must leave every product retryable once
# the token clears, without fabricating missing facts.
glob CANCEL_ROWS: list[tuple[any, ...]] = [
         ("before-flow", True, False),
         ("mid-schedule", False, True)
     ];

def _cancel_row(row: tuple[any, ...]) {
    (row_id, pre_cancelled, cfg_live_after) = row;
    with TemporaryDirectory() as temp_dir {
        program = JacProgram();
        path = os.path.join(temp_dir, f"pipeline_cancel_{row_id}_9151.jac");
        token = CancelToken();
        original = pass_driver.run_pass;
        def cancel_after_flow(
            pass_cls: type, ir_in: any, prog: JacProgram, **kwargs: any
        ) -> any {
            result = original(pass_cls, ir_in, prog, **kwargs);
            if pass_cls is CFGBuildPass {
                token.set();
            }
            return result;
        }
        module = program.parse_str(
            "def answer() -> int { return 42; }\n", path, cancel_token=token
        );
        program.options.cancel_token = token;
        if pre_cancelled {
            token.set();
        }
        with patch.object(pass_driver, "run_pass", cancel_after_flow) {
            assert not require_product(
                program, module, CompilationProduct.ANALYSIS, cancel_token=token
            ) , row_id;
        }
        assert token.is_set() , row_id;
        assert program.analysis.analyses_run.provides(module, AnalysisFact.CFG_SUCC)
            == cfg_live_after , row_id;
        assert not program.analysis.analyses_run.provides(
            module, AnalysisFact.TYPE_OF
        ) , row_id;
        tasks = tasks_of(program, module);
        flow_state = tasks[CompilationProduct.FLOW].state;
        analysis_state = tasks[CompilationProduct.ANALYSIS].state;
        assert flow_state == TaskState.CANCELLED , f"{row_id}: flow {flow_state}";
        assert analysis_state == TaskState.CANCELLED , (
            f"{row_id}: analysis {analysis_state}"
        );
        token.clear();
        assert require_product(program, module, CompilationProduct.ANALYSIS) , row_id;
        assert program.analysis.analyses_run.provides(
            module, AnalysisFact.CFG_SUCC
        ) , row_id;
        assert program.analysis.analyses_run.provides(
            module, AnalysisFact.TYPE_OF
        ) , row_id;
        assert tasks[CompilationProduct.FLOW].state == TaskState.SUCCEEDED , (
            f"{row_id}: flow retry"
        );
        assert tasks[CompilationProduct.ANALYSIS].state == TaskState.SUCCEEDED , (
            f"{row_id}: analysis retry"
        );
    }
}

with entry {
    parametrize(
        "cancellation leaves products retryable without fabricating facts",
        CANCEL_ROWS,
        _cancel_row,
        id_fn=lambda (row: tuple[any, ...]) { row[0]; }
    );
}

test "guard-emptied analysis schedule stays retryable instead of succeeding" {
    with TemporaryDirectory() as temp_dir {
        program = JacProgram();
        path = os.path.join(temp_dir, "pipeline_guard_empty_9151.jac");
        module = program.parse_str("def answer() -> int { return 42; }\n", path);
        load_tok = _analysis_sched_loading.set(True);
        try {
            assert not require_product(program, module, CompilationProduct.ANALYSIS);
            tasks = tasks_of(program, module);
            assert tasks[CompilationProduct.FLOW].state == TaskState.SUCCEEDED , (
                tasks[CompilationProduct.FLOW].state
            );
            assert tasks[CompilationProduct.ANALYSIS].state == TaskState.PENDING , (
                tasks[CompilationProduct.ANALYSIS].state
            );
            assert program.analysis.analyses_run.provides(
                module, AnalysisFact.CFG_SUCC
            );
            assert not program.analysis.analyses_run.provides(
                module, AnalysisFact.TYPE_OF
            );
        } finally {
            _analysis_sched_loading.reset(load_tok);
        }
        assert require_product(program, module, CompilationProduct.ANALYSIS);
        tasks = tasks_of(program, module);
        assert tasks[CompilationProduct.ANALYSIS].state == TaskState.SUCCEEDED;
        assert program.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF);
    }
}

test "module compilation blocks on cancelled analysis and resumes to codegen" {
    with TemporaryDirectory() as temp_dir {
        program = JacProgram();
        path = os.path.join(temp_dir, "pipeline_module_cancel_9151.jac");
        source = "def answer() -> int { return 42; }\n";
        Path(path).write_text(source);
        token = CancelToken();
        original = pass_driver.run_pass;
        def cancel_at_typecheck(
            pass_cls: type, ir_in: any, prog: JacProgram, **kwargs: any
        ) -> any {
            result = original(pass_cls, ir_in, prog, **kwargs);
            if pass_cls is TypeCheckPass {
                token.set();
            }
            return result;
        }
        with patch.object(pass_driver, "run_pass", cancel_at_typecheck) {
            program.compile(path, cancel_token=token);
        }
        assert token.is_set();
        assert not any(
            "scheduling error" in alert.msg for alert in program.errors_had
        ) , [alert.msg for alert in program.errors_had];
        module = program.find_module(os.path.realpath(path));
        assert module is not None;
        assert program.analysis.analyses_run.provides(module, AnalysisFact.CFG_SUCC);
        assert not product_ready(program, module, CompilationProduct.ANALYSIS);
        tasks = program.analysis.product_tasks.get(id(module));
        assert tasks is not None;
        assert tasks[CompilationProduct.ANALYSIS].state == TaskState.CANCELLED;
        assert module.gen.py_bytecode is None;
        resumed = program.compile(path);
        assert not any(
            "scheduling error" in alert.msg for alert in program.errors_had
        ) , [alert.msg for alert in program.errors_had];
        assert program.analysis.analyses_run.provides(resumed, AnalysisFact.TYPE_OF);
        tasks = program.analysis.product_tasks.get(id(resumed));
        assert tasks is not None;
        assert tasks[CompilationProduct.ANALYSIS].state == TaskState.SUCCEEDED;
        assert resumed.gen.py_bytecode is not None;
    }
}

test "product readiness facts are backed by their pipelines" {
    validate_product_specs();
}
