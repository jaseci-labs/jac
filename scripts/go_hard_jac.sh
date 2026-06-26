#!/usr/bin/env bash
# go_hard_jac.sh -- aggressively remove Python toolchains from this machine.
#
# Supports macOS and Ubuntu. "Go hard" = rip out every Python you control:
# Homebrew pythons, pyenv, conda/miniforge, uv, pipx, poetry/pipenv virtualenvs,
# pip caches, and user site-packages. On Ubuntu it also purges apt-installed
# alternate interpreters (e.g. deadsnakes python3.x) and python3-pip/venv.
#
# It deliberately CANNOT remove the operating system's own Python, because doing
# so breaks the machine:
#   * macOS: /usr/bin/python3 belongs to the SIP-protected Command Line Tools
#     (git, clang, make live there too) -- not removable, and we never try.
#   * Ubuntu: /usr/bin/python3 is load-bearing for apt, the desktop, and much of
#     the base system. Purging it cascades into apt/ubuntu-minimal/etc.
# Two guard rails enforce this:
#   1. Every direct delete must resolve to a path under $HOME, or it is refused.
#   2. Every apt purge is simulated first; if it would touch a protected core
#      package (apt, dpkg, python3, ubuntu-*, systemd, gdm3, ...), it is skipped.
#
# This does NOT touch the `jac` binary itself (jac ships its own private bundled
# CPython and is independent of the host Python this removes). Remove jac
# separately if you want it gone.
#
# Usage:
#   scripts/go_hard_jac.sh            # interactive: prints the plan, asks to confirm
#   scripts/go_hard_jac.sh --dry-run  # show exactly what would run, change nothing
#   scripts/go_hard_jac.sh --yes      # skip the confirmation prompt (for automation)
#   scripts/go_hard_jac.sh --help
set -euo pipefail

DRY_RUN=0
ASSUME_YES=0

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes)     ASSUME_YES=1 ;;
    -h|--help)
      # Print the header comment block (portable: awk works on BSD + GNU).
      awk 'NR>1 && /^set -euo pipefail$/{exit} NR>1{sub(/^# ?/,""); print}' "$0"
      exit 0 ;;
    *) printf 'unknown argument: %s (try --help)\n' "$arg" >&2; exit 2 ;;
  esac
done

# --- pretty output --------------------------------------------------------------
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }

# Echo each command, then run it (unless --dry-run). Keeps the teardown auditable.
run() {
  printf '    $ %s\n' "$*"
  [[ $DRY_RUN -eq 1 ]] && return 0
  "$@"
}

# --- guard rail #1: only ever delete things under $HOME -------------------------
HOME_REAL="$(cd "$HOME" && pwd -P)"

