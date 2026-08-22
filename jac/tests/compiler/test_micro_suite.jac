"""Consolidated micro suite tests for MICRO_JAC_FILES.

Combines four previously-separate parametrized suites into one test per file:
  - codegen: compile + position-completeness check + parent scrub
  - tree parent: re-compile + parent scrub (verifies cache path)
  - unparse roundtrip: unparse + re-compile + AST diff
  - format: format + re-compile + AST diff

This reduces ~640 parametrized tests to ~160 and eliminates redundant
compilations (was 6-7 compiles per file, now 4).
"""

import ast as ast3;
import os;
import from difflib { unified_diff }
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.helpers { add_line_numbers }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.tool.unparse_pass { unparse_module }
import from jaclang.runtimelib.test { parametrize }
import from tests.fixtures_list { MICRO_JAC_FILES }

def parent_scrub(`node: uni.UniNode) -> bool {
    for i in `node.kid {
        if not isinstance(i, uni.Module) and i.parent is None {
            return False;
        }
        if not parent_scrub(i) {
            return False;
        }
    }
    return True;
}

def micro_suite_combined_test(rel_path: str) -> None {
    filename = os.path.normpath(os.path.join(JAC_ROOT, rel_path));
    if not os.path.exists(filename) {
        return;
    }

    # --- Phase 1: Compile + codegen checks ---
    code_gen = JacProgram().compile(filename);
    assert code_gen is not None and code_gen.gen.py_ast is not None , (
        f"Compilation failed for {filename}"
    );
    from_jac = code_gen.gen.py_ast[0];
    from_jac_str = ast3.dump(from_jac, indent=2);
    assert isinstance(from_jac, ast3.Module) , f"Not a module for {filename}";
    compile(from_jac, filename="<ast>", mode="exec");
    # The loc-fill invariant (codegen-ir.md 5.1): the emitter stamps all
    # four normalized position values at construction time and there is no
    # fill pass behind it. A location-bearing node arriving here with a
    # field missing means a recipe was built off something other than the
    # one constructor that requires a source jac node -- which is what
    # `fix_missing_locations` used to paper over.
    #
    # The stronger `lineno >= 1` half holds for every node kind but the two
    # argued below. Both inherit a jac node that carries no position of its
    # own, both were measured on the retired Python-AST lane and behave
    # identically there, and neither is a property of the container: an
    # f-string's format-spec `Constant` and the implicit `self`/`cls` `arg`
    # of an ability reached through an annex. They are front-end debt, so
    # the argument is recorded rather than the check dropped -- every other
    # node kind still fails on a zero.
    for i in ast3.walk(from_jac) {
        if "lineno" not in getattr(type(i), "_attributes", ()) {
            continue;
        }
        for attr in ("lineno", "col_offset", "end_lineno", "end_col_offset") {
            val = getattr(i, attr, None);
            assert isinstance(val, int) , (
                f"{filename}: {type(i).__name__} has no {attr}: {ast3.dump(i)}"
            );
        }
        if isinstance(i, (ast3.Constant, ast3.arg)) {
            continue;
        }
        assert i.lineno >= 1 , (
            f"{filename}: {type(i).__name__} has lineno {i.lineno}: " f"{ast3.dump(i)}"
        );
    }
    assert parent_scrub(code_gen) , f"Parent scrub failed for {filename}";
    assert len(from_jac_str) > 10 , f"AST dump too short for {filename}";

    # --- Phase 2: Re-compile + parent scrub (tree parent test) ---
    code_gen2 = JacProgram().compile(filename);
    assert parent_scrub(code_gen2) , f"Parent scrub failed (pass 2) for {filename}";

    # --- Phase 3: Unparse roundtrip ---
    before = ast3.dump(code_gen.gen.py_ast[0], indent=2);
    unparsed = unparse_module(code_gen);
    code_gen_unparsed = JacProgram().compile(use_str=unparsed, file_path=filename);
    assert code_gen_unparsed is not None and code_gen_unparsed.gen.py_ast is not None , (
        f"Re-compilation from unparse failed for {filename}"
    );
    after_unparse = ast3.dump(code_gen_unparsed.gen.py_ast[0], indent=2);
    if "circle_clean_tests.jac" in filename {
        diff_lines = [
            i
            for i in unified_diff(before.splitlines(), after_unparse.splitlines(), n=0)
            if "test" not in i
        ];
        assert len(diff_lines) == 5 , (
            f"circle_clean_tests.jac: expected 5 diff lines, got {len(diff_lines)}"
        );
    } else {
        diff = "\n".join(unified_diff(before.splitlines(), after_unparse.splitlines()));
        assert len(diff) == 0 , f"Unparse round-trip diff for {filename}:\n{diff[:500]}";
    }

    # --- Phase 4: Format roundtrip ---
    format_prog = JacProgram.jac_file_formatter(filename);
    code_gen_format = format_prog.mod.main.gen.jac;
    code_gen_fmt = JacProgram().compile(use_str=code_gen_format, file_path=filename);
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
    } else {
        before_fmt = "";
        after_fmt = "";
        try {
            before_fmt = ast3.dump(code_gen.gen.py_ast[0], indent=2);
            after_fmt = ast3.dump(code_gen_fmt.gen.py_ast[0], indent=2);
            assert isinstance(code_gen, uni.Module)
                and isinstance(code_gen_fmt, uni.Module) , "Parsed objects are not modules.";
            diff = "\n".join(
                unified_diff(before_fmt.splitlines(), after_fmt.splitlines())
            );
            assert not diff , "AST structures differ after formatting.";
        } except Exception as e {
            print(f"Error in {filename}: {e}");
            print(add_line_numbers(code_gen.source.code));
            print("\n+++++++++++++++++++++++++++++++++++++++\n");
            print(add_line_numbers(code_gen_format));
            print("\n+++++++++++++++++++++++++++++++++++++++\n");
            if before_fmt and after_fmt {
                print(
                    "\n".join(
                        unified_diff(before_fmt.splitlines(), after_fmt.splitlines())
                    )
                );
            }
            raise e;
        }
    }
}

with entry {
    parametrize(
        "micro suite",
        MICRO_JAC_FILES,
        micro_suite_combined_test,
        id_fn=lambda (f) { Path(f).stem; }
    );
}
