#!/usr/bin/env bash
# Proves watch_scale_targets observes a real scale-to-zero cycle (#7405 criterion 12).
#
# Wraps the HTTP-activation e2e rather than deploying its own app: that script
# already drives a full 0 -> 1 -> ready -> 0 cycle on a live cluster, and a
# second deploy would add minutes of CI for a cycle we already pay for. The
# recorder watches while it runs; this script asserts on what it recorded.
#
# The wrapped script is the source of truth for pass/fail of the deploy itself,
# so its exit code is honoured before any transition is inspected.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="${1:-${HERE}/../fixtures/keda_http_activation_e2e}"
INNER_E2E="${HERE}/keda_http_activation_real_e2e.sh"
RECORDER="${HERE}/observer_transition_recorder.jac"

for required in "${INNER_E2E}" "${RECORDER}"; do
    if [[ ! -f "${required}" ]]; then
        echo "missing ${required}" >&2
        exit 2
    fi
done

# Read the namespace straight out of jac.toml, the same way the wrapped e2e
# reads its own config: importing jac-scale to resolve it would compile modules
# and print setup lines into the value being captured.
CFG=$(cd "${FIXTURE_DIR}" && jac -c "
import tomllib
with open('jac.toml', 'rb') as f:
    cfg = tomllib.load(f)
print(cfg['scale']['kubernetes'].get('namespace', 'default'))
")
NAMESPACE=$(echo "${CFG}" | sed -n '1p')

# A namespace read wrongly would leave the observer watching nothing while the
# cycle succeeded elsewhere, so reject anything that is not a DNS label rather
# than discovering it as "no transitions recorded" minutes later.
if [[ ! "${NAMESPACE}" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
    echo "resolved namespace '${NAMESPACE}' is not a DNS label; check the fixture" >&2
    exit 2
fi
echo "fixture namespace: ${NAMESPACE}"

TRANSITIONS="$(mktemp)"
RECORDER_LOG="$(mktemp)"
CYCLE=""
RECORDER_PID=""

cleanup() {
    rc=$?
    if [[ -n "${RECORDER_PID}" ]] && kill -0 "${RECORDER_PID}" 2>/dev/null; then
        kill "${RECORDER_PID}" 2>/dev/null || true
        wait "${RECORDER_PID}" 2>/dev/null || true
    fi
    echo "=== recorder log ==="
    cat "${RECORDER_LOG}" || true
    echo "=== transitions recorded ==="
    cat "${TRANSITIONS}" || true
    rm -f "${TRANSITIONS}" "${RECORDER_LOG}" "${CYCLE:-}"
    # The inner e2e hands its namespace over rather than deleting it, so the
    # recorder above could read a settled idle state instead of a terminating
    # one. Teardown lands here, after the recorder is stopped.
    if [[ "${rc}" != "0" && "${E2E_KEEP_NS_ON_FAIL:-1}" == "1" ]]; then
        echo "=== observer e2e failed (rc=${rc}); KEEPING namespace '${NAMESPACE}' for inspection (set E2E_KEEP_NS_ON_FAIL=0 to force cleanup) ==="
    else
        kubectl delete namespace "${NAMESPACE}" --ignore-not-found \
            --timeout="${DELETE_TIMEOUT:-120}s" || true
    fi
    exit "${rc}"
}
trap cleanup EXIT

echo "=== start the observer on namespace '${NAMESPACE}' ==="
E2E_NAMESPACE="${NAMESPACE}" \
E2E_TRANSITIONS_OUT="${TRANSITIONS}" \
E2E_WATCH_SECONDS="${E2E_WATCH_SECONDS:-900}" \
E2E_WAIT_SECONDS="${E2E_WAIT_SECONDS:-420}" \
    jac run "${RECORDER}" >"${RECORDER_LOG}" 2>&1 &
RECORDER_PID=$!

echo "=== drive a real cycle via the HTTP-activation e2e ==="
# Its exit code decides whether a cycle happened at all; a transition assertion
# on a failed deploy would be meaningless.
E2E_KEEP_NS=1 bash "${INNER_E2E}" "${FIXTURE_DIR}"

echo "=== stop the observer and inspect what it saw ==="
# The namespace is still up, so this waits out one more poll of a workload that
# is genuinely idle at zero. Deleting first made the same wait read teardown:
# the last transition landed on degraded or unknown, never on inactive.
sleep 15
if kill -0 "${RECORDER_PID}" 2>/dev/null; then
    kill "${RECORDER_PID}" 2>/dev/null || true
    wait "${RECORDER_PID}" 2>/dev/null || true
fi
RECORDER_PID=""

if [[ ! -s "${TRANSITIONS}" ]]; then
    echo "FAIL: the observer recorded no transitions during a cycle that completed" >&2
    exit 1
fi

# The cycle under test ends when the target returns to inactive. The wrapped
# e2e deletes the namespace from its own cleanup trap, which runs before the
# observer is stopped, so anything recorded after that point is teardown: the
# ScaledObject going unready as it is removed, then the Deployment vanishing.
# Asserting over those would make this fail on how fast a namespace deletes,
# which is not what the cycle is being judged on. Truncate at the first
# inactive, and fail loudly if the cycle never got there.
CYCLE="$(mktemp)"
if ! grep -qE " -> inactive( |$)" "${TRANSITIONS}"; then
    echo "FAIL: never observed a transition into 'inactive'" >&2
    cat "${TRANSITIONS}" >&2
    exit 1
fi
awk '{ print } / -> inactive( |$)/ { exit }' "${TRANSITIONS}" > "${CYCLE}"
echo "=== cycle under test (teardown excluded) ==="
cat "${CYCLE}"

# A watch that yields events is the claim the unit tests cannot make, so assert
# on the states actually observed rather than on a count.
STATES="$(awk '{print $4}' "${CYCLE}" | tr '\n' ' ')"
echo "observed states: ${STATES}"

assert_saw() {
    if ! grep -qE " -> $1( |$)" "${CYCLE}"; then
        echo "FAIL: never observed a transition into '$1'" >&2
        exit 1
    fi
    echo "ok: observed a transition into '$1'"
}

# The wake is the half a Deployment-only watch would also catch; inactive is the
# half that only exists because the floor is read from the live ScaledObject.
assert_saw "active"
assert_saw "inactive"

# Dedup is the property that makes the stream usable: the same state must never
# be emitted twice in a row for one target.
if awk '{ key=$1; state=$4; if (key==lk && state==ls) { print; } lk=key; ls=state; }' \
        "${CYCLE}" | grep -q .; then
    echo "FAIL: the same state was emitted twice in a row for one target" >&2
    exit 1
fi
echo "ok: no consecutive duplicate state for any target"

# A transition must never claim a previous state it did not observe, and the
# first sighting of a target is the only place 'none' is legitimate.
if awk 'NR>1 && $2=="none"' "${CYCLE}" | grep -q .; then
    echo "FAIL: a later transition reported no previous state" >&2
    exit 1
fi
echo "ok: previous_state is only absent on a first sighting"

# A healthy cycle must never report degraded. This is the assertion that was
# missing when this e2e first ran: it recorded two spurious inactive -> degraded
# transitions from KEDA's HPA reporting ScalingActive False at zero replicas,
# and passed anyway because it only checked that active and inactive appeared.
if grep -qE " -> degraded( |$)" "${CYCLE}"; then
    echo "FAIL: a healthy cycle reported degraded" >&2
    grep -E " -> degraded( |$)" "${CYCLE}" >&2
    exit 1
fi
echo "ok: no degraded transition during a healthy cycle"

echo "=== KEDA observer REAL e2e PASSED ==="
