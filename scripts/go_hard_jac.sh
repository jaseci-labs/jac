#!/usr/bin/env bash
# go_hard_jac.sh -- aggressively remove Python and Node toolchains from this machine.
#
# Supports macOS and Ubuntu. "Go hard" = rip out every Python and Node you control:
#   * Python: Homebrew pythons, pyenv, conda/miniforge, uv, pipx, poetry/pipenv
#     virtualenvs, pip caches, and user site-packages. On Ubuntu it also purges
#     apt-installed alternate interpreters (e.g. deadsnakes python3.x) and
#     python3-pip/venv.
#   * Node: nvm, fnm, nodenv, volta, the asdf nodejs plugin, npm/yarn/pnpm/
#     corepack/bun caches + config, and user-scoped global package dirs. On macOS
#     it uninstalls Homebrew node/yarn/pnpm; on Ubuntu it purges the apt
#     nodejs/npm/yarn packages.
#
# It deliberately CANNOT remove the operating system's own Python, because doing
# so breaks the machine:
#   * macOS: /usr/bin/python3 belongs to the SIP-protected Command Line Tools
#     (git, clang, make live there too) -- not removable, and we never try.
#   * Ubuntu: /usr/bin/python3 is load-bearing for apt, the desktop, and much of
#     the base system. Purging it cascades into apt/ubuntu-minimal/etc.
# Node has no such protected floor on either OS (no part of the base system ships
# a load-bearing node), so every Node install found is removed.
# Two guard rails enforce all of this:
#   1. Every direct delete must resolve to a path under $HOME, or it is refused.
#   2. Every apt purge is simulated first. It is skipped unless apt can cleanly
#      resolve the removal AND it touches no protected core package (apt, dpkg,
#      python3, the package backing /usr/bin/python3, ubuntu-*, systemd, ...).
#      A simulation that errors out (non-zero exit / "unmet dependencies") means
#      the removal would break the dependency graph -- so we fail safe and skip.
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
  printf '\nThis will permanently delete the Python and Node toolchains listed above.\n'
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
# 3. Node version managers, package-manager caches, and config (both OSes; $HOME)
# ================================================================================
log "Removing Node version managers (nvm / fnm / nodenv / volta)"
for p in .nvm .fnm .nodenv .volta \
         .local/share/fnm "Library/Application Support/fnm" "Library/Caches/fnm"; do
  rmrf "$HOME/$p"
done

# asdf is multi-language; remove only its Node plugin + installed node versions,
# never the whole ~/.asdf (that would take out other languages it manages).
log "Removing asdf Node plugin + versions (leaving the rest of asdf intact)"
rmrf "$HOME/.asdf/plugins/nodejs"
rmrf "$HOME/.asdf/installs/nodejs"

log "Removing npm cache, config, and user-global package dirs"
for p in .npm .npmrc .npm-global .npm-packages .node-gyp .node_modules \
         .node_repl_history .cache/node .cache/node-gyp "Library/Caches/node-gyp"; do
  rmrf "$HOME/$p"
done

log "Removing yarn caches + config"
for p in .yarn .yarnrc .yarnrc.yml .cache/yarn .config/yarn "Library/Caches/Yarn"; do
  rmrf "$HOME/$p"
done

log "Removing pnpm store + config"
for p in .pnpm-store .pnpm-state .local/share/pnpm .config/pnpm \
         "Library/pnpm" "Library/Caches/pnpm"; do
  rmrf "$HOME/$p"
done

log "Removing corepack + bun + deno"
for p in .local/share/corepack "Library/Caches/corepack" .bun \
         .deno .cache/deno "Library/Caches/deno"; do
  rmrf "$HOME/$p"
done

