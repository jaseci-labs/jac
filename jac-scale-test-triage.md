# jac-scale CI test triage (PR #6850)

Tracking doc for the jac-scale test-discovery work. One section per CI run so we can
see progress over time.

---

## Run 1 - single-process auto-discovery (baseline)

Commit: first auto-discovery attempt (`pytest jac-scale/jac_scale/tests` in one process).

**Result: 838 tests -> 693 passed, 145 failed (15m46s, single process).**

### Headline

Not 145 broken tests. Running every file in **one shared process** let tests pollute each
other's global state (Jac runtime context, in-memory DB, admin identity, fixed ports). This is
exactly why the old workflow listed each file separately - each `pytest <file>` got a fresh
process.

### Cause breakdown

| Code | Meaning | Approx failures |
|---|---|---:|
| ISO | Cross-test contamination - shared process, fixed ports, warm caches, leaked identity/DB | ~110 (vast majority) |
| SVC | Needs a live service (Redis/MongoDB) - mostly perf tests | ~10 |
| K8S | Needs the kubernetes client/cluster | ~5 |
| PROM | Needs Prometheus running | ~6 |
| WARN | A `DeprecationWarning` promoted to error by `pytest.ini` | ~14 (SSO) |

Worst contamination victims (all pass in their own CI step today): test_sso (15/36),
test_admin (13/16), test_restspec (2/9), test_file_upload (2/7), test_webhook (7/6),
test_serve (22/3), test_memory_hierarchy (24/3), test_middleware_async_root (0/2),
test_microservice (3/2), test_s3_storage (16/2).

---

## Run 2 - per-file isolation + 4 parallel shards (fix applied)

Commit: `0f5860687`. Each file runs in its own pytest process (`-x` per file); files are
sharded across 4 runners by index. Run id 27895990690.

**Result: contamination cleared. Failing files 26 -> 17. ~3 min per shard.**

The Run 1 contamination victims (test_sso, test_admin, test_serve, test_restspec, test_webhook,
test_memory_hierarchy, test_middleware_async_root, test_microservice, test_s3_storage) **all pass
now** and are gone from the list. What remains is the genuine tail.

### Remaining failing files (17)

`-x` stops each file at its first failure, so "Failed" = at-least-1, not a total.

| Test file | Passed before stop | Failed | Category | First error |
|---|---:|---:|---|---|
| test_cluster_provider | 0 | 1 | K8S | needs kubernetes client |
| test_database_provisioner | 0 | 1 | K8S | `None has no attribute 'AppsV1Api'` |
| test_keda_autoscaler | - | ERR | K8S | collection error (kubernetes lib) |
| test_ingress_tls_preservation | - | ERR | K8S | collection error (kubernetes lib) |
| test_redis_memory_leak | 0 | 1 | SVC | needs live Redis |
| test_redis_batch_overhead | 0 | 1 | SVC | needs live Redis |
| test_connection_overhead | 0 | 1 | SVC | perf, needs services |
| test_jwt_validation_overhead | 0 | 1 | SVC | perf, needs MongoDB |
| test_metrics | 3 | 1 | PROM | `'NoneType' object is not callable` |
| test_factories | - | ERR | INV | collection error - investigate |
| test_gateway | 14 | 1 | INV | one `AssertionError` in an otherwise-green file |
| test_sv_auth_forward | 23 | 1 | INV | `NoneType has no attribute '__dict__'` |
| test_direct_db | 10 | 1 | INV | `NoneType has no attribute '__dict__'` (likely needs Mongo) |
| test_topology_slice_pushdown | 0 | 1 | INV | `AssertionError` edge-ref |
| test_file_upload | 0 | 1 | INV | `AssertionError` |
| test_user_identity | 0 | 1 | INV | `'NoneType' object is not subscriptable` |
| test_abstractions | 4 | 1 | INV | `AssertionError` |

### Category summary (Run 2)

| Code | Meaning | Files |
|---|---|---:|
| K8S | Needs kubernetes client/cluster | 4 |
| SVC | Needs Redis/MongoDB | 4 |
| PROM | Needs Prometheus | 1 |
| INV | Genuine - needs per-file investigation (several are 1 failing test in an otherwise-passing file) | 8 |

### Next steps

1. Gate SVC/K8S/PROM tests behind service availability (markers + service containers in CI),
   or split them into an integration tier separate from unit tests.
2. Investigate the 8 INV files - several are a single failing assertion in an otherwise-green
   file, so likely small real bugs or a missed service dependency (test_direct_db looks Mongo-bound).
3. Silence the specific SSO `DeprecationWarning` (the WARN bucket from Run 1).

### Broader observation

The suite mixes unit and integration tests in one pipeline and relies on process-per-file
isolation rather than proper fixture teardown. A follow-up audit should split unit vs
integration tiers and fix shared-state leakage at the fixture level.

---

## Run 4 - per-file verdicts + fixes applied (commit `6f2516c58`)

Investigated each of the 14 remaining failures and applied fixes. Verdict: all are real
(fix), none bloated (remove). Most were test drift after past API redesigns; one was a real
product bug the test correctly caught.

Fixed:
- **Test drift (8):** stale `register_user` helper in the 4 perf tests (now nested
  identities/credential + separate login); test_abstractions (`.value`); test_cluster_provider
  (scrape-port returns container port); test_factories (static `from_dict(cls, ...)`);
  test_gateway (pin static admin branch).
- **Real product bug (1):** `PrometheusMetricsCollector` used the global prometheus `REGISTRY`
  -> duplicate-timeseries collision; now owns an isolated `CollectorRegistry`.

Verified locally (jac-local-new): test_abstractions 6/6, test_cluster_provider 3/3, the
targeted from_dict and prometheus-namespace cases pass.

### Key insight: `-x` was masking multiple failures per file

The per-file run used `pytest -x` (stop at first failure), so each file reported only its
FIRST failure. Fixing it surfaces the next. Already seen:
- test_factories: `from_dict` fixed -> now `deployment target with logger` fails
  (`deployment_factory` has no attribute `KubernetesTarget` - genuine, not env; kubernetes 34.1.0
  is installed locally).
- test_metrics: registry fixed -> now `noop/prometheus implements interface` fail
  (`hasattr(collector, "init")` is False at runtime though `init` is defined in the .jac -
  separate genuine issue).

Dropped `-x` from the CI loop so one run now enumerates EVERY failure per file. Run 5 (next CI
run) will give the complete remaining backlog.
