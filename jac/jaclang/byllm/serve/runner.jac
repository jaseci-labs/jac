"""Pure builders for launching a `llama-server` runner subprocess.

Maps `[byllm.local]` launch flags + manifest facts to a llama-server argv, and
selects the bundled runner variant (CPU vs Vulkan) from the `[byllm.serve]`
memory policy and a GPU probe. No process management here (see supervisor.jac).
"""

import os;
import from jaclang.byllm.llama_server { has_gpu, get_llama_server, ensure_accel_runner }

"""GPU layers to offload: all of them when GPU-selected, else pure CPU.

Deliberately all-or-nothing for now; a partial-offload estimator driven by
the manifest's `min_ram_mb` and probed VRAM is future work.
"""
def estimate_ngl(model_entry: dict, use_gpu: bool) -> int {
    return 999 if use_gpu else 0;
}

"""Resolve the runner binary + whether to offload to GPU.

Honours `[byllm.serve].memory` ('auto'/'cpu'/'gpu') and `llama_server_bin`.
Raises when memory='gpu' but no GPU/Vulkan runtime is present.
"""
def resolve_runner(serve_cfg: dict) -> dict {
    memory = str(serve_cfg.get("memory", "auto"));
    override = str(serve_cfg.get("llama_server_bin", ""));
    if override and os.path.isfile(override) {
        return {"bin": override, "use_gpu": memory != "cpu"};
    }
    # Opt-in heavy accelerator (e.g. ROCm): fetched on first use behind the
    # checked-in sums lock; on any failure, fall back to the bundled runner.
    if memory in ("rocm", "cuda") {
        accel_bin = ensure_accel_runner(memory);
        if accel_bin {
            return {"bin": accel_bin, "use_gpu": True};
        }
    }
    gpu = (memory != "cpu") and has_gpu();
    if memory == "gpu" and not gpu {
        raise RuntimeError(
            "[byllm.serve].memory='gpu' but no GPU/Vulkan runtime was detected. "
            "Set memory='auto' (CPU fallback) or 'cpu'."
        );
    }
    return {"bin": get_llama_server(prefer_gpu=gpu), "use_gpu": gpu};
}

"""Build the llama-server argv for an alias/manifest entry.

llama-server speaks OpenAI-compatible HTTP; the daemon proxies to it.
"""
def llama_server_argv(
    binary: str,
    alias: str,
    gguf_path: str,
    port: int,
    local_cfg: dict,
    model_entry: dict,
    use_gpu: bool
) -> list[str] {
    argv: list[str] = [
        binary,
        "-m", gguf_path,
        "--host", "127.0.0.1",
        "--port", str(port),
        "--alias", alias
    ];
    n_ctx = int(local_cfg.get("n_ctx", 0)) or int(model_entry.get("ctx_window", 0));
    if n_ctx > 0 {
        argv += ["-c", str(n_ctx)];
    }
    ngl_cfg = int(local_cfg.get("n_gpu_layers", 0));
    ngl = ngl_cfg if ngl_cfg != 0 else estimate_ngl(model_entry, use_gpu);
    argv += ["-ngl", str(ngl)];
    n_threads = int(local_cfg.get("n_threads", 0));
    if n_threads > 0 {
        argv += ["-t", str(n_threads)];
    }
    launch = model_entry.get("launch", {}) or {};
    if launch.get("jinja") {
        argv += ["--jinja"];
    }
    chat_template = launch.get("chat_template");
    if chat_template {
        argv += ["--chat-template", str(chat_template)];
    }
    if bool(local_cfg.get("verbose", False)) {
        argv += ["--verbose"];
    }
    return argv;
}