# ================================================================================
# 4. OS package manager: remove non-system Python and Node distributions
# ================================================================================
if [[ "$OS" == "macos" ]]; then
  if command -v brew >/dev/null 2>&1; then
    # Uninstall every installed formula whose name matches $1 (anchored regex);
    # $2 is a label for logging. Plain string + while-read (not mapfile) so this
    # also runs under the macOS system bash 3.2 -- a toolchain-removal script must
    # not lean on Homebrew bash. No --force / --ignore-dependencies: if something
    # still depends on a formula, surface it instead of breaking that tool.
    brew_remove_matching() {
      local regex="$1" label="$2" matches
      matches="$(brew list --formula 2>/dev/null | grep -E "$regex" || true)"
      if [[ -z "$matches" ]]; then
        log "No Homebrew $label installed"
        return 0
      fi
      log "Removing Homebrew $label: $(printf '%s' "$matches" | tr '\n' ' ')"
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if ! run brew uninstall "$f"; then
          warn "could not uninstall $f -- something still depends on it:"
          brew uses --installed "$f" 2>/dev/null | sed 's/^/      /' || true
        fi
      done <<< "$matches"
    }

    brew_remove_matching '^python(@[0-9.]+)?$' "pythons"
    brew_remove_matching '^(node(@[0-9.]+)?|nodejs|yarn|pnpm|fnm|nvm|nodenv|volta|bun|deno)$' "node toolchains"
    run brew autoremove
    run brew cleanup -s
  else
    warn "Homebrew not found -- skipping brew removal"
  fi

elif [[ "$OS" == "ubuntu" ]]; then
  # guard rail #2: simulate each purge and skip it unless apt can cleanly resolve
  # the removal AND it touches no protected core package.
  PROTECTED='apt|apt-utils|dpkg|libapt-pkg[0-9.]*|python3|python3-minimal|libpython3-stdlib|libpython3\.[0-9]+-minimal|libpython3\.[0-9]+-stdlib|ubuntu-minimal|ubuntu-standard|ubuntu-desktop|ubuntu-server|systemd|gdm3|netplan\.io|software-properties-common|update-manager-core|command-not-found'

  # Resolved package that owns the OS interpreter (e.g. /usr/bin/python3 ->
  # python3.12 -> the `python3.12` package). Computed below once apt/dpkg are
  # confirmed present; we must never purge it, and on stock Ubuntu it is exactly
  # what the versioned-interpreter scan finds.
  SYS_PKG=""

  apt_safe_purge() {
    local pkg="$1"
    dpkg -l "$pkg" 2>/dev/null | grep -q '^ii' || return 0   # not installed

    # Never touch the package backing the OS interpreter.
    if [[ -n "$SYS_PKG" && "$pkg" == "$SYS_PKG" ]]; then
      warn "skipping '$pkg' -- it backs the protected system interpreter ($SYSTEM_PY)"
      return 0
    fi

    # Simulate the exact purge we would run. Keep the assignment inside the `if`
    # so `set -e` does not abort on apt's non-zero exit -- we want to inspect it.
    local sim rc
    if sim="$(apt-get -s purge "$pkg" 2>&1)"; then rc=0; else rc=$?; fi

    # Fail safe: a resolver error / "unmet dependencies" means the removal would
    # break the dependency graph (e.g. python3 depends on python3.12). The old
    # code read the absence of `Remv` lines here as "harmless" and proceeded --
    # that is how the system interpreter slipped past the guard. Refuse instead.
    if [[ $rc -ne 0 ]] || grep -qiE '^(E:|the following packages have unmet dependencies)' <<<"$sim"; then
      warn "skipping '$pkg' -- apt cannot cleanly remove it (would break dependencies)"
      return 0
    fi
    if grep -qE "^Remv ($PROTECTED) " <<<"$sim"; then
      warn "skipping purge of '$pkg' -- would cascade into protected core packages"
      return 0
    fi

    # A failed real purge must not abort the whole teardown (set -e); warn on.
    run sudo apt-get -y purge "$pkg" || warn "purge of '$pkg' failed -- continuing"
  }

  if command -v apt-get >/dev/null 2>&1; then
    # Resolve the package that owns the real interpreter behind /usr/bin/python3
    # and add it to the protected set, so neither a direct purge nor a cascade
    # can take it out. basename-of-symlink (the old approach) gave "python3",
    # which never matched the real "python3.12" package being deleted.
    if [[ -x "$SYSTEM_PY" ]]; then
      sys_real="$(readlink -f "$SYSTEM_PY" 2>/dev/null || printf '%s' "$SYSTEM_PY")"
      SYS_PKG="$(dpkg -S "$sys_real" 2>/dev/null | head -n1 | cut -d: -f1 || true)"
    fi
    if [[ -n "$SYS_PKG" ]]; then
      PROTECTED="$PROTECTED|$(printf '%s' "$SYS_PKG" | sed 's/[.]/\\./g')"
      log "Purging apt-installed alternate interpreters (system package '$SYS_PKG' is protected)"
    else
      log "Purging apt-installed alternate interpreters (system package unresolved; relying on dependency guard)"
    fi

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

    # Node toolchains installed via apt (nodejs/npm, plus the yarn apt repo).
    # No protected floor here -- nothing in the base system ships a load-bearing
    # node -- but apt_safe_purge still refuses anything that would cascade into a
    # protected core package.
    log "Purging apt-installed Node toolchains (nodejs / npm / yarn)"
    for pkg in nodejs npm yarn; do
      apt_safe_purge "$pkg"
    done

    # NodeSource / Yarn apt repos live outside $HOME; we never edit system files
    # automatically -- just report them so a later apt-get does not silently
    # resurrect node.
    for f in /etc/apt/sources.list.d/nodesource.list \
             /etc/apt/sources.list.d/yarn.list \
             /etc/apt/keyrings/nodesource.gpg \
             /usr/share/keyrings/yarnkey.gpg; do
      [[ -e "$f" ]] && warn "leftover apt repo file (remove by hand): $f"
    done

    run sudo apt-get -y autoremove --purge || warn "autoremove failed -- continuing"
  else
    warn "apt-get not found -- skipping apt python removal"
  fi
