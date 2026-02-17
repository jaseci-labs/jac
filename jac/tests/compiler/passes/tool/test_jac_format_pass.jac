"""Jac format pass tests – migrated from test_jac_format_pass.py.

Tests that the Jac formatter produces correct output: fixture comparisons,
AST preservation, micro suite round-trip, and regression tests.
"""

import ast as ast3;
import os;
import from difflib { unified_diff }
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.helpers { add_line_numbers }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.runtimelib.test { parametrize }
import from tests.fixtures_list { MICRO_JAC_FILES }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "tool", "fixtures"
     );

def compare_files(
    original_file: str, formatted_file: str | None = None, auto_lint: bool = False
) {
    try {
        with open(original_file) as file {
            original_file_content = file.read();
        }
        if formatted_file is None {
            prog = JacProgram.jac_file_formatter(original_file, auto_lint=auto_lint);
            formatted_content = prog.mod.main.gen.jac;
        } else {
            with open(formatted_file) as file {
                formatted_content = file.read();
            }
        }
        diff = "\n".join(
            unified_diff(
                original_file_content.splitlines(),
                formatted_content.splitlines(),
                fromfile="original",
                tofile="formatted" if formatted_file is None else formatted_file,
            )
        );
        if diff {
            print(f"Differences found in comparison:\n{diff}");
            raise AssertionError("Files differ after formatting.") ;
        }
    } except FileNotFoundError {
        print(f"File not found: {original_file} or {formatted_file}");
        raise ;
    } except Exception as e {
        print(f"Error comparing files: {e}");
        raise ;
    }
}

def micro_suite_test(filename: str, auto_lint: bool = False) {
    code_gen_pure = JacProgram().compile(filename);
    format_prog = JacProgram.jac_file_formatter(filename, auto_lint=auto_lint);
    code_gen_format = format_prog.mod.main.gen.jac;
    code_gen_jac = JacProgram().compile(use_str=code_gen_format, file_path=filename);
    if "circle_clean_tests.jac" in filename {
        tokens = code_gen_format.split();
        num_test = 0;
        for i in range(len(tokens)) {
            if tokens[i] == "test" {
                num_test += 1;
                assert tokens[i + 1] == "{";
            }
        }
        assert num_test == 3;
        return;
    }
    before = "";
    after = "";
    try {
        before = ast3.dump(code_gen_pure.gen.py_ast[0], indent=2);
        after = ast3.dump(code_gen_jac.gen.py_ast[0], indent=2);
        assert isinstance(code_gen_pure, uni.Module)
        and isinstance(code_gen_jac, uni.Module) , "Parsed objects are not modules.";
        diff = "\n".join(unified_diff(before.splitlines(), after.splitlines()));
        assert not diff , "AST structures differ after formatting.";
    } except Exception as e {
        print(f"Error in {filename}: {e}");
        print(add_line_numbers(code_gen_pure.source.code));
        print("\n+++++++++++++++++++++++++++++++++++++++\n");
        print(add_line_numbers(code_gen_format));
        print("\n+++++++++++++++++++++++++++++++++++++++\n");
        if before and after {
            print("\n".join(unified_diff(before.splitlines(), after.splitlines())));
        }
        raise e ;
    }
}

test "simple walk fmt" {
    compare_files(os.path.join(FIXTURES, "simple_walk_fmt.jac"));
}

test "tagbreak" {
    compare_files(os.path.join(FIXTURES, "tagbreak.jac"));
}

test "has fmt" {
    compare_files(os.path.join(FIXTURES, "has_frmt.jac"));
}

test "import fmt" {
    compare_files(os.path.join(FIXTURES, "import_fmt.jac"));
}

test "archetype" {
    compare_files(os.path.join(FIXTURES, "archetype_frmt.jac"));
}

test "fstring comment not injected" {
    path = os.path.join(FIXTURES, "fstring_comment.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;
    lines = formatted.splitlines();

    # Check 1: Module-level comment must not end up inside an f-string
    assert "# Standalone comment" in formatted , "Module comment was lost";
    in_fstring = False;
    for line in lines {
        stripped = line.strip();
        if 'f"' in stripped or "f'" in stripped {
            in_fstring = True;
        }
        if in_fstring and "# Standalone comment" in line {
            raise AssertionError(
                "Comment was injected inside an f-string:\n" + formatted
            ) ;
        }
        if in_fstring and '";' in stripped {
            in_fstring = False;
        }
    }

    # Check 2: Body-level comments must stay next to their statements
    before_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "# Comment before" in ln
        ),
        None
    );
    fstring_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "function guard()" in ln
        ),
        None
    );
    after_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "# Comment after" in ln
        ),
        None
    );
    assert before_idx is not None , "'# Comment before' was lost";
    assert fstring_idx is not None , "f-string statement was lost";
    assert after_idx is not None , "'# Comment after' was lost";
    assert before_idx < fstring_idx , (
        f"Comment before f-string was displaced after it "
        f"(comment at line {before_idx + 1}, f-string at line {fstring_idx + 1}):\n" + formatted
    );
    assert after_idx > fstring_idx , (
        f"Comment after f-string was displaced before it "
        f"(comment at line {after_idx + 1}, f-string at line {fstring_idx + 1}):\n" + formatted
    );

    # Check 3: Idempotency
    prog2 = JacProgram.jac_file_formatter(path, auto_lint=True);
    formatted2 = prog2.mod.main.gen.jac;
    assert formatted == formatted2 , "Formatting is not idempotent";
}

test "jsx hash text preserved" {
    path = os.path.join(FIXTURES, "jsx_hash_text.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    assert "# for client-side routing." in formatted , (
        "Hash-prefixed JSX text was lost:\n" + formatted
    );

    lines = formatted.splitlines();
    hash_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "# for client-side routing." in ln
        ),
        None,
    );
    close_p_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "</p>" in ln
        ),
        None,
    );
    assert hash_idx is not None and close_p_idx is not None , (
        "Could not find hash text or </p> in formatted output:\n" + formatted
    );
    assert hash_idx < close_p_idx , (
        f"Hash text at line {hash_idx + 1} should be before </p> at "
        f"line {close_p_idx + 1}:\n" + formatted
    );

    # Idempotency
    prog2 = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert formatted == prog2.mod.main.gen.jac , "Formatting is not idempotent";
}

def format_test(rel_path: str) -> None {
    filename = os.path.normpath(os.path.join(JAC_ROOT, rel_path));
    if not os.path.exists(filename) {
        return;
    }
    micro_suite_test(filename);
}

with entry {
    parametrize("format", MICRO_JAC_FILES, format_test, id_fn=lambda f : Path(f).stem);
}
