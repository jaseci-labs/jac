"""test-gen command: generate deterministic spec-driven tests for by <model>() GenAI abilities.

Registered as a byLLM plugin CLI command. Compiles a .jac file, extracts MTIR
specs for all by <model>() GenAI abilities, calls a configurable LLM to generate deterministic
Jac test blocks, and writes the result to a committed .jac file.

Usage:
    jac test-gen mymodule.jac
    jac test-gen mymodule.jac --output tests/generated/mymodule.test.jac
    jac test-gen mymodule.jac --model openai/gpt-4o --dry-run
"""

import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

"""Generate deterministic Jac test blocks for all by <model>() GenAI abilities in a .jac file."""
@registry.command(
    name="test-gen",
    help="Generate deterministic spec-driven tests for by <model>() GenAI abilities",
    args=[
        Arg.create(
            "filepath",
            kind=ArgKind.POSITIONAL,
            help="Path to the .jac file to generate tests for"
        ),
        Arg.create(
            "output",
            default="",
            help="Output .jac file path (default: <source_dir>/<stem>.test.jac)",
            short="o"
        ),
        Arg.create(
            "model",
            default="openai/gpt-4o",
            help="LLM model to use for test generation (any LiteLLM model identifier)",
            short="m"
        ),
        Arg.create(
            "temperature",
            typ=float,
            default=0.2,
            help="Sampling temperature for test generation (lower = more deterministic)",
            short="t"
        ),
        Arg.create(
            "force",
            typ=bool,
            default=False,
            help="Regenerate tests even if spec hashes are unchanged",
            short="f"
        ),
        Arg.create(
            "dry_run",
            typ=bool,
            default=False,
            help="Print generated tests to stdout without writing to disk",
            short="d"
        ),
        Arg.create(
            "max_retries",
            typ=int,
            default=3,
            help="Max LLM attempts per function (per-attempt validation rounds) and post-gen fix rounds",
            short="r"
        ),
    ],
    examples=[
        ("jac test-gen mymodule.jac", "Generate tests for all by <model>() GenAI abilities"),
        (
            "jac test-gen mymodule.jac --model openai/gpt-4o",
            "Use a specific generator model"
        ),
        (
            "jac test-gen mymodule.jac --output path/to/mymodule.test.jac",
            "Write to a custom output path"
        ),
        ("jac test-gen mymodule.jac --dry-run", "Preview generated tests without writing"),
        ("jac test-gen mymodule.jac --force", "Regenerate all tests ignoring existing hashes"),
    ],
    group="analysis"
)
def test_gen(
    filepath: str,
    output: str = "",
    model: str = "openai/gpt-4o",
    temperature: float = 0.2,
    force: bool = False,
    dry_run: bool = False,
    max_retries: int = 3
) -> int;

"""Run `jac check <path>` on the generated file and return error text, or None if clean."""
def _run_jac_check(path: str) -> str | None {
    import subprocess;
    proc = subprocess.run(
        ["jac", "check", path],
        capture_output=True,
        text=True
    );
    if proc.returncode == 0 {
        return None;
    }
    return (proc.stdout + "\n" + proc.stderr).strip() or "jac check failed (no output)";
}

"""Run `jac test <path>` and return a dict mapping spec name -> error text for failures."""
def _run_jac_tests(path: str) -> dict[str, str] {
    import re;
    import subprocess;
    # Purge the cache first so the freshly-written file is compiled from source,
    # not served from a stale JIR that may have passed an earlier (buggy) version.
    subprocess.run(["jac", "purge"], capture_output=True, text=True);
    proc = subprocess.run(
        ["jac", "test", path],
        capture_output=True,
        text=True
    );
    if proc.returncode == 0 {
        return {};
    }
    output = proc.stdout + "\n" + proc.stderr;
    failures: dict[str, str] = {};
    # Parse: "ERROR: unittest.case.FunctionTestCase (test_fn_name)\n---\n<error>"
    # Also handles "FAIL: ..."
    for m in re.finditer(
        r"(?:ERROR|FAIL): unittest\.case\.FunctionTestCase \((\w+)\)\n-+\n(.*?)(?=\n(?:ERROR|FAIL|Ran |\Z))",
        output,
        re.DOTALL
    ) {
        failures[m.group(1)] = m.group(2).strip();
    }
    # Fallback: if pattern didn't match anything but tests did fail, include full output
    if not failures and proc.returncode != 0 {
        failures["__all__"] = output.strip();
    }
    return failures;
}

