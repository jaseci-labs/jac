"""Smoke test: verify all tools work."""

import from jac_coder.tool.filesystem { read_file, write_file, edit_file, list_files }
import from jac_coder.tool.search { grep_search, find_files }
import from jac_coder.tool.shell { bash_exec }
import from jac_coder.tool.jac_tools { jac_check, jac_run }

with entry {
    # 1. read_file
    result = read_file("cli.jac");
    assert "JacCoder" in result;
    print("read_file: OK");

    # 2. write_file + edit_file
    write_file("/tmp/jc_test.txt", "hello world\nfoo bar\n");
    result = edit_file("/tmp/jc_test.txt", "foo bar", "baz qux");
    assert "Replaced 1" in result;
    result = read_file("/tmp/jc_test.txt");
    assert "baz qux" in result;
    print("write_file + edit_file: OK");

    # 3. list_files
    result = list_files(".", "*.jac");
    assert "cli.jac" in result;
    print("list_files: OK");

    # 4. grep_search
    result = grep_search("def read_file", ".", "*.jac");
    assert "filesystem.jac" in result;
    print("grep_search: OK");

    # 5. find_files
    result = find_files("jac_coder/tool/*.jac");
    assert "filesystem.jac" in result;
    print("find_files: OK");

    # 6. bash_exec
    result = bash_exec("echo 'hello from bash'");
    assert "hello from bash" in result;
    print("bash_exec: OK");

    # 7. jac_check
    result = jac_check("cli.jac");
    print("jac_check: OK (" + str(len(result)) + " chars)");

    print("\n=== All tool tests passed! ===");
}
