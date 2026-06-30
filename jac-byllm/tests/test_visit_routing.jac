import io;
import os;
import sys;
import from jaclang { JacRuntimeInterface as Jac }

glob jac_import = Jac.jac_import,
     FIXTURE_DIR = os.path.join(os.path.dirname(__file__), "fixtures");


test "routes along edge attribute, not just node" {
    captured_output = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured_output;
    try {
        jac_import("routing_edge_choice", base_path=FIXTURE_DIR + "/");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured_output.getvalue();

    assert "VISITED:beta" in stdout_value;
    assert "VISITED:alpha" not in stdout_value;

    assert stdout_value.count("VISITED:") == 1;
}


test "routing-only call_params do not leak to the model" {
    captured_output = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured_output;
    try {
        jac_import("routing_param_leak", base_path=FIXTURE_DIR + "/");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured_output.getvalue();

    assert "LEAKED:" not in stdout_value;
    assert "HAS_TEMPERATURE:True" in stdout_value;
}


test "routes over an arbitrary non-adjacent node list without fabricating edges" {
    captured_output = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured_output;
    try {
        jac_import("routing_node_list", base_path=FIXTURE_DIR + "/");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured_output.getvalue();

    assert "FABRICATED_EDGE" not in stdout_value;
    assert "VISITED:" in stdout_value;
}


test "candidate nodes with identical field values are distinct visit targets" {
    captured_output = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured_output;
    try {
        jac_import("routing_dup_values", base_path=FIXTURE_DIR + "/");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured_output.getvalue();

    assert stdout_value.count("VISIT") == 2;
}


test "routing dispatches the LLM call through the call_llm plugin hook" {
    captured_output = io.StringIO();
    old_stdout = sys.stdout;
    sys.stdout = captured_output;
    try {
        jac_import("routing_call_llm_hook", base_path=FIXTURE_DIR + "/");
    } finally {
        sys.stdout = old_stdout;
    }
    stdout_value = captured_output.getvalue();

    assert "HOOK_CALLS:1" in stdout_value;
    assert "VISITED:a" in stdout_value;
}
