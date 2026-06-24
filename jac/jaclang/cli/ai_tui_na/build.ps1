# Build the NA TUI binary on Windows — nacompile only, no custom C.
# Run from any directory; script resolves paths relative to its own location.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File build.ps1           # full build + tests
#   powershell -ExecutionPolicy Bypass -File build.ps1 -Quick    # shared-lib + exe only

param([switch]$Quick)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $ScriptDir
try {

# ── resolve the jac toolchain ─────────────────────────────────────────────────
# jaclang ships as the self-contained `jac` binary; `pip install -e jac` is gone.
# This dir lives at jac/jaclang/cli/ai_tui_na, so the repo root is four levels up.
# Resolution order: $JAC_BIN override -> repo-built binary -> .venv editable
# (legacy local dev). $JacExe + $JacPre form the invocation
# (`& $JacExe @JacPre <args>`); $JacPre is `-m jaclang` only for the editable case.
# PATH is intentionally not consulted — a stale global `jac` is a common dev-tree
# footgun. Set JAC_BIN, build zig-out, or use the repo .venv.
# NOTE: python-build-standalone has no Windows target, so there is no native
# Windows `jac` binary yet -- native Windows builds are deferred (see the
# test-tui-windows workflow). build.sh cross-compiles the Windows artifacts on Linux.
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..\..\..")).Path
$RepoJac  = Join-Path $RepoRoot "jac\zig-out\bin\jac.exe"
$RepoVenvPy = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if ($env:JAC_BIN) {
    $JacExe = $env:JAC_BIN; $JacPre = @()
} elseif (Test-Path $RepoJac) {
    $JacExe = $RepoJac; $JacPre = @()
} elseif (Test-Path $RepoVenvPy) {
    $JacExe = (Resolve-Path $RepoVenvPy).Path; $JacPre = @("-m", "jaclang")
} else {
    throw @"
No jac build toolchain found.
  Set JAC_BIN to your jac binary, or:
    (cd jac; zig build)   # -> jac\zig-out\bin\jac.exe
    python -m venv .venv; .venv\Scripts\pip install -e jac
"@
}
Write-Host "==> Using jac toolchain: $JacExe $JacPre"

# ── stage the Win32 TTY module ───────────────────────────────────────────────
# libc_tty.na.jac is gitignored; tui.na.jac / host.na.jac import it statically.
Copy-Item "tty\console.win32.na.jac" "libc_tty.na.jac"

$null = New-Item -ItemType Directory -Force -Path "bin"

try {
    # ── build main NA binary (subprocess fallback renderer) ───────────────────
    Write-Host "==> Compiling jac-na-tui.exe ..."
    & $JacExe @JacPre nacompile tui.na.jac --target windows -o bin\jac-na-tui.exe
    if ($LASTEXITCODE -ne 0) { throw "jac-na-tui.exe compile failed" }
    Write-Host "==> Done. Binary: $ScriptDir\bin\jac-na-tui.exe"

    # ── build in-process shared library ──────────────────────────────────────
    Write-Host "==> Compiling tui.dll (in-process host) ..."
    & $JacExe @JacPre nacompile host.na.jac --shared --target windows -o bin\tui.dll
    if ($LASTEXITCODE -ne 0) { throw "tui.dll compile failed" }
    Write-Host "==> Done. Shared lib: $ScriptDir\bin\tui.dll"

    if (-not $Quick) {
        # ── headless logic tests ──────────────────────────────────────────────
        Write-Host "==> Building + running picker logic tests ..."
        & $JacExe @JacPre nacompile test_pickers.na.jac --target windows -o bin\test_pickers.exe
        if ($LASTEXITCODE -ne 0) { throw "test_pickers.exe compile failed" }
        & ".\bin\test_pickers.exe"
        if ($LASTEXITCODE -ne 0) { throw "test_pickers.exe failed" }
        Write-Host "==> Tests passed."

        # ── headless host gate ────────────────────────────────────────────────
        Write-Host "==> Running in-process host gate (ctypes) ..."
        & $JacExe @JacPre run "$ScriptDir\test_host.jac"
        if ($LASTEXITCODE -ne 0) { throw "test_host.jac failed" }
        Write-Host "==> Host gate passed."

        # ── Win32 console constant + VT gate ─────────────────────────────────
        Write-Host "==> Running Win32 console gate ..."
        & $JacExe @JacPre run "$ScriptDir\test_console_win32.jac"
        if ($LASTEXITCODE -ne 0) { throw "test_console_win32.jac failed" }
        Write-Host "==> Console gate passed."
    } else {
        Write-Host "==> Quick build complete (skipped tests)."
    }

} finally {
    # Always remove the staged libc_tty.na.jac so the build tree stays clean.
    Remove-Item "libc_tty.na.jac" -ErrorAction SilentlyContinue
}

} finally {
    Pop-Location
}
