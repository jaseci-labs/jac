"""Tests for ai_service: resolve_jac_imports (pure logic) and update_jac_code (live LLM call)."""

import os;
import shutil;
import tempfile;

def _load_dotenv() -> bool {
    env_path = os.path.join(os.path.realpath("."), ".env");
    if os.path.exists(env_path) {
        with open(env_path, "r") as f {
            for line in f {
                stripped = line.strip();
                if stripped and not stripped.startswith("#") and "=" in stripped {
                    idx = stripped.index("=");
                    key = stripped[:idx].strip();
                    value = stripped[idx + 1:];
                    if key {
                        os.environ[key] = value;
                    }
                }
            }
        }
    }
    return True;
}

glob _env_ready: bool = _load_dotenv();

import from services.ai_service { resolve_jac_imports, update_jac_code }

test "resolve_jac_imports returns empty list for content with no imports" {
    result = resolve_jac_imports("/tmp", "main.jac", "# no imports\nglob x: int = 1;\n");
    assert result == [];
}

test "resolve_jac_imports returns empty list for empty content" {
    result = resolve_jac_imports("/tmp", "main.jac", "");
    assert result == [];
}

test "resolve_jac_imports ignores non-relative imports (stdlib and npm)" {
    content = "import os;\nimport from math { sqrt }\nimport from \"@mantine/core\" { Button }\n";
    result = resolve_jac_imports("/tmp", "main.jac", content);
    assert result == [];
}

test "resolve_jac_imports resolves .jac relative import" {
    tmp_dir = tempfile.mkdtemp();
    try {
        utils_path = os.path.join(tmp_dir, "utils.jac");
        with open(utils_path, "w") as f {
            f.write("def helper() -> str { return \"ok\"; }\n");
        }
        content = "import from .utils { helper }\n";
        result = resolve_jac_imports(tmp_dir, "main.jac", content);
        assert len(result) == 1;
        assert result[0]["path"] == "utils.jac";
        assert "helper" in result[0]["content"];
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "resolve_jac_imports resolves .cl.jac relative import" {
    tmp_dir = tempfile.mkdtemp();
    try {
        comp_path = os.path.join(tmp_dir, "Button.cl.jac");
        with open(comp_path, "w") as f {
            f.write("def:pub Button(props: Any) { return <button />; }\n");
        }
        content = "cl import from .Button { Button }\n";
        result = resolve_jac_imports(tmp_dir, "main.cl.jac", content);
        assert len(result) == 1;
        assert result[0]["path"] == "Button.cl.jac";
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "resolve_jac_imports resolves nested path import" {
    tmp_dir = tempfile.mkdtemp();
    try {
        sub_dir = os.path.join(tmp_dir, "services");
        os.makedirs(sub_dir, exist_ok=True);
        helper_path = os.path.join(sub_dir, "utils.jac");
        with open(helper_path, "w") as f {
            f.write("def nested_helper() -> str { return \"nested\"; }\n");
        }
        content = "import from .services.utils { nested_helper }\n";
        result = resolve_jac_imports(tmp_dir, "main.jac", content);
        assert len(result) == 1;
        assert "services" in result[0]["path"];
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "resolve_jac_imports deduplicates the same import appearing twice" {
    tmp_dir = tempfile.mkdtemp();
    try {
        utils_path = os.path.join(tmp_dir, "utils.jac");
        with open(utils_path, "w") as f {
            f.write("def foo() -> str { return \"foo\"; }\n");
        }
        content = "import from .utils { foo }\nimport from .utils { foo }\n";
        result = resolve_jac_imports(tmp_dir, "main.jac", content);
        assert len(result) == 1;
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "resolve_jac_imports skips file that does not exist on disk" {
    tmp_dir = tempfile.mkdtemp();
    try {
        content = "import from .missing_module { something }\n";
        result = resolve_jac_imports(tmp_dir, "main.jac", content);
        assert result == [];
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "update_jac_code answers a question with explanation and no file updates" {
    result = update_jac_code(
        project_context="",
        user_request="What is the Jac programming language? Just explain briefly, do not modify any code."
    );
    assert result is not None;
    assert isinstance(result.explanation, str);
    assert len(result.explanation) > 0;
    assert isinstance(result.files, list);
    assert len(result.files) == 0;
}

test "update_jac_code returns CodeUpdateResponse with files list when code change requested" {
    simple_jac = "node Counter { has count: int = 0; }\n";
    result = update_jac_code(
        project_context="--- FILE: counter.jac ---\n" + simple_jac + "\n--- END FILE ---",
        user_request="Add a method called reset() that sets count back to 0. Return the full file."
    );
    assert result is not None;
    assert isinstance(result.explanation, str);
    assert isinstance(result.files, list);
    assert len(result.files) >= 1;
    file_update = result.files[0];
    assert isinstance(file_update.path, str);
    assert isinstance(file_update.content, str);
    assert len(file_update.content) > 0;
    assert "reset" in file_update.content;
}

test "update_jac_code returns non-empty explanation for all requests" {
    result = update_jac_code(
        project_context="",
        user_request="How do I define a walker in Jac?"
    );
    assert len(result.explanation) > 10;
}
