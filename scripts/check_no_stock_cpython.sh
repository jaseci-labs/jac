#!/usr/bin/env bash
# Fails when a tracked file names stock CPython as a build or runtime
# dependency: JacPython is the only Python jac builds on, ships or runs.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
# Selecting, building, caching or fetching stock CPython, and the stock
# bootstrap host (its graph patches and its <platform>.host tree).
deny=$(cat <<'EOF'
-Dpython=cpython
jacpython-host=stock
\.python-build["']?(/|, *["'])cpython
\.(precompiled-build|payload-layers)/cpython
(python-build-v[0-9]+|jac-bin-v[0-9]+|jac-precompiled|payload-layers)-cpython
python_cpython
^[[:space:]]*(python|PYTHON):[[:space:]]*["']?cpython
["']cpython["'],[[:space:]]*["']jacpython["']
(build|host)-graph\.patch
\}\.host["']
\.host/python/
actions/setup-python
FROM python:
EOF
)
# Lines that keep the ABI identity wheels and C extensions load against.
abi='sys\.implementation\.name|cache_tag|SOABI|cpython-3[0-9]+-|cp3[0-9]+|Include/cpython|LICENSE\.cpython|PSF'
# Files that may: the pinned source archive (Lib/ and the tests), the manual
# compatibility verdict against stock CPython, plain-source export, history
# and this gate.
hits=$(git grep -nIE -f <(printf '%s\n' "$deny") -- . \
  ':(exclude)jac/bootstrap/python/sources.json' ':(exclude)jac/bootstrap/python/cpython-sources.txt' \
  ':(exclude).github/workflows/jacpython-compat.yml' ':(exclude,glob)scripts/cpython_compat*.jac' \
  ':(exclude).github/actions/polyglot-source/Dockerfile' ':(exclude,glob)**/release_notes/**' \
  ':(exclude,glob)**/CHANGELOG*' ':(exclude)scripts/check_no_stock_cpython.sh' | grep -vE "$abi" || true)
if [ -z "$hits" ]; then
  echo "No tracked file names stock CPython as a build or runtime dependency."
  exit 0
fi
sed -E 's/^([^:]*):([0-9]+):(.*)$/::error file=\1,line=\2::names stock CPython as a build or runtime dependency: \3/' <<<"$hits"
echo "JacPython is the only Python. ABI identity, the pinned source archive or history belong in this script's exemptions." >&2
exit 1
