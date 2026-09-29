"""Records what watch_scale_targets yields during a real cluster cycle.

Run alongside a live scale-to-zero cycle, not standalone: it waits for the
namespace's first ScaledObject, watches until its deadline, and appends one line
per transition. The e2e that drives the cycle asserts on those lines afterwards,
so this process only has to observe and never decides whether the run passed.

Env:
  E2E_NAMESPACE        namespace to watch (required)
  E2E_TRANSITIONS_OUT  file to append transitions to (required)
  E2E_WATCH_SECONDS    how long to keep watching (default 900)
  E2E_WAIT_SECONDS     how long to wait for the first ScaledObject (default 300)
"""

import os;
import sys;
import time;
import from jaclang.scale._optdeps.kubernetes { config, ApiException }
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }


def _log(line: str) {
    print(f"[observer] {line}", flush=True);
}


def _wait_for_first_target(keda: any, namespace: str, deadline: float) -> bool {
    """True once the namespace holds a ScaledObject the watch can resume from.

    A watch opened before KEDA has created anything has no resourceVersion to
    start from, so the recorder would race the deploy it is meant to observe.
    """;
    while time.time() < deadline {
        try {
            (targets, version) = keda._list_scale_targets(namespace);
        } except ApiException as e {
            _log(f"list failed ({e.status}); retrying");
            time.sleep(5);
            continue;
        } except Exception as e {
            _log(f"list error ({e}); retrying");
            time.sleep(5);
            continue;
        }
        if targets {
            _log(f"first targets {sorted(targets.keys())} at version {version}");
            return True;
        }
        time.sleep(5);
    }
    return False;
}


with entry {
    namespace = os.environ.get("E2E_NAMESPACE", "").strip();
    out_path = os.environ.get("E2E_TRANSITIONS_OUT", "").strip();
    if not namespace or not out_path {
        _log("E2E_NAMESPACE and E2E_TRANSITIONS_OUT are required");
        sys.exit(2);
    }
    watch_seconds = float(os.environ.get("E2E_WATCH_SECONDS", "900"));
    wait_seconds = float(os.environ.get("E2E_WAIT_SECONDS", "300"));

    config.load_kube_config();
    keda = KEDAAutoscaler();

    if not _wait_for_first_target(keda, namespace, time.time() + wait_seconds) {
        _log(f"no ScaledObject appeared in '{namespace}' within {wait_seconds}s");
        sys.exit(1);
    }

    deadline = time.time() + watch_seconds;
    seen = 0;
    # Each pass returns when its own timeout elapses, so the loop is what keeps
    # observing across the whole cycle and also exercises resuming a watch.
    while time.time() < deadline {
        remaining = int(max(5.0, min(120.0, deadline - time.time())));
        try {
            for moved in keda.watch_scale_targets(
                namespace, timeout_seconds=remaining
            ) {
                line = (
                    f"{moved.scale_target_name} "
                    f"{moved.previous_state.value if moved.previous_state else 'none'} "
                    f"-> {moved.state.value} "
                    f"reason={moved.reason or '-'} "
                    f"rv={moved.resource_version or '-'} "
                    f"at={moved.observed_at}"
                );
                _log(line);
                with open(out_path, "a") as fh {
                    fh.write(line + "\n");
                }
                seen += 1;
            }
        } except Exception as e {
            _log(f"watch pass ended ({type(e).__name__}: {e}); reopening");
            time.sleep(2);
        }
    }
    _log(f"recorded {seen} transition(s)");
}
