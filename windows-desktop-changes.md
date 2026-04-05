# Windows Desktop Build — Complete Guide

All changes made for Windows desktop compatibility across jaseci, jacBuilder,
jac-coder, and jac-scale. Follow this guide when porting or maintaining
Windows support.

---

## Windows Development Rules

**ALWAYS follow these rules when writing code that runs on Windows:**

### 1. File encoding
- **ALWAYS** use `encoding="utf-8"` on every `open()` call (read AND write)
- Windows defaults to `cp1252` which crashes on emojis and non-ASCII chars
- Also add `encoding="utf-8"` to `subprocess.run(text=True, encoding="utf-8")`
- For safety: `(result.stdout or "").strip()` — subprocess can return `None` on encoding crash

### 2. No Unix-only modules at module level
- `pty`, `fcntl`, `termios`, `select`, `resource`, `pwd`, `grp` don't exist on Windows
- Use `importlib.import_module()` with `sys.platform != "win32"` guard, or `try/except ImportError`
- Never use `os.setsid`, `os.killpg`, `os.getpgid` — use `process.terminate()`/`process.kill()` on Windows

### 3. No Unix paths
- Never hardcode `/tmp/` — use `tempfile.gettempdir()`
- Never hardcode `/bin/bash`, `/usr/local/bin/` — use platform checks
- Venv binaries: `Scripts/jac.exe` on Windows, `bin/jac` on Unix
- Activate scripts: `Scripts/activate.bat` on Windows, `bin/activate` on Unix

### 4. No bash syntax in shell commands
- `source` → `call` on Windows
- `set -a; source file; set +a` → skip on Windows (load env via Python)
- `executable="/bin/bash"` → `None` on Windows
- `preexec_fn=os.setsid` → skip on Windows
- Always use `if sys.platform == "win32"` guards

### 5. Subprocess in frozen apps (PyInstaller sidecar)
- `sys.executable` is the sidecar exe, NOT Python
- Never use `[sys.executable, "-m", "jaclang.cli"]` — it won't work
- Use `[sys.executable, "--jac-cli"]` — the sidecar's multi-mode CLI handler
- For long-running processes (LSP, preview), spawn as subprocess via `--jac-cli`
- For one-shot commands (create, install), also use subprocess to avoid runtime state corruption

### 6. Tauri/desktop build
- Always include `icon.ico` in `tauri.conf.json` icon array — MSI/NSIS require it
- Generate from PNG: `Pillow` → `img.save("icon.ico", format="ICO", sizes=[...])`
- Build regenerates `tauri.conf.json` — manual edits get overwritten
- Use `"targets": "nsis"` to skip MSI (faster, avoids WiX long-path issues)

### 7. Jac compiler cache
- If styles or imports break mysteriously, run `jac purge --all` first
- Stale bytecode cache causes phantom errors unrelated to code changes

### 8. jac_client packaging (CRITICAL for frozen apps)
- Dirs with `__init__.jac` MUST also have `__init__.py` that re-exports via Python imports
- Without `__init__.py`, Python creates namespace packages → `__init__.jac` never executes
- `__init__.py` must `import jaclang` first (registers JacMetaImporter), then import from .jac submodules
- `collect_all('jac_client')` in PyInstaller spec handles bundling when `__init__.py` exists
- Do NOT generate `__init__.py` at build time in the spec — add them to the source

### 9. Building for distribution
- Install `jac-client` and `jaclang` from **local source** (not PyPI) before building:
  ```bash
  pip install /path/to/jac-client --no-deps --force-reinstall
  pip install /path/to/jac --no-deps --force-reinstall
  ```
- This ensures your fixes are bundled, not the PyPI version
- After build, switch back to editable: `pip install -e jac-client -e jac`
- Increase preview timeouts to 300s for first-run compilation in frozen apps

---

## Changes by Project

### jac-client (sidecar + desktop target)

| File | Change | Why |
|------|--------|-----|
| `sidecar/main.py` | `_run_jac_cli()` handler for `--jac-cli` flag | Multi-mode sidecar: one binary, multiple roles |
| `sidecar/main.py` | `_register_frozen_plugins()` registers `jac_scale`, `jac_client`, `byllm` | Entry point discovery fails in frozen apps |
| `sidecar/main.py` | Loads `.env` from `sys._MEIPASS` before CWD change | API keys not found after `os.chdir(data_path)` |
| `sidecar/main.py` | `NO_COLOR=1`, `reconfigure(encoding="utf-8")` in CLI mode | Rich emojis crash `cp1252` in frozen apps |
| `plugin/__init__.py` | Python imports mirroring `__init__.jac` exports | Namespace package fix for frozen PyInstaller |
| `plugin/src/__init__.py` | Python imports mirroring `__init__.jac` exports (ViteCompiler etc.) | Same — `import from .src { ViteCompiler }` fails without this |
| `plugin/utils/__init__.py` | Python imports mirroring `__init__.jac` exports | Same |
| `desktop_target.impl.jac` | `capture_output=False` for PyInstaller build | See build logs in real-time |
| `desktop_target.impl.jac` | Timeout increased to 7200s (2 hours) | Large projects need more time |
| `desktop_target.impl.jac` | UTF-8 runtime hook (`rthook_utf8.py`) | Force UTF-8 in frozen Python |
| `desktop_target.impl.jac` | Auto-bundles `assets/` and `.env` | Templates and config needed at runtime |
| `desktop_target.impl.jac` | `collect_all('jac_client')` in core packages | Proper bundling with `__init__.py` |

