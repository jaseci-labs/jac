#!/usr/bin/env bash
# Jac's Python runtime is JacPython; nothing in the tree names another
# implementation except where the name is part of the Python ABI or of the
# attribution the vendored sources carry:
#   - the vendored standard library and conformance suites (PSF-licensed);
#   - the C API headers' own layout (Include/cpython/, cpython/<header>.h,
#     the "cpython" directory build_jacpython.zig installs them under);
#   - Python's documented audit event names (cpython.run_command, ...);
#   - the ABI and cache tags (cpython-314, SOABI cpython-314-<triplet>);
#   - the PSF notice (LICENSE.cpython);
#   - the interpreter identity sys.implementation and platform report
#     (object_model/sysmodule.jac), which wheel tags and C extensions key on;
#   - release-note history;
#   - the manual compatibility verdict (jacpython-compat.yml and
#     scripts/cpython_compat*), whose subject is a comparison with stock
#     CPython, and the only place the repository runs it.
# Every other mention fails, with its file and line.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

excluded=(
  ':!jac/bootstrap/python/src/**'
  ':!jac/tests/python_conformance/**'
  ':!jac/bootstrap/python/generated/**'
  ':!jac/jaclang/runtime/python/LICENSE.cpython'
  ':!jac/jaclang/cli/docs/community/release_notes/**'
  ':!release_notes/**'
  ':!scripts/check_python_references.sh'
  ':!.github/workflows/jacpython-compat.yml'
  ':!scripts/cpython_compat.jac'
  ':!scripts/cpython_compat.test.jac'
  ':!scripts/cpython_compat.json'
)
export ALLOWED='LICENSE\.cpython|Include/cpython\b|(?<![A-Za-z])cpython/[A-Za-z0-9_./]+|cpython-(3\d+|\{)|(?<![A-Za-z])cpython\.[A-Za-z_]\w*'
# The files whose bare "cpython" / "CPython" literal is the identity or the
# header directory.
export LITERALS='^(jac/jaclang/runtime/python/object_model/sysmodule\.jac|jac/bootstrap/build_jacpython\.zig)$'

# git grep exits 1 when nothing matches; any other failure, or perl's, fails.
matches=$(git grep -n -i -P '(?<![a-z])cpython' -- . "${excluded[@]}") || [ $? -eq 1 ]
found=$(printf '%s\n' "$matches" | perl -ne '
  next unless /^([^:]+):(\d+):(.*)$/;
  my ($path, $text) = ($1, $3);
  $text =~ s{$ENV{ALLOWED}}{}gi;
  $text =~ s{"cpython"}{}gi if $path =~ /$ENV{LITERALS}/;
  print if $text =~ /(?<![a-z])cpython/i;
')
if [ -n "$found" ]; then
  printf '%s\n' "$found"
  echo "::error::$(printf '%s\n' "$found" | wc -l | tr -d ' ') lines name CPython; Jac's Python is JacPython (see scripts/check_python_references.sh for what may stay)"
  exit 1
fi
echo "No CPython references outside the allowlist."
