impl bash_exec(
    command: str, workdir: str = ".", timeout: int = 120, background: bool = False
) -> str {
    blocked = ["rm -rf /", "rm -rf ~", "mkfs", "dd if=", "> /dev/sd"];
    for pattern in blocked {
        if pattern in command {
            return "Error: Blocked dangerous command";
        }
    }

    timeout = min(timeout, 600);

    # Auto-detect long-running server commands and force background mode.
    # These commands never return — running them in foreground hangs forever.
    _server_patterns = ["jac start", "npm start", "npm run dev", "node server"];
    for _pat in _server_patterns {
        if _pat in command and not background {
            background = True;
            break;
        }
    }

    tool_status("bash", command);

    sroot = get_sandbox_root();
    if sroot {
        (workdir, err) = sandbox_path(workdir);
        if err {
            return err;
        }
        if not workdir or not os.path.isdir(workdir) {
            workdir = sroot;
        }
    } else {
        if not workdir or not os.path.isdir(workdir) {
            workdir = os.getcwd();
        }
    }

    if background {
        try {
            log_path = os.path.join(workdir, ".jac-server.log");
            log_file = open(log_path, "w");
            # Force unbuffered output so logs appear immediately
            env = {**os.environ, "PYTHONUNBUFFERED": "1"};
            proc = subprocess.Popen(
                ["bash", "-c", command],
                stdin=subprocess.DEVNULL,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                cwd=workdir,
                start_new_session=True,
                env=env
            );
            pid = proc.pid;

            # Wait for the server to start listening on a port (up to 15s)
            import time;
            port = "";
            for _attempt in range(15) {
                time.sleep(1);
                try {
                    ss_result = subprocess.run(
                        ["bash", "-c", f"ss -ltnp 2>/dev/null | grep 'pid={pid},' | head -1"],
                        stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=3
                    );
                    ss_out = ss_result.stdout.strip();
                    if ss_out {
                        # Extract port from ss output like "LISTEN 0 5 0.0.0.0:8001 ..."
                        for part in ss_out.split() {
                            if ":" in part and not part.startswith("pid") {
                                candidate = part.rsplit(":", 1)[-1];
                                if candidate.isdigit() {
                                    port = candidate;
                                    break;
                                }
                            }
                        }
                        if port {
                            break;
                        }
                    }
                } except Exception { }
            }

            if port {
                tool_end(f"-> PID {pid} listening on :{port}");
                return (
                    f"Background process started (PID: {pid}). "
                    f"Server listening on http://localhost:{port}/. "
                    f"Log: {log_path}. Use `kill {pid}` to stop it."
                );
            } else {
                tool_end(f"-> PID {pid} started (port not yet detected)");
                return (
                    f"Background process started (PID: {pid}). "
                    f"Port not yet detected — check log: {log_path}. "
                    f"Use `ss -ltnp | grep pid={pid}` to find the port. "
                    f"Use `kill {pid}` to stop it."
                );
            }
        } except Exception as e {
            return f"Error starting background process: {str(e)}";
        }
    }

    # Append pwd to capture final CWD after command
    wrapped = command + '\necho "\n__JACCODER_CWD__:$(pwd)"';

    try {
        result = subprocess.run(
            ["bash", "-c", wrapped],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=workdir
        );
    } except subprocess.TimeoutExpired {
        return f"Error: Command timed out after {timeout} seconds. If this is a long-running process (server, watcher), use background=True instead.";
    } except Exception as e {
        return f"Error: {str(e)}";
    }

    stdout = result.stdout or "";
    cwd_marker = "__JACCODER_CWD__:";
    if cwd_marker in stdout {
        parts = stdout.rsplit(cwd_marker, 1);
        stdout = parts[0].rstrip("\n");
    }

    output_parts = [];
    if stdout {
        output_parts.append(stdout);
    }
    if result.stderr {
        output_parts.append(f"STDERR:\n{result.stderr}");
    }

    output = "\n".join(output_parts) if output_parts else "(no output)";

    if result.returncode != 0 {
        output = f"Exit code: {result.returncode}\n{output}";
        tool_end(f"-> exit {result.returncode}", error=True);
    } else {
        out_lines = len(output.splitlines());
        tool_end(f"-> {out_lines} lines");
    }

    (output, _) = truncate_output(output);

    return output;
}