### jacBuilder-dev / jacBuilder-e (service files)

| # | File(s) | Change | Why |
|---|---------|--------|-----|
| 1 | `terminal_manager.jac` | `importlib.import_module()` guard for `pty`, `fcntl`, `termios`, `select` | Unix-only modules crash on Windows |
| 2 | `src-tauri/icons/icon.ico`, `tauri.conf.json` | Generated `.ico`, added to icon array, set `"targets": "nsis"` | Tauri bundler requires `.ico` |
| 3 | `project_manager.jac` | `_run_jac_command()` with `--jac-cli` subprocess, `encoding="utf-8"`, `(result.stdout or "").strip()` | Frozen exe can't use `sys.executable -m`, cp1252 crashes on emoji output |
| 4 | `project_manager.jac` | `TEMPLATE_MANIFEST_PATH` uses `sys._MEIPASS` when frozen | Sidecar changes CWD, can't find templates |
| 5 | `lsp_manager.jac` | `_find_jac_cmd()` with `--jac-cli`, `_build_env_prefix()` returns `""` on Windows, `call` instead of `source` | bash syntax fails on Windows |
| 6 | `preview_manager.jac` | `_find_jac_cmd()` with `--jac-cli`, `tempfile.gettempdir()`, timeout 300s | `/tmp/` doesn't exist, bash syntax fails, first-run compilation slow |
| 7 | `claude_adapter.jac` | `--jac-cli` for frozen, `Scripts/claude.exe` on Windows | Unix paths and frozen exe issue |
| 8 | `ideServer.jac` | `tempfile.gettempdir()` for preview cleanup | Hardcoded `/tmp/` |
| 9 | `jaccoder_adapter.jac` | Cross-platform regex in `_clean_path()` using `tempfile.gettempdir()` | `/tmp/` regex patterns |
| 10 | `terminal_manager.jac` | Disabled on Windows (returns error message), `COMSPEC` for shell | `pty.fork()` is Unix-only, subprocess pipes block GIL |

### jac compiler

| File | Change | Why |
|------|--------|-----|
| `cfg_build_pass.impl.jac` | `encoding="utf-8"` on `open()` | `cp1252` decode error reading .jac files |
| `core.impl.jac` (na_ir_gen) | `encoding="utf-8"` on `open()` | Same |
| `project.impl.jac` | `encoding="utf-8"` on all `open()` write calls | Emoji in templates crash `cp1252` encoder |
| `tools.impl.jac` | `encoding="utf-8"` on config read/write | Same |

### jac-code-main (jac_coder)

| File | Change | Why |
|------|--------|-----|
| `nodes.jac` (2x) | `encoding="utf-8"` on `open()` | `.md` rule files have non-ASCII bytes |
| `impl/config.impl.jac` | `encoding="utf-8"` | Same |
| `impl/memory.impl.jac` | `encoding="utf-8"` | Same |
| `tool/impl/filesystem.impl.jac` | `encoding="utf-8"` | Same |
| `tool/impl/jac_docs.impl.jac` | `encoding="utf-8"` | Same |
| `tool/impl/validate.impl.jac` | `encoding="utf-8"` | Same |

### jac-scale

| File | Change | Why |
|------|--------|-----|
| `local_sandbox.jac` | `process.terminate()`/`kill()` instead of `os.killpg()` on Windows | Unix-only |
| `local_sandbox.jac` | Skip `executable="/bin/bash"` and `preexec_fn=os.setsid` on Windows | Unix-only |
| `local_sandbox.jac` | Use project dir directly instead of copying to temp | `.git/objects` read-only on Windows |
| `local_sandbox.jac` | `tempfile.gettempdir()` instead of `/tmp/` | Cross-platform |
| `local_sandbox.jac` | Windows-compatible shell commands (`call` instead of `source`) | bash syntax fails |
| `local_sandbox.jac` | `_find_jac_binary()`: `--jac-cli` for frozen, `Scripts/jac.exe` on Windows | Preview failed in sidecar |
| `local_sandbox.jac` | Readiness timeout increased to 300s | First-run compilation takes >120s in frozen apps |

---

## Key Architecture: Multi-mode Sidecar

The sidecar exe (`jac-sidecar.exe`) serves two roles:

1. **Server mode** (default): runs the Jac API server with Tauri
2. **CLI mode** (`--jac-cli`): acts as a `jac` CLI proxy

Example: `jac-sidecar.exe --jac-cli create myproject --use template.jacpack --force`

This avoids needing a separate `jac.exe` binary. All services use
`[sys.executable, "--jac-cli"]` when `sys.frozen` is True.

## Key Architecture: __init__.py + __init__.jac coexistence

For directories that have `__init__.jac` (like `jac_client/plugin/`,
`jac_client/plugin/src/`), you MUST also have `__init__.py` that:
1. `import jaclang` — registers JacMetaImporter
2. Re-imports the same symbols from `.jac` submodules

Without this, Python creates namespace packages in frozen apps,
`__init__.jac` never executes, and exports like `ViteCompiler` are missing.

---

## Testing

Run the sidecar test script to verify all endpoints:

```bash
bash sidecar-test-flow.sh 8000
```

Expected: 16/16 pass. Preview takes ~165s on first run (compilation + npm install).

---

## Known Issues

1. **Terminal disabled on Windows** — needs ConPTY implementation
2. **Build regenerates `tauri.conf.json`** — manual edits get overwritten each build
3. **First-run preview is slow** (~3 min) — subsequent runs are fast (cached)
4. **`jac purge --all` needed** after switching branches — stale cache causes issues
