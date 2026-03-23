import os;
import shutil;
import subprocess;
import signal;
import time;
import base64;
import from threading { Lock, Thread }
import from pathlib { Path }
import from typing { Any }
import from jac_scale.abstractions.sandbox_environment { SandboxEnvironment }
import from jac_scale.abstractions.models.sandbox_config { SandboxConfig }
import from jac_scale.abstractions.models.sandbox_result { SandboxResult }
import from jac_scale.abstractions.models.sandbox_status {
    SandboxState,
    SandboxStatus,
    SandboxInfo
}
import from jac_scale.abstractions.logger { Logger }

glob _IMAGE_MIME_TYPES: dict = {
         ".png": "image/png",
         ".jpg": "image/jpeg",
         ".jpeg": "image/jpeg",
         ".gif": "image/gif",
         ".webp": "image/webp",
         ".ico": "image/x-icon",
         ".bmp": "image/bmp",
         ".tiff": "image/tiff",
         ".tif": "image/tiff",
         ".svg": "image/svg+xml"
     },
     PROTECTED_FILES: list = ["jac.toml"],
     _WRITE_ALLOWED_PROTECTED: list = ["jac.toml"];

obj LocalSandbox(SandboxEnvironment) {
    has _registry: dict = {},
        _port_pool: list = list(range(5180, 5200, 2)),
        _lock: Lock = Lock(),
        _base_port: int = 5180,
        _port_count: int = 10;

    def _sandbox_key(user_id: str, project_id: str) -> str {
        safe_user = user_id or "session";
        safe_project = project_id or "__default__";
        return f"{safe_user}::{safe_project}";
    }

    def _sandbox_id(user_id: str, project_id: str) -> str {
        return f"local-{user_id}-{project_id}" if project_id else f"local-{user_id}";
    }

    def _find_jac_binary -> str {
        candidates = [os.path.join(str(Path.home()), ".jacvenv", "bin", "jac")];
        venv = str(os.environ.get("VIRTUAL_ENV", ""));
        if venv {
            candidates.append(os.path.join(venv, "bin", "jac"));
        }
        for p in candidates {
            if os.path.exists(p) {
                return p;
            }
        }
        result = shutil.which("jac");
        if result {
            return str(result);
        }
        raise FileNotFoundError("Could not find 'jac' binary.");
    }

    def _find_activate_script -> str {
        jacvenv_activate = os.path.join(str(Path.home()), ".jacvenv", "bin", "activate");
        if os.path.exists(jacvenv_activate) {
            return jacvenv_activate;
        }
        venv = str(os.environ.get("VIRTUAL_ENV", ""));
        if venv {
            activate = os.path.join(venv, "bin", "activate");
            if os.path.exists(activate) {
                return activate;
            }
        }
        jac_bin = self._find_jac_binary();
        activate = os.path.join(os.path.dirname(jac_bin), "activate");
        if os.path.exists(activate) {
            return activate;
        }
        return "";
    }

    def _resolve_path(preview_dir: str, path: str) -> str {
        candidate = path or ".";
        real_preview = os.path.realpath(preview_dir);
        full = os.path.realpath(
            candidate
                if os.path.isabs(candidate)
                else os.path.join(real_preview, candidate)
        );
        if os.path.commonpath([real_preview, full]) != real_preview {
            raise ValueError("Path is outside sandbox directory");
        }
        return full;
    }

    def _kill_port_listeners(port: int) -> None {
        try {
            result = subprocess.run(
                f"lsof -i :{port} -t",
                shell=True,
                capture_output=True,
                text=True,
                timeout=5
            );
            pids = str(result.stdout).strip();
            if pids {
                for pid_str in pids.split("\n") {
                    pid_str = str(pid_str).strip();
                    if pid_str {
                        try {
                            os.kill(int(pid_str), int(signal.SIGKILL));
                        } except (ProcessLookupError, ValueError) {
                            ;
                        }
                    }
                }
            }
        } except Exception {
            ;
        }
    }

    def _stop_process(rec: dict) -> None {
        log_file = rec.get("log_file");
        if log_file {
            try {
                getattr(log_file, "close")();
            } except Exception {
                ;
            }
            rec["log_file"] = None;
        }
        process = rec.get("process");
        if process is not None {
            try {
                pid = int(getattr(process, "pid"));
                os.killpg(os.getpgid(pid), int(signal.SIGTERM));
                getattr(process, "wait")(timeout=5);
            } except (ProcessLookupError, subprocess.TimeoutExpired) {
                try {
                    pid2 = int(getattr(process, "pid"));
                    os.killpg(os.getpgid(pid2), int(signal.SIGKILL));
                } except ProcessLookupError {
                    ;
                }
            } finally {
                rec["process"] = None;
            }
        }
        port = int(rec.get("port", 0));
        if port {
            for check_port in [port, port + 1] {
                self._kill_port_listeners(int(check_port));
            }
        }
    }

    def _poll_readiness(key: str, port: int, process: Any, log_path: str) -> None {
        import requests;
        vite_url = f"http://localhost:{port}";
        start_time = time.time();
        ready = False;
        while time.time() - start_time < 120 {
            if getattr(process, "poll")() is not None {
                break;
            }
            try {
                if os.path.exists(log_path) {
                    with open(log_path, "r", encoding="utf-8") as lf {
                        log_content = lf.read();
                    }
                    server_ready = "Server ready" in log_content;
                    vite_ready = "VITE v" in log_content and "ready in" in log_content;
                    watching = "Watching for changes" in log_content;
                    if server_ready and (vite_ready or watching) {
                        try {
                            resp = requests.get(vite_url, timeout=3);
                            if 200 <= int(getattr(resp, "status_code")) < 400 {
                                ready = True;
                                break;
                            }
                        } except Exception {
                            ;
                        }
                        if vite_ready {
                            ready = True;
                            break;
                        }
                    }
                    if server_ready {
                        if "Client bundle ready" in log_content
                        or "Client bundle built" in log_content {
                            ready = True;
                            break;
                        }
                    }
                }
            } except Exception {
                ;
            }
            time.sleep(3);
        }
        self._lock.acquire();
        try {
            rec: Any = self._registry.get(key);
            if not rec {
                return;
            }
            if ready {
                rec["status"] = SandboxState.RUNNING;
                rec["needs_install"] = False;
            } else {
                self._stop_process(dict(rec));
                if port not in self._port_pool {
                    self._port_pool.append(port);
                }
                rec["status"] = SandboxState.ERROR;
                rec["port"] = 0;
                rec["process"] = None;
            }
        } finally {
            self._lock.release();
        }
    }

    def create(user_id: str, project_id: str, code_path: str) -> SandboxResult {
        self._lock.acquire();
        try {
            key = self._sandbox_key(user_id, project_id);
            sid = self._sandbox_id(user_id, project_id);

            preview_suffix = f"-{project_id}" if project_id else "";
            preview_dir = f"/tmp/jac-preview-{user_id}{preview_suffix}";

            if key in self._registry {
                rec_d: dict = dict(self._registry[key]);
                previous_port = int(rec_d.get("port", 0));
                if rec_d.get("process") is not None {
                    self._stop_process(rec_d);
                }
            } else {
                previous_port = 0;
                real_code = os.path.realpath(code_path) if code_path else "";
                real_preview = os.path.realpath(preview_dir);
                if real_code and real_code != real_preview {
                    if os.path.exists(preview_dir) {
                        shutil.rmtree(preview_dir);
                    }
                    if os.path.isdir(code_path) {
                        shutil.copytree(code_path, preview_dir, symlinks=True);
                    } else {
                        os.makedirs(preview_dir, exist_ok=True);
                    }
                } elif not os.path.exists(preview_dir) {
                    os.makedirs(preview_dir, exist_ok=True);
                }
            }

            if previous_port
            and previous_port in range(
                self._base_port, self._base_port + self._port_count * 2, 2
            ) {
                port = previous_port;
                if port in self._port_pool {
                    self._port_pool.remove(port);
                }
            } else {
                if not self._port_pool {
                    return SandboxResult(success=False, message="No available ports");
                }
                port = self._port_pool.pop(0);
            }

            main_jac = os.path.join(preview_dir, "main.jac");
            if not os.path.isfile(main_jac) {
                self._port_pool.append(port);
                return SandboxResult(
                    success=False, message="main.jac not found in preview directory"
                );
            }

            api_port = port + 1;
            for check_port in [port, api_port] {
                self._kill_port_listeners(check_port);
            }
            time.sleep(0.5);

            activate_script = self._find_activate_script();
            jac_bin = self._find_jac_binary();

            src_dir = code_path or "";
            home_dir = str(Path.home());
            global_env = os.path.join(home_dir, ".jac-ide", "global.env");
            project_env_file = os.path.join(src_dir, ".env") if src_dir else "";
            env_sources = "";
            if os.path.isfile(global_env) {
                env_sources += f"source \"{global_env}\"; ";
            }
            if project_env_file and os.path.isfile(project_env_file) {
                env_sources += f"source \"{project_env_file}\"; ";
            }
            env_prefix = "";
            if env_sources {
                env_prefix = f"set -a; {env_sources}set +a; ";
            }

            existing_rec: dict = dict(self._registry.get(key, {}));
            needs_install = not (key in self._registry)
            or bool(existing_rec.get("needs_install", True));

            if activate_script {
                if needs_install {
                    shell_cmd = f"{env_prefix}source {activate_script} && jac install && jac start main.jac -p {port} --dev";
                } else {
                    shell_cmd = f"{env_prefix}source {activate_script} && jac start main.jac -p {port} --dev";
                }
            } else {
                if needs_install {
                    shell_cmd = f"{env_prefix}{jac_bin} install && {jac_bin} start main.jac -p {port} --dev";
                } else {
                    shell_cmd = f"{env_prefix}{jac_bin} start main.jac -p {port} --dev";
                }
            }

            log_path = os.path.join(preview_dir, ".jac-preview.log");
            log_file = open(log_path, "w", encoding="utf-8");

            process = subprocess.Popen(
                shell_cmd,
                shell=True,
                executable="/bin/bash",
                cwd=preview_dir,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                preexec_fn=os.setsid
            );

            self._registry[key] = {
                "sandbox_id": sid,
                "port": port,
                "api_port": api_port,
                "process": process,
                "dir": preview_dir,
                "status": SandboxState.STARTING,
                "user_id": user_id,
                "project_id": project_id,
                "source_dir": code_path,
                "needs_install": needs_install,
                "log_file": log_file,
                "log_path": log_path,
                "created_at": time.time()
            };

            checker = Thread(
                target=self._poll_readiness,
                args=(key, port, process, log_path),
                daemon=True
            );
            checker.start();

            url = f"http://localhost:{port}";
            return SandboxResult(
                success=True,
                sandbox_id=sid,
                url=url,
                port=port,
                api_port=api_port,
                message="starting"
            );
        } except Exception as e {
            return SandboxResult(success=False, message=str(e));
        } finally {
            self._lock.release();
        }
    }

    def stop(sandbox_id: str) -> None {
        self._lock.acquire();
        try {
            for (key, rec) in self._registry.items() {
                rec_d: dict = dict(rec);
                if str(rec_d.get("sandbox_id", "")) == sandbox_id {
                    self._stop_process(rec_d);
                    port = int(rec_d.get("port", 0));
                    if port
                    and port in range(
                        self._base_port, self._base_port + self._port_count * 2, 2
                    ) {
                        if port not in self._port_pool {
                            self._port_pool.append(port);
                        }
                    }
                    rec_d["port"] = 0;
                    rec_d["api_port"] = 0;
                    rec_d["status"] = SandboxState.STOPPED;
                    self._registry[key] = rec_d;
                    return;
                }
            }
        } finally {
            self._lock.release();
        }
    }

    def status(sandbox_id: str) -> SandboxStatus {
        for (key, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("sandbox_id", "")) == sandbox_id {
                process: Any = rec_d.get("process");
                state: Any = rec_d.get("status", SandboxState.STOPPED);
                alive = process is not None and getattr(process, "poll")() is None;
                if not alive
                and state in [SandboxState.RUNNING, SandboxState.STARTING] {
                    state = SandboxState.STOPPED;
                }
                created_at = float(rec_d.get("created_at", time.time()));
                uptime = time.time() - created_at if alive else 0.0;
                port_val = int(rec_d.get("port", 0));
                url = f"http://localhost:{port_val}" if alive else "";
                return SandboxStatus(
                    state=state,
                    sandbox_id=sandbox_id,
                    uptime_seconds=uptime,
                    url=url,
                    port=port_val
                );
            }
        }
        return SandboxStatus(state=SandboxState.STOPPED, sandbox_id=sandbox_id);
    }

    def destroy(sandbox_id: str) -> None {
        self.stop(sandbox_id);
        self._lock.acquire();
        try {
            to_remove = "";
            for (key, rec) in self._registry.items() {
                rec_d: dict = dict(rec);
                if str(rec_d.get("sandbox_id", "")) == sandbox_id {
                    to_remove = key;
                    preview_dir = str(rec_d.get("dir", ""));
                    if preview_dir and os.path.exists(preview_dir) {
                        shutil.rmtree(preview_dir, ignore_errors=True);
                    }
                    break;
                }
            }
            if to_remove {
                self._registry.pop(to_remove, None);
            }
        } finally {
            self._lock.release();
        }
    }

    def list_sandboxes(user_id: str) -> list[SandboxInfo] {
        results: list[SandboxInfo] = [];
        for (key, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("user_id", "")) == user_id {
                state_val: Any = rec_d.get("status", SandboxState.STOPPED);
                results.append(
                    SandboxInfo(
                        sandbox_id=str(rec_d.get("sandbox_id", "")),
                        user_id=str(rec_d.get("user_id", "")),
                        project_id=str(rec_d.get("project_id", "")),
                        state=state_val,
                        url=f"http://localhost:{int(rec_d.get('port', 0))}",
                        created_at=float(rec_d.get("created_at", 0.0))
                    )
                );
            }
        }
        return results;
    }

    def cleanup_expired -> int {
        now = time.time();
        expired: list[str] = [];
        for (key, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            created = float(rec_d.get("created_at", now));
            if now - created > self.config.ttl_seconds {
                expired.append(str(rec_d.get("sandbox_id", "")));
            }
        }
        for sid in expired {
            self.destroy(sid);
        }
        return len(expired);
    }

    def logs(sandbox_id: str, offset: int = 0) -> dict {
        for (key, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("sandbox_id", "")) == sandbox_id {
                log_path = str(
                    rec_d.get(
                        "log_path",
                        os.path.join(str(rec_d.get("dir", "")), ".jac-preview.log")
                    )
                );
                if not os.path.exists(log_path) {
                    return {"success": True, "content": "", "offset": 0};
                }
                try {
                    with open(log_path, "r", encoding="utf-8") as f {
                        f.seek(offset);
                        content = f.read();
                    }
                    new_offset = offset + len(content.encode("utf-8"));
                    return {"success": True, "content": content, "offset": new_offset};
                } except Exception as e {
                    return {"success": False, "error": str(e)};
                }
            }
        }
        return {"success": False, "error": "Sandbox not found"};
    }

    def write_file(sandbox_id: str, path: str, content: str) -> dict {
        for (key, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("sandbox_id", "")) == sandbox_id {
                basename = os.path.basename(path);
                if basename in PROTECTED_FILES
                and basename not in _WRITE_ALLOWED_PROTECTED {
                    return {
                        "success": True,
                        "skipped": True,
                        "reason": f"Protected file: {basename}"
                    };
                }
                try {
                    full_path = self._resolve_path(str(rec_d["dir"]), path);
                    parent = os.path.dirname(full_path);
                    if parent and not os.path.exists(parent) {
                        os.makedirs(parent, exist_ok=True);
                    }
                    with open(full_path, "w", encoding="utf-8") as f {
                        f.write(content);
                    }
                    return {"success": True, "path": path};
                } except Exception as e {
                    return {"success": False, "error": str(e)};
                }
            }
        }
        return {"success": False, "error": "Sandbox not found"};
    }

    def read_file(sandbox_id: str, path: str) -> dict {
        for (key, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("sandbox_id", "")) == sandbox_id {
                try {
                    full_path = self._resolve_path(str(rec_d["dir"]), path);
                    if not os.path.isfile(full_path) {
                        return {"success": False, "error": "File not found"};
                    }
                    ext = str(os.path.splitext(path)[1]).lower();
                    if ext in _IMAGE_MIME_TYPES {
                        with open(full_path, "rb") as f {
                            raw = f.read();
                        }
                        b64 = base64.b64encode(raw).decode("utf-8");
                        return {
                            "success": True,
                            "path": path,
                            "content": b64,
                            "is_binary": True,
                            "mime_type": _IMAGE_MIME_TYPES[ext]
                        };
                    }
                    with open(full_path, "r", encoding="utf-8") as f {
                        file_content = f.read();
                    }
                    return {"success": True, "path": path, "content": file_content};
                } except Exception as e {
                    return {"success": False, "error": str(e)};
                }
            }
        }
        return {"success": False, "error": "Sandbox not found"};
    }

    def delete_file(sandbox_id: str, path: str) -> dict {
        for (key, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("sandbox_id", "")) == sandbox_id {
                basename = os.path.basename(path);
                if basename in PROTECTED_FILES {
                    return {
                        "success": False,
                        "error": f"Cannot delete protected file: {basename}"
                    };
                }
                try {
                    full_path = self._resolve_path(str(rec_d["dir"]), path);
                    if os.path.isfile(full_path) {
                        os.remove(full_path);
                    } elif os.path.isdir(full_path) {
                        shutil.rmtree(full_path);
                    } else {
                        return {"success": False, "error": "Path not found"};
                    }
                    return {"success": True, "path": path};
                } except Exception as e {
                    return {"success": False, "error": str(e)};
                }
            }
        }
        return {"success": False, "error": "Sandbox not found"};
    }

    def list_files(sandbox_id: str, path: str = ".") -> dict {
        for (key, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("sandbox_id", "")) == sandbox_id {
                try {
                    preview_dir = str(rec_d["dir"]);
                    base = self._resolve_path(preview_dir, path);
                    real_preview = os.path.realpath(preview_dir);
                    skip_dirs = [".jac", "node_modules", "__pycache__", "dist", ".git"];
                    file_list: list[str] = [];
                    for walk_rec in os.walk(base) {
                        dirpath = str(walk_rec[0]);
                        dirnames: list = list(walk_rec[1]);
                        filenames: list = list(walk_rec[2]);
                        kept = [
                            d
                            for d in dirnames
                            if d not in skip_dirs
                        ];
                        dirnames.clear();
                        for d in kept {
                            dirnames.append(d);
                        }
                        # Update original walk_rec dirnames in-place
                        orig_dirs: list = list(walk_rec[1]);
                        orig_dirs.clear();
                        for d in kept {
                            orig_dirs.append(d);
                        }
                        for fname in filenames {
                            full = os.path.join(dirpath, str(fname));
                            rel = os.path.relpath(str(full), real_preview);
                            file_list.append(str(rel));
                        }
                    }
                    file_list.sort();
                    return {"success": True, "files": file_list};
                } except Exception as e {
                    return {"success": False, "error": str(e)};
                }
            }
        }
        return {"success": False, "error": "Sandbox not found"};
    }

    def exec_command(sandbox_id: str, command: str, timeout: int = 30) -> dict {
        for (key, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("sandbox_id", "")) == sandbox_id {
                try {
                    result = subprocess.run(
                        command,
                        shell=True,
                        cwd=str(rec_d["dir"]),
                        capture_output=True,
                        text=True,
                        timeout=timeout
                    );
                    return {
                        "success": True,
                        "exit_code": result.returncode,
                        "stdout": result.stdout,
                        "stderr": result.stderr
                    };
                } except Exception as e {
                    return {"success": False, "error": str(e)};
                }
            }
        }
        return {"success": False, "error": "Sandbox not found"};
    }

    def get_by_user_project(user_id: str, project_id: str) -> (dict | None) {
        key = self._sandbox_key(user_id, project_id);
        result = self._registry.get(key);
        return dict(result) if result is not None else None;
    }

    def get_sandbox_id(user_id: str, project_id: str) -> (str | None) {
        key = self._sandbox_key(user_id, project_id);
        rec: Any = self._registry.get(key);
        if rec {
            rec_d: dict = dict(rec);
            return str(rec_d.get("sandbox_id", ""));
        }
        return None;
    }

    def get_sandbox_dir(sandbox_id: str) -> (str | None) {
        for (key, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("sandbox_id", "")) == sandbox_id {
                return str(rec_d.get("dir", ""));
            }
        }
        return None;
    }
}
