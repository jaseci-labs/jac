"""Resolver for the bundled `llama-server` runner binary.

The byLLM model daemon execs `llama-server` (llama.cpp's OpenAI-compatible
HTTP server) as a subprocess. Shipped `jac` binaries bundle two runner
variants per Linux platform under `byllm/_llama/<variant>/`:

  * `cpu`    -- the CPU baseline (on macOS this binary also has Metal built in,
                so GPU offload works through it with no separate variant).
  * `vulkan` -- Linux GPU runner (NVIDIA/AMD/Intel via Vulkan).

`get_llama_server(prefer_gpu)` picks the variant; `has_gpu()` is the probe the
daemon uses to decide. `LLAMA_VERSION` is the Jac-side single source of truth,
kept in lockstep with `launcher/llama_release.zig::LLAMA_VER`.
"""

glob LLAMA_VERSION: str = "b10019";

def get_llama_server(prefer_gpu: bool = False) -> str | None;
def has_gpu -> bool;
def llama_server_unavailable_message -> str;

# Phase 4: fetch a heavy accelerated runner (e.g. "rocm") on first use behind
# byllm/llama_sums.lock (CEF pattern). Returns None if unavailable (caller falls
# back to the bundled CPU/Vulkan runner). Never bundled.
def ensure_accel_runner(accel: str) -> str | None;
