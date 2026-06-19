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

# ── resolve jaclang ──────────────────────────────────────────────────────────
# Prefer the repo-root .venv (Scripts\ on Windows) so editable installs are used.
$RepoVenv = Join-Path $ScriptDir "..\..\..\venv"
if (Test-Path (Join-Path $RepoVenv "Scripts\python.exe")) {
    $Py  = Join-Path $RepoVenv "Scripts\python.exe"
} elseif (Test-Path (Join-Path $ScriptDir "..\..\..\.venv\Scripts\python.exe")) {
    $Py  = Join-Path $ScriptDir "..\..\..\.venv\Scripts\python.exe"
    $Py  = (Resolve-Path $Py).Path
} else {
    $Py  = "python"
}
Write-Host "==> Using Python: $Py"

# ── stage the Win32 TTY module ───────────────────────────────────────────────
# libc_tty.na.jac is gitignored; tui.na.jac / host.na.jac import it statically.
Copy-Item "tty\console.win32.na.jac" "libc_tty.na.jac"

$null = New-Item -ItemType Directory -Force -Path "bin"

try {
    # ── build main NA binary (subprocess fallback renderer) ───────────────────
    Write-Host "==> Compiling jac-na-tui.exe ..."
    & $Py -m jaclang nacompile tui.na.jac --target windows -o bin\jac-na-tui.exe
    if ($LASTEXITCODE -ne 0) { throw "jac-na-tui.exe compile failed" }
    Write-Host "==> Done. Binary: $ScriptDir\bin\jac-na-tui.exe"

    # ── build in-process shared library ──────────────────────────────────────
    Write-Host "==> Compiling tui.dll (in-process host) ..."
    & $Py -m jaclang nacompile host.na.jac --shared --target windows -o bin\tui.dll
    if ($LASTEXITCODE -ne 0) { throw "tui.dll compile failed" }
    Write-Host "==> Done. Shared lib: $ScriptDir\bin\tui.dll"

    if (-not $Quick) {
        # ── headless logic tests ──────────────────────────────────────────────
        Write-Host "==> Building + running picker logic tests ..."
        & $Py -m jaclang nacompile test_pickers.na.jac --target windows -o bin\test_pickers.exe
        if ($LASTEXITCODE -ne 0) { throw "test_pickers.exe compile failed" }
        & ".\bin\test_pickers.exe"
        if ($LASTEXITCODE -ne 0) { throw "test_pickers.exe failed" }
        Write-Host "==> Tests passed."

        # ── headless host gate ────────────────────────────────────────────────
        Write-Host "==> Running in-process host gate (ctypes) ..."
        & $Py "$ScriptDir\test_host.py"
        if ($LASTEXITCODE -ne 0) { throw "test_host.py failed" }
        Write-Host "==> Host gate passed."

        # ── Win32 console constant + VT gate ─────────────────────────────────
        Write-Host "==> Running Win32 console gate ..."
        & $Py "$ScriptDir\test_console_win32.py"
        if ($LASTEXITCODE -ne 0) { throw "test_console_win32.py failed" }
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
