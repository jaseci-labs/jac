impl clip(text: str, limit: int = 600) -> str {
    return text.replace("\n", " | ")[:limit];
}

impl probe_fixture(fixture: str, rows: list[tuple[str, str, str]]) -> list[str] {
    lines: list[str] = [];
    try {
        js_code = compile_fixture_to_js(fixture);
    } except Exception as exc {
        lines.append(f"  JS COMPILE FAILED: {clip(str(exc), 3000)}");
        return lines;
    }
    for (label, py_fn, na_fn) in rows {
        cl_fn = na_fn[:-3] + "_cl";
        py = run_py_fixture(fixture[:-4], py_fn);
        try {
            res = run_js_function(js_code, cl_fn);
        } except Exception as exc {
            lines.append(
                f"  [{label}] JS RUN ERROR {type(exc).__name__}: {clip(str(exc), 1500)}"
            );
            continue;
        }
        missing = sorted(set(py.keys()) - set(res.keys()));
        common = set(py.keys()) & set(res.keys());
        lines.append(
            f"  [{label}] py={len(py)} js={len(res)} common={len(common)} missing={len(
                missing
            )}"
        );
        if missing {
            lines.append(f"    missing: {missing[:80]}");
        }
        try {
            compare_results(py, res, label, 1e-9);
            lines.append("    common keys all match");
        } except Exception as exc {
            lines.append(f"    MISMATCH: {clip(str(exc), 1500)}");
        }
    }
    return lines;
}

impl probe_report -> str {
    lines: list[str] = [];
    with tempfile.TemporaryDirectory() as tmp {
        for (fixture, rows) in PROBES {
            lines.append(f"===== {fixture}");
            out_path = os.path.join(tmp, fixture + ".txt");
            pid = os.fork();
            if pid == 0 {
                try {
                    body = probe_fixture(fixture, rows);
                } except BaseException as exc {
                    body = [
                        f"  PROBE ERROR {type(exc).__name__}: {clip(str(exc), 1500)}"
                    ];
                }
                with open(out_path, "w") as fh {
                    fh.write("\n".join(body));
                }
                os._exit(0);
            }
            (_, status) = os.waitpid(pid, 0);
            if os.WIFSIGNALED(status) {
                lines.append(f"  CRASHED with signal {os.WTERMSIG(status)}");
            }
            if os.path.exists(out_path) {
                with open(out_path) as fh {
                    lines.append(fh.read());
                }
            }
        }
    }
    return "\n".join(lines);
}
