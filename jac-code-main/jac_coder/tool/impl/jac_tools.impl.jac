impl jac_check(file: str) -> str {
    (file, err) = sandbox_path(file);
    if err {
        return err;
    }
    tool_status("jac_check", file);
    if not file {
        return "Error: file path is required";
    }

    try {
        result = subprocess.run(
            ["jac", "check", file], stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30
        );
        output = ((result.stdout or "") + (result.stderr or "")).strip();
        if not output {
            tool_end("-> clean");
            return f"No errors found in {file}";
        }
        err_count = len(
            [
                l
                for l in output.splitlines()
                if "error" in l.lower()
            ]
        );
        tool_end(
            f"-> {err_count} errors" if err_count > 0 else "-> clean",
            error=err_count > 0
        );
        (output, _) = truncate_output(output);
        return output;
    } except subprocess.TimeoutExpired {
        tool_end("-> timeout", error=True);
        return "Error: jac check timed out after 30 seconds";
    } except Exception as e {
        tool_end("-> error", error=True);
        return f"Error: {str(e)}";
    }
}


impl jac_run(file: str, args: str = "") -> str {
    (file, err) = sandbox_path(file);
    if err {
        return err;
    }
    tool_status("jac_run", file);
    if not file {
        return "Error: file path is required";
    }

    cmd = ["jac", "run", file];
    if args {
        cmd += args.split();
    }

    try {
        result = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=60);
        output = ((result.stdout or "") + (result.stderr or "")).strip();
        if not output {
            return "(no output)";
        }
        if result.returncode != 0 {
            output = f"Exit code: {result.returncode}\n{output}";
            tool_end(f"-> exit {result.returncode}", error=True);
        } else {
            tool_end("-> ok");
        }
        (output, _) = truncate_output(output);
        return output;
    } except subprocess.TimeoutExpired {
        tool_end("-> timeout", error=True);
        return "Error: jac run timed out after 60 seconds";
    } except Exception as e {
        tool_end("-> error", error=True);
        return f"Error: {str(e)}";
    }
}
