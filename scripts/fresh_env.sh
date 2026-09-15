#!/usr/bin/env bash
# Build the complete Jac toolchain and install local hooks.
# Compiler development uses explicit images; see jac/bootstrap/README.md.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Fetch pinned LLVM, then build the complete distributable binary.
( cd jac && zig build fetch-llvm )
( cd jac && zig build -Dpayload-progress )

JAC_BIN="$PWD/jac/zig-out/bin/jac"
echo "Built: $JAC_BIN"
echo "Add it to PATH, e.g.:  export PATH=\"$PWD/jac/zig-out/bin:\$PATH\""
export PATH="$PWD/jac/zig-out/bin:$PATH"

# byLLM's `llm` capability deps (global so they're importable from anywhere).
# Pins mirror jac/jaclang/project/capabilities.jac. Optional: drop this line if
# you don't need to run `by llm()` flows in this env.
jac install \
  "litellm>=1.75.2,<=1.82.6" "pillow>=12.0.0,<13.0.0" \
  "httpx>=0.27.0" "loguru>=0.7.2,<0.8.0" \
  --global

# Local git hooks come from the jac binary itself: a pre-commit hook that
# formats/lints staged .jac files and a commit-msg hook that blocks AI
# co-author attribution. Markdown lint + the em-dash ban run on every PR via
# pre-commit.ci (see .pre-commit-config.yaml); nothing extra to install here.
jac precommit --install
echo "Done. Ensure 'jac' stays on PATH for the git hooks."
