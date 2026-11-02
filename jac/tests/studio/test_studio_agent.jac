"""The built-in agent: a cancelled turn's tools never act in the next one."""
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.studio.native_agent { NativeAgentSession }

test "tools from a cancelled turn refuse to run once another turn starts" {
    with TemporaryDirectory() as tmp {
        (Path(tmp) / "a.jac").write_text("def a -> int {\n    return 1;\n}\n");
        agent = NativeAgentSession(name="jac", root_dir=tmp, cwd=tmp);
        agent._gen = 1;
        old_turn = {t.__name__: t for t in agent.make_tools(1)};
        agent._gen = 2;
        new_turn = {t.__name__: t for t in agent.make_tools(2)};
        assert old_turn["read_file"]("a.jac") == "error: cancelled";
        assert old_turn["write_file"]("b.jac", "x") == "error: cancelled";
        assert old_turn["run_command"]("echo hi") == "error: cancelled";
        assert not (Path(tmp) / "b.jac").exists();
        assert "def a" in new_turn["read_file"]("a.jac");
    }
}