rmrf() {
  local target="$1"
  [[ -e "$target" || -L "$target" ]] || return 0
  # Resolve to an absolute, symlink-free path of the *parent* so a symlinked
  # target cannot smuggle us outside $HOME.
  local parent base resolved
  parent="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || {
    warn "cannot resolve $target -- skipping"; return 0
  }
  base="$(basename "$target")"
  resolved="$parent/$base"
  case "$resolved/" in
    "$HOME_REAL"/*) run rm -rf -- "$resolved" ;;
    *) err "refusing to delete outside \$HOME: $target -> $resolved"; return 0 ;;
  esac
}

# --- OS detection ---------------------------------------------------------------
OS=""
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)
    if [[ -f /etc/os-release ]] && grep -qiE 'ubuntu|debian' /etc/os-release; then
      OS="ubuntu"
    else
      err "Linux detected but not Ubuntu/Debian; this script only supports macOS and Ubuntu."
      exit 1
    fi ;;
  *) err "unsupported OS: $(uname -s) (only macOS and Ubuntu are supported)"; exit 1 ;;
esac

# The OS-owned interpreter we must never remove. It lives at a fixed path on
# both macOS (Command Line Tools) and Ubuntu. We do NOT use `command -v python3`
# for this: PATH usually resolves to a Homebrew/pyenv python that this script
# *does* remove, so trusting PATH would mislabel the thing being deleted as the
# protected floor.
SYSTEM_PY="/usr/bin/python3"

log "Target OS:        $OS"
if [[ -x "$SYSTEM_PY" ]]; then
  log "System python3:   $SYSTEM_PY (protected -- will NOT be removed)"
else
  log "System python3:   $SYSTEM_PY (not present; nothing there to protect)"
fi
[[ $DRY_RUN -eq 1 ]] && log "Mode:             DRY RUN (nothing will be changed)"

# --- confirmation ---------------------------------------------------------------
if [[ $DRY_RUN -eq 0 && $ASSUME_YES -eq 0 ]]; then
  printf '\nThis will permanently delete the Python toolchains listed above.\n'
  read -r -p 'Type "go hard" to proceed: ' answer
  [[ "$answer" == "go hard" ]] || { err "aborted (got: '${answer}')"; exit 1; }
fi

# ================================================================================
# 1. Version managers and user-scoped Python distributions (both OSes; all $HOME)
# ================================================================================
log "Removing pyenv"
rmrf "$HOME/.pyenv"

log "Removing conda / miniconda / anaconda / miniforge / mambaforge"
for d in miniconda3 anaconda3 miniconda anaconda miniforge3 mambaforge .conda; do
  rmrf "$HOME/$d"
done
rmrf "$HOME/.condarc"

log "Removing uv"
for p in .local/bin/uv .local/bin/uvx .local/share/uv .cache/uv "Library/Application Support/uv" "Library/Caches/uv"; do
  rmrf "$HOME/$p"
done

log "Removing pipx"
rmrf "$HOME/.local/pipx"
rmrf "$HOME/.local/share/pipx"

log "Removing poetry / pipenv virtualenvs + caches"
for p in .virtualenvs .local/share/virtualenvs .cache/pypoetry \
         "Library/Caches/pypoetry" "Library/Application Support/pypoetry"; do
  rmrf "$HOME/$p"
done

# ================================================================================
# 2. pip caches, config, and user site-packages (both OSes; all $HOME)
# ================================================================================
log "Removing pip caches and config"
for p in .cache/pip "Library/Caches/pip" .pip .config/pip .pydistutils.cfg; do
  rmrf "$HOME/$p"
done

log "Removing user site-packages (pip --user installs)"
rmrf "$HOME/Library/Python"        # macOS: ~/Library/Python/3.x
for d in "$HOME"/.local/lib/python*; do
  rmrf "$d"                         # Linux: ~/.local/lib/python3.x (console scripts in ~/.local/bin are left in place)
done

# ================================================================================
# 3. OS package manager: remove non-system Python distributions
# ================================================================================
if [[ "$OS" == "macos" ]]; then
  if command -v brew >/dev/null 2>&1; then
    # Every python formula brew installed (python@3.x and the unversioned python).
    # Plain string + while-read (not mapfile) so this also runs under the macOS
    # system bash 3.2 -- a toolchain-removal script must not lean on Homebrew bash.
    BREW_PY="$(brew list --formula 2>/dev/null | grep -E '^python(@[0-9.]+)?$' || true)"
    if [[ -z "$BREW_PY" ]]; then
      log "No Homebrew python formulae installed"
    else
      log "Removing Homebrew pythons: $(printf '%s' "$BREW_PY" | tr '\n' ' ')"
      # No --force / --ignore-dependencies: if something still depends on a
      # python, surface it instead of breaking that tool silently.
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if ! run brew uninstall "$f"; then
          warn "could not uninstall $f -- something still depends on it:"
          brew uses --installed "$f" 2>/dev/null | sed 's/^/      /' || true
        fi
      done <<< "$BREW_PY"
      run brew autoremove
      run brew cleanup -s
    fi
  else
    warn "Homebrew not found -- skipping brew python removal"
  fi

elif [[ "$OS" == "ubuntu" ]]; then
  # guard rail #2: simulate each purge; refuse if it would remove a core package.
  PROTECTED='apt|apt-utils|dpkg|libapt-pkg[0-9.]*|python3|python3-minimal|libpython3-stdlib|libpython3\.[0-9]+-minimal|libpython3\.[0-9]+-stdlib|ubuntu-minimal|ubuntu-standard|ubuntu-desktop|ubuntu-server|systemd|gdm3|netplan\.io|software-properties-common|update-manager-core|command-not-found'

  apt_safe_purge() {
    local pkg="$1"
    dpkg -l "$pkg" 2>/dev/null | grep -q '^ii' || return 0   # not installed
    local sim
    sim="$(apt-get -s remove "$pkg" 2>/dev/null || true)"
    if grep -qE "^Remv ($PROTECTED) " <<<"$sim"; then
      warn "skipping purge of '$pkg' -- would cascade into protected core packages"
      return 0
    fi
    run sudo apt-get -y purge "$pkg"
  }

  if command -v apt-get >/dev/null 2>&1; then
    SYS_BASENAME="$(basename "${SYSTEM_PY:-python3}")"   # e.g. python3 (the default)
    log "Purging apt-installed alternate interpreters (system $SYS_BASENAME is protected)"

    # Versioned interpreters like python3.11 / python3.13 (deadsnakes etc.).
    APT_PY="$(dpkg-query -W -f='${Package}\n' 'python3.[0-9]*' 2>/dev/null \
              | grep -E '^python3\.[0-9]+$' || true)"
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      apt_safe_purge "$pkg"
    done <<< "$APT_PY"

    # User-facing python tooling (pip/venv/setuptools). The guard skips any that
    # are wired into the protected set.
    for pkg in python3-pip python3-venv python3-setuptools python3-wheel python3-virtualenv pipenv; do
      apt_safe_purge "$pkg"
    done

    run sudo apt-get -y autoremove --purge
  else
    warn "apt-get not found -- skipping apt python removal"
  fi
fi

# ================================================================================
# 4. Report shell-rc lines that still reference removed tools (NOT auto-edited)
# ================================================================================
log "Scanning shell rc files for stale Python references (edit these by hand)"
RC_PATTERN='pyenv|conda|miniconda|anaconda|miniforge|mambaforge|/uv\b|pipx|/Library/Python|\.local/lib/python|python@|deadsnakes'
for rc in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zshenv" \
          "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
  [[ -f "$rc" ]] || continue
  if grep -nE "$RC_PATTERN" "$rc" >/dev/null 2>&1; then
    printf '    %s:\n' "$rc"
    grep -nE "$RC_PATTERN" "$rc" | sed 's/^/      /'
  fi
done

# ================================================================================
# 5. Final state
# ================================================================================
log "Done. Remaining Python-ish commands on PATH:"
for c in python python3 pip pip3 pyenv conda uv uvx pipx poetry; do
  if p="$(command -v "$c" 2>/dev/null)"; then
    printf '      %-8s -> %s\n' "$c" "$p"
  fi
done

cat <<EOF

The only Python that should remain is the OS system interpreter
(${SYSTEM_PY:-/usr/bin/python3}) -- that is the floor on $OS and removing it
would break core OS tooling. Open a new shell (or 'exec \$SHELL') so PATH and
any rc edits take effect.
EOF
