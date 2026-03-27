import os;
import io;
import tarfile;
import time;
import uuid;
import from threading { Lock, Thread }
import from typing { Any }
import from jac_scale.abstractions.sandbox_environment {
    SandboxEnvironment,
    validate_sandbox_path
}
import from jac_scale.abstractions.models.sandbox_config { SandboxConfig }
import from jac_scale.abstractions.models.sandbox_result { SandboxResult }
import from jac_scale.abstractions.models.sandbox_status {
    SandboxState,
    SandboxStatus,
    SandboxInfo
}
import from jac_scale.abstractions.logger { Logger }

glob _SANDBOX_LABEL: str = "jac-sandbox",
     _INTERNAL_PORT: int = 8000;

obj DockerSandbox(SandboxEnvironment) {
    has _client: Any = None,
        _registry: dict = {},
        _lock: Lock = Lock();

    def _get_client -> Any {
        if self._client is None {
            import docker;
            self._client = docker.from_env();
        }
        return self._client;
    }

    def _generate_id(user_id: str, project_id: str) -> str {
        short = str(uuid.uuid4())[:8];
        return f"jac-sandbox-{user_id}-{project_id}-{short}"
            if project_id
            else f"jac-sandbox-{user_id}-{short}";
    }

    def _container_name(sandbox_id: str) -> str {
        return sandbox_id;
    }

    def _ensure_network(sandbox_id: str) -> str {
        if not self.config.network_isolation {
            return "";
        }
        client = self._get_client();
        net_name = f"{sandbox_id}-net";
        try {
            client.networks.get(net_name);
        } except Exception {
            client.networks.create(net_name, driver="bridge", internal=False);
        }
        return net_name;
    }

    def _remove_network(sandbox_id: str) -> None {
        if not self.config.network_isolation {
            return;
        }
        client = self._get_client();
        net_name = f"{sandbox_id}-net";
        try {
            network = client.networks.get(net_name);
            network.remove();
        } except Exception {
            ;
        }
    }

    def _copy_code_to_container(container: Any, code_path: str) -> None {
        buf = io.BytesIO();
        with tarfile.open(fileobj=buf, mode="w") as tar {
            tar.add(code_path, arcname=".");
        }
        buf.seek(0);
        container.put_archive("/app", buf);
    }

    def _poll_container_readiness(sandbox_id: str, port: int) -> None {
        import requests;
        url = f"http://localhost:{port}";
        start_time = time.time();
        ready = False;
        while time.time() - start_time < 120 {
            try {
                container = self._get_client().containers.get(
                    self._container_name(sandbox_id)
                );
                if str(container.status) != "running" {
                    break;
                }
            } except Exception {
                break;
            }
            try {
                resp: Any = requests.get(url, timeout=3);
                if 200 <= int(resp.status_code) < 400 {
                    ready = True;
                    break;
                }
            } except Exception {
                ;
            }
            time.sleep(3);
        }
        self._lock.acquire();
        try {
            rec: Any = self._registry.get(sandbox_id);
            if rec {
                rec["status"] = SandboxState.RUNNING if ready else SandboxState.ERROR;
            }
        } finally {
            self._lock.release();
        }
    }

    def create(user_id: str, project_id: str, code_path: str) -> SandboxResult {
        self._lock.acquire();
        try {
            user_count = 0;
            for (sid, rec) in self._registry.items() {
                rec_d: dict = dict(rec);
                if str(rec_d.get("user_id", "")) == user_id
                and rec_d.get("status") != SandboxState.STOPPED {
                    user_count += 1;
                }
            }
            if user_count >= self.config.max_per_user {
                return SandboxResult(
                    success=False,
                    message=f"Max sandboxes per user ({self.config.max_per_user}) reached"
                );
            }
        } finally {
            self._lock.release();
        }

        client = self._get_client();
        sandbox_id = self._generate_id(user_id, project_id);
        container_name = self._container_name(sandbox_id);

        try {
            try {
                client.images.get(self.config.base_image);
            } except Exception {
                if self.logger {
                    self.logger.info(f"Pulling image {self.config.base_image}...");
                }
                client.images.pull(self.config.base_image);
            }

            net_name = self._ensure_network(sandbox_id);

            environment = {
                "JAC_SANDBOX_ID": sandbox_id,
                "JAC_SANDBOX_USER": user_id,
                "JAC_SANDBOX_PROJECT": project_id
            };

            mem_bytes = self._parse_memory(self.config.memory_limit);
            nano_cpus = self._parse_cpu(self.config.cpu_limit);

            volumes: dict = {};
            tmpfs_mounts: dict = {"/tmp": f"size={self.config.storage_limit}"};

            networking_config = {};
            if net_name {
                networking_config = client.api.create_networking_config(
                    {net_name: client.api.create_endpoint_config()}
                );
            }

            container = client.containers.create(
                image=self.config.base_image,
                name=container_name,
                command=f"bash -c 'cd /app && jac install 2>/dev/null; jac start main.jac -p {_INTERNAL_PORT} --dev'",
                working_dir="/app",
                environment=environment,
                labels={
                    _SANDBOX_LABEL: "true",
                    "jac-sandbox-id": sandbox_id,
                    "jac-sandbox-user": user_id,
                    "jac-sandbox-project": project_id
                },
                ports={f"{_INTERNAL_PORT}/tcp": None},
                mem_limit=mem_bytes,
                nano_cpus=nano_cpus,
                tmpfs=tmpfs_mounts,
                detach=True,
                auto_remove=False
            );

            if code_path and os.path.isdir(code_path) {
                self._copy_code_to_container(container, code_path);
            }

            container.start();
            container.reload();

            network_settings: Any = container.attrs.get("NetworkSettings", {});
            port_bindings: Any = network_settings.get("Ports", {});
            mapped_port = 0;
            binding: Any = port_bindings.get(f"{_INTERNAL_PORT}/tcp");
            if binding and len(binding) > 0 {
                mapped_port = int(binding[0].get("HostPort", 0));
            }

            url = f"http://localhost:{mapped_port}" if mapped_port else "";

            self._lock.acquire();
            try {
                self._registry[sandbox_id] = {
                    "sandbox_id": sandbox_id,
                    "container_name": container_name,
                    "user_id": user_id,
                    "project_id": project_id,
                    "port": mapped_port,
                    "status": SandboxState.STARTING,
                    "url": url,
                    "network": net_name,
                    "created_at": time.time()
                };
            } finally {
                self._lock.release();
            }

            checker = Thread(
                target=self._poll_container_readiness,
                args=(sandbox_id, mapped_port),
                daemon=True
            );
            checker.start();

            return SandboxResult(
                success=True,
                sandbox_id=sandbox_id,
                url=url,
                port=mapped_port,
                message="starting"
            );
        } except Exception as e {
            try {
                client.containers.get(container_name).remove(force=True);
            } except Exception {
                ;
            }
            self._remove_network(sandbox_id);
            return SandboxResult(success=False, message=str(e));
        }
    }

    def stop(sandbox_id: str) -> None {
        client = self._get_client();
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return;
        }
        rec_d: dict = dict(rec);
        try {
            container = client.containers.get(str(rec_d["container_name"]));
            container.stop(timeout=10);
            container.remove(force=True);
        } except Exception {
            ;
        }
        self._remove_network(sandbox_id);
        self._lock.acquire();
        try {
            if sandbox_id in self._registry {
                self._registry[sandbox_id]["status"] = SandboxState.STOPPED;
            }
        } finally {
            self._lock.release();
        }
    }

    def status(sandbox_id: str) -> SandboxStatus {
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return SandboxStatus(state=SandboxState.STOPPED, sandbox_id=sandbox_id);
        }
        rec_d: dict = dict(rec);
        try {
            container = self._get_client().containers.get(str(rec_d["container_name"]));
            container_status = str(container.status);
            if container_status == "running" {
                state: Any = rec_d.get("status", SandboxState.RUNNING);
            } elif container_status == "exited" {
                state = SandboxState.STOPPED;
            } else {
                state = SandboxState.PENDING;
            }
        } except Exception {
            state = SandboxState.STOPPED;
        }
        created_at = float(rec_d.get("created_at", time.time()));
        uptime = time.time() - created_at if state == SandboxState.RUNNING else 0.0;
        return SandboxStatus(
            state=state,
            sandbox_id=sandbox_id,
            uptime_seconds=uptime,
            url=str(rec_d.get("url", "")),
            port=int(rec_d.get("port", 0))
        );
    }

    def destroy(sandbox_id: str) -> None {
        self.stop(sandbox_id);
        self._lock.acquire();
        try {
            self._registry.pop(sandbox_id, None);
        } finally {
            self._lock.release();
        }
    }

    def list_sandboxes(user_id: str) -> list[SandboxInfo] {
        results: list[SandboxInfo] = [];
        for (sid, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("user_id", "")) == user_id {
                state_val: Any = rec_d.get("status", SandboxState.STOPPED);
                results.append(
                    SandboxInfo(
                        sandbox_id=sid,
                        user_id=str(rec_d.get("user_id", "")),
                        project_id=str(rec_d.get("project_id", "")),
                        state=state_val,
                        url=str(rec_d.get("url", "")),
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
        for (sid, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            created = float(rec_d.get("created_at", now));
            if now - created > self.config.ttl_seconds {
                expired.append(sid);
            }
        }
        for sid in expired {
            self.destroy(sid);
        }
        return len(expired);
    }

    def logs(sandbox_id: str, offset: int = 0) -> dict {
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            container = self._get_client().containers.get(str(rec_d["container_name"]));
            log_bytes: Any = container.logs(stdout=True, stderr=True, tail=500);
            content = str(log_bytes.decode("utf-8", errors="replace"));
            if offset > 0 and offset < len(content) {
                content = content[offset:];
            }
            new_offset = offset + len(content);
            return {"success": True, "content": content, "offset": new_offset};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def write_file(sandbox_id: str, path: str, content: str) -> dict {
        try {
            path = validate_sandbox_path(path);
        } except ValueError as e {
            return {"success": False, "error": str(e)};
        }
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            container = self._get_client().containers.get(str(rec_d["container_name"]));
            buf = io.BytesIO();
            content_bytes = content.encode("utf-8");
            with tarfile.open(fileobj=buf, mode="w") as tar {
                info = tarfile.TarInfo(name=path);
                info.size = len(content_bytes);
                tar.addfile(info, io.BytesIO(content_bytes));
            }
            buf.seek(0);
            container.put_archive("/app", buf);
            return {"success": True, "path": path};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def read_file(sandbox_id: str, path: str) -> dict {
        try {
            path = validate_sandbox_path(path);
        } except ValueError as e {
            return {"success": False, "error": str(e)};
        }
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            container = self._get_client().containers.get(str(rec_d["container_name"]));
            (exit_code, output) = container.exec_run(f"cat /app/{path}", demux=True);
            if exit_code != 0 {
                stderr = str(output[1].decode("utf-8"))
                    if output[1]
                    else "File not found";
                return {"success": False, "error": stderr};
            }
            file_content = str(output[0].decode("utf-8")) if output[0] else "";
            return {"success": True, "path": path, "content": file_content};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def delete_file(sandbox_id: str, path: str) -> dict {
        try {
            path = validate_sandbox_path(path);
        } except ValueError as e {
            return {"success": False, "error": str(e)};
        }
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            container = self._get_client().containers.get(str(rec_d["container_name"]));
            (exit_code, output) = container.exec_run(f"rm -rf /app/{path}", demux=True);
            if exit_code != 0 {
                stderr = str(output[1].decode("utf-8"))
                    if output[1]
                    else "Delete failed";
                return {"success": False, "error": stderr};
            }
            return {"success": True, "path": path};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def list_files(sandbox_id: str, path: str = ".") -> dict {
        try {
            path = validate_sandbox_path(path);
        } except ValueError as e {
            return {"success": False, "error": str(e)};
        }
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            container = self._get_client().containers.get(str(rec_d["container_name"]));
            (exit_code, output) = container.exec_run(
                f"find /app/{path} -type f -not -path '*/node_modules/*' -not -path '*/.jac/*' -not -path '*/__pycache__/*' -not -path '*/dist/*' -not -path '*/.git/*'",
                demux=True
            );
            if exit_code != 0 {
                return {"success": False, "error": "Failed to list files"};
            }
            raw = str(output[0].decode("utf-8")) if output[0] else "";
            files = [
                os.path.relpath(str(f).strip(), "/app")
                for f in raw.strip().split("\n")
                if str(f).strip()
            ];
            files.sort();
            return {"success": True, "files": files};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def exec_command(sandbox_id: str, command: str, timeout: int = 30) -> dict {
        rec: Any = self._registry.get(sandbox_id);
        if not rec {
            return {"success": False, "error": "Sandbox not found"};
        }
        rec_d: dict = dict(rec);
        try {
            container = self._get_client().containers.get(str(rec_d["container_name"]));
            (exit_code, output) = container.exec_run(
                f"bash -c '{command}'", workdir="/app", demux=True
            );
            stdout = str(output[0].decode("utf-8")) if output[0] else "";
            stderr = str(output[1].decode("utf-8")) if output[1] else "";
            return {
                "success": True,
                "exit_code": exit_code,
                "stdout": stdout,
                "stderr": stderr
            };
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    def _parse_memory(mem_str: str) -> int {
        mem_str = str(mem_str).strip().upper();
        if mem_str.endswith("GI") {
            return int(float(mem_str[:-2]) * 1073741824);
        } elif mem_str.endswith("MI") {
            return int(float(mem_str[:-2]) * 1048576);
        } elif mem_str.endswith("KI") {
            return int(float(mem_str[:-2]) * 1024);
        } elif mem_str.endswith("G") {
            return int(float(mem_str[:-1]) * 1000000000);
        } elif mem_str.endswith("M") {
            return int(float(mem_str[:-1]) * 1000000);
        } elif mem_str.endswith("K") {
            return int(float(mem_str[:-1]) * 1000);
        }
        return int(mem_str);
    }

    def _parse_cpu(cpu_str: str) -> int {
        cpu_str = str(cpu_str).strip().lower();
        if cpu_str.endswith("m") {
            millicores = int(cpu_str[:-1]);
            return millicores * 1000000;
        }
        return int(float(cpu_str) * 1000000000);
    }

    def get_sandbox_id(user_id: str, project_id: str) -> (str | None) {
        for (sid, rec) in self._registry.items() {
            rec_d: dict = dict(rec);
            if str(rec_d.get("user_id", "")) == user_id
            and str(rec_d.get("project_id", "")) == project_id {
                return sid;
            }
        }
        return None;
    }
}