fi

# ================================================================================
# 5. Report shell-rc lines that still reference removed tools (NOT auto-edited)
# ================================================================================
log "Scanning shell rc files for stale Python/Node references (edit these by hand)"
RC_PATTERN='pyenv|conda|miniconda|anaconda|miniforge|mambaforge|/uv\b|pipx|/Library/Python|\.local/lib/python|python@|deadsnakes|nvm|NVM_DIR|fnm|nodenv|volta|\.npm|npm-global|npm-packages|pnpm|PNPM_HOME|corepack|\.bun|BUN_INSTALL|N_PREFIX|yarn|deno|DENO_INSTALL'
for rc in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zshenv" \
          "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
  [[ -f "$rc" ]] || continue
  if grep -nE "$RC_PATTERN" "$rc" >/dev/null 2>&1; then
    printf '    %s:\n' "$rc"
    grep -nE "$RC_PATTERN" "$rc" | sed 's/^/      /'
  fi
done

# ================================================================================
# 6. Final state
# ================================================================================
log "Done. Remaining Python/Node commands on PATH:"
for c in python python3 pip pip3 pyenv conda uv uvx pipx poetry \
         node nodejs npm npx yarn pnpm corepack nvm fnm volta nodenv bun deno; do
  if p="$(command -v "$c" 2>/dev/null)"; then
    printf '      %-8s -> %s\n' "$c" "$p"
  fi
done

cat <<EOF

The only Python that should remain is the OS system interpreter
(${SYSTEM_PY:-/usr/bin/python3}) -- that is the floor on $OS and removing it
would break core OS tooling. Node has no protected floor, so any 'node' still
shown above is one this script could not reach (e.g. a system-prefix global
install, or an nvm/fnm shim left on PATH for the *current* shell). Open a new
shell (or 'exec \$SHELL') so PATH and any rc edits take effect.
EOF
