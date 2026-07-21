#!/usr/bin/env bash
# Fast differential-identity gate: every kernel, three GC modes, small sizes.
# Byte-identical stdout (minus the ns= timing line) across modes, and the
# enforced build must pass --assert-no-rc. Also validates the eraser: the
# fully erased source must reproduce the annotated digest under rc.
set -euo pipefail
cd "$(dirname "$0")"

declare -A ARGS=(
  [own_binarytrees]="10"
  [own_vecdot]="2000 20"
  [own_histogram]="20000 5"
  [own_vm]="500 200"
  [own_rbtree]="5000 3"
  [own_deriv]="40 10"
)

mkdir -p bin results
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail=0

for k in own_binarytrees own_vecdot own_histogram own_vm own_rbtree own_deriv; do
  for mode in none rc cycles; do
    if [ "$mode" = none ]; then
      flags=(--enforce-nogc --gc none --assert-no-rc)
    else
      flags=(--gc "$mode")
    fi
    jac nacompile "kernels/$k.jac" "${flags[@]}" -o "bin/${k}_${mode}" \
      > "$TMP/${k}_${mode}.log" 2>&1 || {
        echo "FAIL compile $k/$mode"; tail -3 "$TMP/${k}_${mode}.log"; fail=1; continue;
      }
    # shellcheck disable=SC2086
    "bin/${k}_${mode}" ${ARGS[$k]} | grep -v '^ns=' > "$TMP/${k}_${mode}.out" \
      || { echo "FAIL run $k/$mode"; fail=1; }
  done
  if cmp -s "$TMP/${k}_none.out" "$TMP/${k}_rc.out" \
     && cmp -s "$TMP/${k}_rc.out" "$TMP/${k}_cycles.out"; then
    echo "identity OK: $k"
  else
    echo "IDENTITY FAIL: $k"; fail=1
  fi
  jac run harness/erase.jac "kernels/$k.jac" > "$TMP/${k}_bare.jac"
  jac nacompile "$TMP/${k}_bare.jac" --gc rc -o "$TMP/${k}_bare" \
    > "$TMP/${k}_bare.log" 2>&1 || {
      echo "FAIL erased compile $k"; tail -3 "$TMP/${k}_bare.log"; fail=1; continue;
    }
  # shellcheck disable=SC2086
  "$TMP/${k}_bare" ${ARGS[$k]} | grep -v '^ns=' > "$TMP/${k}_bare.out" || fail=1
  if cmp -s "$TMP/${k}_bare.out" "$TMP/${k}_rc.out"; then
    echo "erasure OK:  $k"
  else
    echo "ERASURE FAIL: $k"; fail=1
  fi
done

exit $fail