impl test_gen(
    filepath: str,
    output: str = "",
    model: str = "openai/gpt-4o",
    temperature: float = 0.2,
    force: bool = False,
    dry_run: bool = False,
    max_retries: int = 3
) -> int {
    import from pathlib { Path }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.cli.console { console }
    import from byllm.test_gen.spec_extractor { extract_specs }
    import from byllm.test_gen.code_generator { generate_tests_for_spec }
    import from byllm.test_gen.output_writer { write_test_file, read_existing_hashes }

    console.warning(
        "⚠ BETA: jac test-gen is an experimental feature. "
        "Generated tests may require manual review before use in CI."
    );

    source_path = Path(filepath).resolve();
    if not source_path.exists() {
        console.error(f"File not found: {filepath}");
        return 1;
    }
    if source_path.suffix != ".jac" {
        console.error(f"Expected a .jac file, got: {filepath}");
        return 1;
    }
    import os;
    src_dir: str = os.path.dirname(source_path);

    # Determine output path
    if output {
        output_path = str(Path(output).resolve());
    } else {
        output_path = str(source_path.parent / (source_path.stem + ".test.jac"));
    }

    # Compile the source file to populate the MTIR map
    console.info(f"Compiling {source_path.name}...");
    try {
        Jac.setup();
        Jac.jac_import(
            source_path.stem,
            base_path=str(source_path.parent) + "/",
            reload_module=True
        );
    } except Exception as e {
        console.error(f"Failed to compile {filepath}: {e}");
        return 1;
    }

    mtir_map = Jac.program.mtir_map if Jac.program else {};
    if not mtir_map {
        console.warning("No MTIR entries found — no by <model>() GenAI abilities detected in the file.");
        return 0;
    }

    # Filter MTIR map to only entries from the entrypoint file
    # MTIR keys are "module.qualname" — only include entries whose module matches the source stem
    source_stem = source_path.stem;
    file_mtir = {
        k: v
        for (k, v) in mtir_map.items()
        if k.startswith(source_stem + ".")
    };

    # Extract specs from MTIR
    specs = extract_specs(file_mtir);
    if not specs {
        console.warning("No by <model>() GenAI abilities found to generate tests for.");
        return 0;
    }

    console.info(f"Found {len(specs)} GenAI ability/abilities: {', '.join(s.name for s in specs)}");

    # Load existing hashes for incremental regeneration
    existing_hashes: dict[str, str] = {};
    if not force and not dry_run {
        existing_hashes = read_existing_hashes(output_path);
    }

    # Generate tests (skipping functions whose spec hash hasn't changed)
    results = [];
    skipped = 0;
    for spec in specs {
        current_hash = spec.spec_hash();
        if not force and existing_hashes.get(spec.name) == current_hash {
            console.info(f"  Skipping {spec.name} (spec unchanged)");
            skipped += 1;
            continue;
        }
        console.info(f"  Generating test for: {spec.name}");
        result = generate_tests_for_spec(spec, model_name=model, temperature=temperature, source_dir=src_dir, max_retries=max_retries);
        results.append(result);
        if result.error {
            console.warning(f"  ! {spec.name}: {result.error}");
        } else {
            console.success(f"  + {spec.name}: test generated");
        }
    }

    if not results and skipped > 0 {
        console.info(f"All {skipped} function(s) are up to date. Use --force to regenerate.");
        return 0;
    }

    successful = [r for r in results if r.test_code is not None];
    failed = [r for r in results if r.test_code is None];

    # Output
    if dry_run {
        for r in successful {
            print(f"\n# --- spec_hash:{r.spec.name}:{r.spec.spec_hash()} ---");
            print(r.test_code);
        }
        if failed {
            console.warning(f"\n{len(failed)} function(s) failed generation (see above for errors).");
        }
        return 0 if not failed else 1;
    }

    write_test_file(results, str(source_path), output_path);
    console.success(f"\nGenerated {len(successful)} test(s) → {output_path}");
    if skipped {
        console.info(f"({skipped} unchanged function(s) skipped)");
    }
    if failed {
        console.warning(f"({len(failed)} function(s) failed — see header comments in output file)");
        return 1;
    }

    # --- Post-generation: validate and fix (up to max_retries rounds) ---
    # Round 1: jac check (full-file compilation — catches syntax errors, wrong keywords, etc.)
    # Round 2+: jac test  (runtime assertion failures)
    max_fix_rounds = max_retries;
    spec_by_name = {s.name: s for s in specs};
    result_by_name = {r.spec.name: r for r in results if r.test_code is not None};

    for round_num in range(max_fix_rounds) {
        # Step 1: full-file syntax/type check
        console.info(f"\nRunning jac check on generated file (round {round_num + 1}/{max_fix_rounds})...");
        check_error = _run_jac_check(output_path);
        if check_error {
            console.warning(f"jac check failed — re-generating all tests with error feedback...");
            fixed_any = False;
            for spec_name in list(result_by_name.keys()) {
                if spec_name in spec_by_name {
                    console.info(f"  Re-generating: {spec_name}");
                    fix_result = generate_tests_for_spec(
                        spec_by_name[spec_name],
                        model_name=model,
                        temperature=temperature,
                        source_dir=src_dir,
                        max_retries=max_retries,
                        error_feedback=f"jac check on the generated file failed:\n{check_error}\n\nFix ALL syntax errors (use # for comments, not //; no `let` or `var`; test names must be quoted strings)."
                    );
                    result_by_name[spec_name] = fix_result;
                    fixed_any = True;
                }
            }
            if fixed_any {
                all_results = list(result_by_name.values());
                write_test_file(all_results, str(source_path), output_path);
                console.info(f"  Re-wrote {output_path} with fixes.");
            }
            continue;
        }

        # Step 2: runtime test execution
        console.info("jac check passed. Running jac test...");
        test_failures = _run_jac_tests(output_path);
        if not test_failures {
            console.success("All tests passed.");
            break;
        }

        console.warning(f"{len(test_failures)} test(s) failed — attempting to fix...");

        # Match failure test function names back to spec names
        fixed_any = False;
        for (fail_fn_name, error_text) in test_failures.items() {
            if fail_fn_name == "__all__" {
                # Fallback: re-generate all
                for spec_name in list(result_by_name.keys()) {
                    if spec_name in spec_by_name {
                        console.info(f"  Re-generating: {spec_name}");
                        fix_result = generate_tests_for_spec(
                            spec_by_name[spec_name],
                            model_name=model,
                            temperature=temperature,
                            source_dir=src_dir,
                            max_retries=max_retries,
                            error_feedback=error_text
                        );
                        result_by_name[spec_name] = fix_result;
                        fixed_any = True;
                    }
                }
            } else {
                matched_name: str | None = None;
                for spec_name in result_by_name.keys() {
                    normalized = spec_name.lower().replace(" ", "_");
                    if normalized in fail_fn_name.lower() {
                        matched_name = spec_name;
                        break;
                    }
                }
                if matched_name is not None and matched_name in spec_by_name {
                    console.info(f"  Re-generating: {matched_name} (test failure: {fail_fn_name})");
                    fix_result = generate_tests_for_spec(
                        spec_by_name[matched_name],
                        model_name=model,
                        temperature=temperature,
                        source_dir=src_dir,
                        max_retries=max_retries,
                        error_feedback=error_text
                    );
                    result_by_name[matched_name] = fix_result;
                    fixed_any = True;
                } else {
                    console.warning(f"  Could not match failed test '{fail_fn_name}' to any spec — skipping");
                }
            }
        }

        if not fixed_any {
            break;
        }

        # Re-write the file with updated results
        all_results = list(result_by_name.values());
        write_test_file(all_results, str(source_path), output_path);
        console.info(f"  Re-wrote {output_path} with fixes.");
    }

    return 0;
}
