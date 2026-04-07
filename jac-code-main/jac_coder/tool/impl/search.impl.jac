impl grep_search(
    pattern: str, path: str = ".", file_pattern: str = "", max_results: int = 50
) -> str {
    (path, err) = sandbox_path(path);
    if err {
        return err;
    }
    tool_status("grep", f"'{pattern}' in {path}");
    if not pattern {
        return "Error: pattern is required";
    }

    cmd = ["grep", "-rn", "-E", "--color=never"];
    cmd += [
        "--exclude-dir=.git",
        "--exclude-dir=node_modules",
        "--exclude-dir=__pycache__",
        "--exclude-dir=.jac"
    ];
    if file_pattern {
        cmd += ["--include", file_pattern];
    }
    cmd += ["-m", str(max_results), pattern, path];

    try {
        result = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=15);
        output = result.stdout.strip();
        if not output {
            tool_end("-> 0 matches");
            return f"No matches for '{pattern}' in {path}";
        }
        match_count = len(output.splitlines());
        tool_end(f"-> {match_count} matches");
        (output, _) = truncate_output(output);
        return output;
    } except subprocess.TimeoutExpired {
        tool_end("-> timeout", error=True);
        return "Error: Search timed out after 15 seconds";
    } except Exception as e {
        tool_end("-> error", error=True);
        return f"Error: {str(e)}";
    }
}


impl find_files(pattern: str, directory: str = ".") -> str {
    (directory, err) = sandbox_path(directory);
    if err {
        return err;
    }
    tool_status("glob", f"'{pattern}' in {directory}");
    if not pattern {
        return "Error: pattern is required";
    }

    p = Path(directory);
    if not p.exists() {
        return f"Error: Directory not found: {directory}";
    }

    try {
        files = sorted(
            [
                str(f)
                for f in p.glob(pattern)
                if f.is_file() and ".git" not in f.parts
            ]
        );
    } except Exception as e {
        tool_end("-> error", error=True);
        return f"Error: {str(e)}";
    }

    if not files {
        tool_end("-> 0 files");
        return f"No files matching '{pattern}'";
    }

    total = len(files);
    tool_end(f"-> {total} files");
    if total > 200 {
        return "\n".join(files[:200]) + f"\n\n... and {total - 200} more ({total} total)";
    }
    return "\n".join(files);
}
