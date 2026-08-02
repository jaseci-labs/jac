# CI routing manifest

The PR path classifier lives in `scripts/ci/` and is enforced by `.github/workflows/ci.yml`.

## How to add a routable job

Adding a job that can be selected (or skipped) on pull requests requires a **four-way sync**. `check-ci-coverage.sh` fails if any piece is missing. Jobs that are structurally absent on some workflow events (their own `if:` in `ci.yml` never admits them there) must also be listed under `event_excluded_jobs` in the manifest so `validate-expected-jobs.sh` does not fail full-mode runs on those events. Keep that list in sync with each job's `if:` gate: under-listing breaks the aggregate gate; over-listing silently masks a job that should have run.

1. **`ci-coverage.yml`**: add the job id to the `jobs:` list. If the job is gated by path globs, add a `conditional_jobs:` entry (or a `cross_seam:` rule when multiple categories must fire together).

2. **`.github/workflows/ci.yml`**: define the job with:
   - `needs: [ci-router, build-jac]` (or `needs: ci-router` when the job builds natively and does not use the Linux binary artifact)
   - an `if:` gate that allows non-PR events, `full_ci`, or `needs.ci-router.outputs.run_<job> == 'true'` (hyphens in the job name become underscores in the output name)

3. **`ci-router` outputs**: add `run_<job>: ${{ steps.route.outputs.run_<job> }}` to the `ci-router` job's `outputs:` block. GitHub Actions cannot derive these from a single JSON blob in downstream `if:` expressions, so each routable job gets its own mirrored output.

4. **`everything-passed.needs`**: include the new job id so an unexpected skip fails the aggregate gate.

Jobs in `always_run_jobs` (for example `build-jac`, `jac-check`) and `metadata_jobs` (router, audit, gate) are exempt from per-job `run_*` outputs.

Jobs in `full_ci_excluded_jobs` (for example `installer-test`) are omitted when `full_ci` escalates from path globs, but still selected when their allowlist category or `conditional_jobs` path matches.

Jobs skipped by PR labels (for example `skip-k8s` on k8s lanes) must be listed under `pr_label_skips` in the manifest so `validate-expected-jobs.sh` stays aligned with workflow `if:` gates.

## Local validation

```bash
scripts/ci/check-ci-coverage.sh      # manifest ↔ workflow ↔ router outputs ↔ everything-passed
scripts/ci/verify-shard-inventory.sh # compiler_shards / runtime_shards cover all test files
bash scripts/ci/test/router-tests.sh # classifier fixtures + the checks above
```

## Key files

| File | Role |
|------|------|
| `ci-coverage.yml` | Job inventory, path globs, shard layout, cross-seam rules |
| `classify-changed-files.sh` | Changed paths → `selected_jobs`, `full_ci`, `audit_fail` |
| `check-ci-coverage.sh` | Keeps manifest and workflow in sync |
| `verify-shard-inventory.sh` | Reads `compiler_shards` / `runtime_shards` from the manifest |
| `validate-expected-jobs.sh` | Post-run check that selected jobs did not skip unexpectedly |
